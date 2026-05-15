import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class HistoryBuildPage extends StatefulWidget {
  final String? repoName;
  final String? username;
  final String? ghpToken;
  final String? appName;
  final Function(String)? onBuildComplete;

  const HistoryBuildPage({
    super.key,
    this.repoName,
    this.username,
    this.ghpToken,
    this.appName,
    this.onBuildComplete,
  });

  @override
  State<HistoryBuildPage> createState() => _HistoryBuildPageState();
}

class _HistoryBuildPageState extends State<HistoryBuildPage> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = false;
  String? _buildStatus;
  String? _downloadUrl;
  bool _isBuildComplete = false;

  final Color primaryDark = const Color(0xFF0A0E27);
  final Color cardDark = const Color(0xFF151932);
  final Color successGreen = const Color(0xFF10B981);
  final Color dangerRed = const Color(0xFFEF4444);
  final Color accentBlue = const Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _loadHistory();
    if (widget.repoName != null && widget.username != null) {
      _startBuildMonitoring();
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyList = prefs.getStringList('web_apk_history') ?? [];
    setState(() {
      _history = historyList.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
      _history.sort((a, b) => b['date'].compareTo(a['date']));
    });
  }

  Future<void> _startBuildMonitoring() async {
    setState(() {
      _isLoading = true;
      _buildStatus = "Memulai build...";
    });

    bool buildCompleted = false;
    int attempts = 0;

    while (!buildCompleted && attempts < 120) {
      await Future.delayed(const Duration(seconds: 5));
      
      try {
        final runsResponse = await http.get(
          Uri.parse("https://api.github.com/repos/${widget.username}/${widget.repoName}/actions/runs?per_page=1"),
          headers: {'Authorization': 'token ${widget.ghpToken}'},
        );
        
        if (runsResponse.statusCode == 200) {
          final runsData = jsonDecode(runsResponse.body);
          if (runsData['workflow_runs'] != null && runsData['workflow_runs'].isNotEmpty) {
            final latestRun = runsData['workflow_runs'][0];
            final status = latestRun['status'];
            final conclusion = latestRun['conclusion'];
            
            setState(() {
              _buildStatus = status == 'completed' 
                  ? (conclusion == 'success' ? "Build Selesai ✅" : "Build Gagal ❌")
                  : "Build sedang berjalan... (${attempts * 5}s)";
            });
            
            if (status == 'completed') {
              buildCompleted = true;
              if (conclusion == 'success') {
                final artifactsResponse = await http.get(
                  Uri.parse("https://api.github.com/repos/${widget.username}/${widget.repoName}/actions/runs/${latestRun['id']}/artifacts"),
                  headers: {'Authorization': 'token ${widget.ghpToken}'},
                );
                
                if (artifactsResponse.statusCode == 200) {
                  final artifactsData = jsonDecode(artifactsResponse.body);
                  if (artifactsData['artifacts'] != null && artifactsData['artifacts'].isNotEmpty) {
                    final artifact = artifactsData['artifacts'][0];
                    final downloadUrl = artifact['archive_download_url'];
                    
                    setState(() {
                      _downloadUrl = downloadUrl;
                      _isBuildComplete = true;
                    });
                    
                    if (widget.onBuildComplete != null) {
                      widget.onBuildComplete!(downloadUrl);
                    }
                    
                    _saveToHistory(downloadUrl);
                  }
                }
              }
              break;
            }
          }
        }
      } catch (e) {
        print("Error: $e");
      }
      attempts++;
    }
    
    setState(() {
      _isLoading = false;
      if (!buildCompleted) {
        _buildStatus = "Build Timeout atau Gagal";
      }
    });
  }

  Future<void> _saveToHistory(String downloadUrl) async {
    final historyItem = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'appName': widget.appName ?? 'Unknown',
      'downloadUrl': downloadUrl,
      'packageName': 'com.webapp.${DateTime.now().millisecondsSinceEpoch}',
      'url': '-',
      'date': DateTime.now().toIso8601String(),
      'size': 'Unknown',
    };
    
    final prefs = await SharedPreferences.getInstance();
    List<String> historyList = prefs.getStringList('web_apk_history') ?? [];
    historyList.add(jsonEncode(historyItem));
    await prefs.setStringList('web_apk_history', historyList);
    _loadHistory();
  }

  Future<void> _downloadAPK(String url, String name) async {
    setState(() => _isLoading = true);
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final downloadDir = Directory('/storage/emulated/0/Download/WebApk');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        
        final fileName = name.replaceAll(' ', '_');
        final apkFile = File('${downloadDir.path}/${fileName}_${DateTime.now().millisecondsSinceEpoch}.apk');
        await apkFile.writeAsBytes(response.bodyBytes);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("APK berhasil diunduh!")),
        );
        
        await OpenFilex.open(apkFile.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteHistoryItem(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyList = prefs.getStringList('web_apk_history') ?? [];
    historyList.removeWhere((item) {
      final data = jsonDecode(item);
      return data['id'] == id;
    });
    await prefs.setStringList('web_apk_history', historyList);
    _loadHistory();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("History dihapus")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        title: const Text("History Build", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.repoName != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(_isBuildComplete ? Icons.check_circle : Icons.build_circle,
                          color: _isBuildComplete ? successGreen : accentBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _buildStatus ?? "Memulai build...",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  if (_downloadUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text("Download APK"),
                        style: ElevatedButton.styleFrom(backgroundColor: successGreen),
                        onPressed: () => _downloadAPK(_downloadUrl!, widget.appName ?? "app"),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _history.isEmpty
                ? const Center(
                    child: Text("Belum ada history build", style: TextStyle(color: Colors.white54)),
                  )
                : ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item['appName'],
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => _deleteHistoryItem(item['id']),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "📅 ${DateTime.parse(item['date']).toLocal().toString().substring(0, 19)}",
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.download, size: 16),
                                    label: const Text("Download & Install"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: successGreen,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    onPressed: () => _downloadAPK(item['downloadUrl'], item['appName']),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.share, color: Colors.white),
                                  onPressed: () => Share.share(item['downloadUrl']),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}