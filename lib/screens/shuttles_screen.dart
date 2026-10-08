import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/shuttle_card.dart';
import '../widgets/shuttle_tile.dart';

enum _ShuttleFilter { all, open, full }

/// The Shuttles tab: every shuttle in one list, with filters and refresh.
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
    return ChoiceChip(
      label: Text('$label (${_count(value)})'),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AppColors.metallicBlue,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? AppColors.metallicBlue : AppColors.line),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.navy,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 24),
      children: [
        const Icon(Icons.directions_bus_outlined, size: 56, color: Color(0xFFCBD2DB)),
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
    final visible =
        widget.shuttles.where((s) => _matches(s, _filter)).toList();

    return Column(
      children: [
        AppHeader(
          title: 'Shuttles',
          subtitle: '${widget.shuttles.length} active',
          leading: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.directions_bus, color: Colors.white, size: 28),
          ),
          trailing: IconButton(
            tooltip: 'Refresh',
            onPressed: _handleRefresh,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
    );
  }
}
