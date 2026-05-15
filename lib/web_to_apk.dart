import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:archive/archive.dart';
import 'dart:async';
import 'history_build.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebToApk extends StatefulWidget {
  final String? sessionKey;
  final String? username;
  final String? role;

  const WebToApk({
    super.key,
    this.sessionKey,
    this.username,
    this.role,
  });

  @override
  State<WebToApk> createState() => _WebToApkState();
}

class _WebToApkState extends State<WebToApk> with TickerProviderStateMixin {
  final TextEditingController _ghpTokenController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _appNameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _packageNameController = TextEditingController();
  
  File? _selectedIconFile;
  String? _selectedIconFileName;
  bool _useCustomIcon = false;
  
  bool _isLoading = false;
  bool _isBuildRunning = false;
  String? _apkDownloadUrl;
  List<String> _buildLogs = [];
  ScrollController _terminalScrollController = ScrollController();
  
  double _downloadProgress = 0;
  bool _isDownloading = false;
  Timer? _downloadTimer;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  final Color primaryDark = const Color(0xFF0A0E27);
  final Color primaryBlue = const Color(0xFFB91C1C);
  final Color accentBlue = const Color(0xFFEF4444);
  final Color lightBlue = const Color(0xFFFCA5A5);
  final Color cardDark = const Color(0xFF151932);
  final Color cardDarker = const Color(0xFF0F1330);
  final Color successGreen = const Color(0xFF10B981);
  final Color dangerRed = const Color(0xFFEF4444);

  // Raw URL untuk download template dari GitHub
  final String templateRepoUrl = "https://raw.githubusercontent.com/ObyMoods/android_template/main";
  
  // Daftar lengkap file yang perlu diupload
  final List<Map<String, String>> templateFiles = [
    // Root files
    {'path': 'build.gradle', 'type': 'text', 'modify': 'none'},
    {'path': 'settings.gradle', 'type': 'text', 'modify': 'none'},
    {'path': 'gradle.properties', 'type': 'text', 'modify': 'none'},
    {'path': 'gradlew', 'type': 'binary', 'modify': 'none'},
    {'path': 'gradlew.bat', 'type': 'binary', 'modify': 'none'},
    
    // Gradle wrapper
    {'path': 'gradle/wrapper/gradle-wrapper.properties', 'type': 'text', 'modify': 'none'},
    
    // App files
    {'path': 'app/build.gradle', 'type': 'text', 'modify': 'buildGradle'},
    {'path': 'app/src/main/AndroidManifest.xml', 'type': 'text', 'modify': 'manifest'},
    {'path': 'app/src/main/res/layout/activity_main.xml', 'type': 'text', 'modify': 'none'},
    {'path': 'app/src/main/res/values/strings.xml', 'type': 'text', 'modify': 'strings'},
    {'path': 'app/src/main/java/com/webview/template/MainActivity.java', 'type': 'text', 'modify': 'mainActivity'},
    
    // Icon files (binary)
    {'path': 'app/src/main/res/mipmap-hdpi/ic_launcher.png', 'type': 'binary', 'modify': 'none'},
    {'path': 'app/src/main/res/mipmap-mdpi/ic_launcher.png', 'type': 'binary', 'modify': 'none'},
    {'path': 'app/src/main/res/mipmap-xhdpi/ic_launcher.png', 'type': 'binary', 'modify': 'none'},
    {'path': 'app/src/main/res/mipmap-xxhdpi/ic_launcher.png', 'type': 'binary', 'modify': 'none'},
    {'path': 'app/src/main/res/mipmap-xxxhdpi/ic_launcher.png', 'type': 'binary', 'modify': 'none'},
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initNotifications();
    _generateDefaultPackageName();
    _requestStoragePermission();
  }

  Future<void> _requestStoragePermission() async {
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
  }

  void _generateDefaultPackageName() {
    final random = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    _packageNameController.text = "com.webapp.${random}";
  }

