import 'package:latlong2/latlong.dart';

// =============================================================================
// Centralized E-Byahe route configuration.
//
// This is the ONLY place that defines the shuttle stops, their display names
// and labels, the route sequences, and the checkpoint settings. Screens, the
// simulator and the route manager all read from here; nothing else should
// repeat a stop id, a stop name or a route sequence.
//
// Coordinates are kept in two separate sets:
//   * TEST coordinates (testStopLocations / testCheckpoints) are what the app
//     uses today. They are NOT verified shuttle locations.
//   * PRODUCTION coordinates (productionStopLocations / productionCheckpoints)
//     are intentionally empty. Nothing has been surveyed yet, and no real-world
//     coordinate is invented here.
// =============================================================================

/// How far a coordinate can be trusted.
enum CoordinateStatus {
  /// Already used for this stop's pin on the app's map. The project notes say
  /// it came from the place's map listing. It is NOT a surveyed shuttle stop.
  mapListing,

  /// Approximate or placeholder value for software testing only.
  test,

  /// Surveyed on site and approved for production use.
  verified,
}

/// Calibration for an invisible directional checkpoint. Everything that needs
/// tuning against the real campus road lives here, so no value is hard-coded
/// inside the detection logic.
///
/// [positiveDirection] is true when permitted travel moves toward increasing
/// signed distance from the line (left of lineStart -> lineEnd) and false for
/// decreasing. Swap it if the shuttle drives the other way across the line.
class CheckpointConfig {
  final LatLng lineStart, lineEnd;
  final bool positiveDirection;
  /// Dead band around the line. Readings closer than this are never counted
  /// as being on either side, which absorbs GPS noise near the line.
  final double toleranceMeters;
  /// Valid readings that must follow a detected crossing, all on the far side
  /// of the line, before the route advances. Zero advances immediately.
  final int confirmationReadings;
  final double maxJumpMeters;
  final Duration maxSampleAge, maxFutureSkew;
  const CheckpointConfig({
    required this.lineStart,
    required this.lineEnd,
    required this.positiveDirection,
    this.toleranceMeters = 2.0,
    this.confirmationReadings = 2,
    this.maxJumpMeters = 500,
    this.maxSampleAge = const Duration(seconds: 30),
    this.maxFutureSkew = const Duration(seconds: 5),
  }) : assert(confirmationReadings >= 0);

  CheckpointConfig copyWith({
    LatLng? lineStart,
    LatLng? lineEnd,
    bool? positiveDirection,
    double? toleranceMeters,
    int? confirmationReadings,
    double? maxJumpMeters,
    Duration? maxSampleAge,
    Duration? maxFutureSkew,
  }) => CheckpointConfig(
    lineStart: lineStart ?? this.lineStart,
    lineEnd: lineEnd ?? this.lineEnd,
    positiveDirection: positiveDirection ?? this.positiveDirection,
    toleranceMeters: toleranceMeters ?? this.toleranceMeters,
    confirmationReadings: confirmationReadings ?? this.confirmationReadings,
    maxJumpMeters: maxJumpMeters ?? this.maxJumpMeters,
    maxSampleAge: maxSampleAge ?? this.maxSampleAge,
    maxFutureSkew: maxFutureSkew ?? this.maxFutureSkew,
  );
}

// -----------------------------------------------------------------------------
// Stop identity and labels (shared by test and production; no coordinates).
// -----------------------------------------------------------------------------

const pcuStopId = 'pcu';
const smDasmaStopId = 'sm_dasma';
const robinsonsStopId = 'robinsons';
const collegeStopId = 'college';

/// Stops a route may leave out. A route skips these when the trip is set up
/// without them (for example, a trip that does not go to the College Building).
const optionalStopIds = <String>{collegeStopId};

class StopDefinition {
  /// Stable machine id used in route sequences and stored events.
  final String id;
  /// Display name used for route progress and destinations.
  final String name;
  /// Name of this stop's pin on the Live Map.
  final String landmarkName;
  /// Short label under the pin on the Live Map.
  final String mapLabel;
  /// Short label for cramped lists on the Info screen.
  final String compactLabel;
  const StopDefinition({
    required this.id,
    required this.name,
    required this.landmarkName,
    required this.mapLabel,
    required this.compactLabel,
  });
}

/// The four shuttle stops, in display order.
const stopDefinitions = <StopDefinition>[
  StopDefinition(
    id: pcuStopId,
    name: 'PCU',
    landmarkName: 'Philippine Christian University',
    mapLabel: 'PCU',
    compactLabel: 'PCU',
  ),
  StopDefinition(
    id: smDasmaStopId,
    name: 'SM Dasma',
    landmarkName: 'SM City Dasmariñas',
    mapLabel: 'SM Dasmariñas',
    compactLabel: 'SM Dasmariñas',
  ),
  StopDefinition(
    id: robinsonsStopId,
    name: 'Robinsons Place Dasmariñas',
    landmarkName: 'Robinsons Place Dasmariñas',
    mapLabel: 'Robinsons',
    compactLabel: 'Robinsons',
  ),
  StopDefinition(
    id: collegeStopId,
    name: 'PCU College Building',
    landmarkName: 'PCU College Building',
    mapLabel: 'College Building',
    compactLabel: 'College Bldg',
  ),
];

