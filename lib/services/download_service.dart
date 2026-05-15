import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  static const int _notificationId = 999;
  static bool _isDownloading = false;
  static String _currentFile = "";
  static double _currentProgress = 0.0;
  
  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = 
        InitializationSettings(android: androidSettings);
    await _notifications.initialize(settings);
    
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'download_channel',
      'Download APK',
      description: 'Notifikasi download APK',
      importance: Importance.high,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
  
  static Future<void> _showProgress(double progress, String status) async {
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
    await _notifications.show(
      _notificationId,
      "Mengunduh ${_currentFile.split('/').last}",
      "$status - ${(progress * 100).toStringAsFixed(1)}%",
      details,
    );
  }
  
  static Future<void> _showComplete(String filePath) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Download APK',
      channelDescription: 'Notifikasi download APK selesai',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _notifications.show(
      _notificationId,
      "✅ Download Selesai",
      "APK tersimpan di: $filePath",
      details,
    );
  }
  
  static Future<bool> downloadApk({
    required String url,
    required String fileName,
    required String token,
    Function(double progress)? onProgress,
  }) async {
    if (_isDownloading) {
      debugPrint("Download sedang berjalan...");
      return false;
    }
    
    _isDownloading = true;
    _currentFile = fileName;
    _currentProgress = 0.0;
    
    try {
      await _showProgress(0, "Memulai download...");
      
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Authorization'] = 'token $token';
      request.headers['Accept'] = 'application/vnd.github.v3+json';
      
      final streamedResponse = await request.send();
      final totalBytes = streamedResponse.contentLength ?? 0;
      
      if (streamedResponse.statusCode != 200) {
        throw Exception("Gagal download: ${streamedResponse.statusCode}");
      }
      
      final tempDir = await getTemporaryDirectory();
      final zipFile = File('${tempDir.path}/download_${DateTime.now().millisecondsSinceEpoch}.zip');
      final sink = zipFile.openWrite();
      
      int received = 0;
      final startTime = DateTime.now();
      
      await streamedResponse.stream.listen(
        (chunk) async {
          received += chunk.length;
          sink.add(chunk);
          
          if (totalBytes > 0) {
            final progress = received / totalBytes;
            _currentProgress = progress;
            onProgress?.call(progress);
            
            final elapsed = DateTime.now().difference(startTime).inSeconds;
            final speed = elapsed > 0 ? received / 1024 / 1024 / elapsed : 0;
            await _showProgress(progress, "${(progress * 100).toStringAsFixed(1)}% • ${speed.toStringAsFixed(2)} MB/s");
          }
        },
        onDone: () async {
          await sink.close();
          
          final bytes = await zipFile.readAsBytes();
          final archive = ZipDecoder().decodeBytes(bytes);
          
          File? apkFile;
          for (final file in archive) {
            if (file.name.endsWith('.apk') && file.isFile) {
              final apkPath = File('${tempDir.path}/${file.name.split('/').last}');
              await apkPath.writeAsBytes(file.content as List<int>);
              apkFile = apkPath;
              break;
            }
          }
          
          await zipFile.delete();
          
          if (apkFile == null) {
            throw Exception("Tidak ditemukan APK dalam ZIP");
          }
          
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
          
          final savedApk = File('${downloadDir.path}/$fileName.apk');
          await apkFile.copy(savedApk.path);
          
          final prefs = await SharedPreferences.getInstance();
          final history = prefs.getStringList('download_history') ?? [];
          history.add(jsonEncode({
            'fileName': fileName,
            'path': savedApk.path,
            'date': DateTime.now().toIso8601String(),
            'size': await savedApk.length(),
          }));
          await prefs.setStringList('download_history', history);
          
          await _showComplete(savedApk.path);
          _isDownloading = false;
          return true;
        },
        onError: (e) async {
          sink.close();
          await zipFile.delete();
          _isDownloading = false;
          throw Exception("Error: $e");
        },
      ).asFuture();
      
      return true;
      
    } catch (e) {
      debugPrint("Download error: $e");
      _isDownloading = false;
      return false;
    }
  }
  
  static bool get isDownloading => _isDownloading;
  static double get currentProgress => _currentProgress;
  static String get currentFile => _currentFile;
}