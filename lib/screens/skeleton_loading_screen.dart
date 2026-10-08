import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme.dart';
import '../widgets/shuttle_tile.dart';
import 'home_shell.dart';

/// Shimmering placeholder shaped like the Live Map (header, map, shuttle
/// list) while data loads. It waits on the real fetchShuttles() future, so
/// it stays up exactly as long as loading takes, then opens the app.
class SkeletonLoadingScreen extends StatefulWidget {
  const SkeletonLoadingScreen({super.key});

  @override
  State<SkeletonLoadingScreen> createState() => _SkeletonLoadingScreenState();
}

class _SkeletonLoadingScreenState extends State<SkeletonLoadingScreen> {
  late final Future<List<Shuttle>> _shuttlesFuture;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _shuttlesFuture = fetchShuttles();
    _shuttlesFuture.then(_goToApp);
  }

  void _goToApp(List<Shuttle> shuttles) {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => HomeShell(shuttles: shuttles),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Widget _bar({double width = double.infinity, double height = 14, double radius = 6}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _cardPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(width: 100, height: 14),
                const SizedBox(height: 8),
                _bar(width: 150, height: 12, radius: 10),
                const SizedBox(height: 8),
                _bar(width: 180, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // The real header, so it doesn't flicker when the app appears.
          const AppHeader(title: 'E-Byahe Shuttle', subtitle: 'Loading shuttles...'),
          Expanded(
            child: Shimmer.fromColors(
              baseColor: const Color(0xFFE6E8EC),
              highlightColor: const Color(0xFFF5F6F8),
              child: Column(
                children: [
                  Expanded(child: Container(color: const Color(0xFFECEDF0))),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bar(width: 110, height: 20),
                        const SizedBox(height: 14),
                        _cardPlaceholder(),
                        const SizedBox(height: 10),
                        _cardPlaceholder(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 64,
            color: AppColors.metallicBlue,
          ),
        ],
      ),
    );
  }
}
