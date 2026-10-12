import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

import '../config/route_config.dart';
// Stops, routes and checkpoint settings live in lib/config/route_config.dart.
// Re-exported so code that already imports this file keeps working.
export '../config/route_config.dart';

enum GpsSource { localSimulation, supabaseTestSimulation, realGps }
enum SimulationStatus { stopped, running, paused }

/// Progress of the route itself, independent of the simulator's run state.
/// notStarted: still at the configured starting stop and not running.
/// inProgress: moving, paused, or stopped after leaving the starting stop.
/// completed: the final stop of the selected sequence has been reached.
enum RouteStatus { notStarted, inProgress, completed }
class GpsSample {
  final LatLng position;
  final DateTime timestamp;
  final GpsSource source;
  const GpsSample(this.position, this.timestamp, this.source);
}
class RouteSnapshot {
  final String scenarioId;
  final List<String> stops;
  final int stopIndex;
  final LatLng position;
  final DateTime timestamp;
  final SimulationStatus status;
  final GpsSource source;
  final String? lastEvent;
  /// Index in [stops] where this trip began (0 unless a mid-route start was chosen).
  final int startIndex;
  const RouteSnapshot({
    required this.scenarioId, required this.stops, required this.stopIndex,
    required this.position, required this.timestamp, required this.status,
    required this.source, this.lastEvent, this.startIndex = 0,
  });
  String get currentStopId => stops[stopIndex.clamp(0, stops.length - 1).toInt()];
  String? get nextStopId => stopIndex + 1 < stops.length ? stops[stopIndex + 1] : null;
  String get currentStopName => routeStops[currentStopId]!.name;
  /// Display name of the active route, for example "Start at PCU".
  String get routeName => routeScenarios[scenarioId]?.name ?? scenarioId;
  /// The stop the shuttle last left on this trip, or null before it has left
  /// its starting stop. A trip that starts part-way along a route never
  /// reports a stop it did not actually visit.
  String? get previousStopId => stopIndex > startIndex ? stops[stopIndex - 1] : null;
  String? get previousStopName =>
      previousStopId == null ? null : routeStops[previousStopId]!.name;
  /// Compass bearing, 0 to 360 degrees clockwise from north, of the straight
  /// leg from the current stop to the next destination. Null when complete.
  double? get expectedBearingDegrees {
    final next = nextStopId;
    if (next == null) return null;
    return RouteStateManager.bearingDegrees(
      routeStops[currentStopId]!.position,
      routeStops[next]!.position,
    );
  }
  /// The same leg as an 8-point compass label (N, NE, E, SE, S, SW, W, NW).
  String? get expectedDirection {
    final bearing = expectedBearingDegrees;
    return bearing == null ? null : RouteStateManager.compassLabel(bearing);
  }
  String get nextDestinationName => nextStopId == null ? 'Route complete' : routeStops[nextStopId]!.name;
  double get progress => stops.length < 2 ? 1 : stopIndex / (stops.length - 1);
  bool get isComplete => nextStopId == null;
  RouteStatus get routeStatus {
    if (isComplete) return RouteStatus.completed;
    if (stopIndex == startIndex && status == SimulationStatus.stopped) {
      return RouteStatus.notStarted;
    }
    return RouteStatus.inProgress;
  }
}

/// Central route/GPS manager shared by simulation and future real GPS input.
/// Database writes are intentionally kept outside this class.
class RouteStateManager {
  RouteStateManager({CheckpointConfig? collegeCheckpoint})
      : _collegeCheckpoint = collegeCheckpoint ?? defaultCollegeCheckpoint;

  RouteSnapshot? _state;
  LatLng? _lastPosition;
  DateTime? _lastTimestamp;
  final Set<String> _processedCrossings = <String>{};
  CheckpointConfig _collegeCheckpoint;
  _PendingCrossing? _pending;
  // Most recent reading clearly on the near side of the line; used as the
  // start of the crossing segment when the previous sample fell in the dead band.
  LatLng? _lastNearPoint;

  CheckpointConfig get collegeCheckpoint => _collegeCheckpoint;
  /// Recalibrate the checkpoint. Discards any crossing awaiting confirmation.
  set collegeCheckpoint(CheckpointConfig config) {
    _collegeCheckpoint = config;
    _pending = null;
    _lastNearPoint = null;
  }
  bool get hasPendingCheckpoint => _pending != null;
  int get pendingConfirmations => _pending?.confirmations ?? 0;
  RouteSnapshot? get state => _state;
  LatLng? get lastAcceptedPosition => _lastPosition;
  DateTime? get lastAcceptedTimestamp => _lastTimestamp;

