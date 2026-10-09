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
        body: IndexedStack(
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
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.bottomGradient,
        border: Border(top: BorderSide(color: Color(0xAA9ADFFF), width: 1.2)),
        boxShadow: [
          BoxShadow(color: Color(0x33245F9C), blurRadius: 18, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: _index,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.white,
          unselectedItemColor: const Color(0xD9E8F5FF),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          showUnselectedLabels: true,
          iconSize: 25,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map_rounded),
              label: 'Live Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_bus_outlined),
              activeIcon: Icon(Icons.directions_bus_rounded),
              label: 'Shuttles',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.info_outline_rounded),
              activeIcon: Icon(Icons.info_rounded),
              label: 'Info',
            ),
          ],
        ),
      ),
    );
  }
}