// -----------------------------------------------------------------------------
// Route sequences (shared by test and production).
//
// The starting stop of each route is its first stop, and no two routes may
// start at the same stop, so the starting location alone determines the route.
// A stop may appear twice in a route (PCU in Route A, Robinsons in Route B);
// the route manager tracks progress by position in the sequence, never by
// looking a stop up by id, so revisiting a stop never resets the route.
// -----------------------------------------------------------------------------

class RouteScenario {
  final String id, name;
  final List<String> stopIds;
  const RouteScenario(this.id, this.name, this.stopIds);

  /// The stop this route begins at.
  String get startingStopId => stopIds.first;

  /// The route's stops with the optional ones (the College Building) kept or
  /// left out. The order of the remaining stops is never changed.
  List<String> stopIdsFor({bool includeCollege = true}) => includeCollege
      ? List<String>.of(stopIds)
      : <String>[
          for (final id in stopIds)
            if (!optionalStopIds.contains(id)) id,
        ];
}

const routeDefinitions = <RouteScenario>[
  RouteScenario('A', 'Start at PCU', [
    pcuStopId, smDasmaStopId, robinsonsStopId, pcuStopId, collegeStopId,
  ]),
  RouteScenario('B', 'Start at Robinsons', [
    robinsonsStopId, pcuStopId, collegeStopId, smDasmaStopId, robinsonsStopId,
  ]),
  RouteScenario('C', 'Start at SM Dasma', [
    smDasmaStopId, robinsonsStopId, pcuStopId, collegeStopId,
  ]),
];

// -----------------------------------------------------------------------------
// TEST coordinates and checkpoints. NOT verified shuttle locations.
// -----------------------------------------------------------------------------

class StopLocation {
  final LatLng position;
  final CoordinateStatus status;
  const StopLocation(this.position, this.status);
}

/// Software-only example checkpoint. It is deliberately not drawn on the map.
/// Coordinates are not verified to match a road.
const testCollegeCheckpointStart = LatLng(14.28865449, 120.96280676);
const testCollegeCheckpointEnd = LatLng(14.28965449, 120.96330676);
// Direction is from the PCU stop toward the College Building test stop.
const testCollegeCheckpointPositiveDirection = false;

/// The map-listing coordinates are the ones the app's map already uses. The
/// College Building coordinate is approximate (an offset from the main
/// campus point); replace it once the real building is located.
const testStopLocations = <String, StopLocation>{
  pcuStopId: StopLocation(
    LatLng(14.291403874503066, 120.95875841774566),
    CoordinateStatus.mapListing,
  ),
  smDasmaStopId: StopLocation(
    LatLng(14.299884615406288, 120.9573426776829),
    CoordinateStatus.mapListing,
  ),
  robinsonsStopId: StopLocation(
    LatLng(14.299307290720453, 120.95482412290472),
    CoordinateStatus.mapListing,
  ),
  collegeStopId: StopLocation(
    LatLng(14.289036, 120.963283),
    CoordinateStatus.test,
  ),
};

const testCheckpoints = <String, CheckpointConfig>{
  collegeStopId: CheckpointConfig(
    lineStart: testCollegeCheckpointStart,
    lineEnd: testCollegeCheckpointEnd,
    positiveDirection: testCollegeCheckpointPositiveDirection,
  ),
};

// -----------------------------------------------------------------------------
// PRODUCTION coordinates and checkpoints. Intentionally empty.
//
// To go live, walk each stop with a phone GPS and add one entry per stop id:
//   pcuStopId: StopLocation(LatLng(<lat>, <lng>), CoordinateStatus.verified),
// then add the surveyed College Building checkpoint line under collegeStopId in
// productionCheckpoints. Production mode refuses to start until every stop has
// a verified coordinate and the College Building checkpoint exists, so test
// values can never be mistaken for production ones.
// -----------------------------------------------------------------------------

const productionStopLocations = <String, StopLocation>{};
const productionCheckpoints = <String, CheckpointConfig>{};

// -----------------------------------------------------------------------------
// Composition
// -----------------------------------------------------------------------------

/// A stop with its identity, labels, coordinate and optional checkpoint.
class RouteStop {
  final String id, name, landmarkName, mapLabel, compactLabel;
  final LatLng position;
  final CoordinateStatus coordinateStatus;
  /// Invisible directional checkpoint that confirms arrival at this stop, if
  /// the stop uses one. Only the College Building does today.
  final CheckpointConfig? checkpoint;
  const RouteStop({
    required this.id,
    required this.name,
    required this.landmarkName,
    required this.mapLabel,
    required this.compactLabel,
    required this.position,
    required this.coordinateStatus,
    this.checkpoint,
  });