  RouteSnapshot initialize({
    required String scenarioId, required String startingStopId,
    bool includeCollege = true,
    GpsSource source = GpsSource.localSimulation,
    DateTime? now,
  }) {
    final scenario = routeScenarios[scenarioId];
    if (scenario == null) throw ArgumentError('Unknown route scenario: ' + scenarioId);
    final stops = scenario.stopIdsFor(includeCollege: includeCollege);
    final start = stops.indexOf(startingStopId);
    if (start < 0) throw ArgumentError('Starting stop is not in the selected route');
    final time = (now ?? DateTime.now()).toUtc();
    _lastPosition = routeStops[startingStopId]!.position;
    _lastTimestamp = time;
    _processedCrossings.clear();
    _pending = null;
    _lastNearPoint = null;
    _state = RouteSnapshot(
      scenarioId: scenarioId, stops: List.unmodifiable(stops), stopIndex: start,
      position: _lastPosition!, timestamp: time, status: SimulationStatus.stopped,
      source: source, lastEvent: 'Route initialized; TEST coordinates only',
      startIndex: start,
    );
    return _state!;
  }

  /// Starts a trip from [startingStopId] and lets that stop pick the route:
  /// PCU -> Route A, Robinsons -> Route B, SM Dasma -> Route C. Throws an
  /// [ArgumentError] for a stop that no route starts from (the College Building).
  RouteSnapshot initializeFromStart({
    required String startingStopId,
    bool includeCollege = true,
    GpsSource source = GpsSource.localSimulation,
    DateTime? now,
  }) {
    final route = activeRouteConfig.routeForStart(startingStopId);
    if (route == null) {
      throw ArgumentError('No route starts at stop: $startingStopId');
    }
    return initialize(
      scenarioId: route.id,
      startingStopId: startingStopId,
      includeCollege: includeCollege,
      source: source,
      now: now,
    );
  }

  RouteSnapshot setStatus(SimulationStatus status) {
    final s = _requireState();
    _state = _copy(s, status: status, event: 'Simulation ' + status.name);
    return _state!;
  }

  bool processGps(GpsSample sample, {
    double maxJumpMeters = 1500,
    double minMovementMeters = 0.8,
    Duration maxSampleAge = const Duration(seconds: 30),
    Duration maxFutureSkew = const Duration(seconds: 5),
  }) {
    final s = _requireState();
    final p = sample.position;
    if (!p.latitude.isFinite || !p.longitude.isFinite || p.latitude < -90 ||
        p.latitude > 90 || p.longitude < -180 || p.longitude > 180) {
      _state = _copy(s, event: 'GPS rejected: invalid coordinates');
      return false;
    }
    final now = DateTime.now().toUtc();
    if (sample.timestamp.isBefore(now.subtract(maxSampleAge))) {
      _state = _copy(s, event: 'GPS rejected: stale sample timestamp');
      return false;
    }
    if (sample.timestamp.isAfter(now.add(maxFutureSkew))) {
      _state = _copy(s, event: 'GPS rejected: timestamp is too far in the future');
      return false;
    }
    if (_lastTimestamp != null && !sample.timestamp.isAfter(_lastTimestamp!)) {
      _state = _copy(s, event: 'GPS rejected: duplicate or stale timestamp');
      return false;
    }
    if (_lastPosition != null) {
      final distance = distanceMeters(_lastPosition!, p);
      if (distance > maxJumpMeters) {
        _state = _copy(s, event: 'GPS rejected: implausible ' + distance.toStringAsFixed(0) + ' m jump');
        return false;
      }
      if (distance < minMovementMeters) {
        _state = _copy(s, event: 'GPS rejected: movement within jitter tolerance');
        return false;
      }
    }
    _lastPosition = p;
    _lastTimestamp = sample.timestamp;
    _state = RouteSnapshot(
      scenarioId: s.scenarioId, stops: s.stops, stopIndex: s.stopIndex,
      position: p, timestamp: sample.timestamp, status: s.status,
      source: sample.source, lastEvent: 'GPS position accepted (' + sample.source.name + ')',
      startIndex: s.startIndex,
    );
    return true;
  }