  void _initAnimations() {
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    
    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _initNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'webapk_channel',
      'WebToApk Notifications',
      description: 'Notifikasi status build WebToApk',
      importance: Importance.high,
    );
    
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == 'download_apk') {
      _showDownloadDialog();
    }
  }

  void _showDownloadDialog() {
    if (_apkDownloadUrl == null) return;
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.download, color: Colors.green),
            SizedBox(width: 10),
            Text("APK Siap Download!", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          "Web To APK telah selesai dibuild. Download dan install sekarang?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Nanti", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadAPK();
            },
            style: ElevatedButton.styleFrom(backgroundColor: successGreen),
            child: const Text("Download"),
          ),
        ],
      ),
    );
  }

  Future<void> _showNotification({
    required String title,
    required String body,
    required bool isSuccess,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'webapk_channel',
      'WebToApk Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload ?? (isSuccess ? 'download_apk' : null),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _ghpTokenController.dispose();
    _usernameController.dispose();
    _appNameController.dispose();
    _urlController.dispose();
    _packageNameController.dispose();
    _downloadTimer?.cancel();
    super.dispose();
  }

  void _addBuildLog(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    setState(() {
      _buildLogs.add("[${DateTime.now().toString().substring(11, 19)}] ${isError ? '❌ ' : isSuccess ? '✅ ' : '➜ '}$message");
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_terminalScrollController.hasClients) {
        _terminalScrollController.animateTo(
          _terminalScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickIcon() async {
    try {
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
      if (await Permission.photos.isDenied) {
        await Permission.photos.request();
      }
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
      );
      
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedIconFile = File(result.files.single.path!);
          _selectedIconFileName = result.files.single.name;
          _useCustomIcon = true;
        });
        _addBuildLog("Icon dipilih: $_selectedIconFileName", isSuccess: true);
      } else {
        _addBuildLog("Tidak ada icon yang dipilih", isError: false);
      }
    } catch (e) {
      _addBuildLog("Error memilih icon: $e", isError: true);
      final ImagePicker imagePicker = ImagePicker();
      final XFile? pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedIconFile = File(pickedFile.path);
          _selectedIconFileName = pickedFile.name;
          _useCustomIcon = true;
        });
        _addBuildLog("Icon dipilih via ImagePicker: $_selectedIconFileName", isSuccess: true);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text("✅ Build Berhasil!", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Web To APK telah selesai dibuild!", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text("Download & Install"),
                style: ElevatedButton.styleFrom(backgroundColor: successGreen),
                onPressed: () {
                  Navigator.pop(context);
                  _downloadAPK();
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tutup", style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 10),
            Text("❌ Build Gagal!", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          errorMessage,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tutup", style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _showInstallDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue),
            SizedBox(width: 10),
            Text("Instalasi APK", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          "APK sudah diunduh. Ikuti petunjuk di layar untuk menginstal aplikasi.\n\n"
          "Jika diminta, aktifkan 'Izinkan instalasi dari sumber ini'.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(File apkFile) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.share, color: Colors.orange),
            SizedBox(width: 10),
            Text("Bagikan APK", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          "Tidak bisa membuka installer. Bagikan file APK?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Share.shareXFiles([XFile(apkFile.path)], text: 'APK File');
            },
            style: ElevatedButton.styleFrom(backgroundColor: successGreen),
            child: const Text("Bagikan"),
          ),
        ],
      ),
    );
  }

  // Download file teks (UTF-8)
  Future<String?> _downloadTextFile(String filePath) async {
    final url = "$templateRepoUrl/$filePath";
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return utf8.decode(response.bodyBytes);
      } else {
        _addBuildLog("Gagal download $filePath: ${response.statusCode}", isError: true);
        return null;
      }
    } catch (e) {
      _addBuildLog("Error download $filePath: $e", isError: true);
      return null;
    }
  }

  // Download file binary
  Future<List<int>?> _downloadBinaryFile(String filePath) async {
    final url = "$templateRepoUrl/$filePath";
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        _addBuildLog("Gagal download $filePath: ${response.statusCode}", isError: true);
        return null;
      }
    } catch (e) {
      _addBuildLog("Error download $filePath: $e", isError: true);
      return null;
    }
  }

  // Upload file teks ke repository
  Future<bool> _uploadTextFile(String username, String repoName, String ghpToken, String path, String content) async {
    final response = await http.put(
      Uri.parse("https://api.github.com/repos/$username/$repoName/contents/$path"),
      headers: {
        'Authorization': 'token $ghpToken',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'message': 'Add $path',
        'content': base64Encode(utf8.encode(content)),
        'branch': 'main',
      }),
    );
    
    if (response.statusCode == 201 || response.statusCode == 200) {
      _addBuildLog("✅ $path");
      return true;
    } else {
      _addBuildLog("Gagal upload $path: ${response.statusCode}", isError: true);
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody['message'] != null) {
          _addBuildLog("Error: ${errorBody['message']}", isError: true);
        }
      } catch (_) {}
      return false;
    }
  }

  // Upload file binary ke repository
  Future<bool> _uploadBinaryFile(String username, String repoName, String ghpToken, String path, List<int> bytes) async {
    final response = await http.put(
      Uri.parse("https://api.github.com/repos/$username/$repoName/contents/$path"),
      headers: {
        'Authorization': 'token $ghpToken',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'message': 'Add $path',
        'content': base64Encode(bytes),
        'branch': 'main',
      }),
    );
    
    if (response.statusCode == 201 || response.statusCode == 200) {
      _addBuildLog("✅ $path");
      return true;
    } else {
      _addBuildLog("Gagal upload $path: ${response.statusCode}", isError: true);
      return false;
    }
  }

  // Modifikasi konten berdasarkan jenis
  String _modifyContent(String content, String modifyType, String appName, String packageName, String url) {
    switch (modifyType) {
      case 'buildGradle':
        content = content.replaceAll(
          RegExp(r'applicationId\s+"[^"]*"'),
          'applicationId "$packageName"'
        );
        content = content.replaceAll(
          RegExp(r'namespace\s+"[^"]*"'),
          'namespace "$packageName"'
        );
        break;
      case 'manifest':
        content = content.replaceAll(
          RegExp(r'label\s*=\s*"[^"]*"'),
          'label="$appName"'
        );
        break;
      case 'strings':
        content = content.replaceAll(
          RegExp(r'<string name="app_name">[^<]*</string>'),
          '<string name="app_name">$appName</string>'
        );
        break;
      case 'mainActivity':
        content = content.replaceAll(
          RegExp(r'loadUrl\("([^"]*)"\)'),
          'loadUrl("$url")'
        );
        content = content.replaceAll(
          RegExp(r'package\s+[a-zA-Z0-9_.]+;'),
          'package $packageName;'
        );
        break;
      default:
        break;
    }
    return content;
  }

  Future<void> _buildWebApk() async {
    final ghpToken = _ghpTokenController.text.trim();
    final username = _usernameController.text.trim();
    final appName = _appNameController.text.trim();
    final url = _urlController.text.trim();
    final packageName = _packageNameController.text.trim();

    if (ghpToken.isEmpty || username.isEmpty) {
      _addBuildLog("GitHub Token dan Username harus diisi!", isError: true);
      return;
    }
    
    if (appName.isEmpty) {
      _addBuildLog("Nama APK harus diisi!", isError: true);
      return;
    }
    
    if (url.isEmpty) {
      _addBuildLog("URL Website harus diisi!", isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _isBuildRunning = true;
      _apkDownloadUrl = null;
      _buildLogs = [];
    });

    _addBuildLog("Memulai build Web APK: $appName");
    _addBuildLog("URL: $url");
    _addBuildLog("Package: $packageName");
    
    try {
      _addBuildLog("Membuat repository GitHub...");
      
      final repoName = "webapk_${appName.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}";
      
      final createRepoResponse = await http.post(
        Uri.parse("https://api.github.com/user/repos"),
        headers: {
          'Authorization': 'token $ghpToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': repoName,
          'description': 'Web APK for $appName',
          'private': false,
          'auto_init': true,
        }),
      );
      
      if (createRepoResponse.statusCode != 201 && createRepoResponse.statusCode != 422) {
        _addBuildLog("Gagal membuat repository! Status: ${createRepoResponse.statusCode}", isError: true);
        setState(() { _isBuildRunning = false; _isLoading = false; });
        return;
      }
      _addBuildLog("Repository berhasil dibuat: $repoName ✅", isSuccess: true);
      
      await Future.delayed(const Duration(seconds: 2));
      
      _addBuildLog("Mengupload file template ke repository...");
      
      int successCount = 0;
      int totalFiles = templateFiles.length;
      
      // Upload semua file dari daftar
      for (var file in templateFiles) {
        final filePath = file['path']!;
        final fileType = file['type']!;
        final modifyType = file['modify']!;
        
        if (fileType == 'text') {
          String? content = await _downloadTextFile(filePath);
          if (content != null) {
            if (modifyType != 'none') {
              content = _modifyContent(content, modifyType, appName, packageName, url);
            }
            
            // Untuk MainActivity, path perlu disesuaikan dengan package name
            String uploadPath = filePath;
            if (modifyType == 'mainActivity') {
              uploadPath = "app/src/main/java/${packageName.replaceAll('.', '/')}/MainActivity.java";
            }
            
            final success = await _uploadTextFile(username, repoName, ghpToken, uploadPath, content);
            if (success) successCount++;
          }
        } else if (fileType == 'binary') {
          final bytes = await _downloadBinaryFile(filePath);
          if (bytes != null) {
            final success = await _uploadBinaryFile(username, repoName, ghpToken, filePath, bytes);
            if (success) successCount++;
          }
        }
      }
      
      _addBuildLog("Berhasil mengupload $successCount dari $totalFiles file ✅", isSuccess: true);
      
      // Upload custom icon jika ada
      if (_useCustomIcon && _selectedIconFile != null) {
        _addBuildLog("Mengupload icon custom...");
        final iconBytes = await _selectedIconFile!.readAsBytes();
        final densities = ["hdpi", "mdpi", "xhdpi", "xxhdpi", "xxxhdpi"];
        int iconSuccess = 0;
        for (var density in densities) {
          final path = "app/src/main/res/mipmap-$density/ic_launcher.png";
          final success = await _uploadBinaryFile(username, repoName, ghpToken, path, iconBytes);
          if (success) iconSuccess++;
        }
        _addBuildLog("Icon custom berhasil diupload $iconSuccess/5 ✅", isSuccess: true);
      }
      
      // Upload workflow GitHub Actions
      _addBuildLog("Upload workflow GitHub Actions...");
      final workflowContent = _generateWorkflowContent();
      await _uploadTextFile(username, repoName, ghpToken, '.github/workflows/build.yml', workflowContent);
      
      await Future.delayed(const Duration(seconds: 2));
      
      _addBuildLog("Build akan dimulai secara otomatis via GitHub Actions...", isSuccess: true);
      _addBuildLog("Proses build membutuhkan waktu 3-5 menit", isSuccess: true);
      
      await _showNotification(
        title: "Build Web APK Dimulai",
        body: "Proses build untuk $appName sedang berjalan.",
        isSuccess: true,
      );
      
      setState(() { _isLoading = false; });
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HistoryBuildPage(
              repoName: repoName,
              username: username,
              ghpToken: ghpToken,
              appName: appName,
              onBuildComplete: (downloadUrl) {
                setState(() {
                  _apkDownloadUrl = downloadUrl;
                  _isBuildRunning = false;
                });
                _saveToHistory(appName, downloadUrl, packageName, url);
              },
            ),
          ),
        );
      }
      
    } catch (e) {
      _addBuildLog("Error: $e", isError: true);
      _showErrorDialog("Terjadi error: $e");
      setState(() { _isBuildRunning = false; _isLoading = false; });
    } finally {
      if (mounted) {
        setState(() { 
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveToHistory(String appName, String downloadUrl, String packageName, String url) async {
    final historyItem = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'appName': appName,
      'downloadUrl': downloadUrl,
      'packageName': packageName,
      'url': url,
      'date': DateTime.now().toIso8601String(),
      'size': 'Unknown',
    };
    
    final prefs = await SharedPreferences.getInstance();
    List<String> historyList = prefs.getStringList('web_apk_history') ?? [];
    historyList.add(jsonEncode(historyItem));
    await prefs.setStringList('web_apk_history', historyList);
  }

  String _generateWorkflowContent() {
    return '''name: Build Android APK Native

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: gradle

      - name: Grant execute permission for gradlew
        run: chmod +x gradlew

      - name: Build with Gradle
        run: ./gradlew assembleDebug --no-daemon

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: app-debug-apk
          path: app/build/outputs/apk/debug/*.apk
          retention-days: 30''';
  }

  Future<void> _downloadAPK() async {
    if (_apkDownloadUrl == null) return;

    setState(() { 
      _isDownloading = true;
      _downloadProgress = 0;
    });
    
    _downloadTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        if (_downloadProgress < 0.95) {
          _downloadProgress += 0.05;
        }
      });
    });
    
    try {
      final token = _ghpTokenController.text.trim();
      
      final response = await http.get(
        Uri.parse(_apkDownloadUrl!),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      
      _downloadTimer?.cancel();
      setState(() => _downloadProgress = 1.0);
      
      if (response.statusCode != 200) {
        _addBuildLog("Gagal download!: ${response.statusCode}", isError: true);
        setState(() { _isDownloading = false; });
        return;
      }
      
      final downloadDir = Directory('/storage/emulated/0/Download/WebApk');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      
      final fileName = _appNameController.text.trim().replaceAll(' ', '_');
      final apkFile = File('${downloadDir.path}/${fileName}_${DateTime.now().millisecondsSinceEpoch}.apk');
      await apkFile.writeAsBytes(response.bodyBytes);
      
      _addBuildLog("APK tersimpan di: ${apkFile.path}", isSuccess: true);
      setState(() { _isDownloading = false; });
      
      await _installAPK(apkFile);
      
    } catch (e) {
      _downloadTimer?.cancel();
      _addBuildLog("Error download APK: $e", isError: true);
      setState(() { _isDownloading = false; });
    }
  }

  Future<void> _installAPK(File apkFile) async {
    try {
      if (await Permission.requestInstallPackages.isDenied) {
        await Permission.requestInstallPackages.request();
      }
      
      final result = await OpenFilex.open(apkFile.path);
      
      if (result.type == ResultType.done) {
        _addBuildLog("Instalasi dimulai!", isSuccess: true);
        _showInstallDialog();
      } else {
        _showShareDialog(apkFile);
      }
    } catch (e) {
      _addBuildLog("Error install APK: $e", isError: true);
      _showShareDialog(apkFile);
    }
  }

  Widget _buildTerminal() {
    if (_buildLogs.isEmpty && !_isLoading && !_isBuildRunning) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))),
            child: Row(
              children: [
                Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.yellow, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                const Text("Build Logs", style: TextStyle(color: Colors.white70)),
                const Spacer(),
                if (_isBuildRunning)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
              ],
            ),
          ),
          Container(
            height: 300,
            padding: const EdgeInsets.all(12),
            child: ListView.builder(
              controller: _terminalScrollController,
              itemCount: _buildLogs.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  _buildLogs[index],
                  style: TextStyle(
                    color: _buildLogs[index].contains('❌') ? dangerRed : (_buildLogs[index].contains('✅') ? successGreen : Colors.white),
                    fontSize: 11,
                    fontFamily: 'monospace',
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
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isBuildRunning,
      onPopInvoked: (didPop) {
        if (_isBuildRunning) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Build sedang berjalan, tidak bisa keluar!"),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: primaryDark,
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: accentBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.web, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text("WebToApk", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: primaryDark,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.history, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryBuildPage()),
                );
              },
              tooltip: "History Build",
            ),
          ],
        ),
        body: Stack(
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(colors: [primaryBlue, accentBlue]),
                        ),
                        child: Column(
                          children: [
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, _) => Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                                  child: const Icon(Icons.web, color: Colors.white, size: 40),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text("Web to APK Converter", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text("Convert website to Android", style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: cardDark, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            _buildField(_appNameController, "Nama APK", Icons.app_shortcut, enabled: !_isBuildRunning),
                            const SizedBox(height: 12),
                            _buildField(_urlController, "URL Website (https://...)", Icons.link, enabled: !_isBuildRunning),
                            const SizedBox(height: 12),
                            _buildField(_packageNameController, "Package Name (auto)", Icons.code, enabled: false),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: _isBuildRunning ? null : _pickIcon,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardDarker,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: accentBlue.withOpacity(0.5)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.image, color: accentBlue, size: 30),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedIconFileName ?? "Pilih Icon APK (Optional)",
                                            style: TextStyle(
                                              color: _selectedIconFileName != null ? Colors.white : Colors.white54,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (_selectedIconFileName != null)
                                            Text(
                                              "Klik untuk ganti icon",
                                              style: TextStyle(color: accentBlue, fontSize: 11),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.upload_file, color: accentBlue),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildField(_ghpTokenController, "GitHub Token (ghp_)", Icons.vpn_key, obscure: true, enabled: !_isBuildRunning),
                            const SizedBox(height: 12),
                            _buildField(_usernameController, "GitHub Username", Icons.person, enabled: !_isBuildRunning),
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(colors: [accentBlue, lightBlue]),
                              ),
                              child: ElevatedButton(
                                onPressed: (_isLoading || _isBuildRunning) ? null : _buildWebApk,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                                child: _isLoading || _isBuildRunning
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text("BUILD WEB APK", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            if (_apkDownloadUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Container(
                                  width: double.infinity,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(colors: [successGreen, Color(0xFF34D399)]),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _downloadAPK,
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                                    child: const Text("Download & Install", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTerminal(),
                    ],
                  ),
                ),
              ),
            ),
            if (_isDownloading)
              Positioned(
                bottom: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_downloadProgress * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController c, String hint, IconData icon, {bool obscure = false, bool enabled = true}) {
    return Container(
      decoration: BoxDecoration(color: cardDarker, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: c,
        obscureText: obscure,
        enabled: enabled,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: Icon(icon, color: accentBlue),
        ),
      ),
    );
  }
}