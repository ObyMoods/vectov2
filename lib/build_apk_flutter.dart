import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
    FlutterLocalNotificationsPlugin();

const int downloadNotificationId = 1001;
const int buildNotificationId = 1002;

class BuildState {
  final String id;
  final String appName;
  final String repoName;
  final String username;
  final String ghpToken;
  final DateTime startTime;
  bool isRunning;
  int? runId;
  String status;
  String downloadUrl;

  BuildState({
    required this.id,
    required this.appName,
    required this.repoName,
    required this.username,
    required this.ghpToken,
    required this.startTime,
    this.isRunning = true,
    this.runId,
    this.status = 'running',
    this.downloadUrl = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'appName': appName,
    'repoName': repoName,
    'username': username,
    'ghpToken': ghpToken,
    'startTime': startTime.toIso8601String(),
    'isRunning': isRunning,
    'runId': runId,
    'status': status,
    'downloadUrl': downloadUrl,
  };

  factory BuildState.fromJson(Map<String, dynamic> json) => BuildState(
    id: json['id'],
    appName: json['appName'],
    repoName: json['repoName'],
    username: json['username'],
    ghpToken: json['ghpToken'],
    startTime: DateTime.parse(json['startTime']),
    isRunning: json['isRunning'],
    runId: json['runId'],
    status: json['status'],
    downloadUrl: json['downloadUrl'] ?? '',
  );
}

class BuildHistoryItem {
  final String id;
  final String appName;
  final String downloadUrl;
  final String repoName;
  final String username;
  final DateTime date;
  final String? apkPath;
  final String size;
  final String status;
  final bool isOptimized;

  BuildHistoryItem({
    required this.id,
    required this.appName,
    required this.downloadUrl,
    required this.repoName,
    required this.username,
    required this.date,
    this.apkPath,
    this.size = 'Unknown',
    this.status = 'success',
    this.isOptimized = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'appName': appName,
    'downloadUrl': downloadUrl,
    'repoName': repoName,
    'username': username,
    'date': date.toIso8601String(),
    'apkPath': apkPath,
    'size': size,
    'status': status,
    'isOptimized': isOptimized,
  };

  factory BuildHistoryItem.fromJson(Map<String, dynamic> json) => BuildHistoryItem(
    id: json['id'],
    appName: json['appName'],
    downloadUrl: json['downloadUrl'] ?? '',
    repoName: json['repoName'],
    username: json['username'],
    date: DateTime.parse(json['date']),
    apkPath: json['apkPath'],
    size: json['size'] ?? 'Unknown',
    status: json['status'] ?? 'success',
    isOptimized: json['isOptimized'] ?? false,
  );
}

class DownloadManager {
  static Future<void> showDownloadProgressNotification({
    required int id,
    required String title,
    required String fileName,
    required double progress,
    required String status,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Download APK',
      channelDescription: 'Notifikasi progress download APK',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: (progress * 100).toInt(),
      indeterminate: false,
    );
    final NotificationDetails details = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      "$fileName - $status",
      details,
    );
  }

  static Future<void> showDownloadCompleteNotification({
    required String fileName,
    required String filePath,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Download APK',
      channelDescription: 'Notifikasi download APK selesai',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      downloadNotificationId,
      "✅ Download Selesai",
      "$fileName berhasil diunduh\n📍 $filePath",
      details,
    );
  }

  static Future<void> showDownloadErrorNotification({
    required String fileName,
    required String error,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Download APK',
      channelDescription: 'Notifikasi download APK gagal',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      downloadNotificationId,
      "❌ Download Gagal",
      "$fileName - $error",
      details,
    );
  }

  static Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}

class DownloadProgressPage extends StatefulWidget {
  final String downloadUrl;
  final String fileName;
  final String token;
  final Function(File) onComplete;

  const DownloadProgressPage({
    super.key,
    required this.downloadUrl,
    required this.fileName,
    required this.token,
    required this.onComplete,
  });

