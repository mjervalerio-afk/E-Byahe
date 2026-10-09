import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../widgets/shuttle_card.dart';
import '../widgets/shuttle_tile.dart';

/// Detail page for one shuttle: route and ETA, seat count, a seat map drawn
/// over a top-down van, and route progress.
///
/// Seat-by-seat status is currently derived (not real per-seat data): the
/// first `seatsAvailable` seats are shown green, the rest red. Once the
/// load-cell hardware is connected, replace `_seatStatuses` with real
/// per-seat readings.
class ShuttleDetailScreen extends StatelessWidget {
  final Shuttle shuttle;

  /// Called by pull-to-refresh and the menu's Refresh. Optional so the page
  /// still works when opened from places that don't provide one.
  final Future<void> Function()? onRefresh;

  const ShuttleDetailScreen({super.key, required this.shuttle, this.onRefresh});

  List<bool> get _seatStatuses => List<bool>.filled(shuttle.seatsTotal.clamp(0, 15), true); // Demo mode: at most 15 passenger seats.

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
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
    final text = '${shuttle.name}: ${shuttle.seatsAvailable}/${shuttle.seatsTotal} '
        'seats available. On route to ${shuttle.currentDestinationName}, '
        '${shuttle.etaMinutes} min away.';
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    _toast(context, 'Status copied');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
        children: [
          AppHeader(
            title: shuttle.name,
            subtitle: 'Live updates',
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LivePill(),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_vert, color: Colors.white),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _buildSeatAvailableCard(),
                  const SizedBox(height: 14),
                  _buildSeatMapCard(),
                  const SizedBox(height: 14),
                  _buildRouteProgressCard(),
                  const SizedBox(height: 14),
                  _buildLiveUpdatesBanner(),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: appCardDecoration(radius: 16),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.blue, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'On route to',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                Text(
                  shuttle.currentDestinationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${shuttle.etaMinutes} min',
                style: const TextStyle(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const Text(
                'away',
                style: TextStyle(color: AppColors.blue, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeatAvailableCard() {
    final status = SeatStatus.of(shuttle);

    return _Card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seats available',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${shuttle.seatsAvailable}',
                        style: TextStyle(
                          color: status.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 34,
                        ),
                      ),
                      TextSpan(
                        text: ' / ${shuttle.seatsTotal}',
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                StatusPill(
                  color: status.color,
                  background: status.background,
                  text: status.label,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 120,
            height: 84,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF9FCFF), Color(0xFFDCEEFF)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white, width: 1.3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18265F9E),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/shuttle_van.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.directions_bus_rounded,
                color: AppColors.blue,
                size: 42,
              ),
            ),
          ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Seat Map',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.navy,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.softBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, size: 14, color: AppColors.blue),
                    const SizedBox(width: 4),
                    Text(
                      '$occupied / ${shuttle.seatsTotal}',
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: _VanSeatLayout.artworkAspectRatio,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _VanSeatLayout(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  statuses: statuses,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              _LegendSwatch(color: AppColors.green),
              SizedBox(width: 6),
              Text('Available', style: TextStyle(fontSize: 12, color: AppColors.navy)),
              SizedBox(width: 20),
              _LegendSwatch(color: AppColors.red),
              SizedBox(width: 6),
              Text('Occupied', style: TextStyle(fontSize: 12, color: AppColors.navy)),
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
          const Text(
            'Route Progress',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 16),
          _RouteStepRow(
            title: shuttle.originStopName,
            subtitle: 'Departed • ${shuttle.departedTime}',
            status: _RouteStepStatus.done,
            isLast: false,
          ),
          _RouteStepRow(
            title: shuttle.currentDestinationName,
            subtitle: 'Next stop • ${shuttle.etaMinutes} min away',
            status: _RouteStepStatus.current,
            isLast: false,
          ),
          _RouteStepRow(
            title: shuttle.upcomingStopName,
            subtitle: 'Upcoming stop',
            status: _RouteStepStatus.upcoming,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildLiveUpdatesBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: appCardDecoration(radius: 16),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.podcasts, color: AppColors.blue, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Updates',
                  style: TextStyle(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Pull down to refresh. Data is provided for reference only.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
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
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: child,
    );
  }
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
        borderRadius: BorderRadius.circular(size * 0.18),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: available
          ? null
          : Icon(Icons.close, color: Colors.white, size: size * 0.45),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  final Color color;
  const _LegendSwatch({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
    );
  }
}

enum _RouteStepStatus { done, current, upcoming }

class _RouteStepRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final _RouteStepStatus status;
  final bool isLast;

  const _RouteStepRow({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    final Widget dotChild;
    final Color titleColor;

    switch (status) {
      case _RouteStepStatus.done:
        dotColor = AppColors.green;
        dotChild = const Icon(Icons.check, color: Colors.white, size: 14);
        titleColor = AppColors.navy;
        break;
      case _RouteStepStatus.current:
        dotColor = AppColors.blue;
        dotChild = const SizedBox.shrink();
        titleColor = AppColors.blue;
        break;
      case _RouteStepStatus.upcoming:
        dotColor = const Color(0xFFDDDFE3);
        dotChild = const SizedBox.shrink();
        titleColor = AppColors.muted;
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: status == _RouteStepStatus.upcoming ? Colors.white : dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: dotColor,
                    width: status == _RouteStepStatus.done ? 0 : 2,
                  ),
                ),
                child: Center(child: dotChild),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: const Color(0xFFE1E4E9),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Positions the seats over the real top-down van image
/// (assets/images/van_top_down.png). One front passenger seat plus 14 main
/// seats (seven in each row) gives 15 passenger seats total. Driver seat is not counted.
///
/// Wrapping this in an AspectRatio(aspectRatio: artworkAspectRatio) keeps the
/// image's proportions, and the seat fractions below stay aligned with it, on
/// any phone width. Seat size is the smaller of what fits the width and the
/// height, so the rows can never overflow.
class _VanSeatLayout extends StatelessWidget {
  final double width;
  final double height;
  final List<bool> statuses; // all seats, in reading order

  /// Dimensions of the supplied top-down shuttle image (950 × 422).
  static const double artworkAspectRatio = 950 / 422;

  static const double _cabRightFrac = 0.19;
  static const double _frontColWidthFrac = 0.11;
  static const double _frontGapFrac = 0.025;
  static const double _mainRowsLeftFrac =
      _cabRightFrac + _frontColWidthFrac + _frontGapFrac;
  static const double _seatsRightFrac = 0.97;
  static const double _topRowCenterFrac = 0.30;
  static const double _bottomRowCenterFrac = 0.72;

  const _VanSeatLayout({
    required this.width,
    required this.height,
    required this.statuses,
  });

  List<bool> get _frontSeats =>
      statuses.isNotEmpty ? statuses.sublist(0, 1) : const <bool>[];
  List<bool> get _mainSeats =>
      statuses.length > 1 ? statuses.sublist(1, statuses.length.clamp(1, 15)) : const <bool>[];
  List<bool> get _topRow =>
      _mainSeats.sublist(0, (_mainSeats.length / 2).ceil());
  List<bool> get _bottomRow =>
      _mainSeats.sublist((_mainSeats.length / 2).ceil());

  double get _seatSize {
    final seatCount =
        _topRow.length > _bottomRow.length ? _topRow.length : _bottomRow.length;
    if (seatCount == 0) return height * 0.2;

    const minGap = 4.0;
    final availableRowWidth = width * (_seatsRightFrac - _mainRowsLeftFrac);
    final maxByWidth = (availableRowWidth - (seatCount - 1) * minGap) / seatCount;
    final maxByHeight = seatCount > 7 ? height * 0.16 : height * 0.2;

    final size = maxByWidth < maxByHeight ? maxByWidth : maxByHeight;
    return size.clamp(12.0, maxByHeight);
  }

  Widget _seatRow(List<bool> row, double centerYFrac, double seatSize) {
    return Positioned(
      top: height * centerYFrac - seatSize / 2,
      left: width * _mainRowsLeftFrac,
      right: width * (1 - _seatsRightFrac),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final available in row) _SeatBox(available: available, size: seatSize),
        ],
      ),
    );
  }

  Widget _frontSeatColumn(double seatSize) {
    final centerX = width * 0.245;
    return Stack(
      children: [
        for (int i = 0; i < _frontSeats.length; i++)
          Positioned(
            left: centerX - seatSize / 2,
            top: height * (i == 0 ? _topRowCenterFrac : _bottomRowCenterFrac) -
                seatSize / 2,
            child: _SeatBox(available: _frontSeats[i], size: seatSize),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final seatSize = _seatSize;
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset('assets/images/van_top_down.png', fit: BoxFit.fill),
        ),
        _frontSeatColumn(seatSize),
        _seatRow(_topRow, _topRowCenterFrac, seatSize),
        _seatRow(_bottomRow, _bottomRowCenterFrac, seatSize),
      ],
    );
  }
}