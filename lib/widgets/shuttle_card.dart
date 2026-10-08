import 'package:flutter/material.dart';
import '../connection_status.dart';
import '../theme.dart';
import 'shuttle_tile.dart';

class Dot extends StatelessWidget {
  final Color color;
  const Dot({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// A small rounded badge: "Full · 0/16 seats", "1 active", and so on.
class StatusPill extends StatelessWidget {
  final Color color;
  final Color background;
  final String text;
  final Widget? leading;

  const StatusPill({
    super.key,
    required this.color,
    required this.background,
    required this.text,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// The status badge shown in the headers (a status, not a button).
/// Green "Live" while the phone is connected; red "No internet" when not.
class LivePill extends StatefulWidget {
  const LivePill({super.key});

  @override
  State<LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<LivePill> {
  @override
  void initState() {
    super.initState();
    ConnectionStatus.instance.start(); // safe to call repeatedly
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectionStatus.instance.isOnline,
      builder: (context, online, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: online
                ? Colors.white.withValues(alpha: 0.16)
                : const Color(0xFFE14B4B).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (online)
                const Dot(color: Color(0xFF4ADE80))
              else
                const Icon(Icons.wifi_off, size: 13, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                online ? 'Live' : 'No internet',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One clear status for a shuttle's seats, so the colors mean the same
/// thing everywhere in the app.
class SeatStatus {
  final Color color;
  final Color background;
  final String label;

  const SeatStatus(this.color, this.background, this.label);

  factory SeatStatus.of(Shuttle shuttle) {
    if (shuttle.seatsAvailable <= 0) {
      return const SeatStatus(AppColors.red, AppColors.softRed, 'Full');
    }
    if (shuttle.isLowSeats) {
      return const SeatStatus(AppColors.amber, AppColors.softAmber, 'Almost full');
    }
    return const SeatStatus(AppColors.green, AppColors.softGreen, 'Seats open');
  }
}

/// One shuttle: photo, name, a single status pill, route, and ETA.
class ShuttleCard extends StatelessWidget {
  final Shuttle shuttle;
  final VoidCallback onTap;

  const ShuttleCard({super.key, required this.shuttle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = SeatStatus.of(shuttle);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset(
                  'assets/images/shuttle_van.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shuttle.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 5),
                    StatusPill(
                      color: status.color,
                      background: status.background,
                      text:
                          '${status.label} · ${shuttle.seatsAvailable}/${shuttle.seatsTotal} seats',
                    ),
                    const SizedBox(height: 5),
                    Text(
                      shuttle.routeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${shuttle.etaMinutes}',
                    style: const TextStyle(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      height: 1.0,
                    ),
                  ),
                  const Text(
                    'min',
                    style: TextStyle(
                      color: AppColors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFB7BEC9)),
            ],
          ),
        ),
      ),
    );
  }
}