  @override
  State<DownloadProgressPage> createState() => _DownloadProgressPageState();
}

class _DownloadProgressPageState extends State<DownloadProgressPage> {
  double _progress = 0.0;
  String _status = "Mempersiapkan download...";
  String _speed = "";
  int _receivedBytes = 0;
  int _totalBytes = 0;
  bool _isDownloading = true;
  bool _isExtracting = false;
  CancelToken? _cancelToken;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _startDownload();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
    
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'download_channel',
      'Download APK',
      description: 'Notifikasi progress download APK',
      importance: Importance.high,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _startDownload() async {
    _cancelToken = CancelToken();
    _status = "Menghubungi server...";
    
    await DownloadManager.showDownloadProgressNotification(
      id: downloadNotificationId,
      title: "Mengunduh ${widget.fileName}",
      fileName: widget.fileName,
      progress: 0,
      status: "Memulai download...",
    );
    
    try {
      final request = http.Request('GET', Uri.parse(widget.downloadUrl));
      request.headers['Authorization'] = 'token ${widget.token}';
      request.headers['Accept'] = 'application/vnd.github.v3+json';
      
      final streamedResponse = await request.send();
      _totalBytes = streamedResponse.contentLength ?? 0;
      
      if (streamedResponse.statusCode == 401) {
        throw Exception("Token tidak valid! Periksa kembali token GitHub Anda");
      }
      
      if (streamedResponse.statusCode != 200) {
        throw Exception("Gagal download: ${streamedResponse.statusCode}");
      }
      
      final tempDir = await getTemporaryDirectory();
      final zipFile = File('${tempDir.path}/download_${DateTime.now().millisecondsSinceEpoch}.zip');
      final sink = zipFile.openWrite();
      
      int received = 0;
      final startTime = DateTime.now();
      
      final subscription = streamedResponse.stream.listen(
        (chunk) async {
          if (_cancelToken?.cancelled == true) return;
          
          received += chunk.length;
          _receivedBytes = received;
          if (_totalBytes > 0) {
            final elapsed = DateTime.now().difference(startTime).inSeconds;
            final speed = elapsed > 0 ? received / 1024 / 1024 / elapsed : 0;
            final progressValue = received / _totalBytes;
            
            setState(() {
              _progress = progressValue;
              _speed = "${speed.toStringAsFixed(2)} MB/s";
            });
            
            await DownloadManager.showDownloadProgressNotification(
              id: downloadNotificationId,
              title: "Mengunduh ${widget.fileName}",
              fileName: widget.fileName,
              progress: progressValue,
              status: "${(progressValue * 100).toStringAsFixed(1)}% • ${_formatSize(received)} / ${_formatSize(_totalBytes)}",
            );
          }
          sink.add(chunk);
        },
        onDone: () async {
          await sink.close();
          setState(() {
            _progress = 1.0;
            _status = "Download selesai! Mengekstrak APK...";
            _isExtracting = true;
          });
          
          await DownloadManager.showDownloadProgressNotification(
            id: downloadNotificationId,
            title: "Mengekstrak ${widget.fileName}",
            fileName: widget.fileName,
            progress: 1.0,
            status: "Mengekstrak APK...",
          );
          
          await _extractApk(zipFile);
        },
        onError: (e) async {
          sink.close();
          _errorMessage = e.toString();
          setState(() {
            _status = "Error: $e";
            _isDownloading = false;
            _isExtracting = false;
          });
          await DownloadManager.showDownloadErrorNotification(
            fileName: widget.fileName,
            error: e.toString(),
          );
          await DownloadManager.cancelNotification(downloadNotificationId);
        },
        cancelOnError: true,
      );
      
      await subscription.asFuture();
      
    } catch (e) {
      _errorMessage = e.toString();
      setState(() {
        _status = "Error: $e";
        _isDownloading = false;
        _isExtracting = false;
      });
      await DownloadManager.showDownloadErrorNotification(
        fileName: widget.fileName,
        error: e.toString(),
      );
      await DownloadManager.cancelNotification(downloadNotificationId);
    }
  }

