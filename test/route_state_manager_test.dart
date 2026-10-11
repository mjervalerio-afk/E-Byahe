import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:e_byahe_shuttle/services/route_state_manager.dart';

void main() {
  group('RouteStateManager', () {
    test('keeps the three requested route sequences in order', () {
      expect(routeScenarios['A']!.stopIds, ['pcu','sm_dasma','robinsons','pcu','college']);
      expect(routeScenarios['B']!.stopIds, ['robinsons','pcu','college','sm_dasma','robinsons']);
      expect(routeScenarios['C']!.stopIds, ['sm_dasma','robinsons','pcu','college']);
    });

    test('initializes at selected start and can omit College Building', () {
      final manager = RouteStateManager();
      final state = manager.initialize(scenarioId: 'A', startingStopId: 'pcu', includeCollege: false);
      expect(state.currentStopId, 'pcu');
      expect(state.stops, isNot(contains('college')));
      expect(state.nextDestinationName, 'SM Dasma');
    });

    test('rejects duplicate and stale GPS samples', () {
      final manager = RouteStateManager();
      final now = DateTime.utc(2026, 1, 1);
      manager.initialize(scenarioId: 'A', startingStopId: 'pcu', now: now);
      final point = const LatLng(14.2927, 120.9625);
      expect(manager.processGps(GpsSample(point, now.add(const Duration(seconds: 1)), GpsSource.localSimulation)), isTrue);
      expect(manager.processGps(GpsSample(point, now.add(const Duration(seconds: 2)), GpsSource.localSimulation)), isFalse);
      expect(manager.processGps(GpsSample(const LatLng(14.2928, 120.9626), now, GpsSource.localSimulation)), isFalse);
    });

    test('detects directional crossing and ignores repeated event IDs', () {
      final manager = RouteStateManager();
      const a = LatLng(0, 0), b = LatLng(0, 1);
      const before = LatLng(-1, 0.5), after = LatLng(1, 0.5);
      expect(manager.crossedDirectionalLine(previous: before, current: after, lineStart: a, lineEnd: b, positiveDirection: true, eventId: 'x1'), isTrue);
      expect(manager.crossedDirectionalLine(previous: before, current: after, lineStart: a, lineEnd: b, positiveDirection: true, eventId: 'x1'), isFalse);
      expect(manager.crossedDirectionalLine(previous: after, current: before, lineStart: a, lineEnd: b, positiveDirection: true, eventId: 'x2'), isFalse);
    });
  });
}
