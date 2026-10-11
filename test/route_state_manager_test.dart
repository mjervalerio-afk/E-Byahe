import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:e_byahe_shuttle/services/route_state_manager.dart';

void main() {
  group('RouteStateManager', () {
    test('keeps the three requested route sequences in order', () {
      expect(routeScenarios['A']!.stopIds, ['pcu', 'sm_dasma', 'robinsons', 'pcu', 'college']);
      expect(routeScenarios['B']!.stopIds, ['robinsons', 'pcu', 'college', 'sm_dasma', 'robinsons']);
      expect(routeScenarios['C']!.stopIds, ['sm_dasma', 'robinsons', 'pcu', 'college']);
    });

    test('initializes at selected stop and supports skipping College Building', () {
      final manager = RouteStateManager();
      final state = manager.initialize(
        scenarioId: 'A',
        startingStopId: 'pcu',
        includeCollege: false,
      );
      expect(state.currentStopId, 'pcu');
      expect(state.stops, isNot(contains('college')));
      expect(state.nextDestinationName, 'SM Dasma');
    });

    test('accepts fresh coordinates and rejects duplicate, stale, invalid, and implausible points', () {
      final manager = RouteStateManager();
      final now = DateTime.now().toUtc();
      manager.initialize(scenarioId: 'A', startingStopId: 'pcu', now: now);
      final point = const LatLng(14.2915, 120.9589);
      expect(manager.processGps(GpsSample(point, now.add(const Duration(seconds: 1)), GpsSource.localSimulation)), isTrue);
      expect(
        manager.processGps(GpsSample(point, now.add(const Duration(seconds: 2)), GpsSource.localSimulation)),
        isFalse,
      );
      expect(
        manager.processGps(
          GpsSample(point, now.subtract(const Duration(minutes: 2)), GpsSource.localSimulation),
        ),
        isFalse,
      );
      expect(
        manager.processGps(
          GpsSample(const LatLng(double.nan, 120.0), now.add(const Duration(seconds: 3)), GpsSource.localSimulation),
        ),
        isFalse,
      );
      expect(
        manager.processGps(
          GpsSample(const LatLng(14.4, 121.2), now.add(const Duration(seconds: 4)), GpsSource.localSimulation),
        ),
        isFalse,
      );
    });

    test('rejects movement inside GPS jitter tolerance', () {
      final manager = RouteStateManager();
      final now = DateTime.now().toUtc();
      manager.initialize(scenarioId: 'A', startingStopId: 'pcu', now: now);
      expect(
        manager.processGps(
          GpsSample(const LatLng(14.291403875, 120.958758418), now.add(const Duration(seconds: 1)), GpsSource.localSimulation),
        ),
        isFalse,
      );
    });

    test('detects finite directional crossing and ignores wrong direction or duplicate event IDs', () {
      final manager = RouteStateManager();
      final pcu = routeStops['pcu']!.position;
      final college = routeStops['college']!.position;
      LatLng along(double t) => LatLng(
        pcu.latitude + (college.latitude - pcu.latitude) * t,
        pcu.longitude + (college.longitude - pcu.longitude) * t,
      );
      final before = along(52 / 55);
      final after = along(53 / 55);
      expect(
        manager.crossedDirectionalLine(
          previous: before,
          current: after,
          lineStart: testCollegeCheckpointStart,
          lineEnd: testCollegeCheckpointEnd,
          positiveDirection: testCollegeCheckpointPositiveDirection,
          eventId: 'cross-1',
        ),
        isTrue,
      );
      expect(
        manager.crossedDirectionalLine(
          previous: before,
          current: after,
          lineStart: testCollegeCheckpointStart,
          lineEnd: testCollegeCheckpointEnd,
          positiveDirection: testCollegeCheckpointPositiveDirection,
          eventId: 'cross-1',
        ),
        isFalse,
      );
      expect(
        manager.crossedDirectionalLine(
          previous: after,
          current: before,
          lineStart: testCollegeCheckpointStart,
          lineEnd: testCollegeCheckpointEnd,
          positiveDirection: testCollegeCheckpointPositiveDirection,
          eventId: 'cross-2',
        ),
        isFalse,
      );
    });

    test('College Building transition requires it to be next and processes valid crossing once', () {
      final pcu = routeStops['pcu']!.position;
      final college = routeStops['college']!.position;
      LatLng along(double t) => LatLng(
        pcu.latitude + (college.latitude - pcu.latitude) * t,
        pcu.longitude + (college.longitude - pcu.longitude) * t,
      );
      var now = DateTime.now().toUtc();
      final before = along(33 / 35);
      final after = along(34 / 35);

      var manager = RouteStateManager();
      manager.initialize(scenarioId: 'A', startingStopId: 'pcu', now: now.subtract(const Duration(seconds: 2)));
      expect(
        manager.processCollegeCheckpoint(
          previous: before,
          current: after,
          previousTimestamp: now.add(const Duration(milliseconds: 200)),
          currentTimestamp: now.add(const Duration(milliseconds: 300)),
          eventId: 'not-next',
          now: now,
        ),
        isFalse,
      );
      expect(manager.state!.lastEvent, contains('not the next destination'));

      // This test sends one sample pair, so it opts out of confirmation readings.
      manager = RouteStateManager(
        collegeCheckpoint: defaultCollegeCheckpoint.copyWith(confirmationReadings: 0),
      );
      manager.initialize(scenarioId: 'A', startingStopId: 'pcu', now: now.subtract(const Duration(seconds: 2)));
      for (var i = 0; i < 3; i++) {
        manager.advanceCheckpoint();
      }
      now = DateTime.now().toUtc();
      expect(manager.canTriggerCollegeCheckpoint(), isTrue);
      expect(
        manager.processGps(
          GpsSample(along(51 / 55), now.add(const Duration(milliseconds: 100)), GpsSource.localSimulation),
        ),
        isTrue,
      );
      now = DateTime.now().toUtc();
      expect(
        manager.processCollegeCheckpoint(
          previous: before,
          current: after,
          previousTimestamp: now.add(const Duration(milliseconds: 200)),
          currentTimestamp: now.add(const Duration(milliseconds: 300)),
          eventId: 'college-crossing-1',
          now: now,
        ),
        isTrue,
      );
      expect(manager.state!.currentStopId, 'college');
      expect(
        manager.processCollegeCheckpoint(
          previous: before,
          current: after,
          previousTimestamp: now.add(const Duration(milliseconds: 200)),
          currentTimestamp: now.add(const Duration(milliseconds: 300)),
          eventId: 'college-crossing-1',
          now: now,
        ),
        isFalse,
      );
      expect(manager.state!.lastEvent, contains('Duplicate crossing ignored'));
    });
  });

  group('Route sequences, starting stops and optional College Building', () {
    /// Walks a route to the end, returning every stop id visited in order.
    List<String> walk(RouteStateManager manager) {
      final visited = <String>[manager.state!.currentStopId];
      while (!manager.state!.isComplete) {
        visited.add(manager.advanceCheckpoint().currentStopId);
      }
      return visited;
    }

    test('each route visits its configured stops in order, College included', () {
      final expected = {
        'A': ['pcu', 'sm_dasma', 'robinsons', 'pcu', 'college'],
        'B': ['robinsons', 'pcu', 'college', 'sm_dasma', 'robinsons'],
        'C': ['sm_dasma', 'robinsons', 'pcu', 'college'],
      };
      final starts = {'A': 'pcu', 'B': 'robinsons', 'C': 'sm_dasma'};
      for (final id in expected.keys) {
        final manager = RouteStateManager();
        manager.initialize(scenarioId: id, startingStopId: starts[id]!);
        expect(walk(manager), expected[id], reason: 'Route $id');
      }
    });

    test('skipping College keeps the remaining order of every route intact', () {
      final expected = {
        'A': ['pcu', 'sm_dasma', 'robinsons', 'pcu'],
        'B': ['robinsons', 'pcu', 'sm_dasma', 'robinsons'],
        'C': ['sm_dasma', 'robinsons', 'pcu'],
      };
      final starts = {'A': 'pcu', 'B': 'robinsons', 'C': 'sm_dasma'};
      for (final id in expected.keys) {
        final manager = RouteStateManager();
        manager.initialize(
          scenarioId: id,
          startingStopId: starts[id]!,
          includeCollege: false,
        );
        expect(walk(manager), expected[id], reason: 'Route $id without College');
      }
    });

    test('skipping College does not modify the shared route definitions', () {
      RouteStateManager().initialize(
        scenarioId: 'A',
        startingStopId: 'pcu',
        includeCollege: false,
      );
      expect(routeScenarios['A']!.stopIds, ['pcu', 'sm_dasma', 'robinsons', 'pcu', 'college']);
    });

    test('each route starts at its configured first stop', () {
      final starts = {'A': 'pcu', 'B': 'robinsons', 'C': 'sm_dasma'};
      for (final entry in starts.entries) {
        final state = RouteStateManager().initialize(
          scenarioId: entry.key,
          startingStopId: entry.value,
        );
        expect(state.stopIndex, 0, reason: 'Route ${entry.key}');
        expect(state.currentStopId, entry.value);
        expect(state.position, routeStops[entry.value]!.position);
      }
    });

    test('can start part-way through a route and continue from there', () {
      final manager = RouteStateManager();
      final state = manager.initialize(scenarioId: 'A', startingStopId: 'sm_dasma');
      expect(state.stopIndex, 1);
      expect(state.nextDestinationName, 'Robinsons Place Dasmariñas');
      expect(state.routeStatus, RouteStatus.notStarted);
      expect(walk(manager), ['sm_dasma', 'robinsons', 'pcu', 'college']);
    });

    test('rejects unknown routes, unknown stops, and College when it is excluded', () {
      final manager = RouteStateManager();
      expect(
        () => manager.initialize(scenarioId: 'Z', startingStopId: 'pcu'),
        throwsArgumentError,
      );
      expect(
        () => manager.initialize(scenarioId: 'A', startingStopId: 'nowhere'),
        throwsArgumentError,
      );
      expect(
        () => manager.initialize(
          scenarioId: 'A',
          startingStopId: 'college',
          includeCollege: false,
        ),
        throwsArgumentError,
      );
    });

    test('College is the next destination exactly where the route says so', () {
      // Route B: College follows PCU.
      var manager = RouteStateManager();
      manager.initialize(scenarioId: 'B', startingStopId: 'robinsons');
      expect(manager.canTriggerCollegeCheckpoint(), isFalse);
      manager.advanceCheckpoint(); // at PCU
      expect(manager.state!.nextStopId, 'college');
      expect(manager.canTriggerCollegeCheckpoint(), isTrue);
      manager.advanceCheckpoint(); // at College
      expect(manager.state!.currentStopId, 'college');
      expect(manager.state!.nextDestinationName, 'SM Dasma');

      // Route C without College: it is never offered as a destination.
      manager = RouteStateManager();
      manager.initialize(
        scenarioId: 'C',
        startingStopId: 'sm_dasma',
        includeCollege: false,
      );
      manager.advanceCheckpoint();
      manager.advanceCheckpoint(); // at PCU, last stop
      expect(manager.canTriggerCollegeCheckpoint(), isFalse);
    });

    test('tracks current stop, next destination and progress along Route A', () {
      final manager = RouteStateManager();
      var state = manager.initialize(scenarioId: 'A', startingStopId: 'pcu');
      expect(state.progress, closeTo(0.0, 1e-9));
      expect(state.currentStopName, 'PCU');
      expect(state.nextDestinationName, 'SM Dasma');

      state = manager.advanceCheckpoint();
      expect(state.progress, closeTo(0.25, 1e-9));
      expect(state.currentStopName, 'SM Dasma');
      expect(state.nextDestinationName, 'Robinsons Place Dasmariñas');

      manager.advanceCheckpoint();
      state = manager.advanceCheckpoint();
      expect(state.progress, closeTo(0.75, 1e-9));
      expect(state.nextDestinationName, 'PCU College Building');

      state = manager.advanceCheckpoint();
      expect(state.progress, closeTo(1.0, 1e-9));
      expect(state.nextStopId, isNull);
      expect(state.nextDestinationName, 'Route complete');
    });

    test('route status moves notStarted -> inProgress -> completed', () {
      final manager = RouteStateManager();
      var state = manager.initialize(scenarioId: 'C', startingStopId: 'sm_dasma');
      expect(state.routeStatus, RouteStatus.notStarted);

      state = manager.setStatus(SimulationStatus.running);
      expect(state.routeStatus, RouteStatus.inProgress);

      manager.advanceCheckpoint();
      manager.advanceCheckpoint();
      state = manager.advanceCheckpoint();
      expect(state.currentStopId, 'college');
      expect(state.isComplete, isTrue);
      expect(state.routeStatus, RouteStatus.completed);
    });

    test('advancing past the final stop leaves the completed route unchanged', () {
      final manager = RouteStateManager();
      manager.initialize(scenarioId: 'C', startingStopId: 'sm_dasma');
      walk(manager);
      final lastIndex = manager.state!.stopIndex;
      final state = manager.advanceCheckpoint();
      expect(state.stopIndex, lastIndex);
      expect(state.lastEvent, 'Route already complete');
      expect(state.routeStatus, RouteStatus.completed);
    });
  });

  group('College Building checkpoint reliability', () {
    test('a valid crossing advances the route once, only after confirmation readings', () {
      final manager = managerWithCollegeNext();
      final drive = _Drive(manager);
      // Steps 1-52 stay on the near side of the invisible line.
      for (var i = 1; i <= 52; i++) {
        expect(drive.step(i.toDouble()), isFalse, reason: 'step $i');
      }
      expect(manager.state!.currentStopId, 'pcu');

      expect(drive.step(53), isFalse); // crossing detected, not yet confirmed
      expect(manager.hasPendingCheckpoint, isTrue);
      expect(manager.state!.currentStopId, 'pcu');
      expect(manager.state!.nextStopId, 'college');

      expect(drive.step(54), isFalse);
      expect(manager.pendingConfirmations, 1);
      expect(manager.state!.currentStopId, 'pcu');

      expect(drive.step(55), isTrue); // second confirmation reading
      expect(manager.state!.currentStopId, 'college');
      expect(manager.state!.nextStopId, isNull);
      expect(manager.state!.routeStatus, RouteStatus.completed);
      expect(manager.hasPendingCheckpoint, isFalse);
    });

    test('confirmation can be configured away for immediate acceptance', () {
      final manager = managerWithCollegeNext(
        config: defaultCollegeCheckpoint.copyWith(confirmationReadings: 0),
      );
      final drive = _Drive(manager, seed: pathPoint(50));
      expect(drive.step(51), isFalse);
      expect(drive.step(52), isFalse);
      expect(drive.step(53), isTrue);
      expect(manager.state!.currentStopId, 'college');
    });

    test('reverse-direction crossings never advance the route', () {
      final manager = managerWithCollegeNext();
      final drive = _Drive(manager, seed: pathPoint(54));
      for (final step in [53.0, 52.0, 51.0, 50.0]) {
        expect(drive.step(step), isFalse, reason: 'step $step');
      }
      expect(manager.hasPendingCheckpoint, isFalse);
      expect(manager.state!.currentStopId, 'pcu');
      expect(manager.state!.lastEvent, startsWith('Checkpoint waiting'));
    });

    test('permitted direction is configurable for calibration', () {
      final flipped = defaultCollegeCheckpoint.copyWith(
        positiveDirection: true,
        confirmationReadings: 0,
      );
      // With the direction flipped, the normal PCU -> College drive is wrong...
      var manager = managerWithCollegeNext(config: flipped);
      var drive = _Drive(manager, seed: pathPoint(45));
      for (var i = 46; i <= 55; i++) {
        expect(drive.step(i.toDouble()), isFalse, reason: 'step $i');
      }
      expect(manager.state!.currentStopId, 'pcu');

      // ...and the opposite drive across the same line is now the permitted one.
      manager = managerWithCollegeNext(config: flipped);
      drive = _Drive(manager, seed: pathPoint(54));
      expect(drive.step(53), isFalse);
      expect(drive.step(52), isTrue);
      expect(manager.state!.currentStopId, 'college');
    });

    test('missed crossings do not advance, even close to the College Building', () {
      // Approaching and stopping short of the line.
      var manager = managerWithCollegeNext();
      var drive = _Drive(manager, seed: pathPoint(43));
      for (var i = 44; i <= 51; i++) {
        expect(drive.step(i.toDouble()), isFalse, reason: 'step $i');
      }
      expect(manager.hasPendingCheckpoint, isFalse);
      expect(manager.state!.currentStopId, 'pcu');

      // Driving alongside the line, 3 m on its near side, never crossing it.
      manager = managerWithCollegeNext();
      drive = _Drive(manager, seed: _nearMissPass.first);
      for (final point in _nearMissPass.skip(1)) {
        expect(drive.stepTo(point), isFalse);
      }
      expect(manager.hasPendingCheckpoint, isFalse);
      expect(manager.state!.currentStopId, 'pcu');
      expect(manager.state!.nextStopId, 'college');
    });

    test('noisy readings inside the tolerance band neither trigger nor hide a crossing', () {
      final manager = managerWithCollegeNext();
      final drive = _Drive(manager, seed: pathPoint(48));
      // Readings jitter about 1.2 m either side of the line (inside the 2 m band).
      for (final step in [49.0, 50.0, 51.0, 52.13, 52.37, 52.13, 52.37, 52.13, 52.37]) {
        expect(drive.step(step), isFalse, reason: 'step $step');
      }
      expect(manager.hasPendingCheckpoint, isFalse);
      expect(manager.state!.currentStopId, 'pcu');

      // A genuine crossing right after the noise is still recognised.
      expect(drive.step(54), isFalse);
      expect(manager.hasPendingCheckpoint, isTrue);
      expect(drive.step(55), isFalse);
      expect(drive.step(56), isTrue);
      expect(manager.state!.currentStopId, 'college');
    });

    test('a reading inside the dead band between two clear readings still counts as a crossing', () {
      final manager = managerWithCollegeNext();
      final drive = _Drive(manager, seed: pathPoint(50));
      expect(drive.step(51.45), isFalse); // ~8 m before the line
      expect(drive.step(52.35), isFalse); // ~1 m past the line: inside the band
      expect(drive.step(53.05), isFalse); // ~8 m past the line
      expect(manager.hasPendingCheckpoint, isTrue);
      expect(drive.step(54), isFalse);
      expect(drive.step(55), isTrue);
      expect(manager.state!.currentStopId, 'college');
    });

    test('duplicate and stale readings do not count as confirmation', () {
      final manager = managerWithCollegeNext();
      final drive = _Drive(manager, seed: pathPoint(50));
      expect(drive.step(51), isFalse);
      expect(drive.step(52), isFalse);
      expect(drive.step(53), isFalse);
      expect(manager.hasPendingCheckpoint, isTrue);

      // Same coordinates again with a new timestamp: jitter-sized, rejected.
      expect(drive.step(53), isFalse);
      expect(manager.pendingConfirmations, 0);

      // A reading whose timestamp does not advance is rejected outright.
      expect(
        manager.processCollegeCheckpoint(
          previous: pathPoint(53),
          current: pathPoint(54),
          previousTimestamp: drive.time,
          currentTimestamp: drive.time,
          eventId: drive.eventId,
        ),
        isFalse,
      );
      expect(manager.state!.lastEvent, contains('not increasing'));
      expect(manager.pendingConfirmations, 0);

      expect(drive.step(54), isFalse);
      expect(manager.pendingConfirmations, 1);
      expect(drive.step(55), isTrue);
    });

    test('a brief glitch across the line is cancelled and cannot advance the route', () {
      final manager = managerWithCollegeNext();
      final drive = _Drive(manager, seed: pathPoint(50));
      expect(drive.step(51), isFalse);
      expect(drive.step(52), isFalse);
      expect(drive.step(53.5), isFalse); // glitch across the line
      expect(manager.hasPendingCheckpoint, isTrue);
      expect(drive.step(51.5), isFalse); // back on the near side
      expect(manager.hasPendingCheckpoint, isFalse);
      expect(manager.state!.lastEvent, contains('cancelled'));
      expect(manager.state!.currentStopId, 'pcu');

      // The same trip can still complete a genuine crossing afterwards.
      expect(drive.step(53), isFalse);
      expect(drive.step(54), isFalse);
      expect(drive.step(55), isTrue);
      expect(manager.state!.currentStopId, 'college');
    });

    test('duplicate checkpoint events cannot advance the route twice', () {
      final manager = managerWithCollegeNext();
      final drive = _Drive(manager, seed: pathPoint(50));
      for (final step in [51.0, 52.0, 53.0, 54.0]) {
        expect(drive.step(step), isFalse);
      }
      expect(drive.step(55), isTrue);
      final index = manager.state!.stopIndex;
      expect(manager.state!.currentStopId, 'college');

      // Replaying the same event id is ignored.
      expect(drive.step(56), isFalse);
      expect(manager.state!.lastEvent, contains('Duplicate crossing ignored'));
      expect(manager.state!.stopIndex, index);

      // A new event id cannot move a completed route either.
      expect(
        manager.processCollegeCheckpoint(
          previous: pathPoint(55),
          current: pathPoint(56),
          previousTimestamp: drive.time,
          currentTimestamp: drive.time.add(const Duration(milliseconds: 50)),
          eventId: 'another-event',
        ),
        isFalse,
      );
      expect(manager.state!.stopIndex, index);
    });

    test('College Building not being the next stop blocks every crossing', () {
      // Route A at its start: the next destination is SM Dasma.
      var manager = RouteStateManager();
      manager.initialize(scenarioId: 'A', startingStopId: 'pcu');
      var drive = _Drive(manager, seed: pathPoint(45));
      for (var i = 46; i <= 55; i++) {
        expect(drive.step(i.toDouble()), isFalse, reason: 'step $i');
      }
      expect(manager.state!.lastEvent, contains('not the next destination'));
      expect(manager.state!.stopIndex, 0);
      expect(manager.hasPendingCheckpoint, isFalse);

      // Route C with College skipped: it is never a destination.
      manager = RouteStateManager();
      manager.initialize(scenarioId: 'C', startingStopId: 'sm_dasma', includeCollege: false);
      manager.advanceCheckpoint();
      manager.advanceCheckpoint(); // at PCU, the last stop
      drive = _Drive(manager, seed: pathPoint(45));
      for (var i = 46; i <= 55; i++) {
        expect(drive.step(i.toDouble()), isFalse, reason: 'step $i');
      }
      expect(manager.state!.currentStopId, 'pcu');
      expect(manager.state!.isComplete, isTrue);
    });

    test('losing College as the next stop discards a pending crossing', () {
      final manager = managerWithCollegeNext();
      final drive = _Drive(manager, seed: pathPoint(50));
      drive.step(51);
      drive.step(52);
      drive.step(53);
      expect(manager.hasPendingCheckpoint, isTrue);
      manager.advanceCheckpoint(); // route moved on by another means
      expect(manager.hasPendingCheckpoint, isFalse);
    });

    test('checkpoint coordinates are configurable and recalibration resets pending state', () {
      final manager = managerWithCollegeNext();
      final drive = _Drive(manager, seed: pathPoint(50));
      drive.step(51);
      drive.step(52);
      drive.step(53);
      expect(manager.hasPendingCheckpoint, isTrue);

      manager.collegeCheckpoint = defaultCollegeCheckpoint.copyWith(confirmationReadings: 3);
      expect(manager.hasPendingCheckpoint, isFalse);
      expect(manager.collegeCheckpoint.confirmationReadings, 3);

      // A line moved about a kilometre away is never crossed by this drive.
      final moved = managerWithCollegeNext(
        config: defaultCollegeCheckpoint.copyWith(
          lineStart: LatLng(testCollegeCheckpointStart.latitude + 0.01, testCollegeCheckpointStart.longitude),
          lineEnd: LatLng(testCollegeCheckpointEnd.latitude + 0.01, testCollegeCheckpointEnd.longitude),
        ),
      );
      final movedDrive = _Drive(moved, seed: pathPoint(45));
      for (var i = 46; i <= 55; i++) {
        expect(movedDrive.step(i.toDouble()), isFalse, reason: 'step $i');
      }
      expect(moved.state!.currentStopId, 'pcu');
    });
  });
}

