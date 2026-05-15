import 'dart:io';
import 'dart:convert';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'bugs/bug_sender.dart';
import 'tools/spotify.dart';
import 'services/audio_handler.dart';
import 'manager/admin_page.dart';
import 'bugs/home_page.dart';
import 'tools_gateway.dart';
import 'manager/change_password_page.dart';
import 'info/tqto.dart';
import 'info/info.dart';
import 'update_page.dart';
import 'login_page.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// ==================== WEATHER SERVICE ====================
class WeatherService {
  static const String apiKey = '2125665305325885d0fc15a3c69c070f';
  
  static Future<Map<String, dynamic>?> getWeather(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&units=metric&appid=$apiKey'
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Weather error: $e');
    }
    return null;
  }
  
  static String getWeatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear': return '☀️';
      case 'clouds': return '☁️';
      case 'rain': return '🌧️';
      case 'thunderstorm': return '⛈️';
      case 'snow': return '❄️';
      default: return '🌤️';
    }
  }
}

// ==================== NOTIFICATION MODEL ====================
class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime date;
  final bool isRead;
  NotificationItem({required this.id, required this.title, required this.message, required this.date, this.isRead = false});
  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: json['title']?.toString() ?? 'Notifikasi',
    message: json['message']?.toString() ?? '',
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    isRead: json['is_read'] ?? false,
  );
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'message': message, 'date': date.toIso8601String(), 'isRead': isRead};
}

class UpdateItem {
  final String title;
  final String image;
  final String time;
  final bool isNew;
  final String link;
  UpdateItem({required this.title, required this.image, required this.time, required this.isNew, required this.link});
  factory UpdateItem.fromJson(Map<String, dynamic> json) => UpdateItem(
    title: json['title'], image: json['image'], time: json['time'], isNew: json['is_new'], link: json['link'],
  );
}

// ==================== VIDEO WIDGET ====================
class AutoPlayVideoWidget extends StatefulWidget {
  final String videoPath;
  const AutoPlayVideoWidget({super.key, required this.videoPath});

  @override
  State<AutoPlayVideoWidget> createState() => _AutoPlayVideoWidgetState();
}

class _AutoPlayVideoWidgetState extends State<AutoPlayVideoWidget> with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset(widget.videoPath);
      await _controller.initialize();
      _controller.setLooping(true);
      _controller.setVolume(0);
      await _controller.play();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      try {
        _controller = VideoPlayerController.file(File(widget.videoPath));
        await _controller.initialize();
        _controller.setLooping(true);
        _controller.setVolume(0);
        await _controller.play();
        if (mounted) setState(() => _isInitialized = true);
      } catch (e2) {
        print("Video error: $e2");
        if (mounted) setState(() => _isInitialized = true);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;
    if (state == AppLifecycleState.resumed) _controller.play();
    if (state == AppLifecycleState.paused) _controller.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(color: Colors.black, child: const Center(child: CircularProgressIndicator(color: Color(0xFF4A9EFF))));
    }
    return VideoPlayer(_controller);
  }
}

