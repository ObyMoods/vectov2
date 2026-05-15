import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Pages
import 'landing.dart';
import 'login_page.dart';
import 'splash.dart';
import 'dashboard_page.dart';
import 'purchase_page.dart';
import 'bugs/home_page.dart';
import 'manager/admin_page.dart';
import 'services/audio_handler.dart';
import 'build_apk_flutter.dart';
import 'web_to_apk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    debugPrint('DateFormat error: $e');
  }

  // Inisialisasi audio handler
  try {
    await initAudioHandlerIfNeeded();
  } catch (e) {
    debugPrint('Audio handler init failed: $e');
  }

  // Request permission notifikasi untuk Android 13+
  try {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final savedUsername = prefs.getString('username');
  final savedPassword = prefs.getString('password');
  final savedKey = prefs.getString('sessionKey');
  final savedRole = prefs.getString('role');
  final savedExpiredDate = prefs.getString('expiredDate');
  
  final savedListBug = prefs.getStringList('listBug') ?? [];
  final savedListDoos = prefs.getStringList('listDoos') ?? [];
  final savedNews = prefs.getStringList('news') ?? [];
  
  final listBug = savedListBug.map((e) => Map<String, dynamic>.from(jsonDecode(e))).toList();
  final listDoos = savedListDoos.map((e) => Map<String, dynamic>.from(jsonDecode(e))).toList();
  final news = savedNews.map((e) => Map<String, dynamic>.from(jsonDecode(e))).toList();

  Widget initialPage;
  
  if (isLoggedIn && savedUsername != null && savedPassword != null && savedKey != null) {
    initialPage = SplashScreen(
      username: savedUsername,
      password: savedPassword,
      role: savedRole ?? 'user',
      expiredDate: savedExpiredDate ?? '',
      listBug: listBug,
      listDoos: listDoos,
      news: news,
    );
  } else {
    initialPage = const LandingPage();
  }

  runApp(MyApp(initialPage: initialPage));
}

class MyApp extends StatelessWidget {
  final Widget initialPage;
  
  const MyApp({super.key, required this.initialPage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VECTO X CRASH',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Orbitron',
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark().copyWith(secondary: Colors.purple),
      ),
      home: initialPage,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/landing':
            return MaterialPageRoute(builder: (_) => const LandingPage());

          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginPage());

          case '/splash':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => SplashScreen(
                username: args['username'] ?? '',
                password: args['password'] ?? '',
                role: args['role'] ?? 'user',
                expiredDate: args['expiredDate'] ?? '',
                listBug: List<Map<String, dynamic>>.from(args['listBug'] ?? []),
                listDoos: List<Map<String, dynamic>>.from(args['listDoos'] ?? []),
                news: List<Map<String, dynamic>>.from(args['news'] ?? []),
              ),
            );

          case '/dashboard':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => DashboardPage(
                username: args['username'] ?? '',
                password: args['password'] ?? '',
                role: args['role'] ?? 'user',
                expiredDate: args['expiredDate'] ?? '',
                listBug: List<Map<String, dynamic>>.from(args['listBug'] ?? []),
                listDoos: List<Map<String, dynamic>>.from(args['listDoos'] ?? []),
                news: List<Map<String, dynamic>>.from(args['news'] ?? []),
              ),
            );

          case '/home':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => HomePage(
                username: args['username'] ?? '',
                password: args['password'] ?? '',
                listBug: List<Map<String, dynamic>>.from(args['listBug'] ?? []),
                role: args['role'] ?? 'user',
                expiredDate: args['expiredDate'] ?? '',
                sessionKey: args['sessionKey'],
                initialCoins: args['initialCoins'] ?? 100,
              ),
            );

          case '/admin':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => AdminPage(
                sessionKey: args['sessionKey'],
                currentUserRole: args['role'] ?? 'admin',
              ),
            );

          case '/purchase':
            return PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 400),
              pageBuilder: (_, __, ___) => const PurchasePage(),
              transitionsBuilder: (_, animation, __, child) {
                return SlideTransition(
                  position: Tween(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                );
              },
            );

          case '/build_apk':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => BuildApkFlutter(
                sessionKey: args?['sessionKey'],
                username: args?['username'],
                role: args?['role'],
              ),
            );

          case '/web_to_apk':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => WebToApk(
                sessionKey: args?['sessionKey'],
                username: args?['username'],
                role: args?['role'],
              ),
            );

          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: Text(
                    '404 - Page Not Found',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
        }
      },
    );
  }
}