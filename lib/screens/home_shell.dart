import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/landmarks.dart';
import '../widgets/shuttle_tile.dart';
import 'info_screen.dart';
import 'live_map_screen.dart';
import 'shuttle_detail_screen.dart';
import 'shuttles_screen.dart';

/// Main frame for the three primary E-Byahe sections.
class HomeShell extends StatefulWidget {
  final List<Shuttle> shuttles;

  const HomeShell({super.key, this.shuttles = mockShuttles});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late List<Shuttle> _shuttles = widget.shuttles;
  final ValueNotifier<Landmark?> _focusPlace = ValueNotifier<Landmark?>(null);

  @override
  void dispose() {
    _focusPlace.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final data = await fetchShuttles();
    if (!mounted) return;
    setState(() => _shuttles = data);
  }

  void _openShuttle(Shuttle shuttle) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShuttleDetailScreen(shuttle: shuttle, onRefresh: _refresh),
      ),
    );
  }

  void _showPlaceOnMap(Landmark place) {
    setState(() => _index = 0);
    _focusPlace.value = null;
    _focusPlace.value = place;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
          child: IndexedStack(
          index: _index,
          children: [
            LiveMapScreen(
              shuttles: _shuttles,
              onOpenShuttle: _openShuttle,
              focusPlace: _focusPlace,
            ),
            ShuttlesScreen(
              shuttles: _shuttles,
              onOpenShuttle: _openShuttle,
              onRefresh: _refresh,
            ),
            InfoScreen(onShowPlace: _showPlaceOnMap),
          ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.bottomGradient,
        border: Border(top: BorderSide(color: Color(0xAA9ADFFF), width: 1.3)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33245F9C),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 9, 8, 5),
          child: Row(
            children: [
              _BottomNavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map_rounded,
                label: 'Live Map',
                selected: _index == 0,
                onTap: () => setState(() => _index = 0),
              ),
              _BottomNavItem(
                icon: Icons.directions_bus_outlined,
                activeIcon: Icons.directions_bus_rounded,
                label: 'Shuttles',
                selected: _index == 1,
                onTap: () => setState(() => _index = 1),
              ),
              _BottomNavItem(
                icon: Icons.info_outline_rounded,
                activeIcon: Icons.info_rounded,
                label: 'Info',
                selected: _index == 2,
                onTap: () => setState(() => _index = 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom tab surface gives the active section a soft cyan underline like the
/// reference design, while keeping every tab's touch target evenly spaced.
class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = selected ? Colors.white : const Color(0xD9E8F5FF);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  size: 25,
                  color: labelColor,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: selected ? 44 : 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.sky : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                              color: Color(0xAA7FD9FF),
                              blurRadius: 8,
                              spreadRadius: 0.5,
                            ),
                          ]
                        : const <BoxShadow>[],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