/// A point on the straight PCU -> College Building test path. [step] counts
/// 1/55ths of that path, the same sampling the simulator uses.
LatLng pathPoint(double step) {
  final pcu = routeStops['pcu']!.position;
  final college = routeStops['college']!.position;
  final t = step / 55;
  return LatLng(
    pcu.latitude + (college.latitude - pcu.latitude) * t,
    pcu.longitude + (college.longitude - pcu.longitude) * t,
  );
}

/// Route A, at PCU for the second time, so College Building is the next stop.
RouteStateManager managerWithCollegeNext({CheckpointConfig? config}) {
  final manager = RouteStateManager(
    collegeCheckpoint: config ?? defaultCollegeCheckpoint,
  );
  manager.initialize(scenarioId: 'A', startingStopId: 'pcu');
  for (var i = 0; i < 3; i++) {
    manager.advanceCheckpoint();
  }
  return manager;
}

/// Five readings about 3 m on the near side of the checkpoint line, moving
/// parallel to it (20 m apart). The line is never crossed.
const _nearMissPass = <LatLng>[
  LatLng(14.28884287556204, 120.96287005058032),
  LatLng(14.2890045583065, 120.96295089195254),
  LatLng(14.28916624105096, 120.96303173332478),
  LatLng(14.28932792379542, 120.963112574697),
  LatLng(14.289489606539881, 120.96319341606923),
];

/// Feeds consecutive GPS readings to the College checkpoint 50 ms apart,
/// the way the simulator does.
class _Drive {
  _Drive(this.manager, {LatLng? seed, this.eventId = 'trip-college-checkpoint'}) {
    if (seed == null) {
      last = manager.state!.position;
      time = manager.state!.timestamp;
    } else {
      time = DateTime.now().toUtc().add(const Duration(milliseconds: 100));
      last = seed;
      expect(manager.processGps(GpsSample(seed, time, GpsSource.localSimulation)), isTrue);
    }
  }

  final RouteStateManager manager;
  final String eventId;
  late LatLng last;
  late DateTime time;

  bool step(double at) => stepTo(pathPoint(at));

  bool stepTo(LatLng current) {
    final previousTime = time;
    time = time.add(const Duration(milliseconds: 50));
    final accepted = manager.processCollegeCheckpoint(
      previous: last,
      current: current,
      previousTimestamp: previousTime,
      currentTimestamp: time,
      eventId: eventId,
    );
    last = current;
    return accepted;
  }
}