  RouteSnapshot advanceCheckpoint() {
    final s = _requireState();
    _pending = null;
    _lastNearPoint = null;
    if (s.stopIndex + 1 >= s.stops.length) {
      _state = _copy(s, event: 'Route already complete');
      return _state!;
    }
    final index = s.stopIndex + 1;
    final id = s.stops[index];
    final now = DateTime.now().toUtc();
    final last = _lastTimestamp;
    final time = last != null && !now.isAfter(last)
        ? last.add(const Duration(microseconds: 1))
        : now;
    final pos = routeStops[id]!.position;
    _lastPosition = pos;
    _lastTimestamp = time;
    _state = RouteSnapshot(
      scenarioId: s.scenarioId, stops: s.stops, stopIndex: index,
      position: pos, timestamp: time, status: s.status, source: s.source,
      lastEvent: 'Checkpoint accepted: ' + routeStops[id]!.name + ' (TEST coordinate)',
      startIndex: s.startIndex,
    );
    return _state!;
  }

  /// Moves back one stop on the same route, keeping its sequence and the
  /// trip's starting point. Position in the sequence is used, never a lookup by
  /// stop id, so stepping back from the second PCU of Route A lands on
  /// Robinsons, not on the first PCU. Stepping back deliberately re-arms the
  /// checkpoint events so the same crossing can be processed again.
  RouteSnapshot retreatCheckpoint() {
    final s = _requireState();
    if (s.stopIndex <= 0) {
      _state = _copy(s, event: 'Already at the first stop');
      return _state!;
    }
    _pending = null;
    _lastNearPoint = null;
    _processedCrossings.clear();
    final index = s.stopIndex - 1;
    final id = s.stops[index];
    final now = DateTime.now().toUtc();
    final last = _lastTimestamp;
    final time = last != null && !now.isAfter(last)
        ? last.add(const Duration(microseconds: 1))
        : now;
    final pos = routeStops[id]!.position;
    _lastPosition = pos;
    _lastTimestamp = time;
    _state = RouteSnapshot(
      scenarioId: s.scenarioId, stops: s.stops, stopIndex: index,
      position: pos, timestamp: time, status: s.status, source: s.source,
      lastEvent: 'Moved back to ${routeStops[id]!.name} (TEST coordinate)',
      startIndex: math.min(s.startIndex, index),
    );
    return _state!;
  }

  /// Pure finite-segment directional crossing test in a local metre projection.
  /// True only when the previous -> current segment actually intersects the
  /// finite checkpoint segment, travelling in the permitted direction, with
  /// both readings outside the tolerance dead band.
  static bool crossesDirectionalSegment({
    required LatLng previous, required LatLng current,
    required LatLng lineStart, required LatLng lineEnd,
    required bool positiveDirection,
    double toleranceMeters = 2.0,
  }) {
    final points = _project(previous, current, lineStart, lineEnd);
    final p = points[0], q = points[1], a = points[2], b = points[3];
    final lx = b.x - a.x, ly = b.y - a.y;
    final lineLength = math.sqrt(lx * lx + ly * ly);
    if (lineLength < 0.01) return false;
    final d1 = (lx * (p.y - a.y) - ly * (p.x - a.x)) / lineLength;
    final d2 = (lx * (q.y - a.y) - ly * (q.x - a.x)) / lineLength;
    if (d1.abs() < toleranceMeters || d2.abs() < toleranceMeters) return false;
    final crossed = (d1 < 0 && d2 > 0) || (d1 > 0 && d2 < 0);
    final directionOk = positiveDirection ? d1 < d2 : d1 > d2;
    if (!crossed || !directionOk) return false;

    // Reject crossing the infinite extension outside the configured segment.
    final mx = q.x - p.x, my = q.y - p.y;
    final denominator = mx * ly - my * lx;
    if (denominator.abs() < 1e-9) return false;
    final t = ((a.x - p.x) * ly - (a.y - p.y) * lx) / denominator;
    final u = ((a.x - p.x) * my - (a.y - p.y) * mx) / denominator;
    return t >= 0 && t <= 1 && u >= 0 && u <= 1;
  }

  /// Signed perpendicular distance in metres from [point] to the infinite line
  /// through [lineStart] and [lineEnd]. Same sign convention as
  /// [crossesDirectionalSegment] and [CheckpointConfig.positiveDirection].
  static double signedDistanceToLine(LatLng point, LatLng lineStart, LatLng lineEnd) {
    final points = _project(point, point, lineStart, lineEnd);
    final p = points[0], a = points[2], b = points[3];
    final lx = b.x - a.x, ly = b.y - a.y;
    final lineLength = math.sqrt(lx * lx + ly * ly);
    if (lineLength < 0.01) return 0;
    return (lx * (p.y - a.y) - ly * (p.x - a.x)) / lineLength;
  }

