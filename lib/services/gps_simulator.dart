import 'dart:async';
import 'dart:math' as math;

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
  }) {
    pause();
    _scenarioId = scenarioId;
    _source = source;
    _tripId = DateTime.now().toUtc().millisecondsSinceEpoch.toString();
    _startingStopId = startingStopId ?? _defaultStart(scenarioId);
    _includeCollege = includeCollege;
    _automatic = automatic;
    _speedMultiplier = speedMultiplier.clamp(1, 10);
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
      _log('Simulation paused');
      notifyListeners();
    }
  }

  void resume() => start();

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (state != null) manager.setStatus(SimulationStatus.stopped);
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
    _speedMultiplier = speed.clamp(1, 10);
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
    final now = DateTime.now().toUtc();
    _acceptSample(GpsSample(midpoint, now, _source));
    _acceptSample(GpsSample(destination, now.add(const Duration(seconds: 1)), _source));
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
      source: GpsSource.localSimulation,
    );
    // Advance state to the exact previous index while retaining route order.
    for (var i = 0; i < index - 1; i++) {
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
    const lineStart = LatLng(0, 0);
    const lineEnd = LatLng(0, 1);
    LatLng previous = const LatLng(-1, 0.5);
    LatLng current = const LatLng(1, 0.5);
    switch (testCase) {
      case 'wrong direction':
        previous = current;
        current = const LatLng(-1, 0.5);
        break;
      case 'approach only':
        previous = const LatLng(-1, 0.5);
        current = const LatLng(-0.1, 0.5);
        break;
      case 'duplicate coordinates':
        previous = current = const LatLng(-1, 0.5);
        break;
      case 'noise':
        previous = const LatLng(-0.000001, 0.5);
        current = const LatLng(0.000001, 0.500001);
        break;
    }
    final accepted = manager.crossedDirectionalLine(
      previous: previous,
      current: current,
      lineStart: lineStart,
      lineEnd: lineEnd,
      positiveDirection: true,
      eventId: '${testCase}-${DateTime.now().microsecondsSinceEpoch}',
    );
    _lastCheckpointResult = accepted ? 'Accepted: directional line crossed' : 'Rejected: no valid new crossing';
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
    const totalSteps = 12;
    final t = (_step / totalSteps).clamp(0.0, 1.0);
    final point = LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
    final accepted = _acceptSample(GpsSample(point, DateTime.now().toUtc(), _source));
    if (!accepted) {
      _log(state?.lastEvent ?? 'GPS point rejected');
      return;
    }
    if (_step >= totalSteps) {
      manager.advanceCheckpoint();
      _step = 0;
      _segmentStart = state!.position;
      _segmentDestination = state!.nextStopId == null ? null : routeStops[state!.nextStopId]!.position;
      _log('Checkpoint reached: ${routeStops[destinationId]!.name} (TEST coordinate)');
    } else {
      _log('Simulated GPS update accepted');
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
    final accepted = manager.processGps(GpsSample(
      LatLng(latitude.toDouble(), longitude.toDouble()),
      timestamp,
      GpsSource.supabaseTestSimulation,
    ));
    _log(accepted ? 'Supabase Realtime test GPS update accepted' : (state?.lastEvent ?? 'Supabase update rejected'));
    if (accepted) notifyListeners();
    return accepted;
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
