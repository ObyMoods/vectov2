import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../manager/change_password_page.dart';

class MyInfoPage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final String coins;
  
  const MyInfoPage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.sessionKey,
    required this.coins,
  });

  @override
  State<MyInfoPage> createState() => _MyInfoPageState();
}

class _MyInfoPageState extends State<MyInfoPage> {
  final Color primaryDark = const Color(0xFF000000);
  final Color cardDark = const Color(0xFF1A1A1A);
  final Color cardDarker = const Color(0xFF0D0D0D);
  final Color accentColor = const Color(0xFF2D2D2D);
  static const Color goldColor = Color(0xFFFFD700);
  final Color blueColor = const Color(0xFF4A9EFF);
  final String baseUrl = "http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323";

  File? _profileImage;
  bool showUsername = false;
  bool showPassword = false;
  bool showSessionKey = false;
  
  String _userBio = "";
  String _userName = "";
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get-user-profile?username=${widget.username}"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _userBio = data['user']['bio'] ?? "Halo! Saya pengguna Vecto";
            _userName = data['user']['name'] ?? widget.username;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateBio(String newBio) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/update-bio"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'username': widget.username,
          'bio': newBio,
        }),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _userBio = newBio;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bio berhasil diperbarui"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal update bio: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _updateName(String newName) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/update-name"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'username': widget.username,
          'name': newName,
        }),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _userName = newName;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nama berhasil diperbarui"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal update nama: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image != null) {
      setState(() => _isLoading = true);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_${widget.username}', image.path);
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/update-profile-picture"),
      );
      request.fields['username'] = widget.username;
      request.files.add(await http.MultipartFile.fromPath('avatar', image.path));
      await request.send();

      setState(() {
        _profileImage = File(image.path);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_${widget.username}');

    if (path != null && File(path).existsSync()) {
      setState(() {
        _profileImage = File(path);
      });
    }
  }

  void _showEditBioDialog() {
    final TextEditingController bioController = TextEditingController(text: _userBio);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Edit Bio", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: bioController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "Tulis bio Anda...",
            hintStyle: const TextStyle(color: Colors.white54),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4A9EFF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4A9EFF)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (bioController.text.trim().isNotEmpty) {
                _updateBio(bioController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: blueColor),
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog() {
    final TextEditingController nameController = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Edit Nama", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Masukkan nama Anda",
            hintStyle: const TextStyle(color: Colors.white54),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4A9EFF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4A9EFF)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (nameController.text.trim().isNotEmpty) {
                _updateName(nameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: blueColor),
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  String _mask(String text, {int show = 2}) {
    if (text.length <= show) return "*" * text.length;
    return text.substring(0, show) + "•" * (text.length - show);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        backgroundColor: primaryDark,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          "My Profile",
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A9EFF)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              accentColor,
                              accentColor.withOpacity(0.6),
                            ],
                          ),
                        ),
                        child: Hero(
                          tag: 'profile-avatar',
                          child: CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.transparent,
                            backgroundImage:
                                _profileImage != null ? FileImage(_profileImage!) : null,
                            child: _profileImage == null
                                ? const Icon(FontAwesomeIcons.userNinja,
                                    size: 42, color: goldColor)
                                : null,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: blueColor,
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  GestureDetector(
                    onTap: _showEditNameDialog,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.edit, color: blueColor, size: 18),
                      ],
                    ),
                  ),

                  Text(
                    widget.role.toUpperCase(),
                    style: TextStyle(
                      color: blueColor,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 12),

                  GestureDetector(
                    onTap: _showEditBioDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: blueColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: blueColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Bio", style: TextStyle(color: Colors.white54, fontSize: 11)),
                                Text(
                                  _userBio,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  _infoTile(
                    label: "Username",
                    value: showUsername
                        ? widget.username
                        : _mask(widget.username),
                    toggle: () => setState(() => showUsername = !showUsername),
                  ),

                  _infoTile(
                    label: "Password",
                    value: showPassword
                        ? widget.password
                        : "•" * widget.password.length,
                    toggle: () => setState(() => showPassword = !showPassword),
                  ),

                  _staticTile("Role", widget.role.toUpperCase(), Icons.badge),
                  _staticTile("Expired Date", widget.expiredDate, Icons.calendar_today),
                  _staticTile("Balance", "${widget.coins} Coins", FontAwesomeIcons.dollarSign),
                  
                  _infoTile(
                    label: "Session Key",
                    value: showSessionKey
                        ? widget.sessionKey
                        : _mask(widget.sessionKey, show: 6),
                    toggle: () => setState(() => showSessionKey = !showSessionKey),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.lock_reset, color: Colors.white),
                      label: const Text(
                        "CHANGE PASSWORD",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blueColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangePasswordPage(
                              username: widget.username,
                              sessionKey: widget.sessionKey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _staticTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cardDarker,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: goldColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required String label,
    required String value,
    required VoidCallback toggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cardDarker,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              label == "Username" 
                ? Icons.person
                : label == "Password"
                  ? Icons.lock
                  : Icons.vpn_key,
              color: blueColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              value.contains("•")
                  ? Icons.visibility
                  : Icons.visibility_off,
              color: blueColor,
            ),
            onPressed: toggle,
          ),
        ],
      ),
    );
  }
}