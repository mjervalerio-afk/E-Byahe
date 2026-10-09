import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/shuttle_card.dart';
import '../widgets/shuttle_tile.dart';

enum _ShuttleFilter { all, open, full }

/// Fleet list with quick seat-status filters.
class ShuttlesScreen extends StatefulWidget {
  final List<Shuttle> shuttles;
  final ValueChanged<Shuttle> onOpenShuttle;
  final Future<void> Function() onRefresh;

  const ShuttlesScreen({
    super.key,
    required this.shuttles,
    required this.onOpenShuttle,
    required this.onRefresh,
  });

  @override
  State<ShuttlesScreen> createState() => _ShuttlesScreenState();
}

class _ShuttlesScreenState extends State<ShuttlesScreen> {
  _ShuttleFilter _filter = _ShuttleFilter.all;

  bool _matches(Shuttle s, _ShuttleFilter filter) {
    switch (filter) {
      case _ShuttleFilter.all:
        return true;
      case _ShuttleFilter.open:
        return s.seatsAvailable > 0;
      case _ShuttleFilter.full:
        return s.seatsAvailable <= 0;
    }
  }

  int _count(_ShuttleFilter filter) =>
      widget.shuttles.where((s) => _matches(s, filter)).length;

  Future<void> _handleRefresh() async {
    await widget.onRefresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Shuttle list updated'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Widget _chip(String label, _ShuttleFilter value) {
    final selected = _filter == value;
    final radius = BorderRadius.circular(15);

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: selected ? AppColors.headerGradient : AppColors.glassGradient,
          borderRadius: radius,
          border: Border.all(
            color: selected ? const Color(0xFF85CFFF) : AppColors.line,
            width: selected ? 1.3 : 1,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x332A78BC),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: () => setState(() => _filter = value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            child: Text(
              '$label (${_count(value)})',
              style: TextStyle(
                color: selected ? Colors.white : AppColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 24),
      children: [
        const Icon(Icons.directions_bus_outlined, size: 56, color: Color(0xFFB9CCE2)),
        const SizedBox(height: 12),
        const Text(
          'No shuttles match this filter',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Try another filter, or pull down to refresh.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _filter = _ShuttleFilter.all),
            child: const Text('Show all shuttles'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.shuttles.where((s) => _matches(s, _filter)).toList();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF8FBFF),
            AppColors.background,
            Color(0xFFEDF6FF),
          ],
          stops: [0, 0.62, 1],
        ),
      ),
      child: Column(
        children: [
          AppHeader(
            title: 'Shuttles',
            subtitle: '${widget.shuttles.length} active',
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x667FD1FF), Color(0x22FFFFFF)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33204470),
                    blurRadius: 9,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_bus_rounded,
                color: Colors.white,
                size: 27,
              ),
            ),
            trailing: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22204470),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                tooltip: 'Refresh',
                onPressed: _handleRefresh,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('All', _ShuttleFilter.all),
                  _chip('Seats open', _ShuttleFilter.open),
                  _chip('Full', _ShuttleFilter.full),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.blue,
              onRefresh: _handleRefresh,
              child: visible.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => ShuttleCard(
                        shuttle: visible[i],
                        onTap: () => widget.onOpenShuttle(visible[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
