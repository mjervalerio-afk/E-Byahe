import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'skeleton_loading_screen.dart';

/// Plays assets/videos/splash.mp4 once, full-bleed, then hands off to the
/// skeleton loading screen. If the video fails to load for any reason, a
/// timeout still moves the user forward so no one gets stuck on a black screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/splash.mp4');
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      // Browsers (Chrome/Edge) block autoplay with sound unless the user has
      // already interacted with the page. Muting avoids that block so the
      // splash actually plays instead of silently failing to start.
      _controller.setVolume(0);
      _controller.play();
    });

    _controller.addListener(_checkIfFinished);

    // Fallback in case the video can't play (missing codec, bad asset path, etc.)
    Future.delayed(const Duration(seconds: 5), _goNext);
  }

  void _checkIfFinished() {
    final value = _controller.value;
    if (value.duration > Duration.zero &&
        value.position >= value.duration) {
      _goNext();
    }
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SkeletonLoadingScreen()),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_checkIfFinished);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B4C),
      body: Center(
        child: _controller.value.isInitialized
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}