  /// Directional crossing that is also idempotent per [eventId]: once a
  /// crossing has been reported for an eventId it is never reported again.
  bool crossedDirectionalLine({
    required LatLng previous, required LatLng current,
    required LatLng lineStart, required LatLng lineEnd,
    required bool positiveDirection, required String eventId,
    double toleranceMeters = 2.0,
  }) {
    if (_processedCrossings.contains(eventId)) return false;
    if (!crossesDirectionalSegment(
      previous: previous, current: current,
      lineStart: lineStart, lineEnd: lineEnd,
      positiveDirection: positiveDirection,
      toleranceMeters: toleranceMeters,
    )) {
      return false;
    }
    _processedCrossings.add(eventId);
    return true;
  }

  /// Evaluates the College Building's invisible directional checkpoint using
  /// the configured [collegeCheckpoint]. The route advances only when
  ///  1. College Building is the next destination,
  ///  2. the sample is valid, fresh, plausible and not a jitter/duplicate,
  ///  3. previous -> current crosses the finite line in the permitted direction,
  ///  4. the configured number of confirmation readings then stay on the far
  ///     side, and
  ///  5. the eventId has not already advanced the route.
  /// Distance to the College Building is never used to trigger the transition.
  /// The optional limits override the configured values for a single call.
  bool processCollegeCheckpoint({
    required LatLng previous,
    required LatLng current,
    required DateTime previousTimestamp,
    required DateTime currentTimestamp,
    required String eventId,
    DateTime? now,
    GpsSource source = GpsSource.localSimulation,
    double? maxJumpMeters,
    Duration? maxSampleAge,
    Duration? maxFutureSkew,
    double? toleranceMeters,
  }) {
    final config = _collegeCheckpoint;
    final jumpLimit = maxJumpMeters ?? config.maxJumpMeters;
    final ageLimit = maxSampleAge ?? config.maxSampleAge;
    final skewLimit = maxFutureSkew ?? config.maxFutureSkew;
    final tolerance = toleranceMeters ?? config.toleranceMeters;
    final s = _requireState();
    if (_processedCrossings.contains(eventId)) {
      _state = _copy(s, event: 'Duplicate crossing ignored: event already processed');
      return false;
    }
    if (!canTriggerCollegeCheckpoint()) {
      _pending = null;
      _lastNearPoint = null;
      _state = _copy(s, event: 'Checkpoint rejected: College Building is not the next destination');
      return false;
    }
    final clock = (now ?? DateTime.now()).toUtc();
    if (!currentTimestamp.isAfter(previousTimestamp)) {
      _state = _copy(s, event: 'Checkpoint rejected: GPS timestamps are not increasing');
      return false;
    }
    for (final timestamp in [previousTimestamp, currentTimestamp]) {
      if (timestamp.isBefore(clock.subtract(ageLimit)) ||
          timestamp.isAfter(clock.add(skewLimit))) {
        _state = _copy(s, event: 'Checkpoint rejected: GPS sample is stale or future-dated');
        return false;
      }
    }
    bool valid(LatLng p) => p.latitude.isFinite && p.longitude.isFinite &&
        p.latitude >= -90 && p.latitude <= 90 &&
        p.longitude >= -180 && p.longitude <= 180;
    if (!valid(previous) || !valid(current)) {
      _state = _copy(s, event: 'Checkpoint rejected: invalid GPS coordinates');
      return false;
    }
    if (distanceMeters(previous, current) > jumpLimit) {
      _state = _copy(s, event: 'Checkpoint rejected: implausible GPS jump');
      return false;
    }
    // Every valid sample still updates the tracked shuttle position, even if
    // it did not cross the invisible line; otherwise the next pair is invalid.
    // Duplicate, stale and jitter-sized samples are rejected here, so they can
    // never count as a confirmation reading either.
    if (!processGps(GpsSample(current, currentTimestamp, source),
        maxJumpMeters: jumpLimit, maxSampleAge: ageLimit, maxFutureSkew: skewLimit)) {
      return false;
    }

    // Positive "side" means the far side of the line, i.e. after a permitted crossing.
    final farSign = config.positiveDirection ? 1.0 : -1.0;
    final side = signedDistanceToLine(current, config.lineStart, config.lineEnd) * farSign;

    final pending = _pending;
    if (pending != null) {
      return _confirmPending(pending, side, tolerance, config);
    }

    // If the previous sample sits inside the dead band, measure the crossing
    // from the last reading that was clearly on the near side instead, so a
    // noisy reading near the line cannot hide a real crossing.
    var from = previous;
    final previousSide =
        signedDistanceToLine(previous, config.lineStart, config.lineEnd).abs();
    if (previousSide < tolerance && _lastNearPoint != null) from = _lastNearPoint!;
    final crossed = crossesDirectionalSegment(
      previous: from,
      current: current,
      lineStart: config.lineStart,
      lineEnd: config.lineEnd,
      positiveDirection: config.positiveDirection,
      toleranceMeters: tolerance,
    );
    if (side <= -tolerance) _lastNearPoint = current;
    if (!crossed) {
      _state = _copy(_state!, event: 'Checkpoint waiting: no valid directional line crossing');
      return false;
    }
    if (config.confirmationReadings <= 0) return _commitCheckpoint(eventId);
    _pending = _PendingCrossing(eventId);
    _state = _copy(_state!,
        event: 'Checkpoint waiting: crossing detected, awaiting 0/${config.confirmationReadings} confirmation readings');
    return false;
  }

