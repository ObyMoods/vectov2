import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dashboard_page.dart';

class SplashScreen extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;
  final List<dynamic> news;

  const SplashScreen({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.listBug,
    required this.listDoos,
    required this.news,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  late AnimationController _fadeController;
  late AnimationController _shimmerController;

  bool _fadeOutStarted = false;
  bool _navigated = false;
  bool showSkip = false;

  double _progress = 0.0;

  @override
  void initState() {
    super.initState();

    // Fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    // Shimmer animation
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Show skip button after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => showSkip = true);
    });

    // Video init
    _videoController = VideoPlayerController.asset("assets/videos/splash.mp4")
      ..initialize().then((_) {
        setState(() {});
        _videoController
          ..setLooping(false)
          ..play();

        _videoController.addListener(_videoListener);
      });
  }

  void _videoListener() {
    final position = _videoController.value.position;
    final duration = _videoController.value.duration;

    if (duration.inMilliseconds > 0) {
      setState(() {
        _progress =
            position.inMilliseconds / duration.inMilliseconds;
        _progress = _progress.clamp(0.0, 1.0);
      });

      // Start fade out near end
      if (position >= duration - const Duration(seconds: 1) &&
          !_fadeOutStarted) {
        _fadeOutStarted = true;
        _fadeController.forward();
      }

      // Auto navigate
      if (position >= duration) {
        _navigateToDashboard();
      }
    }
  }

  void _navigateToDashboard() {
    if (!mounted || _navigated) return;
    _navigated = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DashboardPage(
          username: widget.username,
          password: widget.password,
          role: widget.role,
          expiredDate: widget.expiredDate,
          listBug: widget.listBug,
          listDoos: widget.listDoos,
          news: widget.news,
        ),
      ),
    );
  }

  void _skipVideo() {
    if (_fadeOutStarted || _navigated) return;

    _fadeOutStarted = true;

    _fadeController.forward().then((_) {
      if (!mounted) return;

      _videoController.pause();
      _videoController.removeListener(_videoListener);

      _navigateToDashboard();
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _fadeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // VIDEO BACKGROUND
          if (_videoController.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.purple),
            ),

          // OVERLAY GRADIENT
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),

          // TEXT + PROGRESS
          Positioned(
            bottom: 80,
            left: 40,
            right: 40,
            child: Column(
              children: [
                Text(
                  "VECTO X CRASH",
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(
                        color: Colors.purpleAccent.withOpacity(0.9),
                        blurRadius: 10,
                        offset: const Offset(2, 2),
                      ),
                      Shadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 15,
                        offset: const Offset(-2, -2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // PROGRESS BAR
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        FractionallySizedBox(
                          widthFactor: _progress,
                          child: AnimatedBuilder(
                            animation: _shimmerController,
                            builder: (context, child) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF8B5CF6),
                                      Color(0xFFA855F7),
                                      Color(0xFFC084FC),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  "Loading...",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // FADE OUT
          if (_fadeOutStarted)
            FadeTransition(
              opacity: _fadeController,
              child: Container(color: Colors.black),
            ),

          // SKIP BUTTON
          if (showSkip)
            Positioned(
              top: 50,
              right: 20,
              child: AnimatedOpacity(
                opacity: showSkip ? 1 : 0,
                duration: const Duration(milliseconds: 500),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _skipVideo,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: const [
                          Text(
                            "Lewati",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.skip_next,
                              color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}