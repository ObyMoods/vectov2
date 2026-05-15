import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:video_player/video_player.dart';
import 'splash.dart';

const String baseUrl = "http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323";

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  // Controllers
  final userController = TextEditingController();
  final passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // State variables
  bool isLoading = false;
  bool _obscurePassword = true;
  bool isChecking = true;
  String? androidId;

  // Animations
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  // Video
  late VideoPlayerController _videoController;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initVideo();
    _checkAutoLogin();
  }

  void _initAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );
  }

  void _initVideo() {
    _videoController = VideoPlayerController.asset('assets/videos/banner.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _videoInitialized = true);
          _videoController.play();
          _videoController.setLooping(true);
          _videoController.setVolume(0.0);
        }
      }).catchError((error) {
        debugPrint("Error initializing video: $error");
      });
  }

  // ==================== AUTO LOGIN ====================
  Future<void> _checkAutoLogin() async {
    androidId = await _getAndroidId();

    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString("username");
    final savedPass = prefs.getString("password");
    final savedKey = prefs.getString("sessionKey");

    if (savedUser != null && savedPass != null && savedKey != null) {
      final uri = Uri.parse(
        "$baseUrl/myInfo?username=$savedUser&password=$savedPass&androidId=$androidId&key=$savedKey",
      );

      try {
        final res = await http.get(uri).timeout(const Duration(seconds: 8));
        final data = jsonDecode(res.body);

        if (data['valid'] == true && mounted) {
          _navigateToSplashScreen(
            username: savedUser,
            password: savedPass,
            role: data['role'],
            expiredDate: data['expiredDate'],
            listBug: (data['listBug'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
            listDoos: (data['listDDoS'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
            news: (data['news'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
          );
          return;
        }
      } catch (e) {
        debugPrint("Auto login gagal: $e");
      }
    }

    if (mounted) {
      setState(() => isChecking = false);
    }
  }

  Future<String> _getAndroidId() async {
    final deviceInfo = DeviceInfoPlugin();
    final android = await deviceInfo.androidInfo;
    return android.id ?? "unknown_device";
  }

  // ==================== LOGIN ====================
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    androidId ??= await _getAndroidId();

    final username = userController.text.trim();
    final password = passController.text.trim();

    setState(() => isLoading = true);

    try {
      final validate = await http.post(
        Uri.parse("$baseUrl/validate"),
        body: {
          "username": username,
          "password": password,
          "androidId": androidId ?? "unknown_device",
        },
      );

      final validData = jsonDecode(validate.body);
      debugPrint("VALIDATE RESPONSE => $validData");

      if (validData['expired'] == true) {
        _showErrorPopup(
          title: "⏳ Access Expired",
          message: "Your access has expired.\nPlease renew it.",
          color: Colors.orange,
          showContact: true,
        );
        setState(() => isLoading = false);
      } else if (validData['valid'] != true) {
        _showErrorPopup(
          title: "❌ Login Failed",
          message: "Invalid username or password.",
          color: Colors.red,
        );
        setState(() => isLoading = false);
      } else {
        await _saveLoginSession(
          username: username,
          password: password,
          key: validData['key'],
          role: validData['role'],
          expiredDate: validData['expiredDate'],
          listBug: (validData['listBug'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
          listDoos: (validData['listDDoS'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
          news: (validData['news'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );

        if (mounted) {
          _navigateToSplashScreen(
            username: username,
            password: password,
            role: validData['role'],
            expiredDate: validData['expiredDate'],
            listBug: (validData['listBug'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
            listDoos: (validData['listDDoS'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
            news: (validData['news'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
          );
        }
      }
    } catch (e) {
      _showErrorPopup(
        title: "⚠️ Connection Error",
        message: "Failed to connect to the server.\nPlease check your internet connection.",
        color: const Color(0xFFE53935),
      );
      setState(() => isLoading = false);
    }
  }

  // ==================== SAVE SESSION ====================
  Future<void> _saveLoginSession({
    required String username,
    required String password,
    required String key,
    required String role,
    required String expiredDate,
    required List<Map<String, dynamic>> listBug,
    required List<Map<String, dynamic>> listDoos,
    required List<dynamic> news,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('username', username);
    await prefs.setString('password', password);
    await prefs.setString('sessionKey', key);
    await prefs.setString('role', role);
    await prefs.setString('expiredDate', expiredDate);
    await prefs.setStringList(
      'listBug',
      listBug.map((e) => jsonEncode(e)).toList(),
    );
    await prefs.setStringList(
      'listDoos',
      listDoos.map((e) => jsonEncode(e)).toList(),
    );
    await prefs.setStringList(
      'news',
      news.map((e) => jsonEncode(e)).toList(),
    );
  }

  // ==================== NAVIGATION ====================
  void _navigateToSplashScreen({
    required String username,
    required String password,
    required String role,
    required String expiredDate,
    required List<Map<String, dynamic>> listBug,
    required List<Map<String, dynamic>> listDoos,
    required List<dynamic> news,
  }) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SplashScreen(
          username: username,
          password: password,
          role: role,
          expiredDate: expiredDate,
          listBug: listBug,
          listDoos: listDoos,
          news: news,
        ),
      ),
    );
  }

  // ==================== POPUP ERROR ====================
  void _showErrorPopup({
    required String title,
    required String message,
    Color color = Colors.red,
    bool showContact = false,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF141A2D).withOpacity(0.95),
                const Color(0xFF0A0E17).withOpacity(0.98),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.grey.shade800.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.2),
                            color.withOpacity(0.1),
                          ],
                        ),
                        border: Border.all(
                          color: color.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          title.substring(0, 2),
                          style: TextStyle(
                            fontSize: 24,
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.grey.shade100,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 15,
                        height: 1.5,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        if (showContact)
                          Expanded(
                            child: _buildContactButton(),
                          ),
                        if (showContact) const SizedBox(width: 12),
                        Expanded(
                          child: _buildCloseButton(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade700.withOpacity(0.8),
            Colors.purple.shade900.withOpacity(0.9),
          ],
        ),
        border: Border.all(
          color: Colors.purple.shade800.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () async {
            final uri = Uri.parse("https://t.me/crit_v");
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          borderRadius: BorderRadius.circular(14),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.telegram, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  "Contact",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade800.withOpacity(0.5),
          width: 1,
        ),
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade900.withOpacity(0.4),
            Colors.grey.shade800.withOpacity(0.3),
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(14),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Center(
              child: Text(
                "Close",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== WIDGETS ====================
  Widget _buildLoader() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Color(0xFF5C6BC0),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade800.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: TextFormField(
            controller: controller,
            obscureText: isPassword ? _obscurePassword : false,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade900.withOpacity(0.3),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.grey.shade700,
                  width: 1,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1,
                ),
              ),
            ),
            validator: (value) =>
                value == null || value.isEmpty ? "Please enter $hint" : null,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade800.withOpacity(0.4),
            Colors.grey.shade900.withOpacity(0.5),
          ],
        ),
        border: Border.all(
          color: Colors.grey.shade800.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white70,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    "Logging in...",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              )
            : const Text(
                "LOGIN",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
      ),
    );
  }

  Widget _buildContactAdminButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade800.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.grey.shade900.withOpacity(0.2),
            child: InkWell(
              onTap: () async {
                final uri = Uri.parse("https://t.me/crit_v");
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.purple,
                      size: 16,
                    ),
                    SizedBox(width: 10),
                    Text(
                      "Contact Admin",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isChecking
          ? _buildLoader()
          : Stack(
              children: [
                // Video Background
                Positioned.fill(
                  child: _videoInitialized
                      ? FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _videoController.value.size.width,
                            height: _videoController.value.size.height,
                            child: VideoPlayer(_videoController),
                          ),
                        )
                      : Container(color: Colors.black),
                ),

                // Gradient Overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ),

                // Login Card
                Center(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: ScaleTransition(
                      scale: _scaleAnim,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.85,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      image: DecorationImage(
                                        image: AssetImage('assets/images/logo.jpg'),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  const Text(
                                    "Welcome Back",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  Text(
                                    "Login to continue",
                                    style: TextStyle(
                                      color: Colors.grey.shade300,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  _buildTextField(
                                    controller: userController,
                                    hint: "Username",
                                  ),
                                  const SizedBox(height: 16),

                                  _buildTextField(
                                    controller: passController,
                                    hint: "Password",
                                    isPassword: true,
                                  ),
                                  const SizedBox(height: 24),

                                  _buildLoginButton(),
                                  const SizedBox(height: 16),

                                  _buildContactAdminButton(),
                                ],
                              ),
                            ),
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

  @override
  void dispose() {
    _controller.dispose();
    _videoController.dispose();
    userController.dispose();
    passController.dispose();
    super.dispose();
  }
}