import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../screens/shuttle_detail_screen.dart';

/// Placeholder shuttle model. Later, replace static lists of these with a
/// stream from Firestore, fed by the NEO-6M GPS + load cell hardware.
class Shuttle {
  final String id;
  final String name;
  final int seatsAvailable;
  final int seatsTotal;
  final int etaMinutes;
  final String routeLabel;
  final Color avatarColor;
  final LatLng position; // real GPS coordinate, once hardware feeds this live

  // Route progress timeline, shown on the Shuttle Detail screen.
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
    seatsAvailable: 16,
    seatsTotal: 16,
    etaMinutes: 2,
    routeLabel: 'On route to PCU College Building',
    avatarColor: Color(0xFF7BC67E),
    position: LatLng(14.292640, 120.962401), // placeholder: sitting at PCU for now
    originStopName: 'PCU Main Entrance',
    departedTime: '9:35 AM',
    currentDestinationName: 'PCU College Building',
    upcomingStopName: 'PCU Dormitory',
  ),
];

/// Stand-in for a real data fetch (Firestore, REST, etc). The delay scales
/// with how much data there is, so the skeleton screen naturally stays up
/// longer when there's more to load — same as it would with a real backend.
/// Swap the body of this function for your real Firestore query later; the
/// skeleton screen doesn't need to change at all when you do.
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
            CircleAvatar(
              radius: 22,
              backgroundColor: shuttle.avatarColor,
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    'assets/images/shuttle_van.png',
                    fit: BoxFit.contain,
                  ),
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