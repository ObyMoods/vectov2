import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ThanksToPage extends StatefulWidget {
  const ThanksToPage({Key? key}) : super(key: key);

  @override
  _ThanksToPageState createState() => _ThanksToPageState();
}

class _ThanksToPageState extends State<ThanksToPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> thanksToList = [];
  bool isLoading = true;
  bool hasError = false;
  int currentIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final Color primaryRed = const Color(0xFF8B0000);
  final Color accentRed = const Color(0xFFDC143C);
  final Color cardDarker = const Color(0xFF141414);
  final Color primaryDark = const Color(0xFF0A0A0A);
  final Color cardDark = const Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.8);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    fetchThanksTo();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> fetchThanksTo() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final response = await http.get(Uri.parse('http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/tq'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == true && data['result'] is List) {
          setState(() {
            thanksToList = List<Map<String, dynamic>>.from(data['result']);
            isLoading = false;
          });
          _animationController.forward();
        } else {
          setState(() {
            hasError = true;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          hasError = true;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  Future<void> launchContact(String url) async {
  if (url.isEmpty) return; // jika kosong, langsung return

  Uri uri;

  if (url.startsWith('http')) {
    uri = Uri.parse(url); // sudah lengkap, pakai langsung
  } else if (url.startsWith('t.me/')) {
    uri = Uri.parse('https://$url'); // tambahkan https://
  } else {
    uri = Uri.parse('https://t.me/$url'); // default tambah t.me/
  }

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication); 
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cannot open: ${uri.toString()}'),
        backgroundColor: const Color(0xFFDC143C),
      ),
    );
  }
}

  Widget _buildProfileCard(Map<String, dynamic> person, int index) {
    final bool isCenter = index == currentIndex;
    
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      },
      child: AnimatedBuilder(
        animation: _pageController,
        builder: (context, child) {
          double value = 1.0;
          if (_pageController.position.haveDimensions) {
            value = _pageController.page! - index;
            value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
          }
          
          return Transform.scale(
            scale: isCenter ? 1.0 : 0.9 * value,
            child: Opacity(
              opacity: isCenter ? 1.0 : 0.7,
              child: child,
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: cardDark,
            boxShadow: [
              BoxShadow(
                color: isCenter ? accentRed.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                blurRadius: isCenter ? 25 : 15,
                spreadRadius: isCenter ? 2 : 1,
                offset: const Offset(0, 10),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isCenter 
                ? [cardDark, Color(0xFF1E1E1E)]
                : [Color(0xFF1A1A1A), cardDark],
            ),
            border: Border.all(
              color: isCenter ? accentRed.withOpacity(0.4) : Colors.white.withOpacity(0.1),
              width: isCenter ? 1.5 : 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentRed.withOpacity(isCenter ? 0.8 : 0.4),
                      width: isCenter ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentRed.withOpacity(isCenter ? 0.2 : 0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: person['ppUrl'] != null &&
                            person['ppUrl'].toString().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: person['ppUrl'].toString(),
                            placeholder: (context, url) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primaryRed.withOpacity(0.1), accentRed.withOpacity(0.1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.person,
                                  color: accentRed.withOpacity(0.5),
                                  size: 50,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primaryRed.withOpacity(0.1), accentRed.withOpacity(0.1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.person,
                                  color: accentRed.withOpacity(0.5),
                                  size: 50,
                                ),
                              ),
                            ),
                            fit: BoxFit.cover,
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryRed.withOpacity(0.1), accentRed.withOpacity(0.1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.person,
                                color: accentRed.withOpacity(0.5),
                                size: 50,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  person['name']?.toString() ?? 'Unknown',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCenter ? 22 : 20,
                    fontWeight: isCenter ? FontWeight.bold : FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentRed.withOpacity(0.3)),
                  ),
                  child: Text(
                    person['status']?.toString() ?? 'No Status',
                    style: TextStyle(
                      color: accentRed,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 20),
                if (person['contac'] != null &&
                    person['contac'].toString().isNotEmpty && isCenter)
                  ElevatedButton(
                    onPressed: () => launchContact(person['contac'].toString()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      elevation: 5,
                      shadowColor: accentRed.withOpacity(0.4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(FontAwesomeIcons.telegram, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'Contact on Telegram',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
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

  Widget _buildIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        thanksToList.length,
        (index) {
          return Container(
            width: currentIndex == index ? 20 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: currentIndex == index ? accentRed : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    "Thanks To",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(accentRed),
                            strokeWidth: 2,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Loading Profiles...",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : hasError
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: accentRed.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: accentRed.withOpacity(0.3)),
                                ),
                                child: const Icon(
                                  Icons.error_outline,
                                  color: Color(0xFFDC143C),
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                "Failed to load data",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Please check your connection",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: fetchThanksTo,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentRed,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 14,
                                  ),
                                ),
                                child: Text(
                                  "Retry",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : thanksToList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.group,
                                      color: Colors.white54,
                                      size: 50,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    "No profiles available",
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                Expanded(
                                  child: AnimatedBuilder(
                                    animation: _animationController,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _scaleAnimation.value,
                                        child: child,
                                      );
                                    },
                                    child: PageView.builder(
                                      controller: _pageController,
                                      itemCount: thanksToList.length,
                                      onPageChanged: (index) {
                                        setState(() {
                                          currentIndex = index;
                                        });
                                      },
                                      itemBuilder: (context, index) {
                                        return _buildProfileCard(thanksToList[index], index);
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildIndicator(),
                                const SizedBox(height: 20),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }
}