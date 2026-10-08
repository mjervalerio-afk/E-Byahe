import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../widgets/shuttle_card.dart';
import '../widgets/shuttle_tile.dart';

class ShuttleDetailScreen extends StatelessWidget {
  final Shuttle shuttle;
  final Future<void> Function()? onRefresh;

  const ShuttleDetailScreen({super.key, required this.shuttle, this.onRefresh});

  List<bool> get _seatStatuses => List.generate(
        shuttle.seatsTotal,
        (i) => i < shuttle.seatsAvailable,
      );

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  Future<void> _refresh(BuildContext context) async {
    if (onRefresh != null) {
      await onRefresh!();
    } else {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (!context.mounted) return;
    _toast(context, 'Shuttle status is up to date');
  }

  Future<void> _copyStatus(BuildContext context) async {
    final text = '${shuttle.name}: ${shuttle.seatsAvailable}/${shuttle.seatsTotal} seats available. '
        'On route to ${shuttle.currentDestinationName}, ${shuttle.etaMinutes} min away.';
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    _toast(context, 'Status copied');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: shuttle.name,
            subtitle: 'Live shuttle status',
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LivePill(),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'refresh') _refresh(context);
                    if (value == 'copy') _copyStatus(context);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'refresh', child: Text('Refresh')),
                    PopupMenuItem(value: 'copy', child: Text('Copy status')),
                  ],
                ),
              ],
            ),
            bottom: _buildRouteCard(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refresh(context),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                children: [
                  _buildSeatAvailableCard(),
                  const SizedBox(height: 12),
                  _buildSeatMapCard(),
                  const SizedBox(height: 12),
                  _buildRouteProgressCard(),
                  const SizedBox(height: 12),
                  _buildLiveUpdatesBanner(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: AppColors.softBlue, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.route_rounded, color: AppColors.blue, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('On route to', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600)),
                Text(
                  shuttle.currentDestinationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${shuttle.etaMinutes} min', style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w900, fontSize: 15)),
              const Text('away', style: TextStyle(color: AppColors.muted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeatAvailableCard() {
    final status = SeatStatus.of(shuttle);
    final occupied = shuttle.seatsTotal - shuttle.seatsAvailable;
    final ratio = shuttle.seatsTotal == 0 ? 0.0 : occupied / shuttle.seatsTotal;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Current occupancy', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy)),
              ),
              StatusPill(color: status.color, background: status.background, text: status.label),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$occupied', style: TextStyle(color: status.color, fontWeight: FontWeight.w900, fontSize: 38, height: .95)),
              Text(' / ${shuttle.seatsTotal} occupied', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              Container(
                width: 92,
                height: 64,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF7F9FC), Color(0xFFEAF0F6)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset('assets/images/shuttle_van.png', fit: BoxFit.contain, filterQuality: FilterQuality.high),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: ratio,
              backgroundColor: const Color(0xFFE9EDF2),
              valueColor: AlwaysStoppedAnimation<Color>(status.color),
            ),
          ),
          const SizedBox(height: 7),
          Text('${shuttle.seatsAvailable} seats available', style: TextStyle(color: status.color, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildSeatMapCard() {
    final statuses = _seatStatuses;
    final occupied = shuttle.seatsTotal - shuttle.seatsAvailable;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Van occupancy', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy)),
                    SizedBox(height: 2),
                    Text('Seat-by-seat availability', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(99)),
                child: Text('$occupied/${shuttle.seatsTotal}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: AspectRatio(
              aspectRatio: _VanSeatLayout.artworkAspectRatio,
              child: LayoutBuilder(
                builder: (context, constraints) => _VanSeatLayout(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  statuses: statuses,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const _LegendSwatch(color: AppColors.green),
              const SizedBox(width: 6),
              const Text('Available', style: TextStyle(fontSize: 11, color: AppColors.navy, fontWeight: FontWeight.w600)),
              const SizedBox(width: 18),
              const _LegendSwatch(color: AppColors.red),
              const SizedBox(width: 6),
              const Text('Occupied', style: TextStyle(fontSize: 11, color: AppColors.navy, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$shuttle.seatsTotal seats total', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteProgressCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Route progress', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy)),
          const SizedBox(height: 16),
          _RouteStepRow(title: shuttle.originStopName, subtitle: 'Departed • ${shuttle.departedTime}', status: _RouteStepStatus.done, isLast: false),
          _RouteStepRow(title: shuttle.currentDestinationName, subtitle: 'Next stop • ${shuttle.etaMinutes} min away', status: _RouteStepStatus.current, isLast: false),
          _RouteStepRow(title: shuttle.upcomingStopName, subtitle: 'Upcoming stop', status: _RouteStepStatus.upcoming, isLast: true),
        ],
      ),
    );
  }

  Widget _buildLiveUpdatesBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.softBlue, borderRadius: BorderRadius.circular(15)),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sensors_rounded, color: AppColors.blue, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live sensor data', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w800, fontSize: 12)),
                SizedBox(height: 3),
                Text('Seat status will update automatically when the load-cell system is connected.', style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: appCardDecoration(),
    child: child,
  );
}

class _SeatBox extends StatelessWidget {
  final bool available;
  final double size;
  const _SeatBox({required this.available, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: available ? AppColors.green : AppColors.red,
        borderRadius: BorderRadius.circular(size * .22),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x180D1B4C), blurRadius: 5, offset: Offset(0, 2))],
      ),
      child: Center(
        child: Icon(available ? Icons.event_seat_rounded : Icons.person_rounded, color: Colors.white, size: size * .42),
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  final Color color;
  const _LegendSwatch({required this.color});
  @override
  Widget build(BuildContext context) => Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)));
}

