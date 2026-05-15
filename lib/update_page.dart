import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';

class UpdatePage extends StatefulWidget {
  final Widget nextPage;
  const UpdatePage({super.key, required this.nextPage});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  bool checking = true;
  bool updateAvailable = false;
  bool forceUpdate = false;
  bool downloading = false;

  double progress = 0;

  String currentVersion = '';
  String serverVersion = '';
  String apkUrl = '';
  List<String> changelog = [];

  File? apkFile;

  @override
  void initState() {
    super.initState();
    checkUpdate();
  }

  // ================= VERSION CHECK =================
  Future<void> checkUpdate() async {
    setState(() => checking = true);

    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version;

      final res = await Dio().get(
        'http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/app/version',
      );

      final data =
          res.data is String ? jsonDecode(res.data) : res.data;

      serverVersion = data['version'];
      apkUrl = data['apk_url'];
      forceUpdate = data['force_update'] ?? false;
      changelog = List<String>.from(data['changelog'] ?? []);

      updateAvailable = isNewer(currentVersion, serverVersion);

      // cek APK sudah ada atau belum
      final path =
          '/storage/emulated/0/Download/Vecto X Crash-$serverVersion.apk';
      final file = File(path);
      apkFile = file.existsSync() ? file : null;
    } catch (e) {
      debugPrint('CHECK UPDATE ERROR: $e');
      updateAvailable = false;
    }

    setState(() => checking = false);

    if (!updateAvailable) {
      Future.delayed(const Duration(milliseconds: 300), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => widget.nextPage),
        );
      });
    }
  }

  bool isNewer(String current, String server) {
    final c = current.split('.').map(int.parse).toList();
    final s = server.split('.').map(int.parse).toList();
    final max = c.length > s.length ? c.length : s.length;

    for (int i = 0; i < max; i++) {
      final cv = i < c.length ? c[i] : 0;
      final sv = i < s.length ? s[i] : 0;
      if (sv > cv) return true;
      if (sv < cv) return false;
    }
    return false;
  }

  // ================= DOWNLOAD =================
  Future<void> downloadApk() async {
    try {
      final installPerm =
          await Permission.requestInstallPackages.request();
      if (!installPerm.isGranted) return;

      setState(() {
        downloading = true;
        progress = 0;
      });

      final dir = Directory('/storage/emulated/0/Download');
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final filePath =
          '${dir.path}/sadistic-$serverVersion.apk';

      await Dio().download(
        apkUrl,
        filePath,
        onReceiveProgress: (r, t) {
          if (t > 0) {
            setState(() => progress = r / t);
          }
        },
      );

      apkFile = File(filePath);
    } catch (e) {
      debugPrint('DOWNLOAD ERROR: $e');
    }

    setState(() => downloading = false);
  }

  void installApk() {
    if (apkFile != null) {
      OpenFilex.open(apkFile!.path);
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF020617),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
  body: Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF020617),
          Color(0xFF020617),
          Color(0xFF0F172A),
        ],
      ),
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _heroHeader(),
            const SizedBox(height: 20),
            _infoCard(),
            const SizedBox(height: 14),
            _changelog(),
            const Spacer(),
            downloading ? _progress() : _buttons(),
          ],
        ),
      ),
    ),
  ),
);
  }
  
  Widget _heroHeader() {
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: forceUpdate
                ? [Colors.redAccent, Colors.deepOrange]
                : [Colors.cyanAccent, Colors.purpleAccent],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 1,
            )
          ],
        ),
        child: const Icon(
          Icons.system_update_alt,
          size: 48,
          color: Colors.black,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        forceUpdate ? 'UPDATE WAJIB' : 'UPDATE TERSEDIA',
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Versi baru siap dipasang',
        style: TextStyle(color: Colors.grey.shade400),
      ),
    ],
  );
}

  Widget _buttons() {
  return Column(
    children: [
      SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: apkFile == null ? downloadApk : installApk,
          child: Text(
            apkFile == null ? 'DOWNLOAD UPDATE' : 'INSTALL SEKARANG',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: checkUpdate,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
          if (!forceUpdate)
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => widget.nextPage),
                );
              },
              child: const Text('Lewati'),
            ),
        ],
      ),
    ],
  );
}

  Widget _progress() {
  return Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 10,
          backgroundColor: Colors.white10,
          valueColor:
              const AlwaysStoppedAnimation(Colors.cyanAccent),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Mengunduh ${(progress * 100).toStringAsFixed(0)}%',
        style: TextStyle(color: Colors.grey.shade300),
      ),
    ],
  );
}

  Widget _header() {
    return Column(
      children: [
        const Icon(Icons.system_update,
            size: 56, color: Colors.cyan),
        const SizedBox(height: 8),
        Text(
          forceUpdate ? 'UPDATE WAJIB' : 'UPDATE TERSEDIA',
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _infoCard() {
  return _card(Column(
    children: [
      _row('Versi Saat Ini', currentVersion),
      const Divider(color: Colors.white12),
      _row('Versi Terbaru', serverVersion),
    ],
  ));
}

  Widget _changelog() {
  return _card(Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '✨ Pembaruan',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      const SizedBox(height: 10),
      ...changelog.map(
        (e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.check_circle,
                  size: 18, color: Colors.cyanAccent),
              const SizedBox(width: 8),
              Expanded(child: Text(e)),
            ],
          ),
        ),
      ),
    ],
  ));
}

  Widget _row(String a, String b) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(a, style: const TextStyle(color: Colors.grey)),
          Text(b,
              style:
                  const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _card(Widget child) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white10),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 20,
        )
      ],
    ),
    child: child,
  );
}
}