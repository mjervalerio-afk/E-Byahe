import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'route_state_manager.dart';

/// Browser/device-local simulator. Coordinates here are for software testing
/// only and must not be represented as a verified production vehicle position.
class GpsSimulator extends ChangeNotifier {
  GpsSimulator({RouteStateManager? manager, Future<void> Function(GpsSample sample, String tripId)? onGpsSample})
      : manager = manager ?? RouteStateManager(), onGpsSample = onGpsSample;

  final RouteStateManager manager;
  final Future<void> Function(GpsSample sample, String tripId)? onGpsSample;
  GpsSource _source = GpsSource.localSimulation;
  String _tripId = DateTime.now().toUtc().millisecondsSinceEpoch.toString();
  Timer? _timer;
  int _step = 0;
  double _simulatedSpeedKmh = 0;
  LatLng? _segmentStart;
  LatLng? _segmentDestination;
  int _speedMultiplier = 1;
  bool _automatic = true;
  bool _includeCollege = true;
  String _scenarioId = 'A';
  String _startingStopId = 'pcu';
  String? _lastCheckpointResult;
  final List<String> _events = <String>[];

  RouteSnapshot? get state => manager.state;
  GpsSource get source => _source;
  String get tripId => _tripId;
  bool get automatic => _automatic;
  bool get includeCollege => _includeCollege;
  int get speedMultiplier => _speedMultiplier;
  double get simulatedSpeedKmh => _simulatedSpeedKmh;
  double get routeProgress {
    final snapshot = state;
    if (snapshot == null) return 0;
    final nextId = snapshot.nextStopId;
    if (nextId == null) return 1;
    final start = routeStops[snapshot.currentStopId]!.position;
    final end = routeStops[nextId]!.position;
    final total = RouteStateManager.distanceMeters(start, end);
    if (total <= 0) return snapshot.progress;
    final travelled = RouteStateManager.distanceMeters(start, snapshot.position);
    final segmentFraction = (travelled / total).clamp(0.0, 1.0).toDouble();
    return ((snapshot.stopIndex + segmentFraction) / (snapshot.stops.length - 1))
        .clamp(0.0, 1.0).toDouble();
  }
  String get scenarioId => _scenarioId;
  String get startingStopId => _startingStopId;
  String? get lastCheckpointResult => _lastCheckpointResult;
  List<String> get events => List.unmodifiable(_events);

  // A straight-line coordinate interpolation used only for deterministic UI
  // testing. Replace with sampled road geometry when verified path points exist.
  void configure({
    String scenarioId = 'A',
    String? startingStopId,
    bool includeCollege = true,
    bool automatic = true,
    int speedMultiplier = 1,
    GpsSource source = GpsSource.localSimulation,
    String? tripId,
  }) {
    pause();
    _scenarioId = scenarioId;
    _source = source;
    _tripId = tripId != null && tripId.trim().isNotEmpty
        ? tripId.trim()
        : DateTime.now().toUtc().millisecondsSinceEpoch.toString();
    _startingStopId = startingStopId ?? _defaultStart(scenarioId);
    _includeCollege = includeCollege;
    _automatic = automatic;
    _speedMultiplier = speedMultiplier.clamp(1, 10).toInt();
    manager.initialize(
      scenarioId: _scenarioId,
      startingStopId: _startingStopId,
      includeCollege: _includeCollege,
      source: _source,
    );
    _step = 0;
    _segmentStart = state!.position;
    _segmentDestination = state!.nextStopId == null ? null : routeStops[state!.nextStopId]!.position;
    _log('Route initialized: ${routeScenarios[_scenarioId]!.name}; TEST coordinates only');
    notifyListeners();
  }

