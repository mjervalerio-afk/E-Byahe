import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/route_state_manager.dart';

/// The four fixed locations the Live Map is allowed to pin, per the current
/// scope. Coordinates for the malls and the main PCU campus come from Google
/// Places. "PCU College Building" doesn't have its own separate map listing
/// (it's a building inside the 97-hectare campus), so its coordinate here is
/// an approximate offset from the main campus point — walk it with a phone
/// GPS or drop a pin in Google Maps at the actual building and update
/// `collegeBuilding` below with the real lat/lng once you have it.
class Landmark {
  final String name;
  final LatLng position;
  final Color color;
  final IconData icon;

  const Landmark({
    required this.name,
    required this.position,
    required this.color,
    required this.icon,
  });
}

final smCityDasmarinas = Landmark(
  name: 'SM City Dasmariñas',
  position: routeStops['sm_dasma']!.position,
  color: const Color(0xFFE8C468),
  icon: Icons.local_mall,
);

final robinsonsPlaceDasmarinas = Landmark(
  name: 'Robinsons Place Dasmariñas',
  position: routeStops['robinsons']!.position,
  color: const Color(0xFF7BC67E),
  icon: Icons.local_mall,
);

final pcuMainCampus = Landmark(
  name: 'Philippine Christian University',
  position: routeStops['pcu']!.position,
  color: const Color(0xFF2E6FF2),
  icon: Icons.school,
);

// TODO: approximate — replace with the real coordinate for the actual
// College Building once you have it (see class doc comment above).
final pcuCollegeBuilding = Landmark(
  name: 'PCU College Building',
  position: routeStops['college']!.position,
  color: const Color(0xFFE79E7D),
  icon: Icons.apartment,
);

final liveMapLandmarks = <Landmark>[
  smCityDasmarinas,
  robinsonsPlaceDasmarinas,
  pcuMainCampus,
  pcuCollegeBuilding,
];

/// Center point + zoom that keeps all four landmarks comfortably in view.
const liveMapInitialCenter = LatLng(14.298104, 120.957735);
const liveMapInitialZoom = 14.3;