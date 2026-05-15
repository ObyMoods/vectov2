import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tools/manage_server.dart';
import 'tools/wifi_internal.dart';
import 'tools/wifi_external.dart';
import 'tools/ddos_panel.dart';
import 'tools/nik_check.dart';
import 'tools/tiktok_page.dart';
import 'tools/instagram_page.dart';
import 'tools/qr_gen.dart';
import 'tools/domain_page.dart';
import 'tools/spam_ngl.dart';
import 'tools/ai.dart';
import 'tools/anime.dart';
import 'build_apk_flutter.dart';
import 'web_to_apk.dart';
import 'tools/yts.dart';
import 'tools/spotify.dart';
import 'tools/tele.dart';
import 'tools/public_chat.dart';
import 'tools/spyware.dart';
import 'tools/protect_panel_page.dart';
import 'tools/install_panel.dart';

class ToolsPage extends StatefulWidget {
  final String username;
  final String sessionKey;
  final String userRole;
  final List<Map<String, dynamic>> listDoos;

  const ToolsPage({
    super.key,
    required this.username,
    required this.sessionKey,
    required this.userRole,
    required this.listDoos,
  });

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> with TickerProviderStateMixin {
  late AnimationController _cardController;
  late Animation<double> _cardAnimation;
  late AnimationController _bgController;
  
  String searchQuery = '';

  final Color primaryDark = const Color(0xFF000000);
  final Color primaryRed = const Color(0xFFB71C1C);
  final Color accentRed = const Color(0xFFFF1744);
  final Color primaryWhite = Colors.white;
  final Color cardDark = const Color(0xFF1A1A1A);
  final Color borderGrey = const Color(0xFF2A2A2A);

  @override
  void initState() {
    super.initState();
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _cardAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
    );

    _cardController.forward();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _cardController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgController,
              builder: (context, child) {
                final t = _bgController.value;
                final colorA = Color.lerp(
                  const Color(0xFF0F0C29),
                  const Color(0xFF021B79),
                  t,
                )!;
                final colorB = Color.lerp(
                  const Color(0xFF021B79),
                  const Color(0xFF004D7A),
                  1 - t,
                )!;
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colorA, colorB],
                    ),
                  ),
                  child: Stack(children: _buildBackgroundShapes()),
                );
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 22),
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search tools...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        searchQuery = val.toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildToolsGrid(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(6),
            color: Colors.white10,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white12,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back,',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                widget.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [accentRed, primaryRed]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.star, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                widget.userRole.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolsGrid() {
    final List<Map<String, dynamic>> tools = [
      {
        "icon": Icons.visibility,
        "title": "Spyware Manager",
        "subtitle": "Monitor & control connected devices",
        "badge": "VIP",
        "onTap": () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SpywarePage(
              username: widget.username,
              sessionKey: widget.sessionKey,
              userRole: widget.userRole,
            ),
          ),
        ),
      },
      {
        "icon": Icons.forum,
        "title": "Public Chat",
        "subtitle": "Global real-time lounge",
        "onTap": () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PublicChatPage(
              username: widget.username,
            ),
          ),
        ),
      },
      {
        "icon": Icons.report,
        "title": "Telegram Report",
        "subtitle": "Mass report Telegram account",
        "onTap": () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TelegramSpamPage(
              sessionKey: widget.sessionKey,
            ),
          ),
        ),
      },
      {
        "icon": Icons.chat_bubble_outline,
        "title": "Chat AI",
        "subtitle": "AI-Copilot conversation assistant",
        "onTap": () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AIPage(
              username: widget.username,
              sessionKey: widget.sessionKey,
            ),
          ),
        ),
      },
      {
        "icon": Icons.music_note,
        "title": "Spotify Play",
        "subtitle": "Cari & putar lagu dari Spotify",
        "onTap": () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SpotifyPage()),
        ),
      },
      {
        "icon": Icons.badge_outlined,
        "title": "NIK Check",
        "subtitle": "Validate Indonesian identity numbers",
        "onTap": () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NikCheckerPage()),
        ),
      },
      {
        "icon": Icons.public,
        "title": "Subdomain Finder",
        "subtitle": "Discover subdomains of any domain",
        "onTap": () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DomainOsintPage()),
        ),
      },
      {
        "icon": Icons.movie_outlined,
        "title": "Anime",
        "subtitle": "Tempat Nya Para Wibu Marathon Anime",
        "onTap": () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HomeAnimePage()),
        ),
      },
      {
        "icon": Icons.music_note,
        "title": "YouTube Music",
        "subtitle": "Search Music From YouTube",
        "onTap": () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const YouTubeS()),
        ),
      },
      {
        "icon": Icons.flash_on,
        "title": "DDoS Tools",
        "subtitle": "Network attack tools",
        "onTap": () => _showDDoSTools(context),
      },
      {
        "icon": Icons.wifi,
        "title": "Network Tools",
        "subtitle": "WiFi & Network utilities",
        "onTap": () => _showNetworkTools(context),
      },
      {
        "icon": Icons.download,
        "title": "Media Downloader",
        "subtitle": "Download from social media",
        "onTap": () => _showDownloaderTools(context),
      },
      {
        "icon": Icons.qr_code,
        "title": "QR Generator",
        "subtitle": "Create QR codes",
        "onTap": () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QrGeneratorPage()),
        ),
      },
      {
        "icon": Icons.shield,
        "title": "Pterodactyl",
        "subtitle": "Install Panel && Protect Panel",
        "badge": "VIP",
        "onTap": () => _showToolsPanel(context),
      },
      {
        "icon": Icons.android,
        "title": "Builder Tools",
        "subtitle": "Builder APK Flutter & WebToApk",
        "badge": "VIP",
        "onTap": () => _showBuilderTools(context),
      },
    ];
    
    final filteredTools = tools.where((tool) {
      return tool["title"].toLowerCase().contains(searchQuery);
    }).toList();

    return AnimatedBuilder(
      animation: _cardAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _cardAnimation.value,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredTools.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (context, index) {
              return _buildToolCard(filteredTools[index], index);
            },
          ),
        );
      },
    );
  }

  Widget _buildToolCard(Map<String, dynamic> tool, int index) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset((1 - value) * 30, 0),
          child: Opacity(
            opacity: value,
            child: AnimatedScale(
              scale: value,
              duration: const Duration(milliseconds: 300),
              child: Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Colors.white10, Colors.white12],
                      ),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          tool["onTap"]();
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFEE4266), Color(0xFF9B1B6A)],
                                  ),
                                ),
                                child: Icon(tool["icon"], color: Colors.white),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                tool["title"],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tool["subtitle"],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (tool["badge"] != null)
                    Positioned(
                      right: 10,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          tool["badge"],
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildBackgroundShapes() {
    return [
      Positioned(
        left: -80,
        top: -40,
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Colors.white24.withOpacity(0.06), Colors.transparent],
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: const SizedBox(),
          ),
        ),
      ),
      Positioned(
        right: -60,
        bottom: -60,
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Colors.pinkAccent.withOpacity(0.08), Colors.transparent],
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: const SizedBox(),
          ),
        ),
      ),
      Positioned(
        left: 20,
        bottom: 60,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: Colors.white10,
          ),
        ),
      ),
    ];
  }

  void _showDDoSTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          _buildModalSheet(context, "DDoS Tools", Icons.flash_on, [
            _buildModalOption(
              icon: Icons.flash_on,
              label: "Attack Panel",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AttackPanel(
                      sessionKey: widget.sessionKey,
                      listDoos: widget.listDoos,
                    ),
                  ),
                );
              },
            ),
            _buildModalOption(
              icon: Icons.dns,
              label: "Manage Server",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ManageServerPage(keyToken: widget.sessionKey),
                  ),
                );
              },
            ),
          ]),
    );
  }

  void _showNetworkTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          _buildModalSheet(context, "Network Tools", Icons.wifi, [
            _buildModalOption(
              icon: Icons.newspaper_outlined,
              label: "Spam NGL",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NglPage()),
                );
              },
            ),
            _buildModalOption(
              icon: Icons.wifi_off,
              label: "WiFi Killer (Internal)",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WifiKillerPage()),
                );
              },
            ),
            if (widget.userRole == "vip" || widget.userRole == "owner")
              _buildModalOption(
                icon: Icons.router,
                label: "WiFi Killer (External)",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          WifiInternalPage(sessionKey: widget.sessionKey),
                    ),
                  );
                },
              ),
          ]),
    );
  }
  
  void _showBuilderTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildModalSheet(
        context, 
        "Builder Tools", 
        Icons.build_circle_outlined, 
        [
          _buildModalOption(
            icon: Icons.rocket_launch,
            label: "Build APK Flutter",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BuildApkFlutter(
                    sessionKey: widget.sessionKey,
                    username: widget.username,
                    role: widget.userRole,
                  ),
                ),
              );
            },
          ),
          _buildModalOption(
            icon: Icons.web,
            label: "Web To APK",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WebToApk(
                    sessionKey: widget.sessionKey,
                    username: widget.username,
                    role: widget.userRole,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  void _showToolsPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildModalSheet(
        context, 
        "Pterodactyl", 
        Icons.build_circle_outlined, 
        [
          _buildModalOption(
            icon: Icons.rocket_launch,
            label: "Install Panel",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PterodactylInstallerPage(
                    sessionKey: widget.sessionKey,
                    username: widget.username,
                    role: widget.userRole,
                  ),
                ),
              );
            },
          ),
          _buildModalOption(
            icon: Icons.shield,
            label: "Protect Panel",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                   builder: (context) => ProtectPanelPage(
                   sessionKey: widget.sessionKey,
                   username: widget.username,
                   role: widget.userRole,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDownloaderTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          _buildModalSheet(context, "Media Downloader", Icons.download, [
            _buildModalOption(
              icon: Icons.video_library,
              label: "TikTok Downloader",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TiktokDownloaderPage(),
                  ),
                );
              },
            ),
            _buildModalOption(
              icon: Icons.camera_alt,
              label: "Instagram Downloader",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InstagramDownloaderPage(),
                  ),
                );
              },
            ),
          ]),
    );
  }

  Widget _buildModalSheet(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> options,
  ) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        border: Border.all(color: borderGrey),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderGrey)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primaryRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentRed, size: 22),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: primaryWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(children: options),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: primaryDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderGrey),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primaryRed.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accentRed, size: 20),
        ),
        title: Text(
          label,
          style: TextStyle(color: primaryWhite, fontWeight: FontWeight.w500),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey.shade600,
          size: 16,
        ),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
      ),
    );
  }
}