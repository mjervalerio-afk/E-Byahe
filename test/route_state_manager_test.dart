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

      manager = RouteStateManager();
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
}
