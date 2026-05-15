import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
    
    late VideoPlayerController _controller;
    late AnimationController _animController;
    late Animation<double> _fadeAnim;
    late Animation<Offset> _slideAnim;
    
    bool _isCheckingSession = true;
    bool _isLoggedIn = false;

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  
  _checkLoginSession();

  _controller = VideoPlayerController.asset(
    "assets/videos/landing.mp4",
  )..initialize().then((_) async {
      if (!mounted) return;

      await _controller.setLooping(true);
      await _controller.setVolume(0);
      await _controller.play();

      setState(() {});
    });

  _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
    CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ),
  );

  _slideAnim = Tween<Offset>(
    begin: const Offset(0, 0.3),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ),
  );

  _animController.forward();
}

  Future<void> _checkLoginSession() async {
    setState(() {
      _isCheckingSession = true;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      final savedUsername = prefs.getString('username');
      final savedSessionKey = prefs.getString('sessionKey');
      
      if (isLoggedIn && savedUsername != null && savedSessionKey != null) {
        _isLoggedIn = true;
        
        if (mounted) {
          Navigator.pushReplacementNamed(
            context, 
            "/dashboard",
            arguments: {
              'username': savedUsername,
              'sessionKey': savedSessionKey,
            },
          );
        }
      } else {
        _isLoggedIn = false;
      }
    } catch (e) {
      print("Error checking session: $e");
      _isLoggedIn = false;
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingSession = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;

    if (state == AppLifecycleState.paused) {
      _controller.pause();
    } else if (state == AppLifecycleState.resumed) {
      _controller.play();
      _checkLoginSession();
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _goToLogin() async {
    await _controller.pause();
    if (mounted) {
      Navigator.pushReplacementNamed(context, "/login");
    }
  }

  Future<void> _goToRegister() async {
    await _controller.pause();
    if (mounted) {
      Navigator.pushReplacementNamed(context, "/purchase");
    }
  }

@override
Widget build(BuildContext context) {
  if (_isCheckingSession) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF5C6BC0), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF5C6BC0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "CHECKING SESSION...",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  return Scaffold(
    body: Stack(
      children: [
        if (_controller.value.isInitialized)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          )
        else
          Container(color: Colors.black),

        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.8),
                const Color(0xFF0A0E27).withOpacity(0.9),
                Colors.black.withOpacity(0.95),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // ⚡ CONTENT
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    Text(
                      "VECTO X CRASH",
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 25,
                            color: const Color(0xFF5C6BC0),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      "BY XYROO",
                      style: TextStyle(
                        fontSize: 16,
                        letterSpacing: 4,
                        color: Colors.white70,
                      ),
                    ),

                    const SizedBox(height: 70),

                    _cyberButton(
                      title: "LOGIN",
                      onTap: _goToLogin,
                    ),

                    const SizedBox(height: 16),

                    _cyberButton(
                      title: "REGISTER",
                      onTap: _goToRegister,
                    ),

                    const Spacer(),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _socialBtn(
                          FontAwesomeIcons.telegram,
                          "https://t.me/crit_v",
                        ),
                        const SizedBox(width: 20),
                        _socialBtn(
                          FontAwesomeIcons.tiktok,
                          "https://www.tiktok.com/@",
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      "SYSTEM ACTIVE • 2026",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _cyberButton({
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF5C6BC0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5C6BC0).withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialBtn(IconData icon, String url) {
    return GestureDetector(
      onTap: () => _openUrl(url),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF5C6BC0)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5C6BC0).withOpacity(0.5),
              blurRadius: 15,
            ),
          ],
        ),
        child: Center(
          child: FaIcon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}