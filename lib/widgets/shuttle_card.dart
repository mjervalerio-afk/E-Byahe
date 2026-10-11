import 'package:flutter/material.dart';
import '../connection_status.dart';
import '../theme.dart';
import 'shuttle_tile.dart';

class Dot extends StatelessWidget {
  final Color color;
  const Dot({super.key, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// Rounded status badge used for seats, connectivity, and active shuttle count.
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.12)),
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

/// Connectivity badge matching the luminous blue header.
class LivePill extends StatefulWidget {
  const LivePill({super.key});

  @override
  State<LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<LivePill> {
  @override
  void initState() {
    super.initState();
    ConnectionStatus.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectionStatus.instance.isOnline,
      builder: (context, online, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: online
              ? Colors.white.withValues(alpha: 0.16)
              : const Color(0xFFE14B4B).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (online)
              const Dot(color: Color(0xFF4ADEAA))
            else
              const Icon(Icons.wifi_off, size: 13, color: Colors.white),
            const SizedBox(width: 7),
            Text(
              online ? 'Live' : 'No internet',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

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

/// Tappable shuttle summary with the van artwork, seat status, route, and ETA.
class ShuttleCard extends StatelessWidget {
  final Shuttle shuttle;
  final VoidCallback onTap;

  const ShuttleCard({super.key, required this.shuttle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = SeatStatus.of(shuttle);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: appCardDecoration(radius: 20),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF9FCFF), Color(0xFFDCEEFF)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 1.3),
                  boxShadow: const [
                    BoxShadow(color: Color(0x18265F9E), blurRadius: 9, offset: Offset(0, 3)),
                  ],
                ),
                child: Image.asset('assets/images/shuttle_van.png', fit: BoxFit.contain),
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
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StatusPill(
                      color: status.color,
                      background: status.background,
                      text: '${status.label} · ${shuttle.seatsAvailable}/${shuttle.seatsTotal}',
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        minHeight: 5,
                        value: shuttle.seatsTotal <= 0
                            ? 0
                            : (shuttle.seatsTotal - shuttle.seatsAvailable) / shuttle.seatsTotal,
                        backgroundColor: const Color(0xFFE3EDF8),
                        valueColor: AlwaysStoppedAnimation<Color>(status.color),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      shuttle.routeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    if (shuttle.remainingDistanceLabel != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        shuttle.remainingDistanceLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: 10),
                      ),
                    ],
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
                      fontSize: 22,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'min',
                    style: TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF91ACCE), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}