  bool get isVerified => coordinateStatus == CoordinateStatus.verified;
  bool get hasCheckpoint => checkpoint != null;
}

class RouteConfig {
  final bool production;
  final Map<String, RouteStop> stops;
  final Map<String, RouteScenario> routes;
  RouteConfig._({
    required this.production,
    required this.stops,
    required this.routes,
  });

  /// Combines the shared stop and route definitions with one coordinate set.
  /// [locations] and [checkpoints] override the built-in sets (for tests).
  /// Throws a [StateError] if the configuration is incomplete or inconsistent.
  factory RouteConfig.compose({
    required bool production,
    Map<String, StopLocation>? locations,
    Map<String, CheckpointConfig>? checkpoints,
  }) {
    final stopLocations =
        locations ?? (production ? productionStopLocations : testStopLocations);
    final stopCheckpoints =
        checkpoints ?? (production ? productionCheckpoints : testCheckpoints);

    final missing = <String>[
      for (final definition in stopDefinitions)
        if (!stopLocations.containsKey(definition.id)) definition.id,
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        '${production ? 'Production' : 'Test'} route configuration is '
        'incomplete: no coordinates for ${missing.join(', ')}. Add them to '
        '${production ? 'productionStopLocations' : 'testStopLocations'} in '
        'lib/config/route_config.dart.',
      );
    }
    if (production) {
      final unverified = <String>[
        for (final definition in stopDefinitions)
          if (stopLocations[definition.id]!.status != CoordinateStatus.verified)
            definition.id,
      ];
      if (unverified.isNotEmpty) {
        throw StateError(
          'Production route configuration refuses unverified coordinates for '
          '${unverified.join(', ')}. Mark each surveyed stop as '
          'CoordinateStatus.verified.',
        );
      }
    }
    if (!stopCheckpoints.containsKey(collegeStopId)) {
      throw StateError(
        'No College Building checkpoint is configured. Add one for '
        '"$collegeStopId" to '
        '${production ? 'productionCheckpoints' : 'testCheckpoints'}.',
      );
    }

    final stops = <String, RouteStop>{
      for (final definition in stopDefinitions)
        definition.id: RouteStop(
          id: definition.id,
          name: definition.name,
          landmarkName: definition.landmarkName,
          mapLabel: definition.mapLabel,
          compactLabel: definition.compactLabel,
          position: stopLocations[definition.id]!.position,
          coordinateStatus: stopLocations[definition.id]!.status,
          checkpoint: stopCheckpoints[definition.id],
        ),
    };

    final routes = <String, RouteScenario>{};
    final startingStops = <String>{};
    for (final route in routeDefinitions) {
      for (final id in route.stopIds) {
        if (!stops.containsKey(id)) {
          throw StateError('Route ${route.id} uses unknown stop "$id".');
        }
      }
      if (!startingStops.add(route.startingStopId)) {
        throw StateError(
          'More than one route starts at "${route.startingStopId}", so the '
          'starting stop could not determine the route.',
        );
      }
      routes[route.id] = route;
    }

    return RouteConfig._(
      production: production,
      stops: Map<String, RouteStop>.unmodifiable(stops),
      routes: Map<String, RouteScenario>.unmodifiable(routes),
    );
  }

  /// The route that begins at [startingStopId], or null when none does (for
  /// example the College Building, which no route starts from).
  RouteScenario? routeForStart(String startingStopId) {
    for (final route in routes.values) {
      if (route.startingStopId == startingStopId) return route;
    }
    return null;
  }

  /// The stop shown on the map under [landmarkName], if any.
  RouteStop? stopForLandmark(String landmarkName) {
    for (final stop in stops.values) {
      if (stop.landmarkName == landmarkName) return stop;
    }
    return null;
  }

  /// True only when every stop has a surveyed coordinate.
  bool get coordinatesVerified => stops.values.every((stop) => stop.isVerified);

  /// Text for any screen or log that shows these coordinates.
  String get coordinateNotice => coordinatesVerified
      ? 'Verified production coordinates'
      : 'TEST coordinates, not verified shuttle locations';
}

/// Build the app with --dart-define=E_BYAHE_PRODUCTION_ROUTE=true to use the
/// production coordinate set. It fails fast until that set is complete.
const useProductionRouteConfig = bool.fromEnvironment('E_BYAHE_PRODUCTION_ROUTE');

final RouteConfig activeRouteConfig =
    RouteConfig.compose(production: useProductionRouteConfig);

/// Convenience views of the active configuration.
final Map<String, RouteStop> routeStops = activeRouteConfig.stops;
final Map<String, RouteScenario> routeScenarios = activeRouteConfig.routes;
final CheckpointConfig defaultCollegeCheckpoint =
    routeStops[collegeStopId]!.checkpoint!;
