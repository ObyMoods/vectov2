import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

final baseUrl = 'http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323';

class ProtectPanelPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;

  const ProtectPanelPage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
  });

  @override
  State<ProtectPanelPage> createState() => _ProtectPanelPageState();
}

class _ProtectPanelPageState extends State<ProtectPanelPage> {
  late String sessionKey;
  late String userLogin;
  late String userRole;

  final TextEditingController vpsIpController = TextEditingController();
  final TextEditingController vpsPasswordController = TextEditingController();
  final TextEditingController vpsPortController = TextEditingController();

  bool isLoggedInToVps = false;
  String currentVpsIp = '';
  bool isLoading = false;
  String selectedProtect = 'installprotect1';
  
  final Map<String, Map<String, String>> protectList = {
    'installprotect1': {
      'name': '🛡️ PROTECT 1',
      'desc': 'Anti Intip Server, Anti Update Detail, Anti Build, Anti Database, Anti Transfer, Anti Suspend, Anti Reinstall, Anti Delete',
      'icon': '🛡️',
      'file': 'ServerController.php, BuildModificationService.php, DatabaseManagementService.php, dll'
    },
    'installprotect2': {
      'name': '👥 PROTECT 2',
      'desc': 'Anti Intip Users & Anti CADMIN - Hanya Admin ID 1 yang bisa lihat/edit user lain',
      'icon': '👥',
      'file': 'UserController.php'
    },
    'installprotect3': {
      'name': '📍 PROTECT 3',
      'desc': 'Anti Intip Location - Hanya Admin ID 1 yang bisa akses menu Location',
      'icon': '📍',
      'file': 'LocationController.php'
    },
    'installprotect4': {
      'name': '🖥️ PROTECT 4',
      'desc': 'Anti Intip Nodes - Hanya Admin ID 1 yang bisa akses menu Nodes',
      'icon': '🖥️',
      'file': 'NodeController.php'
    },
    'installprotect5': {
      'name': '🥚 PROTECT 5',
      'desc': 'Anti Intip Nest - Hanya Admin ID 1 yang bisa akses menu Nests',
      'icon': '🥚',
      'file': 'NestController.php'
    },
    'installprotect6': {
      'name': '⚙️ PROTECT 6',
      'desc': 'Anti Intip Settings - Hanya Admin ID 1 yang bisa akses menu Settings',
      'icon': '⚙️',
      'file': 'IndexController.php'
    },
    'installprotect7': {
      'name': '📁 PROTECT 7',
      'desc': 'Anti Akses File & Download - Hanya Owner server yang bisa akses file',
      'icon': '📁',
      'file': 'FileController.php'
    },
    'installprotect8': {
      'name': '🔍 PROTECT 8',
      'desc': 'Anti Intip Server - Hanya Admin ID 1 atau Owner yang bisa lihat detail server',
      'icon': '🔍',
      'file': 'ServerController.php (API)'
    },
    'installprotect9': {
      'name': '🔑 PROTECT 9',
      'desc': 'Anti Intip API Key - Hanya Admin ID 1 yang bisa akses Application API',
      'icon': '🔑',
      'file': 'ApiController.php'
    },
    'installprotect10': {
      'name': '🔐 PROTECT 10',
      'desc': 'Anti Create Client API Key - Hanya Admin ID 1 yang bisa buat API Key',
      'icon': '🔐',
      'file': 'ApiKeyController.php'
    },
    'installprotect11': {
      'name': '🗄️ PROTECT 11',
      'desc': 'Anti Intip Database - Hanya Admin ID 1 yang bisa akses menu Database',
      'icon': '🗄️',
      'file': 'DatabaseController.php'
    },
    'installprotect12': {
      'name': '💾 PROTECT 12',
      'desc': 'Anti Intip Mounts - Hanya Admin ID 1 yang bisa akses menu Mounts',
      'icon': '💾',
      'file': 'MountController.php'
    },
    'installprotect13': {
      'name': '🔒 PROTECT 13',
      'desc': 'Anti Button Two Factor - Hanya Admin ID 1 yang bisa atur 2FA',
      'icon': '🔒',
      'file': 'TwoFactorController.php'
    },
    'installprotect14': {
      'name': '🎨 PROTECT 14',
      'desc': 'Menghilangkan Bar Menu - Nodes, Locations, Database, Settings, API, Mounts, Nest untuk user biasa',
      'icon': '🎨',
      'file': 'admin.blade.php'
    },
    'installprotectall': {
      'name': '⭐ PROTECT ALL',
      'desc': 'Install SEMUA proteksi sekaligus (1-14)',
      'icon': '⭐',
      'file': 'Semua file proteksi'
    },
  };

