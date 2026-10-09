import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../screens/shuttle_detail_screen.dart';

/// Shuttle data model. Seat totals represent the vehicle's configured capacity.
class Shuttle {
  final String id;
  final String name;
  final int seatsAvailable;
  final int seatsTotal;
  final int etaMinutes;
  final String routeLabel;
  final Color avatarColor;
  final LatLng position;

  final String originStopName;
  final String departedTime;
  final String currentDestinationName;
  final String upcomingStopName;

  const Shuttle({
    required this.id,
    required this.name,
    required this.seatsAvailable,
    required this.seatsTotal,
    required this.etaMinutes,
    required this.routeLabel,
    required this.avatarColor,
    required this.position,
    required this.originStopName,
    required this.departedTime,
    required this.currentDestinationName,
    required this.upcomingStopName,
  });

  bool get isLowSeats => seatsAvailable <= 1;
}

const mockShuttles = <Shuttle>[
  Shuttle(
    id: 'shuttle-01',
    name: 'Shuttle 01',
    // Demo state: all 15 passenger seats are available.
    seatsAvailable: 15,
    seatsTotal: 15,
    etaMinutes: 2,
    routeLabel: 'On route to PCU College Building',
    avatarColor: Color(0xFF7BC67E),
    position: LatLng(14.292640, 120.962401),
    originStopName: 'PCU Main Entrance',
    departedTime: '9:35 AM',
    currentDestinationName: 'PCU College Building',
    upcomingStopName: 'PCU Dormitory',
  ),
];

/// Stand-in for a real data fetch (Firestore, REST, etc). Replace with the
/// live backend/hardware feed when the GPS and load-cell system is connected.
Future<List<Shuttle>> fetchShuttles() async {
  final simulatedNetworkDelay = Duration(milliseconds: 250 * mockShuttles.length);
  await Future.delayed(simulatedNetworkDelay);
  return mockShuttles;
}

class ShuttleTile extends StatelessWidget {
  final Shuttle shuttle;
  final bool selected;
  final VoidCallback? onTap;

  const ShuttleTile({
    super.key,
    required this.shuttle,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final seatColor =
        shuttle.isLowSeats ? const Color(0xFFE14B4B) : const Color(0xFF22A45D);

    return InkWell(
      onTap: onTap ??
          () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ShuttleDetailScreen(shuttle: shuttle),
                ),
              ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        color: selected ? const Color(0xFFEAF1FF) : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD7E7F8)),
              ),
              child: Image.asset(
                'assets/images/shuttle_van.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.directions_bus_rounded,
                  color: Color(0xFF2671B8),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shuttle.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    '${shuttle.seatsAvailable} / ${shuttle.seatsTotal} seats available',
                    style: TextStyle(
                        color: seatColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(shuttle.routeLabel,
                      style: const TextStyle(
                          color: Color(0xFF8A93A6), fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${shuttle.etaMinutes} min',
                    style: const TextStyle(
                        color: Color(0xFF2E6FF2),
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const Text('away',
                    style: TextStyle(color: Color(0xFF2E6FF2), fontSize: 12)),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Color(0xFFB7BEC9)),
          ],
        ),
      ),
    );
  }
}
