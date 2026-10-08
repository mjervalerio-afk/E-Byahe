import 'package:flutter/material.dart';
import '../connection_status.dart';
import '../theme.dart';
import 'shuttle_tile.dart';

class Dot extends StatelessWidget {
  final Color color;
  const Dot({super.key, required this.color});
  @override
  Widget build(BuildContext context) => Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class StatusPill extends StatelessWidget {
  final Color color;
  final Color background;
  final String text;
  final Widget? leading;
  const StatusPill({super.key, required this.color, required this.background, required this.text, this.leading});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (leading != null) ...[leading!, const SizedBox(width: 6)],
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800))),
      ]),
    );
  }
}

class LivePill extends StatefulWidget {
  const LivePill({super.key});
  @override
  State<LivePill> createState() => _LivePillState();
}
class _LivePillState extends State<LivePill> {
  @override
  void initState() { super.initState(); ConnectionStatus.instance.start(); }
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectionStatus.instance.isOnline,
      builder: (context, online, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: online ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFE14B4B).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: online ? 0.12 : 0)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          online ? const Dot(color: Color(0xFF5EE68B)) : const Icon(Icons.wifi_off, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(online ? 'Live' : 'No internet', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
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
    if (shuttle.seatsAvailable <= 0) return const SeatStatus(AppColors.red, AppColors.softRed, 'Full');
    if (shuttle.isLowSeats) return const SeatStatus(AppColors.amber, AppColors.softAmber, 'Almost full');
    return const SeatStatus(AppColors.green, AppColors.softGreen, 'Seats open');
  }
}

class ShuttleCard extends StatelessWidget {
  final Shuttle shuttle;
  final VoidCallback onTap;
  const ShuttleCard({super.key, required this.shuttle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = SeatStatus.of(shuttle);
    final occupied = shuttle.seatsTotal - shuttle.seatsAvailable;
    final occupancy = shuttle.seatsTotal == 0 ? 0.0 : occupied / shuttle.seatsTotal;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 60, height: 60, padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF7F9FC), Color(0xFFEAF0F6)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.asset('assets/images/shuttle_van.png', fit: BoxFit.contain, filterQuality: FilterQuality.high),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(shuttle.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy))),
                  const SizedBox(width: 6),
                  Text('${shuttle.etaMinutes} min', style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w800, fontSize: 13)),
                ]),
                const SizedBox(height: 6),
                StatusPill(color: status.color, background: status.background, text: '${status.label} • ${shuttle.seatsAvailable}/${shuttle.seatsTotal}'),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(minHeight: 5, value: occupancy, backgroundColor: const Color(0xFFE9EDF2), valueColor: AlwaysStoppedAnimation<Color>(status.color)),
                ),
                const SizedBox(height: 7),
                Text(shuttle.routeLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w500)),
              ]),
            ),
            const SizedBox(width: 5),
            const Padding(padding: EdgeInsets.only(top: 18), child: Icon(Icons.chevron_right_rounded, color: Color(0xFFB7BEC9))),
          ]),
        ),
      ),
    );
  }
}