// ==================== DASHBOARD PAGE ====================
class DashboardPage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;
  final List<dynamic> news;
  const DashboardPage({super.key, required this.username, required this.password, required this.role, required this.expiredDate, required this.listBug, required this.listDoos, required this.news});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String? sessionKey;
  late String username, password, role, expiredDate;
  late List<Map<String, dynamic>> listBug, listDoos;
  late List<dynamic> newsList;
  String androidId = "unknown";
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  List<NotificationItem> notifications = [];
  bool isLoadingNotif = false;
  List<UpdateItem> latestUpdates = [];
  bool isLoadingUpdates = true;
  
  String _selectedCityName = "Mendeteksi lokasi...";
  bool _isDetectingCity = false;
  int _selectedTabIndex = 0;
  double? _currentLatitude, _currentLongitude;
  bool _isLocationPermissionGranted = false;
  bool _hasLoadedSavedLocation = false;
  
  Map<String, dynamic>? _weatherData;
  bool _isLoadingWeather = false;
  
  final Color primaryBlue = const Color(0xFF4A9EFF);
  final Color primaryBlueDark = const Color(0xFF2D6FB0);
  final Color primaryBlueLight = const Color(0xFF6DB3F2);
  final Color primaryDark = const Color(0xFF000000);
  final Color cardDark = const Color(0xFF1A1A1A);
  final Color goldColor = const Color(0xFFFFD700);
  
  int onlineUsers = 0;
  int activeConnections = 0;
  String myCoins = "0";
  bool _isLoadingKey = false;
  bool isLoadingBalance = false;
  
  Map<String, Map<String, String>> _sholatTimes = {};
  bool _isLoadingSholat = false;
  bool _hasDetectedCityOnce = false;
  bool _hasShownLocationFallback = false;
  String _nextPrayerName = "", _nextPrayerTime = "", _timeToNextPrayer = "";
  Timer? _countdownTimer;
  
  final List<Map<String, dynamic>> prayers = [
    {'name': 'Subuh', 'icon': Icons.wb_sunny_outlined, 'key': 'Fajr'},
    {'name': 'Dzuhur', 'icon': Icons.wb_sunny, 'key': 'Dhuhr'},
    {'name': 'Ashar', 'icon': Icons.sunny, 'key': 'Asr'},
    {'name': 'Maghrib', 'icon': Icons.nights_stay, 'key': 'Maghrib'},
    {'name': 'Isya', 'icon': Icons.nightlight_round, 'key': 'Isha'},
  ];

  @override
  void initState() {
    super.initState();
    _initData();
    _initAnimations();
    _initTimers();
    _loadSavedLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) { _getSessionKey(); fetchNotifications(); fetchLatestUpdates(); } });
  }

  void _initData() {
    username = widget.username;
    password = widget.password;
    role = widget.role;
    expiredDate = widget.expiredDate;
    listBug = widget.listBug;
    listDoos = widget.listDoos;
    newsList = widget.news;
  }

  void _initAnimations() {
    _fadeController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this)..forward();
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
  }

  void _initTimers() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _now = DateTime.now()); });
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLat = prefs.getDouble('saved_latitude');
    final savedLon = prefs.getDouble('saved_longitude');
    final savedCity = prefs.getString('saved_city_name');
    final savedPrayerTimes = prefs.getString('saved_prayer_times');
    final savedWeather = prefs.getString('saved_weather');
    
    if (savedLat != null && savedLon != null && savedCity != null) {
      setState(() {
        _currentLatitude = savedLat;
        _currentLongitude = savedLon;
        _selectedCityName = savedCity;
        _hasLoadedSavedLocation = true;
      });
      if (savedWeather != null) setState(() { try { _weatherData = jsonDecode(savedWeather); } catch (_) {} });
      if (savedPrayerTimes != null) {
        try {
          setState(() { _sholatTimes['MAIN'] = Map<String, String>.from(jsonDecode(savedPrayerTimes)); _isLoadingSholat = false; });
          _calculateNextPrayer();
          _startCountdownTimer();
        } catch (_) {}
      }
      await _fetchSholatTimesByCoordinates(savedLat, savedLon);
      await _fetchWeatherByCoordinates(savedLat, savedLon);
    } else {
      _checkAndRequestLocationPermission();
    }
  }

  Future<void> _saveLocationData({required double lat, required double lon, required String cityName, Map<String, String>? prayerTimes, Map<String, dynamic>? weather}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('saved_latitude', lat);
    await prefs.setDouble('saved_longitude', lon);
    await prefs.setString('saved_city_name', cityName);
    if (prayerTimes != null) await prefs.setString('saved_prayer_times', jsonEncode(prayerTimes));
    if (weather != null) await prefs.setString('saved_weather', jsonEncode(weather));
  }

  Future<void> _checkAndRequestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _showLocationPermissionDialog();
      return;
    }
    _isLocationPermissionGranted = true;
    _getCurrentLocation();
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Izin Lokasi Diperlukan", style: TextStyle(color: Colors.white)),
        content: const Text("Aplikasi memerlukan izin lokasi untuk menampilkan jadwal sholat dan cuaca sesuai lokasi Anda.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); _setDefaultLocation(); }, child: const Text("Pakai Default", style: TextStyle(color: Colors.white70))),
          ElevatedButton(onPressed: () async { Navigator.pop(context); final p = await Geolocator.requestPermission(); if (p == LocationPermission.always || p == LocationPermission.whileInUse) { _isLocationPermissionGranted = true; _getCurrentLocation(); } else { _setDefaultLocation(); } }, style: ElevatedButton.styleFrom(backgroundColor: primaryBlue), child: const Text("Izinkan")),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    if (_isDetectingCity) return;
    setState(() { _isDetectingCity = true; _selectedCityName = "Mendeteksi lokasi..."; });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) { _showLocationServiceDialog(); return; }
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 15));
      _currentLatitude = position.latitude;
      _currentLongitude = position.longitude;
      final cityName = await _reverseGeocode(position.latitude, position.longitude);
      setState(() { _selectedCityName = cityName ?? "Lokasi Anda"; _hasDetectedCityOnce = true; });
      await Future.wait([
        _fetchSholatTimesByCoordinates(position.latitude, position.longitude),
        _fetchWeatherByCoordinates(position.latitude, position.longitude),
      ]);
    } catch (e) {
      if (!_hasShownLocationFallback) {
        _hasShownLocationFallback = true;
        if (!_hasLoadedSavedLocation) _setDefaultLocation();
      }
    } finally { setState(() => _isDetectingCity = false); }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Layanan Lokasi Mati", style: TextStyle(color: Colors.white)),
        content: const Text("Layanan lokasi sedang tidak aktif. Aktifkan GPS untuk mendapatkan informasi akurat.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); if (!_hasLoadedSavedLocation) _setDefaultLocation(); }, child: const Text("Pakai Default", style: TextStyle(color: Colors.white70))),
          ElevatedButton(onPressed: () async { Navigator.pop(context); await Geolocator.openLocationSettings(); await Future.delayed(const Duration(seconds: 2)); _getCurrentLocation(); }, style: ElevatedButton.styleFrom(backgroundColor: primaryBlue), child: const Text("Buka Pengaturan")),
        ],
      ),
    );
  }

  void _setDefaultLocation() {
    setState(() { _selectedCityName = "Jakarta (Default)"; _currentLatitude = -6.2088; _currentLongitude = 106.8456; });
    _fetchSholatTimesByCoordinates(-6.2088, 106.8456);
    _fetchWeatherByCoordinates(-6.2088, 106.8456);
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    final uri = Uri.parse("https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=10&addressdetails=1");
    final res = await http.get(uri, headers: {"User-Agent": "VectoApp/1.0"});
    if (res.statusCode != 200) return null;
    final address = jsonDecode(res.body)['address'];
    return address['city'] ?? address['town'] ?? address['village'] ?? address['municipality'] ?? address['county'] ?? address['state'] ?? "Lokasi Anda";
  }

  Future<void> _fetchWeatherByCoordinates(double lat, double lon) async {
    setState(() => _isLoadingWeather = true);
    final weather = await WeatherService.getWeather(lat, lon);
    if (weather != null && mounted) {
      setState(() { _weatherData = weather; _isLoadingWeather = false; });
      await _saveLocationData(lat: lat, lon: lon, cityName: _selectedCityName, weather: weather);
    } else {
      setState(() => _isLoadingWeather = false);
    }
  }

  Future<void> _fetchSholatTimesByCoordinates(double lat, double lon) async {
    setState(() => _isLoadingSholat = true);
    try {
      final res = await http.get(Uri.parse("https://api.aladhan.com/v1/timings/${DateFormat('yyyy-MM-dd').format(DateTime.now())}?latitude=$lat&longitude=$lon&method=20")).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final timings = jsonDecode(res.body)['data']['timings'];
        final prayerTimes = { 'Fajr': _cleanTime(timings['Fajr']), 'Dhuhr': _cleanTime(timings['Dhuhr']), 'Asr': _cleanTime(timings['Asr']), 'Maghrib': _cleanTime(timings['Maghrib']), 'Isha': _cleanTime(timings['Isha']) };
        if (mounted) {
          setState(() { _sholatTimes['MAIN'] = prayerTimes; _isLoadingSholat = false; });
          _calculateNextPrayer();
          _startCountdownTimer();
        }
        await _saveLocationData(lat: lat, lon: lon, cityName: _selectedCityName, prayerTimes: prayerTimes);
      } else throw Exception("Gagal mengambil jadwal sholat");
    } catch (e) {
      setState(() => _isLoadingSholat = false);
      setState(() { _sholatTimes['MAIN'] = { 'Fajr': '04:30', 'Dhuhr': '11:55', 'Asr': '15:15', 'Maghrib': '17:55', 'Isha': '19:10' }; });
      _calculateNextPrayer();
      _startCountdownTimer();
    }
  }

  String _cleanTime(String time) => time.split(' ').first;

  void _calculateNextPrayer() {
    if (_sholatTimes.isEmpty || _sholatTimes['MAIN'] == null) return;
    final nowTime = DateFormat('HH:mm').format(DateTime.now());
    final prayerList = [
      {'name': 'Subuh', 'time': _sholatTimes['MAIN']!['Fajr']!},
      {'name': 'Dzuhur', 'time': _sholatTimes['MAIN']!['Dhuhr']!},
      {'name': 'Ashar', 'time': _sholatTimes['MAIN']!['Asr']!},
      {'name': 'Maghrib', 'time': _sholatTimes['MAIN']!['Maghrib']!},
      {'name': 'Isya', 'time': _sholatTimes['MAIN']!['Isha']!},
    ];
    for (int i = 0; i < prayerList.length; i++) {
      if (nowTime.compareTo(prayerList[i]['time']!) < 0) {
        _nextPrayerName = prayerList[i]['name']!;
        _nextPrayerTime = prayerList[i]['time']!;
        _updateTimeToNextPrayer();
        return;
      }
    }
    _nextPrayerName = 'Subuh';
    _nextPrayerTime = prayerList[0]['time']!;
    _updateTimeToNextPrayer();
  }

  void _updateTimeToNextPrayer() {
    if (!mounted || _nextPrayerTime.isEmpty) return;
    final now = DateTime.now();
    final parts = _nextPrayerTime.split(':');
    DateTime nextPrayer = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    if (nextPrayer.isBefore(now)) nextPrayer = nextPrayer.add(const Duration(days: 1));
    final diff = nextPrayer.difference(now);
    if (diff.isNegative) return;
    setState(() => _timeToNextPrayer = '${diff.inHours.toString().padLeft(2, '0')}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}');
  }

  void _startCountdownTimer() {
    if (_sholatTimes.isEmpty) return;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) _updateTimeToNextPrayer(); });
  }

  Future<void> _getSessionKey() async {
    setState(() => _isLoadingKey = true);
    try {
      final response = await http.get(Uri.parse("http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/getKey?username=$username")).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && mounted) {
          setState(() { sessionKey = data['key']; _isLoadingKey = false; _fetchCoinBalance(); });
        } else setState(() => _isLoadingKey = false);
      } else setState(() => _isLoadingKey = false);
    } catch (e) { if (mounted) setState(() => _isLoadingKey = false); }
  }

  Future<void> fetchLatestUpdates() async {
    try {
      final response = await http.get(Uri.parse('http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/api/latest_updates'));
      if (response.statusCode == 200) setState(() => latestUpdates = (jsonDecode(response.body) as List).map((e) => UpdateItem.fromJson(e)).toList());
    } catch (e) {}
    setState(() => isLoadingUpdates = false);
  }

  Future<void> _fetchCoinBalance() async {
    if (isLoadingBalance || sessionKey == null) return;
    setState(() => isLoadingBalance = true);
    try {
      final response = await http.get(Uri.parse('http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/refreshCoins?key=$sessionKey'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['valid'] == true && mounted) setState(() { myCoins = (data['coins'] ?? 0).toString(); isLoadingBalance = false; });
        else setState(() => isLoadingBalance = false);
      } else setState(() => isLoadingBalance = false);
    } catch (e) { setState(() => isLoadingBalance = false); }
  }

  Future<void> fetchNotifications() async {
    setState(() => isLoadingNotif = true);
    try {
      final res = await http.get(Uri.parse("http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/notif.json"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == true && data['notifications'] != null) {
          List<NotificationItem> newNotif = [];
          for (var item in data['notifications']) newNotif.add(NotificationItem.fromJson(item));
          final existingIds = notifications.map((n) => n.id).toSet();
          final uniqueNewNotif = newNotif.where((n) => !existingIds.contains(n.id)).toList();
          final allNotif = [...uniqueNewNotif, ...notifications];
          allNotif.sort((a, b) => b.date.compareTo(a.date));
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList('user_notifications', allNotif.map((n) => jsonEncode(n.toJson())).toList());
          setState(() { notifications = allNotif; isLoadingNotif = false; });
        } else { _loadStoredNotifications(); }
      } else { _loadStoredNotifications(); }
    } catch (e) { _loadStoredNotifications(); }
  }

  Future<void> _loadStoredNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final savedNotif = prefs.getStringList('user_notifications');
    if (savedNotif != null && savedNotif.isNotEmpty) setState(() => notifications = savedNotif.map((n) => NotificationItem.fromJson(jsonDecode(n))).toList());
    setState(() => isLoadingNotif = false);
  }

  Widget _getCurrentPage() {
    return IndexedStack(
      index: _selectedTabIndex,
      children: [
        _buildNewsPage(),
        sessionKey == null ? _buildNewsPage() : HomePage(username: username, password: password, sessionKey: sessionKey!, listBug: listBug, role: role, expiredDate: expiredDate, initialCoins: myCoins),
        sessionKey == null ? _buildNewsPage() : ToolsPage(username: username, userRole: role, sessionKey: sessionKey!, listDoos: listDoos),
      ],
    );
  }

  Widget _buildNewsPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeaderPanel(),
          const SizedBox(height: 12),
          _buildWeatherAndTimePanel(),
          const SizedBox(height: 12),
          _buildWaktuSholat(),
          const SizedBox(height: 12),
          _buildBugSenderButton(),
          const SizedBox(height: 12),
          buildLatestUpdates(),
        ]),
      ),
    );
  }

  Widget _buildHeaderPanel() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 230,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AutoPlayVideoWidget(videoPath: "assets/images/banner.mp4"),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.5), Colors.transparent, Colors.black.withOpacity(0.7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -30),
          child: _buildProfileCard(),
        ),
      ],
    );
  }

  Widget _buildWeatherAndTimePanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryBlue.withOpacity(0.15), Colors.black26],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryBlue.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("WAKTU", style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(
                DateFormat('HH:mm').format(_now),
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryBlue, shadows: [Shadow(blurRadius: 10, color: primaryBlue)]),
              ),
              Text(DateFormat('EEEE, d MMM yyyy', 'id').format(_now), style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          _isLoadingWeather
              ? const SizedBox(width: 60, child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))))
              : (_weatherData != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Text(
                              WeatherService.getWeatherIcon(_weatherData!['weather'][0]['main']),
                              style: const TextStyle(fontSize: 28),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "${(_weatherData!['main']['temp'] as num).round()}°C",
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        Text(
                          _weatherData!['weather'][0]['description'],
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    )
                  : const Text("Cuaca", style: TextStyle(color: Colors.white54, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: primaryBlue.withOpacity(0.3), width: 1),
              boxShadow: [BoxShadow(color: primaryBlue.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: primaryBlue.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)]),
                      child: CircleAvatar(radius: 32, backgroundColor: primaryBlue, child: const Icon(Icons.person, color: Colors.white, size: 32)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Selamat Datang", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(username, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: primaryBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Text(role.toUpperCase(), style: TextStyle(color: primaryBlue, fontSize: 10, fontWeight: FontWeight.bold))),
                              const SizedBox(width: 8),
                              Text("Exp: $expiredDate", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItemGlass(Icons.people_outline, "$onlineUsers", "Users"),
                    _statItemGlass(Icons.link_outlined, "$activeConnections", "Active"),
                    _statItemGlass(Icons.monetization_on, myCoins, "Coins"),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statItemGlass(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryBlue.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: primaryBlue.withOpacity(0.3), width: 0.5)), child: Icon(icon, color: primaryBlue, size: 18)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildWaktuSholat() {
    final times = _sholatTimes['MAIN'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryBlue.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("WAKTU SHOLAT", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: primaryBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 10, color: primaryBlue),
                    const SizedBox(width: 4),
                    Text(_selectedCityName.length > 18 ? '${_selectedCityName.substring(0, 18)}...' : _selectedCityName, style: TextStyle(color: primaryBlue, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingSholat)
            const Center(child: CircularProgressIndicator())
          else if (times != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: prayers.map((prayer) {
                final prayerTime = times[prayer['key']] ?? '--:--';
                return Column(
                  children: [
                    Icon(prayer['icon'] as IconData, color: Colors.white54, size: 22),
                    const SizedBox(height: 6),
                    Text(prayer['name'] as String, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(prayerTime, style: TextStyle(color: primaryBlue, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryBlue.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("NEXT", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryBlue, primaryBlueDark]), borderRadius: BorderRadius.circular(24)),
                  child: Text("$_nextPrayerName in $_timeToNextPrayer", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBugSenderButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [primaryBlue, primaryBlueDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: primaryBlue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.bug_report, color: Colors.white),
        label: const Text("MANAGE BUG SENDER", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 14)),
        onPressed: () {
          if (sessionKey == null) return;
          Navigator.push(context, MaterialPageRoute(builder: (_) => BugSenderPage(sessionKey: sessionKey!, username: username, role: role)));
        },
      ),
    );
  }

  Widget buildLatestUpdates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("LATEST UPDATES", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: primaryBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryBlue.withOpacity(0.3))),
                child: Text("${latestUpdates.length} Updates", style: TextStyle(color: primaryBlue, fontSize: 11)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 240,
          child: isLoadingUpdates
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: latestUpdates.length,
                  itemBuilder: (context, index) {
                    final item = latestUpdates[index];
                    return Container(
                      width: 240,
                      margin: const EdgeInsets.only(left: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primaryBlue.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            child: Image.network(item.image, height: 140, width: 240, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 140, color: Colors.grey[900], child: const Icon(Icons.error, color: Colors.white54))),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 6),
                                Row(children: [Icon(Icons.access_time, size: 12, color: Colors.white54), const SizedBox(width: 4), Text(item.time, style: TextStyle(color: Colors.white54, fontSize: 11))]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: bottomPadding + 8),
      child: Container(
        height: 65,
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: primaryBlue.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: primaryBlue.withOpacity(0.15), blurRadius: 12, spreadRadius: 2, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_outlined, Icons.home, 0, "Home"),
            _navItemCenter(Icons.bug_report_outlined, Icons.bug_report, 1, "Bugs"),
            _navItem(Icons.handyman_outlined, Icons.handyman, 2, "Tools"),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData iconOutline, IconData iconFilled, int index, String label) {
    final isActive = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: isActive ? primaryBlue.withOpacity(0.15) : Colors.transparent),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? iconFilled : iconOutline, color: isActive ? primaryBlue : Colors.white54, size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: isActive ? primaryBlue : Colors.white54, fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _navItemCenter(IconData iconOutline, IconData iconFilled, int index, String label) {
    final isActive = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isActive ? LinearGradient(colors: [primaryBlue, primaryBlueDark]) : LinearGradient(colors: [Colors.white24, Colors.white12]),
              boxShadow: isActive ? [BoxShadow(color: primaryBlue.withOpacity(0.5), blurRadius: 12, spreadRadius: 1)] : [],
            ),
            child: Icon(isActive ? iconFilled : iconOutline, color: isActive ? Colors.white : Colors.white54, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isActive ? primaryBlue : Colors.white54, fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: const BoxDecoration(image: DecorationImage(image: AssetImage("assets/images/vecto.jpg"), fit: BoxFit.cover)),
              child: Container(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withOpacity(0.85), Colors.transparent, Colors.black.withOpacity(0.9)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text("Vecto X Crash", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text("User: $username", style: TextStyle(color: primaryBlue, fontSize: 13)),
                      Text("Role: $role", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      Text("Expired: $expiredDate", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  _drawerItem(Icons.person, "My Info", () {
                    if (sessionKey != null) Navigator.push(context, MaterialPageRoute(builder: (_) => MyInfoPage(username: username, password: password, role: role, expiredDate: expiredDate, sessionKey: sessionKey!, coins: myCoins)));
                  }),
                  if (role != "member") _drawerItem(Icons.admin_panel_settings, "Admin Page", () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminPage(sessionKey: sessionKey!, currentUserRole: role)))),
                  _drawerItem(Icons.group, "Thanks To", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThanksToPage()))),
                  _drawerItem(Icons.system_update_alt, "Update APK", () => Navigator.push(context, MaterialPageRoute(builder: (_) => UpdatePage(nextPage: DashboardPage(username: username, password: password, role: role, expiredDate: expiredDate, listBug: listBug, listDoos: listDoos, news: newsList))))),
                  const Divider(color: Colors.white24),
                  _drawerItem(Icons.logout, "Logout", () async { (await SharedPreferences.getInstance()).clear(); if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false); }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap) => ListTile(leading: Icon(icon, color: primaryBlue), title: Text(label, style: const TextStyle(color: Colors.white)), onTap: onTap);

  @override
  Widget build(BuildContext context) {
  if (sessionKey == null && _isLoadingKey) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
  return Scaffold(
    backgroundColor: primaryDark,
    appBar: AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      titleSpacing: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset("assets/images/logo.png", height: 30),
          const SizedBox(width: 6),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(colors: [primaryBlue, primaryBlueLight, Colors.white]).createShader(bounds),
            child: const Text("VECTO X CRASH", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white)),
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.music_note, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpotifyPage()))),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none, color: Colors.white),
              if (notifications.isNotEmpty)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(10)),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('${notifications.length}', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotifikasiPage(notifications: notifications))),
        ),
        const SizedBox(width: 4),
        IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () async { (await SharedPreferences.getInstance()).clear(); if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false); }),
      ],
    ),
    drawer: _buildDrawer(),
    body: _getCurrentPage(),
    bottomNavigationBar: _buildBottomNav(),
  );
}

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    _clockTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}

