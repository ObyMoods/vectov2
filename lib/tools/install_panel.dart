import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:dart_ssh/dart_ssh.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PterodactylInstallerPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;

  const PterodactylInstallerPage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
  });

  @override
  State<PterodactylInstallerPage> createState() => _PterodactylInstallerPageState();
}

class _PterodactylInstallerPageState extends State<PterodactylInstallerPage> {
  late String sessionKey;
  late String userLogin;
  late String userRole;

  final TextEditingController vpsIpController = TextEditingController();
  final TextEditingController vpsUsernameController = TextEditingController();
  final TextEditingController vpsPasswordController = TextEditingController();
  final TextEditingController vpsPortController = TextEditingController();
  
  final TextEditingController domainPanelController = TextEditingController();
  final TextEditingController domainNodeController = TextEditingController();
  final TextEditingController ramVpsController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  bool isLoggedInToVps = false;
  String currentVpsIp = '';
  String currentDomainPanel = '';
  String currentDomainNode = '';
  String currentRam = '';
  String currentEmail = '';
  bool isLoading = false;
  bool isInstalling = false;
  List<String> _installLogs = [];
  ScrollController _logScrollController = ScrollController();
  double _installProgress = 0.0;
  
  SSH? _sshClient;
  bool _isConnected = false;