enum _RouteStepStatus { done, current, upcoming }

class _RouteStepRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final _RouteStepStatus status;
  final bool isLast;
  const _RouteStepRow({required this.title, required this.subtitle, required this.status, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    final Widget dotChild;
    final Color titleColor;
    switch (status) {
      case _RouteStepStatus.done:
        dotColor = AppColors.green; dotChild = const Icon(Icons.check, color: Colors.white, size: 14); titleColor = AppColors.navy; break;
      case _RouteStepStatus.current:
        dotColor = AppColors.blue; dotChild = const Icon(Icons.navigation_rounded, color: Colors.white, size: 11); titleColor = AppColors.blue; break;
      case _RouteStepStatus.upcoming:
        dotColor = const Color(0xFFCDD3DB); dotChild = const SizedBox.shrink(); titleColor = AppColors.muted; break;
    }
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: status == _RouteStepStatus.upcoming ? Colors.white : dotColor,
              shape: BoxShape.circle,
              border: Border.all(color: dotColor, width: status == _RouteStepStatus.done ? 0 : 2),
            ),
            child: Center(child: dotChild),
          ),
          if (!isLast) Container(width: 2, height: 40, color: const Color(0xFFE1E4E9)),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: titleColor)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
        )),
      ]),
    );
  }
}

class _VanSeatLayout extends StatelessWidget {
  final double width;
  final double height;
  final List<bool> statuses;

  static const double artworkAspectRatio = 462 / 236;
  static const double _cabRightFrac = 0.335;
  static const double _frontColWidthFrac = 0.09;
  static const double _frontGapFrac = 0.02;
  static const double _mainRowsLeftFrac = _cabRightFrac + _frontColWidthFrac + _frontGapFrac;
  static const double _seatsRightFrac = 0.97;
  static const double _topRowCenterFrac = 0.30;
  static const double _bottomRowCenterFrac = 0.72;

  const _VanSeatLayout({required this.width, required this.height, required this.statuses});

  List<bool> get _frontSeats => statuses.length > 2 ? statuses.sublist(0, 2) : statuses;
  List<bool> get _mainSeats => statuses.length > 2 ? statuses.sublist(2) : const <bool>[];
  List<bool> get _topRow => _mainSeats.sublist(0, (_mainSeats.length / 2).ceil());
  List<bool> get _bottomRow => _mainSeats.sublist((_mainSeats.length / 2).ceil());

  double get _seatSize {
    final count = _topRow.length > _bottomRow.length ? _topRow.length : _bottomRow.length;
    if (count == 0) return height * .2;
    const gap = 4.0;
    final rowWidth = width * (_seatsRightFrac - _mainRowsLeftFrac);
    final byWidth = (rowWidth - (count - 1) * gap) / count;
    final byHeight = height * .17;
    return (byWidth < byHeight ? byWidth : byHeight).clamp(16.0, byHeight);
  }

  Widget _seatRow(List<bool> row, double centerY, double size) {
    return Positioned(
      top: height * centerY - size / 2,
      left: width * _mainRowsLeftFrac,
      right: width * (1 - _seatsRightFrac),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [for (final available in row) _SeatBox(available: available, size: size)],
      ),
    );
  }

  Widget _frontSeatColumn(double size) {
    final centerX = width * (_cabRightFrac + _frontColWidthFrac / 2);
    return Stack(children: [
      for (int i = 0; i < _frontSeats.length; i++)
        Positioned(
          left: centerX - size / 2,
          top: height * (i == 0 ? _topRowCenterFrac : _bottomRowCenterFrac) - size / 2,
          child: _SeatBox(available: _frontSeats[i], size: size),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final size = _seatSize;
    return Stack(children: [
      Positioned.fill(child: Image.asset('assets/images/van_top_down.png', fit: BoxFit.fill, filterQuality: FilterQuality.high)),
      _frontSeatColumn(size),
      _seatRow(_topRow, _topRowCenterFrac, size),
      _seatRow(_bottomRow, _bottomRowCenterFrac, size),
    ]);
  }
}
