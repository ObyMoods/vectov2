import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:core';

class HomePage extends StatefulWidget {
  final String username;
  final String password;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final String role;
  final String expiredDate;
  final String initialCoins;

  const HomePage({
    super.key,
    required this.username,
    required this.password,
    required this.sessionKey,
    required this.listBug,
    required this.role,
    required this.expiredDate,
    required this.initialCoins,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final targetController = TextEditingController();
  final groupLinkController = TextEditingController();
  String selectedBugId = "";
  bool _isSending = false;
  String? _responseMessage;
  int selectedBugIndex = 0;
  int userCoins = 0;
  final int coinCostPerBug = 25;
  final int coinCostPerGroupBug = 50;
  bool _isRefreshing = false;
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  bool _isGroupMode = false;
  bool _isPublicSender = true;
  bool _showSenderTypeDialog = true;
  final Color primaryDark = const Color(0xFF000000);
  final Color cardDark = const Color(0xFF1A1A1A);
  final Color cardDarker = const Color(0xFF0D0D0D);
  final Color goldColor = const Color(0xFFFFD700);
  final Color blueColor = const Color(0xFF4A9EFF);
  
  late AnimationController _controller;
  late AnimationController _fadeController;
  late Animation<double> _animation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
     userCoins = int.tryParse(widget.initialCoins) ?? 0;
    _refreshCoinsFromServer();

    if (widget.listBug.isNotEmpty) {
      selectedBugId = widget.listBug[0]['bug_id'];
    }

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _controller.forward();
    _fadeController.forward();

    _initializeVideoPlayer();
  }
  
@override
void didChangeDependencies() {
  super.didChangeDependencies();

  final route = ModalRoute.of(context);
  if (route != null && route.isCurrent) {
    // Hanya reset kalau page ini benar-benar jadi aktif lagi
    if (!_showSenderTypeDialog) {
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _showSenderTypeDialog = true;
          });
        }
      });
    }
  }
}

  void _initializeVideoPlayer() {
    _videoController = VideoPlayerController.asset(
      'assets/videos/banner.mp4',
    );

    _videoController.initialize().then((_) {
      setState(() {
        _videoController.setVolume(0);
        _videoController.setLooping(true);
        _videoController.play();
        _isVideoInitialized = true;
      });
    }).catchError((error) {
      print("Video initialization error: $error");
      setState(() {
        _isVideoInitialized = false;
      });
    });
  }

  Future<void> _refreshCoinsFromServer() async {
  if (_isRefreshing) return;

  setState(() {
    _isRefreshing = true;
  });

  try {
    final response = await http.get(
      Uri.parse(
        "http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/refreshCoins?"
        "key=${widget.sessionKey}"
      ),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Timeout');
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['valid'] == true) {
        final dynamic coinsData = data['coins'];
        int newCoins = 0;

        if (coinsData is int) {
          newCoins = coinsData;
        } else if (coinsData is String) {
          newCoins = int.tryParse(coinsData) ?? 0;
        } else if (coinsData is double) {
          newCoins = coinsData.toInt();
        }

        if (newCoins != userCoins) {
          setState(() {
            userCoins = newCoins;
          });
        }
      }
    }
  } catch (e) {
    print('❌ Error refreshing coins: $e');
  } finally {
    if (!mounted) return;
    setState(() {
      _isRefreshing = false;
    });
  }
}

  @override
  void dispose() {
    targetController.dispose();
    groupLinkController.dispose();
    _videoController.dispose();
    _controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String? formatPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleaned.startsWith('+') || cleaned.length < 8) return null;
    return cleaned;
  }

  Future<void> _sendBug() async {
    if (_isGroupMode) {
      await _attackGroup();
    } else {
      await _sendContactBug();
    }
  }

  Future<void> _sendContactBug() async {
    final rawInput = targetController.text.trim();
    final target = formatPhoneNumber(rawInput);
    final key = widget.sessionKey;

    if (target == null || key.isEmpty) {
      _showAlert("❌ Invalid Number",
          "Gunakan nomor internasional (misal: +62, 1, 44), bukan 08xxx.");
      return;
    }

    if (_isPublicSender && userCoins < coinCostPerBug) {
      _showAlert("💰 Coin Tidak Cukup",
          "Anda membutuhkan $coinCostPerBug coin untuk mengirim bug.\nSaldo Anda saat ini: $userCoins coin.");
      return;
    }

    setState(() {
      _isSending = true;
      _responseMessage = null;
    });

    try {
      final endpoint = _isPublicSender ? "sendBugP" : "sendBug";
      final res = await http
    .get(
      Uri.parse(
        "http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/$endpoint?key=$key&target=$target&bug=$selectedBugId",
      ),
    )
    .timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        throw Exception("Request timeout");
      },
    );
      final data = jsonDecode(res.body);

       if (data["cooldown"] == true) {
  _showAlert(
    "⏳ Cooldown",
    "Tunggu beberapa saat sebelum mengirim bug lagi.",
  );
  setState(() {
    _isSending = false;
  });
  return;
} else if (data["valid"] == false) {
        setState(() => _responseMessage = "❌ Key Invalid: Silakan login ulang.");
      } else if (data['sender'] == false) {
  if (_isPublicSender) {
    _showAlert("❌ Failed", "Sender publik sendang kosong");
  } else {
    _showAlert("❌ Failed", "kamu tidak memiliki sender pribadi!\nsilahkan add sender terlebih dahulu");
  }
  setState(() {
    _isSending = false;
  });
  return;
} else if (data["sended"] == false) {
        setState(() => _responseMessage = "⚠️ Gagal: Server sedang maintenance.");
      } else {
        if (_isPublicSender) {
          setState(() {
            userCoins -= coinCostPerBug;
          });
          _showAlert("✅ Success", "Berhasil mengirim bug ke $target!\n💰 -$coinCostPerBug coin (Sisa: $userCoins coin)");
        } else {
          _showAlert("✅ Success", "Berhasil mengirim bug ke $target!\n⚡ Menggunakan sender pribadi");
        }
        
        targetController.clear();
        
        if (_isPublicSender) {
          Future.delayed(const Duration(seconds: 2), () {
            _refreshCoinsFromServer();
          });
        }
      }
    } catch (_) {
      setState(() => _responseMessage = "❌ Error: Terjadi kesalahan. Coba lagi.");
    } finally {
  if (!mounted) return;
  setState(() {
    _isSending = false;
  });
}
}

  Future<void> _attackGroup() async {
    final groupLink = groupLinkController.text.trim();
    final key = widget.sessionKey;
    
    if (groupLink.isEmpty || !groupLink.contains('chat.whatsapp.com')) {
      _showAlert("❌ Invalid Link", "Please enter a valid WhatsApp group link.");
      return;
    }

    if (_isPublicSender && userCoins < coinCostPerGroupBug) {
      _showAlert("💰 Insufficient Coins", "You need $coinCostPerGroupBug coins to attack a group.");
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final endpoint = _isPublicSender ? "raidGroupP" : "raidGroup";
      final response = await http.get(
        Uri.parse(
          "http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/$endpoint?key=$key&link=$groupLink"
        ),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["cooldown"] == true) {
  _showAlert(
    "⏳ Cooldown",
    "Tunggu beberapa saat sebelum mengirim bug lagi.",
  );
  setState(() {
    _isSending = false;
  });
  return;
}
        if (data['valid'] == false) {
  _showAlert("❌ Failed", "Invalid session key. Please login again.");
  setState(() {
    _isSending = false;
  });
  return;
}
        
        if (data['sender'] == false) {
  if (_isPublicSender) {
    _showAlert("❌ Failed", "Sender publik sendang kosong");
  } else {
    _showAlert("❌ Failed", "kamu tidak memiliki sender pribadi!\nsilahkan add sender terlebih dahulu");
  }
  setState(() {
    _isSending = false;
  });
  return;
}
        
        if (data['sended'] == true) {
          if (_isPublicSender) {
            setState(() {
              userCoins -= coinCostPerGroupBug;
            });
            _showAlert("✅ Success", "Successfully sent bug to group!\n💰 -$coinCostPerGroupBug coins (Remaining: $userCoins coins)");
          } else {
            _showAlert("✅ Success", "Successfully sent bug to group!\n⚡ Using private sender");
          }
          
          groupLinkController.clear();
          
          if (_isPublicSender) {
            Future.delayed(const Duration(seconds: 2), () {
              _refreshCoinsFromServer();
            });
          }
        } else {
          _showAlert("❌ Failed", "Failed to send bug to group. Please try again.");
        }
      } else {
        _showAlert("❌ Server Error", "Failed to connect to server. Please try again.");
      }
    } catch (e) {
      print('❌ Group bug error: $e');
      _showAlert("❌ Error", "An error occurred. Please check your connection and try again.");
    } finally {
  if (!mounted) return;
  setState(() {
    _isSending = false;
  });
  }
}

  void _showAlert(String title, String msg) {
  if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cardDark.withOpacity(0.95),
                      cardDarker.withOpacity(0.98),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: title.contains('✅')
                              ? [
                                  Colors.green.withOpacity(0.3),
                                  const Color(0xFF00FF88).withOpacity(0.3),
                                ]
                              : title.contains('❌')
                                  ? [
                                      const Color(0xFFDC143C).withOpacity(0.3),
                                      const Color(0xFFFF416C).withOpacity(0.3),
                                    ]
                                  : title.contains('💰')
                                      ? [
                                          goldColor.withOpacity(0.3),
                                          const Color(0xFFFFD166).withOpacity(0.3),
                                        ]
                                      : [
                                          blueColor.withOpacity(0.3),
                                          const Color(0xFF4A9EFF).withOpacity(0.3),
                                        ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(
                        title.contains('✅')
                            ? Icons.check_circle
                            : title.contains('❌')
                                ? Icons.error
                                : title.contains('💰')
                                    ? Icons.monetization_on
                                    : Icons.info,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        msg,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 15,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: title.contains('✅')
                              ? const Color(0xFF00FF88).withOpacity(0.2)
                              : title.contains('❌')
                                  ? const Color(0xFFDC143C).withOpacity(0.2)
                                  : blueColor.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: title.contains('✅')
                                  ? const Color(0xFF00FF88).withOpacity(0.5)
                                  : title.contains('❌')
                                      ? const Color(0xFFDC143C).withOpacity(0.5)
                                      : blueColor.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          "GOT IT",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (title.contains('✅') && msg.contains('coin'))
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              color: goldColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Balance: $userCoins coins",
                              style: TextStyle(
                                color: goldColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return _buildGlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: Color(0xFF2A2A2A),
                  child: Icon(Icons.person, color: Colors.white60, size: 32),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                    ),
                    child: const Icon(Icons.verified, color: Color(0xFFDC143C), size: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.role.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Text(
              "EXP: ${widget.expiredDate}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVideoBanner() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      )),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        width: double.infinity,
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_isVideoInitialized)
                SizedBox(
                  width: double.infinity,
                  height: 280,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController.value.size.width,
                      height: _videoController.value.size.height,
                      child: VideoPlayer(_videoController),
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 280,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cardDarker.withOpacity(0.8),
                        cardDark.withOpacity(0.8)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow, color: goldColor, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          "Loading Video...",
                          style: TextStyle(color: goldColor),
                        ),
                      ],
                    ),
                  ),
                ),
              Container(
                width: double.infinity,
                height: 280,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeTransition(
                        opacity: Tween(begin: 0.6, end: 1.0)
                            .animate(_fadeController),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                cardDark.withOpacity(0.4),
                                primaryDark.withOpacity(0.4)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryDark.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const CircleAvatar(
                            radius: 40,
                            backgroundImage:
                                AssetImage('assets/images/logo.jpg'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [goldColor, Colors.white],
                        ).createShader(bounds),
                        child: Text(
                          widget.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: goldColor.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: goldColor.withOpacity(0.6)),
                            ),
                            child: Text(
                              widget.role.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: Colors.white.withOpacity(0.4)),
                            ),
                            child: Text(
                              "Exp: ${widget.expiredDate}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelectorCard() {
    return _buildGlassCard(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isGroupMode = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: !_isGroupMode ? const Color(0xFFDC143C).withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !_isGroupMode ? const Color(0xFFDC143C) : Colors.white.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.person,
                        color: !_isGroupMode ? Colors.white : Colors.white.withOpacity(0.6),
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Contact",
                        style: TextStyle(
                          color: !_isGroupMode ? Colors.white : Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isGroupMode = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: _isGroupMode ? const Color(0xFFDC143C).withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isGroupMode ? const Color(0xFFDC143C) : Colors.white.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.groups,
                        color: _isGroupMode ? Colors.white : Colors.white.withOpacity(0.6),
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Group",
                        style: TextStyle(
                          color: _isGroupMode ? Colors.white : Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetNumberCard() {
    if (_isGroupMode) {
      return _buildGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.link,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  "Group Link",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: groupLinkController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: const Color(0xFFDC143C),
                    decoration: InputDecoration(
                      hintText: "https://chat.whatsapp.com/...",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.link,
                        color: Colors.white.withOpacity(0.4),
                        size: 20,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFDC143C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFDC143C).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFFDC143C).withOpacity(0.8),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "This tool will automatically join the group, send a bug, and leave without any trace.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return _buildGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.phone_android,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  "Target Number",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: targetController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: const Color(0xFFDC143C),
                    decoration: InputDecoration(
                      hintText: "e.g. +62xxxxxxxxxx",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.language,
                        color: Colors.white.withOpacity(0.4),
                        size: 22,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildBugTypeCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  FontAwesomeIcons.whatsapp,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                "Bug Type",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.listBug.length,
              itemBuilder: (context, index) {
                final bug = widget.listBug[index];
                final isSelected = index == selectedBugIndex;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedBugIndex = index;
                      selectedBugId = bug['bug_id'];
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 200,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: isSelected
                          ? primaryDark.withOpacity(0.85)
                          : cardDarker,
                      border: Border.all(
                        color: isSelected
                            ? primaryDark
                            : Colors.white.withOpacity(0.15),
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primaryDark.withOpacity(0.5),
                                blurRadius: 12,
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(FontAwesomeIcons.whatsapp,
                                color: Colors.white, size: 20),
                            const Spacer(),
                            if (isSelected)
                              const Icon(Icons.check_circle,
                                  color: Colors.white, size: 18),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          bug['bug_name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildIndicatorDots(),
        ],
      ),
    );
  }
            
  Widget _buildIndicatorDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.listBug.length, (index) {
        final isActive = index == selectedBugIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? primaryDark : Colors.white24,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  Widget _buildSendButton() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      width: double.infinity,
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendBug,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isSending
                  ? const SizedBox(
                      height: 26,
                      width: 26,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_isGroupMode ? Icons.groups : Icons.send, color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Text(
                          _isGroupMode ? "ATTACK GROUP" : "SEND BUG",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.white.withOpacity(0.4),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isGroupMode 
                    ? "This tool will join the group, send a bug, and leave without any trace." 
                    : "Use responsibly. We are not responsible for misuse.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSenderTypeDialog() {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4A9EFF).withOpacity(0.3),
                          const Color(0xFFDC143C).withOpacity(0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      FontAwesomeIcons.whatsapp,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Select Sender Type",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Choose how you want to send bugs",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isPublicSender = true;
                              _showSenderTypeDialog = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A9EFF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF4A9EFF).withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.public,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  "Public",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "${_isGroupMode ? coinCostPerGroupBug : coinCostPerBug} coins/attack",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4A9EFF)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    "Recommended",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isPublicSender = false;
                              _showSenderTypeDialog = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC143C).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFDC143C).withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.security,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  "Private",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Free",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC143C)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    "Device Online",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.white.withOpacity(0.6),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Public: Uses server resources (costs coins)\nPrivate: Uses your WhatsApp account (free)",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isVideoInitialized)
            Positioned.fill(
              child: Opacity(
                opacity: 0.25,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController.value.size.width,
                    height: _videoController.value.size.height,
                    child: VideoPlayer(_videoController),
                  ),
                ),
              ),
            ),
          
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProfileCard(),
                  _buildVideoBanner(),
                  _buildModeSelectorCard(),
                  _buildTargetNumberCard(),
                  if (!_isGroupMode) _buildBugTypeCard(),
                  _buildSendButton(),
                  _buildDisclaimer(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          
          if (_showSenderTypeDialog)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: _buildSenderTypeDialog(),
              ),
            ),
        ],
      ),
    );
  }
}