  Future<void> _extractApk(File zipFile) async {
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      File? apkFile;
      for (final file in archive) {
        if (file.name.endsWith('.apk') && file.isFile) {
          final appDir = await getApplicationDocumentsDirectory();
          final appApkDir = Directory('${appDir.path}/built_apks');
          if (!await appApkDir.exists()) {
            await appApkDir.create(recursive: true);
          }
          apkFile = File('${appApkDir.path}/${widget.fileName}_${DateTime.now().millisecondsSinceEpoch}.apk');
          await apkFile!.writeAsBytes(file.content as List<int>);
          break;
        }
      }
      
      await zipFile.delete();
      
      if (apkFile == null) {
        setState(() {
          _status = "Tidak ditemukan APK dalam ZIP!";
          _isDownloading = false;
          _isExtracting = false;
        });
        await DownloadManager.cancelNotification(downloadNotificationId);
        return;
      }
      
      setState(() {
        _status = "APK berhasil diekstrak! Mengoptimalkan...";
      });
      
      await DownloadManager.showDownloadProgressNotification(
        id: downloadNotificationId,
        title: "Mengoptimalkan ${widget.fileName}",
        fileName: widget.fileName,
        progress: 1.0,
        status: "Mengoptimalkan APK...",
      );
      
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      
      final savedApk = File('${downloadDir.path}/${widget.fileName}_${DateTime.now().millisecondsSinceEpoch}.apk');
      await apkFile.copy(savedApk.path);
      
      final fileSize = await savedApk.length();
      final sizeMB = (fileSize / 1024 / 1024).toStringAsFixed(2);
      
      setState(() {
        _status = "Optimasi selesai! APK tersimpan ($sizeMB MB)";
        _isDownloading = false;
        _isExtracting = false;
      });
      
      await DownloadManager.showDownloadCompleteNotification(
        fileName: widget.fileName,
        filePath: savedApk.path,
      );
      
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        widget.onComplete(savedApk);
        Navigator.pop(context);
      }
      
    } catch (e) {
      setState(() {
        _status = "Error ekstrak: $e";
        _isDownloading = false;
        _isExtracting = false;
      });
      await DownloadManager.cancelNotification(downloadNotificationId);
    }
  }

  Future<File> _autoOptimizeApk(File apkFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final extractDir = Directory('${tempDir.path}/apk_opt_${DateTime.now().millisecondsSinceEpoch}');
      await extractDir.create(recursive: true);
      
      final apkBytes = await apkFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(apkBytes);
      
      for (var file in archive.files) {
        if (!file.isFile) continue;
        
        var content = file.content as List<int>;
        
        if (file.name.endsWith('.xml')) {
          try {
            String xmlString = utf8.decode(content);
            String cleaned = xmlString.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
            cleaned = cleaned.replaceAll(RegExp(r'>\s+<'), '><');
            content = utf8.encode(cleaned);
          } catch (e) {}
        }
        
        final outputFile = File('${extractDir.path}/${file.name}');
        await outputFile.create(recursive: true);
        await outputFile.writeAsBytes(content);
      }
      
      final outputZip = File('${tempDir.path}/optimized_${DateTime.now().millisecondsSinceEpoch}.apk');
      final encoder = ZipEncoder();
      final newArchive = Archive();
      
      for (var file in archive.files) {
        if (file.isFile) {
          final inputFile = File('${extractDir.path}/${file.name}');
          if (await inputFile.exists()) {
            final bytes = await inputFile.readAsBytes();
            newArchive.addFile(ArchiveFile(file.name, bytes.length, bytes));
          }
        }
      }
      
      final zipBytes = encoder.encode(newArchive);
      await outputZip.writeAsBytes(zipBytes!);
      await extractDir.delete(recursive: true);
      
      return outputZip;
      
    } catch (e) {
      return apkFile;
    }
  }

  void _cancelDownload() {
    setState(() {
      _cancelToken?.cancelled = true;
      _status = "Download dibatalkan";
      _isDownloading = false;
      _isExtracting = false;
    });
    DownloadManager.cancelNotification(downloadNotificationId);
  }

  Future<void> _openUrlInBrowser() async {
    final url = Uri.parse(widget.downloadUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tidak bisa membuka URL"), backgroundColor: Colors.red),
      );
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(2)} KB";
    return "${(bytes / 1024 / 1024).toStringAsFixed(2)} MB";
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDownloading && !_isExtracting,
      onPopInvoked: (didPop) {
        if (_isDownloading && !didPop) {
          _cancelDownload();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: AppBar(
          title: const Text("Mengunduh APK", style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF000000),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              if (_isDownloading) {
                _cancelDownload();
              }
              Navigator.pop(context);
            },
          ),
        ),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage != null && !_isDownloading)
                  const Icon(Icons.error, size: 60, color: Color(0xFFEF4444))
                else
                  const Icon(Icons.download, size: 60, color: Color(0xFFCC0000)),
                const SizedBox(height: 20),
                Text(
                  widget.fileName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white24,
                  color: const Color(0xFFCC0000),
                  minHeight: 8,
                ),
                const SizedBox(height: 12),
                Text(
                  "${(_progress * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "${_formatSize(_receivedBytes)} / ${_formatSize(_totalBytes)}",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                if (_speed.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _speed,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      if (_isDownloading || _isExtracting)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFCC0000)),
                        )
                      else if (_errorMessage != null)
                        const Icon(Icons.error, color: Color(0xFFEF4444), size: 20)
                      else
                        const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _status,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null && !_isDownloading) ...[
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openUrlInBrowser,
                          icon: const Icon(Icons.open_in_browser, size: 18),
                          label: const Text("Cek URL"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFCC0000)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _startDownload,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text("Coba Lagi"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCC0000),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                Text(
                  "APK tersimpan di:\n /storage/emulated/0/Download/\n Data Aplikasi (History)",
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Notifikasi download akan muncul di tray",
                  style: TextStyle(color: Colors.white38.withOpacity(0.7), fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CancelToken {
  bool cancelled = false;
}

// ==================== HISTORY BUILD PAGE ====================
class HistoryBuildPageFlutter extends StatefulWidget {
  final Function(String, String, String)? onDownload;
  final Function(String)? onShare;
  final Function(BuildHistoryItem)? onInstall;
  
  const HistoryBuildPageFlutter({
    super.key, 
    this.onDownload, 
    this.onShare,
    this.onInstall,
  });

  @override
  State<HistoryBuildPageFlutter> createState() => _HistoryBuildPageFlutterState();
}

class _HistoryBuildPageFlutterState extends State<HistoryBuildPageFlutter> {
  List<BuildHistoryItem> _history = [];
  bool _isLoading = true;

  final Color neonRed = const Color(0xFFCC0000);
  final Color successGreen = const Color(0xFF10B981);
  final Color dangerRed = const Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
    
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'download_channel',
      'Download APK',
      description: 'Notifikasi progress download APK',
      importance: Importance.high,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('build_apk_flutter_history') ?? [];
      _history = historyJson
          .map((json) => BuildHistoryItem.fromJson(jsonDecode(json)))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {}
    setState(() => _isLoading = false);
  }

  Future<void> _deleteHistoryItem(String id) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Hapus History?", style: TextStyle(color: Colors.white)),
        content: const Text("Apakah Anda yakin ingin menghapus history ini?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal", style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (_history.firstWhere((h) => h.id == id, orElse: () => BuildHistoryItem(id: '', appName: '', downloadUrl: '', repoName: '', username: '', date: DateTime.now())).apkPath != null) {
                try {
                  await File(_history.firstWhere((h) => h.id == id).apkPath!).delete();
                } catch (e) {}
              }
              setState(() => _history.removeWhere((h) => h.id == id));
              final prefs = await SharedPreferences.getInstance();
              await prefs.setStringList('build_apk_flutter_history', _history.map((h) => jsonEncode(h.toJson())).toList());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("History berhasil dihapus"), backgroundColor: Color(0xFF10B981)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: dangerRed),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  Future<void> _shareApk(String apkPath) async {
    final file = File(apkPath);
    if (await file.exists()) {
      await Share.shareXFiles([XFile(apkPath)], text: 'Bagikan APK - ${apkPath.split('/').last}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Membuka menu share..."), backgroundColor: Color(0xFF10B981)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("File APK tidak ditemukan!"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _downloadApkFromUrl(String downloadUrl, String fileName, String token) async {
    if (widget.onDownload != null) {
      widget.onDownload!(downloadUrl, fileName, token);
      Navigator.pop(context);
    }
  }

  Future<void> _openWebsiteUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tidak bisa membuka URL"), backgroundColor: Colors.red),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 7) return "${date.day}/${date.month}/${date.year}";
    if (diff.inDays > 0) return "${diff.inDays} hari yang lalu";
    if (diff.inHours > 0) return "${diff.inHours} jam yang lalu";
    if (diff.inMinutes > 0) return "${diff.inMinutes} menit yang lalu";
    return "Baru saja";
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(2)} KB";
    return "${(bytes / 1024 / 1024).toStringAsFixed(2)} MB";
  }

  Future<String> _getFileSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        return _formatSize(size);
      }
    } catch (e) {}
    return "Unknown";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: const Text("History Build", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              color: dangerRed,
              onPressed: () async {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A1A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text("Hapus Semua?", style: TextStyle(color: Colors.white)),
                    content: const Text("Apakah Anda yakin ingin menghapus semua history?", style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal", style: TextStyle(color: Colors.white70))),
                      ElevatedButton(
                        onPressed: () async {
                          for (var item in _history) {
                            if (item.apkPath != null) {
                              try {
                                await File(item.apkPath!).delete();
                              } catch (e) {}
                            }
                          }
                          setState(() => _history.clear());
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('build_apk_flutter_history');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Semua history dihapus"), backgroundColor: Color(0xFF10B981)),
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: dangerRed),
                        child: const Text("Hapus Semua"),
                      ),
                    ],
                  ),
                );
              },
              tooltip: "Hapus Semua",
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history, size: 80, color: Colors.white54),
                      const SizedBox(height: 16),
                      const Text("Belum ada history build", style: TextStyle(color: Colors.white54, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text(
                        "Build APK pertama Anda akan muncul di sini",
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final hasApkFile = item.apkPath != null && File(item.apkPath!).existsSync();
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: neonRed.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: (item.status == 'success' ? successGreen : dangerRed).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                item.status == 'success' ? Icons.check_circle : Icons.error,
                                color: item.status == 'success' ? successGreen : dangerRed,
                                size: 30,
                              ),
                            ),
                            title: Text(
                              item.appName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.username, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                Text(_formatDate(item.date), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                if (item.size != 'Unknown')
                                  Text("Ukuran: ${item.size} MB", style: TextStyle(color: neonRed, fontSize: 10)),
                                if (hasApkFile)
                                  FutureBuilder<String>(
                                    future: _getFileSize(item.apkPath!),
                                    builder: (context, snapshot) {
                                      return Text(
                                        "✓ Tersimpan di aplikasi (${snapshot.data ?? '...'})",
                                        style: TextStyle(color: successGreen, fontSize: 10),
                                      );
                                    },
                                  ),
                                if (item.isOptimized)
                                  Text("✓ Dioptimalkan", style: TextStyle(color: neonRed, fontSize: 10)),
                              ],
                            ),
                            trailing: SizedBox(
                              width: 160,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (hasApkFile)
                                    IconButton(
                                      icon: const Icon(Icons.share, color: Colors.green),
                                      onPressed: () => _shareApk(item.apkPath!),
                                      tooltip: "Share APK",
                                      iconSize: 20,
                                    ),
                                  if (item.status == 'success' && item.downloadUrl.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.download, color: Colors.blue),
                                      onPressed: () => _downloadApkFromUrl(item.downloadUrl, item.appName, ""),
                                      tooltip: "Download Ulang",
                                      iconSize: 20,
                                    ),
                                  if (item.downloadUrl.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.language, color: Colors.purple),
                                      onPressed: () => _openWebsiteUrl(item.downloadUrl),
                                      tooltip: "Buka URL di Chrome",
                                      iconSize: 20,
                                    ),
                                  if (hasApkFile && widget.onInstall != null)
                                    IconButton(
                                      icon: const Icon(Icons.install_mobile),
                                      color: successGreen,
                                      onPressed: () => widget.onInstall!(item),
                                      tooltip: "Install APK",
                                      iconSize: 20,
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    color: dangerRed,
                                    onPressed: () => _deleteHistoryItem(item.id),
                                    tooltip: "Hapus History",
                                    iconSize: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (item.downloadUrl.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: GestureDetector(
                                onTap: () => _openWebsiteUrl(item.downloadUrl),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D0D0D),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: neonRed.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.link, size: 14, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "URL Download",
                                          style: TextStyle(color: Colors.white54, fontSize: 10),
                                        ),
                                      ),
                                      const Icon(Icons.open_in_new, size: 14, color: Colors.white54),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (hasApkFile)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D0D0D),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.folder, size: 14, color: Colors.white54),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.apkPath!.split('/').last,
                                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.folder_open, size: 14, color: Colors.white54),
                                      onPressed: () => OpenFilex.open(item.apkPath!.replaceAll('/${item.apkPath!.split('/').last}', '')),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ==================== BUILD APK FLUTTER (MAIN CLASS) ====================