  bool _confirmPending(
    _PendingCrossing pending,
    double side,
    double tolerance,
    CheckpointConfig config,
  ) {
    if (side <= -tolerance) {
      _pending = null;
      _lastNearPoint = _lastPosition;
      _state = _copy(_state!,
          event: 'Checkpoint waiting: crossing cancelled, shuttle returned to the near side');
      return false;
    }
    if (side < tolerance) {
      _state = _copy(_state!,
          event: 'Checkpoint waiting: confirmation reading is inside the tolerance band');
      return false;
    }
    pending.confirmations++;
    if (pending.confirmations >= config.confirmationReadings) {
      return _commitCheckpoint(pending.eventId);
    }
    _state = _copy(_state!,
        event: 'Checkpoint waiting: confirmation ${pending.confirmations}/${config.confirmationReadings}');
    return false;
  }

  /// The only place a checkpoint crossing advances the route.
  bool _commitCheckpoint(String eventId) {
    _processedCrossings.add(eventId);
    advanceCheckpoint(); // also clears pending and near-side memory
    _state = _copy(_state!, event: 'College Building checkpoint accepted');
    return true;
  }

  /// The College Building event may trigger only when it is actually next.
  bool canTriggerCollegeCheckpoint() => _state?.nextStopId == collegeStopId;

  void reset() {
    _state = null; _lastPosition = null; _lastTimestamp = null;
    _processedCrossings.clear();
    _pending = null;
    _lastNearPoint = null;
  }
  RouteSnapshot _requireState() => _state ?? (throw StateError('Initialize a route before processing GPS'));
  RouteSnapshot _copy(RouteSnapshot s, {SimulationStatus? status, String? event}) => RouteSnapshot(
    scenarioId: s.scenarioId, stops: s.stops, stopIndex: s.stopIndex,
    position: s.position, timestamp: s.timestamp, status: status ?? s.status,
    source: s.source, lastEvent: event, startIndex: s.startIndex,
  );

  static List<_XY> _project(LatLng previous, LatLng current, LatLng a, LatLng b) {
    final refLat = (previous.latitude + current.latitude + a.latitude + b.latitude) / 4;
    final xScale = 111320.0 * math.cos(refLat * math.pi / 180);
    const yScale = 111320.0;
    _XY cv(LatLng v) => _XY(v.longitude * xScale, v.latitude * yScale);
    return [cv(previous), cv(current), cv(a), cv(b)];
  }

  /// Initial great-circle bearing from [from] to [to] in degrees (0 = north).
  static double bearingDegrees(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180, lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// 8-point compass label for a bearing in degrees.
  static String compassLabel(double bearing) {
    const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return labels[(((bearing % 360) + 22.5) % 360 ~/ 45)];
  }

  static double distanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final lat1 = a.latitude * math.pi / 180, lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(h)));
  }
}
class _PendingCrossing {
  final String eventId;
  int confirmations = 0;
  _PendingCrossing(this.eventId);
}
class _XY {
  final double x, y;
  const _XY(this.x, this.y);
}