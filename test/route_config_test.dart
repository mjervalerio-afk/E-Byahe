import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:e_byahe_shuttle/services/gps_simulator.dart';
import 'package:e_byahe_shuttle/services/route_state_manager.dart';

/// Walks a route to the end, returning every stop id visited in order.
List<String> walk(RouteStateManager manager) {
  final visited = <String>[manager.state!.currentStopId];
  while (!manager.state!.isComplete) {
    visited.add(manager.advanceCheckpoint().currentStopId);
  }
  return visited;
}

/// A complete, fully verified location set, used to test production mode.
Map<String, StopLocation> verifiedLocations() => {
  for (var i = 0; i < stopDefinitions.length; i++)
    stopDefinitions[i].id: StopLocation(
      LatLng(14.0 + i * 0.01, 120.9),
      CoordinateStatus.verified,
    ),
};

void main() {
  group('Central stop configuration', () {
    test('defines exactly the four shuttle stops, in order, with display names', () {
      expect(stopDefinitions.map((d) => d.id), ['pcu', 'sm_dasma', 'robinsons', 'college']);
      expect(stopDefinitions.map((d) => d.name), [
        'PCU',
        'SM Dasma',
        'Robinsons Place Dasmariñas',
        'PCU College Building',
      ]);
      expect(routeStops.length, 4);
      for (final definition in stopDefinitions) {
        expect(routeStops[definition.id]!.name, definition.name);
      }
    });

    test('every stop has a coordinate, and only the College Building has a checkpoint', () {
      for (final stop in routeStops.values) {
        expect(stop.position.latitude, inInclusiveRange(-90, 90), reason: stop.id);
        expect(stop.position.longitude, inInclusiveRange(-180, 180), reason: stop.id);
        expect(stop.hasCheckpoint, stop.id == collegeStopId, reason: stop.id);
      }
      expect(defaultCollegeCheckpoint, same(routeStops[collegeStopId]!.checkpoint));
    });

    test('map pin names and labels come from the configuration', () {
      final college = activeRouteConfig.stopForLandmark('PCU College Building')!;
      expect(college.id, collegeStopId);
      expect(college.mapLabel, 'College Building');
      expect(college.compactLabel, 'College Bldg');
      expect(activeRouteConfig.stopForLandmark('SM City Dasmariñas')!.mapLabel, 'SM Dasmariñas');
      expect(
        activeRouteConfig.stopForLandmark('Robinsons Place Dasmariñas')!.compactLabel,
        'Robinsons',
      );
      expect(activeRouteConfig.stopForLandmark('Philippine Christian University')!.mapLabel, 'PCU');
      expect(activeRouteConfig.stopForLandmark('Somewhere else'), isNull);
    });
  });

  group('Test and production coordinates are kept separate', () {
    test('the active configuration uses TEST coordinates and is never presented as verified', () {
      expect(activeRouteConfig.production, isFalse);
      expect(activeRouteConfig.coordinatesVerified, isFalse);
      expect(routeStops.values.any((stop) => stop.isVerified), isFalse);
      expect(routeStops[collegeStopId]!.coordinateStatus, CoordinateStatus.test);
      expect(routeStops[pcuStopId]!.coordinateStatus, CoordinateStatus.mapListing);
      expect(activeRouteConfig.coordinateNotice, contains('TEST'));
      expect(activeRouteConfig.coordinateNotice, contains('not verified'));
    });

    test('the production set is empty, so production mode refuses to start', () {
      expect(productionStopLocations, isEmpty);
      expect(productionCheckpoints, isEmpty);
      expect(() => RouteConfig.compose(production: true), throwsStateError);
    });

    test('production mode rejects coordinates that are not marked verified', () {
      expect(
        () => RouteConfig.compose(
          production: true,
          locations: testStopLocations,
          checkpoints: testCheckpoints,
        ),
        throwsStateError,
      );
    });

    test('production mode needs the College Building checkpoint', () {
      expect(
        () => RouteConfig.compose(
          production: true,
          locations: verifiedLocations(),
          checkpoints: const <String, CheckpointConfig>{},
        ),
        throwsStateError,
      );
    });

    test('production mode accepts a complete, verified set', () {
      final config = RouteConfig.compose(
        production: true,
        locations: verifiedLocations(),
        checkpoints: {collegeStopId: defaultCollegeCheckpoint},
      );
      expect(config.production, isTrue);
      expect(config.coordinatesVerified, isTrue);
      expect(config.coordinateNotice, isNot(contains('TEST')));
      // The same route definitions are used; only the coordinates differ.
      expect(config.routes.keys, routeScenarios.keys);
      expect(config.stops[pcuStopId]!.position, const LatLng(14.0, 120.9));
    });
  });

  group('Required route sequences', () {
    List<String> names(String routeId) =>
        routeScenarios[routeId]!.stopIds.map((id) => routeStops[id]!.name).toList();

    test('Route A, B and C are exactly the required sequences', () {
      expect(names('A'), [
        'PCU',
        'SM Dasma',
        'Robinsons Place Dasmariñas',
        'PCU',
        'PCU College Building',
      ]);
      expect(names('B'), [
        'Robinsons Place Dasmariñas',
        'PCU',
        'PCU College Building',
        'SM Dasma',
        'Robinsons Place Dasmariñas',
      ]);
      expect(names('C'), [
        'SM Dasma',
        'Robinsons Place Dasmariñas',
        'PCU',
        'PCU College Building',
      ]);
    });

    test('the starting stop alone determines the route', () {
      expect(activeRouteConfig.routeForStart('pcu')!.id, 'A');
      expect(activeRouteConfig.routeForStart('robinsons')!.id, 'B');
      expect(activeRouteConfig.routeForStart('sm_dasma')!.id, 'C');
      expect(activeRouteConfig.routeForStart('college'), isNull);

      final expectedStarts = {'pcu': 'A', 'robinsons': 'B', 'sm_dasma': 'C'};
      for (final entry in expectedStarts.entries) {
        final manager = RouteStateManager();
        final state = manager.initializeFromStart(startingStopId: entry.key);
        expect(state.scenarioId, entry.value);
        expect(state.currentStopId, entry.key);
        expect(state.stopIndex, 0);
        expect(state.routeName, routeScenarios[entry.value]!.name);
      }
    });

    test('no two routes start at the same stop', () {
      final starts = routeDefinitions.map((route) => route.startingStopId).toSet();
      expect(starts.length, routeDefinitions.length);
    });

    test('starting from a stop no route begins at is rejected', () {
      final manager = RouteStateManager();
      expect(() => manager.initializeFromStart(startingStopId: 'college'), throwsArgumentError);
      expect(() => manager.initializeFromStart(startingStopId: 'nowhere'), throwsArgumentError);
    });

    test('the College Building is optional on every route without changing the rest', () {
      for (final route in routeScenarios.values) {
        final full = route.stopIdsFor();
        final trimmed = route.stopIdsFor(includeCollege: false);
        expect(full, route.stopIds, reason: 'Route ${route.id}');
        expect(trimmed.contains(collegeStopId), isFalse, reason: 'Route ${route.id}');
        expect(
          trimmed,
          route.stopIds.where((id) => id != collegeStopId).toList(),
          reason: 'Route ${route.id}',
        );
      }
      // Asking for a copy never alters the shared definition.
      final copy = routeScenarios['A']!.stopIdsFor()..add('extra');
      expect(copy.length, 6);
      expect(routeScenarios['A']!.stopIds.length, 5);
    });

    test('a trip without the College Building never heads to it', () {
      for (final start in ['pcu', 'robinsons', 'sm_dasma']) {
        final manager = RouteStateManager();
        manager.initializeFromStart(startingStopId: start, includeCollege: false);
        final visited = walk(manager);
        expect(visited.contains(collegeStopId), isFalse, reason: 'start $start');
        expect(manager.canTriggerCollegeCheckpoint(), isFalse, reason: 'start $start');
        expect(manager.state!.nextStopId, isNull);
      }
    });

    test('a trip with the College Building ends there, except Route B', () {
      final ends = {'pcu': 'college', 'sm_dasma': 'college', 'robinsons': 'robinsons'};
      for (final entry in ends.entries) {
        final manager = RouteStateManager();
        manager.initializeFromStart(startingStopId: entry.key);
        expect(walk(manager).last, entry.value, reason: 'start ${entry.key}');
      }
    });
  });

  group('Route manager knowledge', () {
    test('tracks route, current, previous and next stop along Route A', () {
      final manager = RouteStateManager();
      var state = manager.initializeFromStart(startingStopId: 'pcu');
      expect(state.routeName, 'Start at PCU');
      expect(state.currentStopId, 'pcu');
      expect(state.previousStopId, isNull);
      expect(state.nextStopId, 'sm_dasma');

      state = manager.advanceCheckpoint();
      expect(state.currentStopId, 'sm_dasma');
      expect(state.previousStopId, 'pcu');
      expect(state.nextStopId, 'robinsons');

      state = manager.advanceCheckpoint();
      expect(state.currentStopId, 'robinsons');
      expect(state.previousStopId, 'sm_dasma');
      expect(state.nextStopId, 'pcu');

      state = manager.advanceCheckpoint(); // PCU, second visit
      expect(state.currentStopId, 'pcu');
      expect(state.previousStopId, 'robinsons');
      expect(state.previousStopName, 'Robinsons Place Dasmariñas');
      expect(state.nextStopId, 'college');

      state = manager.advanceCheckpoint();
      expect(state.currentStopId, 'college');
      expect(state.previousStopId, 'pcu');
      expect(state.nextStopId, isNull);
    });

    test('a trip that starts part-way never reports a stop it did not visit', () {
      final manager = RouteStateManager();
      final state = manager.initialize(scenarioId: 'A', startingStopId: 'sm_dasma');
      expect(state.stopIndex, 1);
      expect(state.previousStopId, isNull);
      expect(manager.advanceCheckpoint().previousStopId, 'sm_dasma');
    });

    test('reports the expected direction of travel for each leg', () {
      // Route A: PCU -> SM Dasma -> Robinsons -> PCU -> College Building.
      final manager = RouteStateManager();
      var state = manager.initializeFromStart(startingStopId: 'pcu');
      expect(state.expectedDirection, 'N');
      expect(state.expectedBearingDegrees, closeTo(350.8, 0.5));
      state = manager.advanceCheckpoint();
      expect(state.expectedDirection, 'W');
      expect(state.expectedBearingDegrees, closeTo(256.7, 0.5));
      state = manager.advanceCheckpoint();
      expect(state.expectedDirection, 'SE');
      expect(state.expectedBearingDegrees, closeTo(154.2, 0.5));
      state = manager.advanceCheckpoint();
      expect(state.expectedDirection, 'SE');
      expect(state.expectedBearingDegrees, closeTo(118.4, 0.5));
      state = manager.advanceCheckpoint();
      expect(state.expectedDirection, isNull);
      expect(state.expectedBearingDegrees, isNull);

      // Route B turns back from the College Building toward SM Dasma.
      final routeB = RouteStateManager();
      routeB.initializeFromStart(startingStopId: 'robinsons');
      routeB.advanceCheckpoint();
      routeB.advanceCheckpoint();
      expect(routeB.state!.currentStopId, 'college');
      expect(routeB.state!.nextStopId, 'sm_dasma');
      expect(routeB.state!.expectedDirection, 'NW');
      expect(routeB.state!.expectedBearingDegrees, closeTo(332.0, 0.5));
    });

    test('compass labels cover all eight points and wrap around north', () {
      final expected = <double, String>{
        0.0: 'N', 45.0: 'NE', 90.0: 'E', 135.0: 'SE',
        180.0: 'S', 225.0: 'SW', 270.0: 'W', 315.0: 'NW',
        359.0: 'N', 360.0: 'N', 22.4: 'N', 22.6: 'NE',
      };
      for (final entry in expected.entries) {
        expect(RouteStateManager.compassLabel(entry.key), entry.value, reason: '${entry.key}');
      }
    });
  });

  group('Revisiting a stop never resets the route', () {
    test('Route A passes PCU twice and still heads to the College Building', () {
      final manager = RouteStateManager();
      manager.initializeFromStart(startingStopId: 'pcu');
      for (var i = 0; i < 3; i++) {
        manager.advanceCheckpoint();
      }
      expect(manager.state!.stopIndex, 3);
      expect(manager.state!.currentStopId, 'pcu');
      expect(manager.state!.nextStopId, 'college');

      // A reading back at SM Dasma, a stop already visited, is just a position.
      final smDasma = routeStops['sm_dasma']!.position;
      final accepted = manager.processGps(GpsSample(
        smDasma,
        DateTime.now().toUtc().add(const Duration(milliseconds: 10)),
        GpsSource.localSimulation,
      ));
      expect(accepted, isTrue);
      expect(manager.state!.stopIndex, 3);
      expect(manager.state!.nextStopId, 'college');
      expect(manager.state!.routeStatus, isNot(RouteStatus.completed));
    });

    test('Route B passes Robinsons twice and only completes at the second visit', () {
      final manager = RouteStateManager();
      manager.initializeFromStart(startingStopId: 'robinsons');
      expect(manager.state!.isComplete, isFalse);
      final visited = <String>[manager.state!.currentStopId];
      var guard = 0;
      while (!manager.state!.isComplete && guard++ < 10) {
        visited.add(manager.advanceCheckpoint().currentStopId);
        if (visited.length == 2) {
          // Having left Robinsons once, the route must not look finished.
          expect(manager.state!.stopIndex, 1);
        }
      }
      expect(visited, ['robinsons', 'pcu', 'college', 'sm_dasma', 'robinsons']);
      expect(manager.state!.stopIndex, 4);
      expect(manager.state!.routeStatus, RouteStatus.completed);
    });

    test('stepping back from the second PCU lands on Robinsons, not the first PCU', () {
      final manager = RouteStateManager();
      manager.initializeFromStart(startingStopId: 'pcu');
      for (var i = 0; i < 3; i++) {
        manager.advanceCheckpoint();
      }
      var state = manager.retreatCheckpoint();
      expect(state.stopIndex, 2);
      expect(state.currentStopId, 'robinsons');
      expect(state.nextStopId, 'pcu');
      state = manager.retreatCheckpoint();
      expect(state.currentStopId, 'sm_dasma');
      state = manager.retreatCheckpoint();
      expect(state.stopIndex, 0);
      expect(state.currentStopId, 'pcu');
      state = manager.retreatCheckpoint();
      expect(state.stopIndex, 0);
      expect(state.lastEvent, 'Already at the first stop');
    });

    test('stepping back keeps the trip start and can be advanced again', () {
      final manager = RouteStateManager();
      manager.initialize(scenarioId: 'A', startingStopId: 'sm_dasma');
      manager.advanceCheckpoint();
      var state = manager.retreatCheckpoint();
      expect(state.stopIndex, 1);
      expect(state.startIndex, 1);
      expect(state.routeStatus, RouteStatus.notStarted);
      state = manager.advanceCheckpoint();
      expect(state.currentStopId, 'robinsons');
    });

    test('the simulator steps back within the route and starts from the configured stop', () {
      final simulator = GpsSimulator();
      for (final route in routeScenarios.values) {
        simulator.configure(scenarioId: route.id);
        expect(simulator.state!.currentStopId, route.startingStopId, reason: 'Route ${route.id}');
      }

      simulator.configure(scenarioId: 'A');
      for (var i = 0; i < 3; i++) {
        simulator.manager.advanceCheckpoint();
      }
      expect(simulator.state!.stopIndex, 3);
      simulator.previousCheckpoint();
      expect(simulator.state!.stopIndex, 2);
      expect(simulator.state!.currentStopId, 'robinsons');
      simulator.dispose();
    });
  });
}
