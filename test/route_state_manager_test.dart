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

    test('detects one finite directional crossing and ignores wrong direction or duplicate event IDs', () {
      final manager = RouteStateManager();
      final pcu = routeStops['pcu']!.position;
      final college = routeStops['college']!.position;
      LatLng along(double t) => LatLng(
        pcu.latitude + (college.latitude - pcu.latitude) * t,
        pcu.longitude + (college.longitude - pcu.longitude) * t,
      );
      final before = along(5 / 11);
      final after = along(6 / 11);
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

    test('College Building transition requires it to be the next stop and processes a valid crossing once', () {
      final pcu = routeStops['pcu']!.position;
      final college = routeStops['college']!.position;
      LatLng along(double t) => LatLng(
        pcu.latitude + (college.latitude - pcu.latitude) * t,
        pcu.longitude + (college.longitude - pcu.longitude) * t,
      );
      var manager = RouteStateManager();
      var now = DateTime.now().toUtc();
      manager.initialize(scenarioId: 'A', startingStopId: 'pcu', now: now.subtract(const Duration(seconds: 2)));
      final before = along(5 / 11);
      final after = along(6 / 11);
      expect(
        manager.processCollegeCheckpoint(
          previous: before,
          current: after,
          previousTimestamp: now.subtract(const Duration(seconds: 1)),
          currentTimestamp: now,
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
        manager.processCollegeCheckpoint(
          previous: before,
          current: after,
          previousTimestamp: now.subtract(const Duration(seconds: 1)),
          currentTimestamp: now,
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
          previousTimestamp: now.subtract(const Duration(seconds: 1)),
          currentTimestamp: now,
          eventId: 'college-crossing-1',
          now: now,
        ),
        isFalse,
      );
      expect(manager.state!.lastEvent, contains('Duplicate crossing ignored'));
    });
  });
}