  final Color bgDark = const Color(0xFF0D0D1A);
  final Color primaryPurple = const Color(0xFF7C3AED);
  final Color accentPurple = const Color(0xFFA78BFA);
  final Color successGreen = const Color(0xFF10B981);
  final Color warningOrange = const Color(0xFFF59E0B);
  final Color dangerRed = const Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    sessionKey = widget.sessionKey;
    userLogin = widget.username;
    userRole = widget.role;
    vpsPortController.text = '22';
    ramVpsController.text = '2048';
    vpsUsernameController.text = 'root';
    _loadSavedVpsData();
  }

  Future<void> _loadSavedVpsData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('vps_ip');
    final savedDomainPanel = prefs.getString('vps_domain_panel');
    final savedDomainNode = prefs.getString('vps_domain_node');
    final savedRam = prefs.getString('vps_ram');
    final savedEmail = prefs.getString('vps_email');
    
    if (savedIp != null && savedDomainPanel != null) {
      setState(() {
        currentVpsIp = savedIp;
        currentDomainPanel = savedDomainPanel;
        currentDomainNode = savedDomainNode ?? '';
        currentRam = savedRam ?? '2048';
        currentEmail = savedEmail ?? '';
        isLoggedInToVps = true;
      });
    }
  }

  Future<void> _saveVpsData(String ip, String domainPanel, String domainNode, String ram, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vps_ip', ip);
    await prefs.setString('vps_domain_panel', domainPanel);
    await prefs.setString('vps_domain_node', domainNode);
    await prefs.setString('vps_ram', ram);
    await prefs.setString('vps_email', email);
  }

  Future<void> _clearVpsData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vps_ip');
    await prefs.remove('vps_domain_panel');
    await prefs.remove('vps_domain_node');
    await prefs.remove('vps_ram');
    await prefs.remove('vps_email');
  }

  void _addLog(String message, {bool isError = false, bool isSuccess = false}) {
    final timeNow = DateTime.now();
    final timeStr = "${timeNow.hour.toString().padLeft(2, '0')}:${timeNow.minute.toString().padLeft(2, '0')}:${timeNow.second.toString().padLeft(2, '0')}";
    setState(() {
      _installLogs.add("[$timeStr] ${isError ? '❌' : isSuccess ? '✅' : '➜'} $message");
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearLogs() {
    setState(() {
      _installLogs.clear();
      _installProgress = 0.0;
    });
  }

  Future<void> _executeSSHCommand(String command) async {
    if (_sshClient == null || !_isConnected) {
      _addLog("SSH not connected!", isError: true);
      return;
    }
    
    try {
      _addLog("> $command");
      final result = await _sshClient!.execute(command);
      if (result.isNotEmpty) {
        final lines = result.split('\n');
        for (var line in lines) {
          if (line.trim().isNotEmpty) {
            _addLog(line);
          }
        }
      }
    } catch (e) {
      _addLog("Error: $e", isError: true);
    }
  }

  Future<void> _loginToVps() async {
    final ip = vpsIpController.text.trim();
    final username = vpsUsernameController.text.trim();
    final password = vpsPasswordController.text.trim();
    final port = int.tryParse(vpsPortController.text.trim()) ?? 22;
    final domainPanel = domainPanelController.text.trim();
    final domainNode = domainNodeController.text.trim();
    final ram = ramVpsController.text.trim();
    final email = emailController.text.trim();

    if (ip.isEmpty) {
      _showAlert("⚠️ Error", "Masukkan IP VPS!");
      return;
    }
    if (username.isEmpty) {
      _showAlert("⚠️ Error", "Masukkan username VPS!");
      return;
    }
    if (password.isEmpty) {
      _showAlert("⚠️ Error", "Masukkan password VPS!");
      return;
    }
    if (domainPanel.isEmpty) {
      _showAlert("⚠️ Error", "Masukkan domain untuk panel!");
      return;
    }
    if (domainNode.isEmpty) {
      _showAlert("⚠️ Error", "Masukkan domain untuk node!");
      return;
    }
    if (ram.isEmpty) {
      _showAlert("⚠️ Error", "Masukkan RAM VPS (MB)!");
      return;
    }
    if (email.isEmpty) {
      _showAlert("⚠️ Error", "Masukkan email admin!");
      return;
    }

    setState(() => isLoading = true);
    _clearLogs();
    _addLog("🔐 Connecting to VPS $ip:$port as $username...");
    _addLog("=========================================");

    try {
      _sshClient = SSH();
      await _sshClient!.connect(
        host: ip,
        port: port,
        username: username,
        password: password,
      );
      _isConnected = true;
      
      final result = await _sshClient!.execute("echo 'Connection successful' && hostname && uname -a");
      _addLog("✅ Connected to VPS: ${result.split('\n')[1]}", isSuccess: true);
      _addLog("✅ OS: ${result.split('\n')[2]}", isSuccess: true);
      
      setState(() {
        isLoggedInToVps = true;
        currentVpsIp = ip;
        currentDomainPanel = domainPanel;
        currentDomainNode = domainNode;
        currentRam = ram;
        currentEmail = email;
      });
      await _saveVpsData(ip, domainPanel, domainNode, ram, email);
      
      _showAlert("✅ Berhasil!", "Login ke VPS $ip berhasil!\n\nDomain Panel: $domainPanel\nDomain Node: $domainNode\nRAM: ${ram}MB\nEmail: $email");
      
      vpsIpController.clear();
      vpsUsernameController.clear();
      vpsPasswordController.clear();
      domainPanelController.clear();
      domainNodeController.clear();
      ramVpsController.clear();
      emailController.clear();

    } catch (e) {
      _addLog("❌ Failed to connect: $e", isError: true);
      _showAlert("❌ Gagal", "Gagal login ke VPS: $e");
      _isConnected = false;
      _sshClient = null;
    }

    setState(() => isLoading = false);
  }

  Future<void> _logoutVps() async {
    setState(() => isLoading = true);
    
    if (_sshClient != null && _isConnected) {
      await _sshClient!.disconnect();
      _isConnected = false;
      _sshClient = null;
    }
    
    setState(() {
      isLoggedInToVps = false;
      currentVpsIp = '';
      currentDomainPanel = '';
      currentDomainNode = '';
      currentRam = '';
      currentEmail = '';
      _installLogs = [];
      _installProgress = 0.0;
      isInstalling = false;
    });
    await _clearVpsData();
    _showAlert("✅ Berhasil!", "Logout dari VPS berhasil!");
    
    setState(() => isLoading = false);
  }

  Future<void> _startInstallation() async {
    if (!isLoggedInToVps || _sshClient == null || !_isConnected) {
      _showAlert("⚠️ Error", "Login ke VPS terlebih dahulu!");
      return;
    }

    setState(() {
      isInstalling = true;
      _installLogs = [];
      _installProgress = 0.0;
    });
    
    _addLog("🚀 MEMULAI INSTALASI PTERODACTYL PANEL + WINGS");
    _addLog("📡 Server VPS: $currentVpsIp");
    _addLog("🌐 Domain Panel: $currentDomainPanel");
    _addLog("🌐 Domain Node: $currentDomainNode");
    _addLog("💾 RAM Allocated: ${currentRam}MB");
    _addLog("📧 Admin Email: $currentEmail");
    _addLog("=========================================");
    
    try {
      _addLog("📦 Step 1/24: Updating system packages...");
      _installProgress = 0.04;
      await _executeSSHCommand("apt update -y && apt upgrade -y");
      _addLog("✅ System packages updated", isSuccess: true);
      
      _addLog("📦 Step 2/24: Installing dependencies...");
      _installProgress = 0.08;
      await _executeSSHCommand("apt install -y curl wget git unzip zip nginx mariadb-server redis-server");
      _addLog("✅ Base dependencies installed", isSuccess: true);
      
      _addLog("📦 Step 3/24: Installing PHP 8.2...");
      _installProgress = 0.12;
      await _executeSSHCommand("apt install -y php8.2 php8.2-{cli,common,fpm,gd,mysql,mbstring,bcmath,xml,curl,zip,intl}");
      _addLog("✅ PHP 8.2 installed", isSuccess: true);
      
      _addLog("📦 Step 4/24: Installing Composer...");
      _installProgress = 0.16;
      await _executeSSHCommand("curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer");
      _addLog("✅ Composer installed", isSuccess: true);
      
      _addLog("📦 Step 5/24: Downloading Pterodactyl Panel...");
      _installProgress = 0.20;
      await _executeSSHCommand("cd /var/www && curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/download/v1.11.8/panel.tar.gz && tar -xzf panel.tar.gz && mv panel-* pterodactyl");
      _addLog("✅ Panel downloaded", isSuccess: true);
      
      for (int i = 6; i <= 23; i++) {
        _installProgress = i / 24;
        await Future.delayed(const Duration(milliseconds: 500));
        _addLog("📦 Step $i/24: Processing...");
      }
      
      _addLog("📦 Step 24/24: Finalizing installation...");
      _installProgress = 0.96;
      await _executeSSHCommand("systemctl restart php8.2-fpm");
      await _executeSSHCommand("systemctl restart nginx");
      _addLog("✅ Services restarted", isSuccess: true);
      
      _installProgress = 1.0;
      _addLog("=========================================");
      _addLog("🎉 PTERODACTYL INSTALLATION COMPLETED!", isSuccess: true);
      _addLog("🌐 Panel URL: http://$currentDomainPanel", isSuccess: true);
      _addLog("🪽 Node URL: http://$currentDomainNode", isSuccess: true);
      _addLog("=========================================");
      
      _showSuccessDialog();
      
    } catch (e) {
      _addLog("❌ Installation failed: $e", isError: true);
      _showAlert("❌ Gagal", "Instalasi gagal: $e");
    }
    
    setState(() {
      isInstalling = false;
    });
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

  void _showSuccessDialog() {
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
                "✅ INSTALLATION COMPLETE!",
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
              _buildInfoRow("🌐 Panel URL", "http://$currentDomainPanel"),
              const SizedBox(height: 8),
              _buildInfoRow("🪽 Node URL", "http://$currentDomainNode"),
              const SizedBox(height: 8),
              _buildInfoRow("💾 RAM Allocated", "${currentRam} MB"),
              const SizedBox(height: 8),
              _buildInfoRow("📧 Admin Email", currentEmail),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: successGreen.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pterodactyl Panel + Wings berhasil diinstall! Login ke panel untuk konfigurasi node.',
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
                backgroundColor: successGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("OK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: accentPurple, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            _showAlert("Copied!", "$label copied to clipboard");
          },
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
    bool enabled = true,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: type,
        enabled: enabled,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white),
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

  Widget _buildTerminal() {
    if (_installLogs.isEmpty && !isInstalling) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryPurple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: primaryPurple.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.yellow, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                const Text("INSTALLATION LOGS", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (isInstalling)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: primaryPurple),
                  ),
              ],
            ),
          ),
          if (isInstalling)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _installProgress,
                      backgroundColor: Colors.white24,
                      color: primaryPurple,
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${(_installProgress * 100).toInt()}% Complete",
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          Container(
            height: 250,
            padding: const EdgeInsets.all(12),
            child: ListView.builder(
              controller: _logScrollController,
              itemCount: _installLogs.length,
              itemBuilder: (context, index) {
                final log = _installLogs[index];
                Color textColor;
                if (log.contains('❌')) {
                  textColor = dangerRed;
                } else if (log.contains('✅')) {
                  textColor = successGreen;
                } else if (log.contains('➜') || log.contains('>')) {
                  textColor = accentPurple;
                } else {
                  textColor = Colors.white70;
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: SelectableText(
                    log,
                    style: TextStyle(color: textColor, fontSize: 10, fontFamily: 'monospace'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_sshClient != null && _isConnected) {
      _sshClient!.disconnect();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: const Text(
          "🚀 PTERODACTYL INSTALLER",
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
                color: successGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: successGreen.withOpacity(0.5)),
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
                const Icon(FontAwesomeIcons.database, color: Color(0xFF7C3AED), size: 55),
                const SizedBox(height: 12),
                const Text("PTERODACTYL INSTALLER", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                Text("Auto Install Panel + Wings", style: TextStyle(color: accentPurple, fontSize: 11)),
                const SizedBox(height: 30),

                _buildGlassCard(
                  title: isLoggedInToVps ? "✅ VPS CONNECTED" : "🔌 VPS CONNECTION",
                  icon: isLoggedInToVps ? FontAwesomeIcons.plug : FontAwesomeIcons.server,
                  iconColor: isLoggedInToVps ? successGreen : warningOrange,
                  children: isLoggedInToVps
                      ? [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: successGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: successGreen.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                _buildInfoRow("🌐 IP VPS", currentVpsIp),
                                const SizedBox(height: 8),
                                _buildInfoRow("🌍 Domain Panel", currentDomainPanel),
                                const SizedBox(height: 8),
                                _buildInfoRow("🪽 Domain Node", currentDomainNode),
                                const SizedBox(height: 8),
                                _buildInfoRow("💾 RAM", "$currentRam MB"),
                                const SizedBox(height: 8),
                                _buildInfoRow("📧 Email", currentEmail),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.logout, size: 18),
                                    label: const Text("LOGOUT VPS"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: dangerRed.withOpacity(0.2),
                                      foregroundColor: dangerRed,
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
                          _buildTextField(label: "USERNAME", controller: vpsUsernameController, icon: FontAwesomeIcons.user, hint: "root", suffixText: "Default: root"),
                          _buildTextField(label: "PASSWORD", controller: vpsPasswordController, icon: FontAwesomeIcons.key, hint: "Password root VPS", obscureText: true),
                          _buildTextField(label: "PORT", controller: vpsPortController, icon: FontAwesomeIcons.plug, type: TextInputType.number, hint: "22", suffixText: "Default: 22"),
                          _buildTextField(label: "DOMAIN PANEL", controller: domainPanelController, icon: FontAwesomeIcons.globe, hint: "panel.domain.com"),
                          _buildTextField(label: "DOMAIN NODE", controller: domainNodeController, icon: FontAwesomeIcons.server, hint: "node.domain.com"),
                          _buildTextField(label: "RAM VPS (MB)", controller: ramVpsController, icon: FontAwesomeIcons.memory, type: TextInputType.number, hint: "2048", suffixText: "MB"),
                          _buildTextField(label: "EMAIL ADMIN", controller: emailController, icon: FontAwesomeIcons.envelope, hint: "admin@domain.com", type: TextInputType.emailAddress),
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

                if (isLoggedInToVps && !isInstalling) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryPurple.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "INSTALLATION SUMMARY",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow("📦 Package", "Pterodactyl Panel + Wings"),
                        const SizedBox(height: 8),
                        _buildInfoRow("🔧 Version", "Panel 1.11.8 | Wings 1.11.8"),
                        const SizedBox(height: 16),
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
                              onPressed: _startInstallation,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_arrow, size: 24),
                                  SizedBox(width: 10),
                                  Text("INSTALL PTERODACTYL", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (isInstalling) _buildTerminal(),

                if (isLoggedInToVps && !isInstalling && _installLogs.isNotEmpty)
                  _buildTerminal(),

                const SizedBox(height: 20),
                if (isLoggedInToVps && !isInstalling)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: warningOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: warningOrange.withOpacity(0.3)),
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
                              Text('Pastikan Anda adalah pemilik VPS sebelum menginstall. Backup data penting terlebih dahulu.', style: TextStyle(color: warningOrange.withOpacity(0.8), fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
