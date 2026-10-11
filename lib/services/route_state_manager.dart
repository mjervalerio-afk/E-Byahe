import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Uses the locations already configured in the app's map. The College Building
/// point remains approximate; interpolated shuttle movement is synthetic, not a
/// road-matched path or a verified live shuttle position.
class RouteStop {
  final String id, name;
  final LatLng position;
  const RouteStop(this.id, this.name, this.position);
}
const routeStops = <String, RouteStop>{
  'pcu': RouteStop('pcu', 'PCU', LatLng(14.291403874503066, 120.95875841774566)),
  'sm_dasma': RouteStop('sm_dasma', 'SM Dasma', LatLng(14.299884615406288, 120.9573426776829)),
  'robinsons': RouteStop('robinsons', 'Robinsons Place Dasmariñas', LatLng(14.299307290720453, 120.95482412290472)),
  'college': RouteStop('college', 'PCU College Building', LatLng(14.289036, 120.963283)),
};
class RouteScenario {
  final String id, name;
  final List<String> stopIds;
  const RouteScenario(this.id, this.name, this.stopIds);
}
const routeScenarios = <String, RouteScenario>{
  'A': RouteScenario('A', 'Start at PCU', ['pcu', 'sm_dasma', 'robinsons', 'pcu', 'college']),
  'B': RouteScenario('B', 'Start at Robinsons', ['robinsons', 'pcu', 'college', 'sm_dasma', 'robinsons']),
  'C': RouteScenario('C', 'Start at SM Dasma', ['sm_dasma', 'robinsons', 'pcu', 'college']),
};

/// Software-only example checkpoint. It is deliberately not drawn on the map.
/// Coordinates are not verified to match a road.
const testCollegeCheckpointStart = LatLng(14.289719937, 120.960770709);
const testCollegeCheckpointEnd = LatLng(14.290719937, 120.961270709);
// Direction is from the PCU stop toward the College Building test stop.
const testCollegeCheckpointPositiveDirection = false;

enum GpsSource { localSimulation, supabaseTestSimulation, realGps }
enum SimulationStatus { stopped, running, paused }
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
  const RouteSnapshot({
    required this.scenarioId, required this.stops, required this.stopIndex,
    required this.position, required this.timestamp, required this.status,
    required this.source, this.lastEvent,
  });
  String get currentStopId => stops[stopIndex.clamp(0, stops.length - 1).toInt()];
  String? get nextStopId => stopIndex + 1 < stops.length ? stops[stopIndex + 1] : null;
  String get currentStopName => routeStops[currentStopId]!.name;
  String get nextDestinationName => nextStopId == null ? 'Route complete' : routeStops[nextStopId]!.name;
  double get progress => stops.length < 2 ? 1 : stopIndex / (stops.length - 1);
}