  final Color bgDark = const Color(0xFF0D0D1A);
  final Color primaryPurple = const Color(0xFF7C3AED);
  final Color accentPurple = const Color(0xFFA78BFA);

  @override
  void initState() {
    super.initState();
    sessionKey = widget.sessionKey;
    userLogin = widget.username;
    userRole = widget.role;
    vpsPortController.text = '22';
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.copy, color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Text('$label berhasil disalin!', style: const TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.green.withOpacity(0.8),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _loginToVps() async {
    final ip = vpsIpController.text.trim();
    final password = vpsPasswordController.text.trim();
    final port = vpsPortController.text.trim();

    if (ip.isEmpty) {
      _showAlert("⚠️ Error", "Masukkan IP VPS!");
      return;
    }
    if (password.isEmpty) {
      _showAlert("⚠️ Error", "Masukkan password VPS!");
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/vps/login?key=$sessionKey&ip=$ip&password=$password&port=${port.isEmpty ? 22 : int.parse(port)}'),
      );
      final data = jsonDecode(res.body);

      if (data['valid'] == true && data['success'] == true) {
        setState(() {
          isLoggedInToVps = true;
          currentVpsIp = ip;
        });
        _showAlert("✅ Berhasil!", "Login ke VPS $ip berhasil!\n\nSekarang kamu bisa install proteksi.");
        vpsIpController.clear();
        vpsPasswordController.clear();
      } else {
        _showAlert("❌ Gagal", data['message'] ?? 'Gagal login ke VPS');
      }
    } catch (e) {
      _showAlert("🌐 Error", "Gagal menghubungi server: $e");
    }

    setState(() => isLoading = false);
  }

  Future<void> _logoutVps() async {
    setState(() => isLoading = true);

    try {
      final res = await http.get(Uri.parse('$baseUrl/api/vps/logout?key=$sessionKey'));
      final data = jsonDecode(res.body);

      if (data['valid'] == true && data['success'] == true) {
        setState(() {
          isLoggedInToVps = false;
          currentVpsIp = '';
        });
        _showAlert("✅ Berhasil!", "Logout dari VPS berhasil!");
      } else {
        _showAlert("❌ Gagal", data['message'] ?? 'Gagal logout');
      }
    } catch (e) {
      _showAlert("🌐 Error", "Gagal menghubungi server: $e");
    }

    setState(() => isLoading = false);
  }

  Future<void> _installProtect() async {
    if (!isLoggedInToVps) {
      _showAlert("⚠️ Error", "Login ke VPS terlebih dahulu!");
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await http.get(Uri.parse('$baseUrl/api/$selectedProtect?key=$sessionKey'));
      final data = jsonDecode(res.body);

      if (data['valid'] == true && data['success'] == true) {
        _showSuccessDialog(data);
      } else {
        _showAlert("❌ Gagal", data['message'] ?? 'Gagal memasang proteksi');
      }
    } catch (e) {
      _showAlert("🌐 Error", "Gagal menghubungi server: $e");
    }

    setState(() => isLoading = false);
  }

  void _showSuccessDialog(Map<String, dynamic> data) {
    final protectName = protectList[selectedProtect]?['name'] ?? selectedProtect.toUpperCase();
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.green),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "✅ PROTEKSI TERPASANG!",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRowWithCopy(
                label: "🛡️ Proteksi",
                value: protectName,
                onCopy: () => _copyToClipboard(protectName, "Nama proteksi disalin"),
              ),
              const SizedBox(height: 12),
              _buildDetailRowWithCopy(
                label: "📂 Lokasi",
                value: data['file_path'] ?? protectList[selectedProtect]?['file'] ?? '-',
                onCopy: () => _copyToClipboard(data['file_path'] ?? protectList[selectedProtect]?['file'] ?? '-', "Path file disalin"),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Proteksi berhasil dipasang! Panel Anda sekarang lebih aman.',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("OK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithCopy({
    required String label,
    required String value,
    required VoidCallback onCopy,
  }) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: accentPurple, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: onCopy,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: primaryPurple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentPurple.withOpacity(0.3)),
            ),
            child: Icon(Icons.copy, color: accentPurple, size: 14),
          ),
        ),
      ],
    );
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: accentPurple.withOpacity(0.3)),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: accentPurple)),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor ?? accentPurple, size: 22),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType type = TextInputType.text,
    String? hint,
    String? suffixText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        obscureText: label.toLowerCase().contains('password'),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFFA78BFA), fontSize: 12),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          prefixIcon: Icon(icon, color: accentPurple, size: 18),
          suffixText: suffixText,
          suffixStyle: TextStyle(color: accentPurple, fontSize: 12),
          filled: true,
          fillColor: Colors.white.withOpacity(0.03),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF7C3AED)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: const Text(
          "🛡️ PANEL PROTECTOR",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        backgroundColor: bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFA78BFA)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isLoggedInToVps)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(currentVpsIp, style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgDark, primaryPurple.withOpacity(0.08), bgDark],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(FontAwesomeIcons.shieldHalved, color: Color(0xFF7C3AED), size: 55),
                const SizedBox(height: 12),
                const Text("PTERODACTYL PROTECTOR", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                Text("Amankan Panel Anda dari Cadmin & Intip", style: TextStyle(color: accentPurple, fontSize: 11)),
                const SizedBox(height: 30),

                _buildGlassCard(
                  title: isLoggedInToVps ? "✅ VPS CONNECTED" : "🔌 VPS CONNECTION",
                  icon: isLoggedInToVps ? FontAwesomeIcons.plug : FontAwesomeIcons.server,
                  iconColor: isLoggedInToVps ? Colors.green : Colors.orange,
                  children: isLoggedInToVps
                      ? [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text("Terkoneksi ke VPS: $currentVpsIp", style: const TextStyle(color: Colors.white))),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.logout, size: 18),
                                    label: const Text("LOGOUT VPS"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.withOpacity(0.2),
                                      foregroundColor: Colors.red,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: _logoutVps,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]
                      : [
                          _buildTextField(label: "IP VPS", controller: vpsIpController, icon: FontAwesomeIcons.server, hint: "123.45.67.89"),
                          _buildTextField(label: "PASSWORD", controller: vpsPasswordController, icon: FontAwesomeIcons.key, hint: "Password root VPS"),
                          _buildTextField(label: "PORT", controller: vpsPortController, icon: FontAwesomeIcons.plug, type: TextInputType.number, hint: "22", suffixText: "Default: 22"),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              icon: isLoading ? null : const Icon(Icons.login, size: 18),
                              label: isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("LOGIN KE VPS", style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              onPressed: isLoading ? null : _loginToVps,
                            ),
                          ),
                        ],
                ),

                if (isLoggedInToVps) ...[
                  _buildGlassCard(
                    title: "PILIH PROTEKSI",
                    icon: FontAwesomeIcons.shield,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedProtect,
                            icon: Icon(Icons.arrow_drop_down, color: accentPurple),
                            dropdownColor: bgDark,
                            style: const TextStyle(color: Colors.white),
                            isExpanded: true,
                            items: protectList.keys.map((key) {
                              return DropdownMenuItem<String>(
                                value: key,
                                child: Row(
                                  children: [
                                    Text(protectList[key]!['icon']!, style: const TextStyle(fontSize: 18)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(protectList[key]!['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          Text(protectList[key]!['desc']!, style: TextStyle(color: Colors.white54, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) => setState(() => selectedProtect = value!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primaryPurple.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: accentPurple, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(protectList[selectedProtect]!['desc']!, style: TextStyle(color: accentPurple, fontSize: 11))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)]),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [BoxShadow(color: primaryPurple.withOpacity(0.4), blurRadius: 12)],
                          ),
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _installProtect,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                            child: isLoading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(protectList[selectedProtect]!['icon']!, style: const TextStyle(fontSize: 18)),
                                      const SizedBox(width: 10),
                                      Text("INSTALL ${protectList[selectedProtect]!['name']!}", style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.security, color: Colors.orange, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('⚠️ PERINGATAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text('Pastikan Anda adalah pemilik VPS sebelum menginstall proteksi. Backup file asli terlebih dahulu.', style: TextStyle(color: Colors.orange.withOpacity(0.8), fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}