class BuildApkFlutter extends StatefulWidget {
  final String? sessionKey;
  final String? username;
  final String? role;

  const BuildApkFlutter({
    super.key,
    this.sessionKey,
    this.username,
    this.role,
  });

  @override
  State<BuildApkFlutter> createState() => _BuildApkFlutterState();
}

class _BuildApkFlutterState extends State<BuildApkFlutter> with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _ghpTokenController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  
  File? _selectedZipFile;
  String? _selectedZipFileName;
  
  bool _isLoading = false;
  bool _isBuildRunning = false;
  String? _apkDownloadUrl;
  List<String> _buildLogs = [];
  ScrollController _terminalScrollController = ScrollController();
  
  List<BuildHistoryItem> _buildHistory = [];
  bool _isLoadingHistory = true;
  
  BuildState? _currentBuildState;
  Timer? _buildMonitorTimer;
  
  Timer? _downloadCheckTimer;
  bool _isBackgroundDownloading = false;
  double _backgroundProgress = 0.0;
  String _backgroundFileName = "";
  
  bool _isDownloadingUrl = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  
  final Color primaryDark = const Color(0xFF000000);
  final Color primaryBlue = const Color(0xFFB91C1C);
  final Color neonRed = const Color(0xFFCC0000);
  final Color cardDark = const Color(0xFF1A1A1A);
  final Color cardDarker = const Color(0xFF0D0D0D);
  final Color successGreen = const Color(0xFF10B981);
  final Color dangerRed = const Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initNotifications();
    _loadHistory();
    _loadRunningBuildState();
    _requestPermissions();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkRunningBuild();
    }
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
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

  Future<void> _requestPermissions() async {
    await [Permission.storage, Permission.manageExternalStorage, Permission.requestInstallPackages].request();
  }

  Future<void> _loadRunningBuildState() async {
    final prefs = await SharedPreferences.getInstance();
    final buildStateJson = prefs.getString('current_build_state');
    if (buildStateJson != null) {
      try {
        final state = BuildState.fromJson(jsonDecode(buildStateJson));
        if (state.isRunning) {
          _currentBuildState = state;
          _isBuildRunning = true;
          _addBuildLog("Build sedang berjalan: ${state.appName}");
          _startMonitoringExistingBuild(state);
        }
      } catch (e) {}
    }
  }

  Future<void> _saveRunningBuildState(BuildState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_build_state', jsonEncode(state.toJson()));
  }

  Future<void> _clearRunningBuildState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_build_state');
    _currentBuildState = null;
  }

  Future<void> _checkRunningBuild() async {
    if (_currentBuildState != null && _currentBuildState!.isRunning) {
      _addBuildLog("Membuka kembali aplikasi, mengecek build yang sedang berjalan...");
      await _monitorBuild(_currentBuildState!);
    }
  }

  Future<void> _startMonitoringExistingBuild(BuildState state) async {
    _buildMonitorTimer?.cancel();
    _buildMonitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _monitorBuild(state);
    });
  }

  void _addBuildLog(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    final timeNow = DateTime.now();
    final timeStr = "${timeNow.hour.toString().padLeft(2, '0')}:${timeNow.minute.toString().padLeft(2, '0')}:${timeNow.second.toString().padLeft(2, '0')}";
    setState(() => _buildLogs.add("[$timeStr] ${isError ? '❌' : isSuccess ? '✅' : '➜'} $message"));
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

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('build_apk_flutter_history') ?? [];
      _buildHistory = historyJson.map((json) => BuildHistoryItem.fromJson(jsonDecode(json))).toList()..sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {}
    setState(() => _isLoadingHistory = false);
  }

  Future<void> _saveToHistory(String appName, String downloadUrl, String repoName, String username, {String? apkPath, String status = 'success', String size = 'Unknown', bool isOptimized = false}) async {
    final existingIndex = _buildHistory.indexWhere((h) => h.appName == appName && h.repoName == repoName);
    if (existingIndex != -1) {
      final existing = _buildHistory[existingIndex];
      _buildHistory[existingIndex] = BuildHistoryItem(
        id: existing.id,
        appName: appName,
        downloadUrl: downloadUrl,
        repoName: repoName,
        username: username,
        date: existing.date,
        apkPath: apkPath ?? existing.apkPath,
        size: size,
        status: status,
        isOptimized: isOptimized,
      );
    } else {
      _buildHistory.insert(0, BuildHistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        appName: appName,
        downloadUrl: downloadUrl,
        repoName: repoName,
        username: username,
        date: DateTime.now(),
        apkPath: apkPath,
        size: size,
        status: status,
        isOptimized: isOptimized,
      ));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('build_apk_flutter_history', _buildHistory.map((h) => jsonEncode(h.toJson())).toList());
  }

  Future<void> _pickZipFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    if (result != null) {
      setState(() {
        _selectedZipFile = File(result.files.single.path!);
        _selectedZipFileName = result.files.single.name;
      });
      _addBuildLog("File ZIP dipilih: $_selectedZipFileName", isSuccess: true);
    }
  }

  Future<void> _createFileInRepo(String username, String repoName, String ghpToken, String path, String content) async {
    final response = await http.put(
      Uri.parse("https://api.github.com/repos/$username/$repoName/contents/$path"),
      headers: {'Authorization': 'token $ghpToken', 'Content-Type': 'application/json'},
      body: jsonEncode({'message': 'Add $path', 'content': base64Encode(utf8.encode(content)), 'branch': 'main'}),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      _addBuildLog("✅ $path");
    } else if (response.statusCode == 401) {
      _addBuildLog("❌ Token GitHub tidak valid! Periksa kembali token Anda", isError: true);
    } else {
      _addBuildLog("❌ Gagal $path: ${response.statusCode}", isError: true);
    }
  }

  Future<bool> _validateGitHubToken(String token, String username) async {
    try {
      final response = await http.get(Uri.parse("https://api.github.com/user"), headers: {'Authorization': 'token $token'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final login = data['login'];
        if (login != username) {
          _addBuildLog("❌ Username tidak sesuai! Token milik: $login, tapi Anda menggunakan: $username", isError: true);
          return false;
        }
        final scopes = response.headers['x-oauth-scopes'] ?? '';
        if (!scopes.contains('repo') || !scopes.contains('workflow')) {
          _addBuildLog("⚠️ Token tidak memiliki izin yang cukup!", isError: true);
          return false;
        }
        _addBuildLog("Token valid! User: $login", isSuccess: true);
        return true;
      } else if (response.statusCode == 401) {
        _addBuildLog("❌ Token tidak valid! Status: 401 Unauthorized", isError: true);
        return false;
      }
      return false;
    } catch (e) {
      _addBuildLog("⚠️ Error verifikasi token: $e", isError: true);
      return false;
    }
  }

  Future<void> _monitorBuild(BuildState state) async {
    try {
      final runsResponse = await http.get(
        Uri.parse("https://api.github.com/repos/${state.username}/${state.repoName}/actions/runs?per_page=1"),
        headers: {'Authorization': 'token ${state.ghpToken}'},
      );
      if (runsResponse.statusCode == 401) {
        _addBuildLog("❌ Token tidak valid! Build dihentikan.", isError: true);
        _buildMonitorTimer?.cancel();
        await _clearRunningBuildState();
        setState(() => _isBuildRunning = false);
        return;
      }
      if (runsResponse.statusCode == 200) {
        final runsData = jsonDecode(runsResponse.body);
        if (runsData['workflow_runs'] != null && runsData['workflow_runs'].isNotEmpty) {
          final latestRun = runsData['workflow_runs'][0];
          final status = latestRun['status'];
          final conclusion = latestRun['conclusion'];
          final runId = latestRun['id'];
          if (status == 'completed') {
            _buildMonitorTimer?.cancel();
            if (conclusion == 'success') {
              _addBuildLog("Build ${state.appName} Berhasil!", isSuccess: true);
              final artifactsResponse = await http.get(
                Uri.parse("https://api.github.com/repos/${state.username}/${state.repoName}/actions/runs/$runId/artifacts"),
                headers: {'Authorization': 'token ${state.ghpToken}'},
              );
              if (artifactsResponse.statusCode == 200) {
                final artifactsData = jsonDecode(artifactsResponse.body);
                if (artifactsData['artifacts'] != null && artifactsData['artifacts'].isNotEmpty) {
                  final artifact = artifactsData['artifacts'][0];
                  final downloadUrl = artifact['archive_download_url'] ?? '';
                  final sizeMB = (artifact['size_in_bytes'] / 1024 / 1024).toStringAsFixed(2);
                  _addBuildLog("APK ${state.appName} siap didownload! ($sizeMB MB)", isSuccess: true);
                  if (downloadUrl.isNotEmpty) {
                    _apkDownloadUrl = downloadUrl;
                    await _saveToHistory(state.appName, downloadUrl, state.repoName, state.username, size: sizeMB);
                    _addBuildLog("History ${state.appName} tersimpan!", isSuccess: true);
                    await _startDownloadWithProgress(downloadUrl);
                  }
                }
              }
            } else {
              _addBuildLog("❌ Build ${state.appName} Gagal! Status: $conclusion", isError: true);
              await _saveToHistory(state.appName, '', state.repoName, state.username, status: 'failed');
            }
            await _clearRunningBuildState();
            setState(() => _isBuildRunning = false);
          } else {
            if (_buildMonitorTimer != null && _buildMonitorTimer!.isActive) {
              _addBuildLog("Build ${state.appName} sedang berjalan...");
            }
          }
        }
      }
    } catch (e) {
      _addBuildLog("⚠️ Error checking build: $e", isError: true);
    }
  }

  Future<void> _showDownloadUrlDialog() async {
    final TextEditingController urlController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Download dari URL", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "URL Download APK (ZIP atau APK)",
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: Icon(Icons.link, color: neonRed),
                filled: true,
                fillColor: cardDarker,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Nama APK (opsional)",
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: Icon(Icons.apps, color: neonRed),
                filled: true,
                fillColor: cardDarker,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("URL tidak boleh kosong!"), backgroundColor: Colors.red),
                );
                return;
              }
              final name = nameController.text.trim().isEmpty 
                  ? "download_${DateTime.now().millisecondsSinceEpoch}"
                  : nameController.text.trim();
              Navigator.pop(context);
              _downloadFromUrl(url, name);
            },
            style: ElevatedButton.styleFrom(backgroundColor: neonRed),
            child: const Text("Download"),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadFromUrl(String url, String fileName) async {
    if (_isDownloadingUrl) return;
    setState(() => _isDownloadingUrl = true);
    
    try {
      _addBuildLog("📥 Memulai download dari URL: $fileName");
      
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DownloadProgressPage(
            downloadUrl: url,
            fileName: fileName,
            token: _ghpTokenController.text.trim(),
            onComplete: (apkFile) async {
              await _installAPK(apkFile);
              await _saveToHistory(
                fileName,
                url,
                "direct_download",
                _usernameController.text.trim().isEmpty ? "direct" : _usernameController.text.trim(),
                apkPath: apkFile.path,
                isOptimized: true,
              );
              _addBuildLog("✅ Download selesai: $fileName", isSuccess: true);
              setState(() => _isDownloadingUrl = false);
            },
          ),
        ),
      );
    } catch (e) {
      _addBuildLog("❌ Gagal download: $e", isError: true);
      setState(() => _isDownloadingUrl = false);
    }
  }

  Future<void> _buildAPK() async {
    final ghpToken = _ghpTokenController.text.trim();
    final username = _usernameController.text.trim();

    if (_selectedZipFile == null) {
      _addBuildLog("❌ Pilih file ZIP terlebih dahulu!", isError: true);
      return;
    }
    if (ghpToken.isEmpty || username.isEmpty) {
      _addBuildLog("❌ Semua field harus diisi!", isError: true);
      return;
    }

    _addBuildLog("🔐 Memverifikasi token GitHub...");
    final bool isValid = await _validateGitHubToken(ghpToken, username);
    if (!isValid) {
      _addBuildLog("❌ Build dibatalkan karena token tidak valid", isError: true);
      setState(() { _isLoading = false; _isBuildRunning = false; });
      return;
    }

    setState(() {
      _isLoading = true;
      _isBuildRunning = true;
      _buildLogs = [];
    });

    final appName = _selectedZipFileName!.replaceAll('.zip', '');
    final repoName = "flutter_build_${DateTime.now().millisecondsSinceEpoch}";
    
    final buildState = BuildState(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      appName: appName,
      repoName: repoName,
      username: username,
      ghpToken: ghpToken,
      startTime: DateTime.now(),
    );
    _currentBuildState = buildState;
    await _saveRunningBuildState(buildState);
    
    _addBuildLog("🚀 Memulai build APK: $appName");
    _addBuildLog("📦 Repository: $repoName");
    _addBuildLog("👤 Username: $username");
    
    try {
      _addBuildLog("Membuat repository GitHub...");
      final createRepo = await http.post(
        Uri.parse("https://api.github.com/user/repos"),
        headers: {'Authorization': 'token $ghpToken', 'Content-Type': 'application/json'},
        body: jsonEncode({'name': repoName, 'description': 'Flutter App: $appName', 'private': false, 'auto_init': true}),
      );
      if (createRepo.statusCode == 401) {
        _addBuildLog("❌ Token tidak valid! Silakan buat token baru di GitHub", isError: true);
        await _saveToHistory(appName, '', repoName, username, status: 'failed');
        await _clearRunningBuildState();
        setState(() { _isBuildRunning = false; _isLoading = false; });
        return;
      }
      if (createRepo.statusCode != 201 && createRepo.statusCode != 422) {
        _addBuildLog("❌ Gagal membuat repository! Status: ${createRepo.statusCode}", isError: true);
        await _saveToHistory(appName, '', repoName, username, status: 'failed');
        await _clearRunningBuildState();
        setState(() { _isBuildRunning = false; _isLoading = false; });
        return;
      }
      _addBuildLog("Repository berhasil dibuat", isSuccess: true);
      
      _addBuildLog("Mengupload file ZIP...");
      final zipBytes = await _selectedZipFile!.readAsBytes();
      final uploadZip = await http.put(
        Uri.parse("https://api.github.com/repos/$username/$repoName/contents/project.zip"),
        headers: {'Authorization': 'token $ghpToken', 'Content-Type': 'application/json'},
        body: jsonEncode({'message': 'Upload project', 'content': base64Encode(zipBytes)}),
      );
      if (uploadZip.statusCode == 401) {
        _addBuildLog("❌ Token tidak valid!", isError: true);
        await _saveToHistory(appName, '', repoName, username, status: 'failed');
        await _clearRunningBuildState();
        setState(() { _isBuildRunning = false; _isLoading = false; });
        return;
      }
      if (uploadZip.statusCode != 201 && uploadZip.statusCode != 200) {
        _addBuildLog("❌ Gagal upload ZIP! Status: ${uploadZip.statusCode}", isError: true);
        await _saveToHistory(appName, '', repoName, username, status: 'failed');
        await _clearRunningBuildState();
        setState(() { _isBuildRunning = false; _isLoading = false; });
        return;
      }
      _addBuildLog("ZIP berhasil diupload", isSuccess: true);
      
      _addBuildLog("⚙️ Membuat workflow GitHub Actions...");
      final workflow = r'''name: Build Flutter APK
on:
  workflow_dispatch:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
      - run: |
          if [ -f "project.zip" ]; then
            unzip -o project.zip -d .
            rm project.zip
          fi
          flutter pub get
          flutter build apk --release
      - uses: actions/upload-artifact@v4
        with:
          name: app-release
          path: build/app/outputs/flutter-apk/app-release.apk''';
      await _createFileInRepo(username, repoName, ghpToken, '.github/workflows/build.yml', workflow);
      _addBuildLog("Workflow berhasil dibuat", isSuccess: true);
      
      _addBuildLog("Menjalankan workflow...");
      final trigger = await http.post(
        Uri.parse("https://api.github.com/repos/$username/$repoName/actions/workflows/build.yml/dispatches"),
        headers: {'Authorization': 'token $ghpToken', 'Content-Type': 'application/json'},
        body: jsonEncode({'ref': 'main'}),
      );
      if (trigger.statusCode == 401) {
        _addBuildLog("❌ Token tidak valid!", isError: true);
        await _saveToHistory(appName, '', repoName, username, status: 'failed');
        await _clearRunningBuildState();
        setState(() { _isBuildRunning = false; _isLoading = false; });
        return;
      }
      if (trigger.statusCode != 204) {
        _addBuildLog("❌ Gagal menjalankan workflow! Status: ${trigger.statusCode}", isError: true);
        await _saveToHistory(appName, '', repoName, username, status: 'failed');
        await _clearRunningBuildState();
        setState(() { _isBuildRunning = false; _isLoading = false; });
        return;
      }
      _addBuildLog("Workflow berhasil dijalankan", isSuccess: true);
      
      _addBuildLog("Menunggu build APK: $appName selesai (3-8 menit)...");
      _addBuildLog("Aplikasi bisa ditutup, build akan tetap berjalan di background");
      setState(() => _isLoading = false);
      
      _buildMonitorTimer?.cancel();
      _buildMonitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        await _monitorBuild(buildState);
      });
      
    } catch (e) {
      _addBuildLog("❌ Error: $e", isError: true);
      await _saveToHistory(appName, '', repoName, username, status: 'failed');
      await _clearRunningBuildState();
      setState(() { _isBuildRunning = false; _isLoading = false; });
    }
  }

  Future<void> _startDownloadWithProgress(String downloadUrl) async {
    final token = _ghpTokenController.text.trim();
    final fileName = _selectedZipFileName?.replaceAll('.zip', '') ?? 'app';
    
    setState(() {
      _isBackgroundDownloading = true;
      _backgroundFileName = fileName;
      _backgroundProgress = 0.0;
    });
    
    _downloadCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted && _isBackgroundDownloading) {
        setState(() {});
      }
    });
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DownloadProgressPage(
          downloadUrl: downloadUrl,
          fileName: fileName,
          token: token,
          onComplete: (apkFile) async {
            await _installAPK(apkFile);
            if (_buildHistory.isNotEmpty && _buildHistory.first.appName == fileName) {
              await _saveToHistory(
                _buildHistory.first.appName,
                _buildHistory.first.downloadUrl,
                _buildHistory.first.repoName,
                _buildHistory.first.username,
                apkPath: apkFile.path,
                isOptimized: true,
              );
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("✅ APK $fileName berhasil diunduh!\n📍 Tersimpan di Download & Data Aplikasi"), backgroundColor: successGreen),
            );
            setState(() {
              _isBackgroundDownloading = false;
              _backgroundProgress = 1.0;
            });
            _downloadCheckTimer?.cancel();
          },
        ),
      ),
    );
  }

  Future<void> _installFromHistory(BuildHistoryItem item) async {
    if (item.apkPath == null || !await File(item.apkPath!).exists()) {
      _addBuildLog("❌ File APK ${item.appName} tidak ditemukan! Download ulang terlebih dahulu.", isError: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("File APK tidak ditemukan! Download ulang terlebih dahulu."), backgroundColor: Colors.red),
      );
      if (item.downloadUrl.isNotEmpty) {
        await _startDownloadWithProgress(item.downloadUrl);
      }
      return;
    }
    final apkFile = File(item.apkPath!);
    _addBuildLog("Menginstall APK: ${item.appName}");
    await _installAPK(apkFile);
  }

  Future<void> _installAPK(File apkFile) async {
    try {
      if (await Permission.requestInstallPackages.isDenied) {
        await Permission.requestInstallPackages.request();
      }
      final result = await OpenFilex.open(apkFile.path);
      if (result.type == ResultType.done) {
        _addBuildLog("✅ Instalasi dimulai!", isSuccess: true);
      }
    } catch (e) {
      _addBuildLog("❌ Error install: $e", isError: true);
    }
  }

  @override
  void dispose() {
    _buildMonitorTimer?.cancel();
    _downloadCheckTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _ghpTokenController.dispose();
    _usernameController.dispose();
    _terminalScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _buildTerminal() {
    if (_buildLogs.isEmpty && !_isLoading && !_isBuildRunning) return const SizedBox.shrink();
    return Container(
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
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              ],
            ),
          ),
          Container(
            height: 200,
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
          prefixIcon: Icon(icon, color: neonRed),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (_isBuildRunning && !didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Build tetap berjalan di background"), backgroundColor: Colors.orange),
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
                decoration: BoxDecoration(color: neonRed.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.folder_zip, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text("Builder APK Flutter", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: primaryDark,
          elevation: 0,
          actions: [
            if (_isBuildRunning)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
                    SizedBox(width: 4),
                    Text("Building", style: TextStyle(color: Colors.orange, fontSize: 10)),
                  ],
                ),
              ),
            IconButton(
              icon: const Icon(Icons.link, color: Colors.white),
              onPressed: _isDownloadingUrl ? null : _showDownloadUrlDialog,
              tooltip: "Download dari URL",
            ),
            IconButton(
              icon: const Icon(Icons.history, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HistoryBuildPageFlutter(
                      onDownload: (url, fileName, token) {
                        _downloadFromUrl(url, fileName);
                      },
                      onInstall: (item) async {
                        await _installFromHistory(item);
                      },
                    ),
                  ),
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
                          gradient: LinearGradient(colors: [primaryBlue, neonRed]),
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
                                  child: const Icon(Icons.folder_zip, color: Colors.white, size: 40),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text("Builder APK Flutter", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text("Build APK dari file ZIP", style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: cardDark, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _isBuildRunning ? null : _pickZipFile,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardDarker,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: neonRed.withOpacity(0.5)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.folder_zip, color: neonRed, size: 30),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedZipFileName ?? "Pilih File ZIP",
                                            style: TextStyle(
                                              color: _selectedZipFileName != null ? Colors.white : Colors.white54,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (_selectedZipFileName != null)
                                            Text("Klik untuk ganti file", style: TextStyle(color: neonRed, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.upload_file, color: neonRed),
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
                                gradient: LinearGradient(colors: [neonRed, neonRed.withOpacity(0.7)]),
                              ),
                              child: ElevatedButton(
                                onPressed: (_isLoading || _isBuildRunning) ? null : _buildAPK,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                                child: _isLoading || _isBuildRunning
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text("BUILD APK", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            if (_isBuildRunning)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Build sedang berjalan di background. Anda bisa menutup aplikasi, build akan tetap berjalan.",
                                          style: TextStyle(color: Colors.orange, fontSize: 11),
                                        ),
                                      ),
                                    ],
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
            if (_isBackgroundDownloading)
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
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCC0000)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_backgroundProgress * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _backgroundFileName.length > 15 
                            ? '${_backgroundFileName.substring(0, 15)}...' 
                            : _backgroundFileName,
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
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
}