/// Central route/GPS manager shared by simulation and future real GPS input.
/// Database writes are intentionally kept outside this class.
class RouteStateManager {
  RouteSnapshot? _state;
  LatLng? _lastPosition;
  DateTime? _lastTimestamp;
  final Set<String> _processedCrossings = <String>{};
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
    final stops = List<String>.from(scenario.stopIds)..removeWhere((id) => !includeCollege && id == 'college');
    final start = stops.indexOf(startingStopId);
    if (start < 0) throw ArgumentError('Starting stop is not in the selected route');
    final time = (now ?? DateTime.now()).toUtc();
    _lastPosition = routeStops[startingStopId]!.position;
    _lastTimestamp = time;
    _processedCrossings.clear();
    _state = RouteSnapshot(
      scenarioId: scenarioId, stops: List.unmodifiable(stops), stopIndex: start,
      position: _lastPosition!, timestamp: time, status: SimulationStatus.stopped,
      source: source, lastEvent: 'Route initialized; TEST coordinates only',
    );
    return _state!;
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
    );
    return true;
  }

  RouteSnapshot advanceCheckpoint() {
    final s = _requireState();
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
    );
    return _state!;
  }

  /// Finite-segment directional crossing in a local metre projection.
  /// eventId must be stable for a trip/checkpoint to make retries idempotent.
  bool crossedDirectionalLine({
    required LatLng previous, required LatLng current,
    required LatLng lineStart, required LatLng lineEnd,
    required bool positiveDirection, required String eventId,
    double toleranceMeters = 2.0,
  }) {
    if (_processedCrossings.contains(eventId)) return false;
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
    if (t < 0 || t > 1 || u < 0 || u > 1) return false;
    _processedCrossings.add(eventId);
    return true;
  }

  /// Evaluates and applies the College Building's invisible directional
  /// checkpoint. Rejects events when the stop is not next, samples are stale,
  /// coordinates are invalid, movement is implausible, or the event was replayed.
  bool processCollegeCheckpoint({
    required LatLng previous,
    required LatLng current,
    required DateTime previousTimestamp,
    required DateTime currentTimestamp,
    required String eventId,
    DateTime? now,
    GpsSource source = GpsSource.localSimulation,
    double maxJumpMeters = 500,
    Duration maxSampleAge = const Duration(seconds: 30),
    Duration maxFutureSkew = const Duration(seconds: 5),
    double toleranceMeters = 2.0,
    GpsSource source = GpsSource.localSimulation,
  }) {
    final s = _requireState();
    if (_processedCrossings.contains(eventId)) {
      _state = _copy(s, event: 'Duplicate crossing ignored: event already processed');
      return false;
    }
    if (!canTriggerCollegeCheckpoint()) {
      _state = _copy(s, event: 'Checkpoint rejected: College Building is not the next destination');
      return false;
    }
    final clock = (now ?? DateTime.now()).toUtc();
    if (!currentTimestamp.isAfter(previousTimestamp)) {
      _state = _copy(s, event: 'Checkpoint rejected: GPS timestamps are not increasing');
      return false;
    }
    for (final timestamp in [previousTimestamp, currentTimestamp]) {
      if (timestamp.isBefore(clock.subtract(maxSampleAge)) ||
          timestamp.isAfter(clock.add(maxFutureSkew))) {
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
    if (distanceMeters(previous, current) > maxJumpMeters) {
      _state = _copy(s, event: 'Checkpoint rejected: implausible GPS jump');
      return false;
    }
    // Every valid sample still updates the tracked shuttle position, even if
    // it did not cross the invisible line; otherwise the next pair is invalid.
    if (!processGps(GpsSample(current, currentTimestamp, source),
        maxJumpMeters: maxJumpMeters, minMovementMeters: 0)) {
      return false;
    }
    final beforeCrossing = _state!;
    final crossed = crossedDirectionalLine(
      previous: previous,
      current: current,
      lineStart: testCollegeCheckpointStart,
      lineEnd: testCollegeCheckpointEnd,
      positiveDirection: testCollegeCheckpointPositiveDirection,
      eventId: eventId,
      toleranceMeters: toleranceMeters,
    );
    if (!crossed) {
      _state = _copy(beforeCrossing, event: 'Checkpoint waiting: no valid directional line crossing');
      return false;
    }
    advanceCheckpoint();
    _state = _copy(_state!, event: 'College Building checkpoint accepted');
    return true;
  }

  /// The College Building event may trigger only when it is actually next.
  bool canTriggerCollegeCheckpoint() => _state?.nextStopId == 'college';

  void reset() {
    _state = null; _lastPosition = null; _lastTimestamp = null;
    _processedCrossings.clear();
  }
  RouteSnapshot _requireState() => _state ?? (throw StateError('Initialize a route before processing GPS'));
  RouteSnapshot _copy(RouteSnapshot s, {SimulationStatus? status, String? event}) => RouteSnapshot(
    scenarioId: s.scenarioId, stops: s.stops, stopIndex: s.stopIndex,
    position: s.position, timestamp: s.timestamp, status: status ?? s.status,
    source: s.source, lastEvent: event,
  );

  static List<_XY> _project(LatLng previous, LatLng current, LatLng a, LatLng b) {
    final refLat = (previous.latitude + current.latitude + a.latitude + b.latitude) / 4;
    final xScale = 111320.0 * math.cos(refLat * math.pi / 180);
    const yScale = 111320.0;
    _XY cv(LatLng v) => _XY(v.longitude * xScale, v.latitude * yScale);
    return [cv(previous), cv(current), cv(a), cv(b)];
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
class _XY {
  final double x, y;
  const _XY(this.x, this.y);
}