  void start() {
    if (state == null) configure();
    if (!_automatic) {
      manager.setStatus(SimulationStatus.running);
      _log('Manual simulation started');
      notifyListeners();
      return;
    }
    if (state!.status != SimulationStatus.paused) {
      _segmentStart = state!.position;
      _segmentDestination = state!.nextStopId == null ? null : routeStops[state!.nextStopId]!.position;
      _step = 0;
    }
    manager.setStatus(SimulationStatus.running);
    _log('Automatic simulation started');
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: 1000 ~/ _speedMultiplier), (_) => _tick());
    notifyListeners();
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    if (state != null && state!.status == SimulationStatus.running) {
      manager.setStatus(SimulationStatus.paused);
      _simulatedSpeedKmh = 0;
      _log('Simulation paused');
      notifyListeners();
    }
  }

  void resume() => start();

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (state != null) manager.setStatus(SimulationStatus.stopped);
    _simulatedSpeedKmh = 0;
    _log('Simulation stopped');
    notifyListeners();
  }

  void reset() {
    stop();
    manager.reset();
    configure(
      scenarioId: _scenarioId,
      startingStopId: _startingStopId,
      includeCollege: _includeCollege,
      automatic: _automatic,
      speedMultiplier: _speedMultiplier,
      source: _source,
      tripId: _tripId,
    );
    _log('Simulation reset');
  }

  void setMode(bool automatic) {
    _automatic = automatic;
    if (state != null && state!.status == SimulationStatus.running && automatic) start();
    if (!automatic) {
      _timer?.cancel();
      _timer = null;
    }
    notifyListeners();
  }

  void setSpeed(int speed) {
    _speedMultiplier = speed.clamp(1, 10).toInt();
    if (state?.status == SimulationStatus.running && _automatic) start();
    notifyListeners();
  }

  void nextCheckpoint() {
    if (state == null) configure();
    _timer?.cancel();
    _timer = null;
    final before = state!.position;
    final nextId = state!.nextStopId;
    if (nextId == null) {
      _log('Route complete; no next checkpoint');
      notifyListeners();
      return;
    }
    // Simulate a few intermediate GPS points so the same GPS processing path
    // is exercised before the logical checkpoint transition.
    final destination = routeStops[nextId]!.position;
    final midpoint = LatLng(
      (before.latitude + destination.latitude) / 2,
      (before.longitude + destination.longitude) / 2,
    );
    _simulatedSpeedKmh = 0;
    final now = DateTime.now().toUtc();
    _acceptSample(GpsSample(midpoint, now, _source));
    _acceptSample(GpsSample(destination, now.add(const Duration(milliseconds: 5)), _source));
    manager.advanceCheckpoint();
    _step = 0;
    _segmentStart = state!.position;
    _segmentDestination = state!.nextStopId == null ? null : routeStops[state!.nextStopId]!.position;
    _log('Manual checkpoint accepted: ${routeStops[nextId]!.name} (TEST position)');
    notifyListeners();
  }

  void previousCheckpoint() {
    if (state == null || state!.stopIndex <= 0) {
      _log('Previous checkpoint unavailable');
      notifyListeners();
      return;
    }
    final current = state!;
    final index = current.stopIndex - 1;
    final id = current.stops[index];
    manager.initialize(
      scenarioId: current.scenarioId,
      startingStopId: current.stops.first,
      includeCollege: _includeCollege,
      source: _source,
    );
    // Advance state to the exact previous index while retaining route order.
    for (var i = 0; i < index; i++) {
      manager.advanceCheckpoint();
    }
    _step = 0;
    _segmentStart = state!.position;
    _segmentDestination = state!.nextStopId == null ? null : routeStops[state!.nextStopId]!.position;
    _log('Moved to previous checkpoint: ${routeStops[id]!.name}');
    notifyListeners();
  }

  /// Exercises the configured invisible line detector with a set of
  /// deterministic cases. The coordinates are synthetic, not road-aligned.
  void runCheckpointTest(String testCase) {
    // These synthetic cases send a single sample pair, so they use immediate
    // acceptance (no confirmation readings) to exercise the line detector itself.
    final checkpointManager = RouteStateManager(
      collegeCheckpoint: defaultCollegeCheckpoint.copyWith(confirmationReadings: 0),
    );
    checkpointManager.initialize(scenarioId: 'A', startingStopId: 'pcu');
    if (testCase != 'college not next') {
      // Route A revisits PCU immediately before the College Building stop.
      for (var i = 0; i < 3; i++) {
        checkpointManager.advanceCheckpoint();
      }
    }

    final now = DateTime.now().toUtc();
    final pcu = routeStops['pcu']!.position;
    final college = routeStops['college']!.position;
    LatLng along(double t) => LatLng(
      pcu.latitude + (college.latitude - pcu.latitude) * t,
      pcu.longitude + (college.longitude - pcu.longitude) * t,
    );
    var previous = along(52 / 55);
    var current = along(53 / 55);
    var previousTimestamp = now.add(const Duration(milliseconds: 200));
    var currentTimestamp = now.add(const Duration(milliseconds: 300));

    switch (testCase) {
      case 'wrong direction':
        final temp = previous;
        previous = current;
        current = temp;
        break;
      case 'approach only':
        previous = along(49 / 55);
        current = along(50 / 55);
        break;
      case 'duplicate coordinates':
        current = previous;
        break;
      case 'noise':
        previous = along(0.94999);
        current = along(0.95001);
        break;
      case 'stale GPS':
        previousTimestamp = now.subtract(const Duration(minutes: 3));
        currentTimestamp = now.subtract(const Duration(minutes: 2));
        break;
      case 'invalid GPS':
        current = const LatLng(100, 120.9622);
        break;
      case 'unrealistic jump':
        current = const LatLng(14.3020, 120.9622);
        break;
    }

    final eventId = '$testCase-${DateTime.now().microsecondsSinceEpoch}';
    // Seed the service with the last valid sample before the test pair so that
    // the test itself doesn't simulate an implausible jump from the route origin.
    final seedTime = now.add(const Duration(milliseconds: 100));
    final seedPosition = testCase == 'wrong direction'
        ? along(53 / 55)
        : (testCase == 'approach only'
            ? along(48 / 55)
            : (testCase == 'noise' ? along(0.94995) : along(51 / 55)));
    checkpointManager.processGps(
      GpsSample(seedPosition, seedTime, GpsSource.localSimulation),
    );
    final accepted = checkpointManager.processCollegeCheckpoint(
      previous: previous,
      current: current,
      previousTimestamp: previousTimestamp,
      currentTimestamp: currentTimestamp,
      eventId: eventId,
      now: now,
    );
    var repeatedIgnored = false;
    if (testCase == 'repeated crossing' && accepted) {
      repeatedIgnored = !checkpointManager.processCollegeCheckpoint(
        previous: previous,
        current: current,
        previousTimestamp: previousTimestamp,
        currentTimestamp: currentTimestamp,
        eventId: eventId,
        now: now,
      );
    }
    _lastCheckpointResult = accepted
        ? (repeatedIgnored
            ? 'Accepted first crossing; duplicate event ignored'
            : 'Accepted: College Building checkpoint crossed')
        : (checkpointManager.state?.lastEvent ?? 'Rejected: checkpoint conditions not met');
    _log('Checkpoint test "$testCase": $_lastCheckpointResult. Synthetic coordinates.');
    notifyListeners();
  }

  void clearEvents() {
    _events.clear();
    notifyListeners();
  }

  void _tick() {
    final snapshot = state;
    if (snapshot == null || snapshot.status != SimulationStatus.running) return;
    final destinationId = snapshot.nextStopId;
    if (destinationId == null) {
      stop();
      _log('Route completed');
      return;
    }
    _segmentStart ??= snapshot.position;
    _segmentDestination ??= routeStops[destinationId]!.position;
    final from = _segmentStart!;
    final to = _segmentDestination!;
    _step++;
    // The 55 interpolation steps cross the near-destination College checkpoint
    // between samples instead of landing inside its tolerance band.
    const totalSteps = 55;
    final t = (_step / totalSteps).clamp(0.0, 1.0);
    final point = LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
    final sampleTime = DateTime.now().toUtc();
    final realElapsedSeconds = sampleTime.difference(snapshot.timestamp).inMilliseconds / 1000.0;
    final simulatedElapsedSeconds = realElapsedSeconds * _speedMultiplier;
    final movedMeters = RouteStateManager.distanceMeters(snapshot.position, point);
    _simulatedSpeedKmh = simulatedElapsedSeconds > 0 ? movedMeters / simulatedElapsedSeconds * 3.6 : 0;
    var accepted = false;
    var collegeCheckpointAccepted = false;

    if (destinationId == 'college') {
      collegeCheckpointAccepted = manager.processCollegeCheckpoint(
        previous: snapshot.position,
        current: point,
        previousTimestamp: snapshot.timestamp,
        currentTimestamp: sampleTime,
        eventId: '$_tripId-college-checkpoint',
        source: _source,
      );
      accepted = collegeCheckpointAccepted ||
          (state?.lastEvent?.startsWith('Checkpoint waiting:') ?? false);
      // The generated point is part of the isolated simulated feed even while
      // the route is waiting for its directional checkpoint to be crossed.
      _publish(GpsSample(point, sampleTime, _source));
    } else {
      accepted = _acceptSample(GpsSample(point, sampleTime, _source));
    }

    if (!accepted) {
      _log(state?.lastEvent ?? 'GPS point rejected');
      notifyListeners();
      return;
    }

    if (collegeCheckpointAccepted) {
      _step = 0;
      _segmentStart = state!.position;
      _segmentDestination = state!.nextStopId == null ? null : routeStops[state!.nextStopId]!.position;
      _log('College Building directional checkpoint accepted');
    } else if (_step >= totalSteps) {
      if (destinationId == 'college') {
        manager.setStatus(SimulationStatus.paused);
        _timer?.cancel();
        _timer = null;
        _log('Simulation paused: College Building checkpoint was not accepted; route did not advance');
      } else {
        manager.advanceCheckpoint();
        _step = 0;
        _segmentStart = state!.position;
        _segmentDestination = state!.nextStopId == null ? null : routeStops[state!.nextStopId]!.position;
        _log('Checkpoint reached: ${routeStops[destinationId]!.name} (test path)');
      }
    } else {
      _log(destinationId == 'college'
          ? (state?.lastEvent ?? 'Waiting for College Building checkpoint')
          : 'Simulated GPS update accepted');
    }
    notifyListeners();
  }

  bool _acceptSample(GpsSample sample) {
    final accepted = manager.processGps(sample);
    if (accepted) _publish(sample);
    return accepted;
  }

  void _publish(GpsSample sample) {
    if (sample.source != GpsSource.supabaseTestSimulation || onGpsSample == null) return;
    onGpsSample!(sample, _tripId).catchError((Object error) {
      _log('Supabase test write failed: ' + error.toString());
      notifyListeners();
    });
  }

  /// Applies a Realtime test row only while database simulation is selected
  /// and only for the active trip. Production GPS is never accepted.
  bool processRealtimeRecord(Map<String, dynamic> record) {
    if (_source != GpsSource.supabaseTestSimulation ||
        record['trip_id']?.toString() != _tripId ||
        record['source_type']?.toString() != 'simulated') return false;
    final latitude = record['latitude'];
    final longitude = record['longitude'];
    final timestamp = DateTime.tryParse(record['recorded_at']?.toString() ?? '');
    if (latitude is! num || longitude is! num || timestamp == null) {
      _log('Supabase update rejected: invalid test location row');
      notifyListeners();
      return false;
    }
    final incomingPosition = LatLng(latitude.toDouble(), longitude.toDouble());
    final currentState = state;
    // Ignore our own stream echo and any old record already reflected in UI.
    if (currentState != null && !timestamp.isAfter(currentState.timestamp)) return false;
    final accepted = currentState != null && currentState.nextStopId == 'college'
        ? manager.processCollegeCheckpoint(
            previous: currentState.position,
            current: incomingPosition,
            previousTimestamp: currentState.timestamp,
            currentTimestamp: timestamp,
            eventId: '$_tripId-college-checkpoint',
            source: GpsSource.supabaseTestSimulation,
          )
        : manager.processGps(GpsSample(
            incomingPosition,
            timestamp,
            GpsSource.supabaseTestSimulation,
          ));
    final updatedState = state;
    final locationUpdated = updatedState != null &&
        currentState != null &&
        timestamp.isAfter(currentState.timestamp) &&
        updatedState.timestamp.isAtSameMomentAs(timestamp);
    _log(accepted
        ? 'Supabase Realtime checkpoint transition accepted'
        : (locationUpdated
            ? 'Supabase Realtime location update accepted; route checkpoint still pending'
            : (state?.lastEvent ?? 'Supabase update rejected')));
    if (accepted || locationUpdated) notifyListeners();
    return accepted || locationUpdated;
  }

  void _log(String message) {
    final timestamp = DateTime.now().toLocal().toString().split('.').first;
    _events.insert(0, '$timestamp — $message');
    if (_events.length > 100) _events.removeRange(100, _events.length);
  }

  static String _defaultStart(String scenarioId) {
    switch (scenarioId) {
      case 'B': return 'robinsons';
      case 'C': return 'sm_dasma';
      default: return 'pcu';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