// ==================== NOTIFIKASI PAGE ====================
class NotifikasiPage extends StatefulWidget {
  final List<NotificationItem> notifications;
  const NotifikasiPage({super.key, required this.notifications});

  @override
  State<NotifikasiPage> createState() => _NotifikasiPageState();
}

class _NotifikasiPageState extends State<NotifikasiPage> {
  late List<NotificationItem> notifications;
  final Color primaryBlue = const Color(0xFF4A9EFF);

  @override
  void initState() {
    super.initState();
    notifications = List.from(widget.notifications);
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) return "${date.day}/${date.month}/${date.year}";
    if (diff.inDays > 0) return "${diff.inDays} hari yang lalu";
    if (diff.inHours > 0) return "${diff.inHours} jam yang lalu";
    if (diff.inMinutes > 0) return "${diff.inMinutes} menit yang lalu";
    return "Baru saja";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B1C2C), Color(0xFF112D44)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_none, color: Colors.white70),
                    const SizedBox(width: 10),
                    const Text("Notifikasi", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Expanded(
                child: notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_off, size: 50, color: Colors.white54),
                            const SizedBox(height: 16),
                            const Text("Tidak ada notifikasi", style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notif = notifications[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: primaryBlue.withOpacity(0.2)),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryBlue.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.notifications, color: primaryBlue, size: 22),
                              ),
                              title: Text(notif.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text(notif.message, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              trailing: Text(_formatDate(notif.date), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}