import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';

class AdminPage extends StatefulWidget {
  final String sessionKey;
  final String currentUserRole;

  const AdminPage({
    super.key,
    required this.sessionKey,
    required this.currentUserRole,
  });

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late String sessionKey;
  late String currentUserRole;
  List<dynamic> fullUserList = [];
  List<dynamic> filteredList = [];
  final List<String> roleOptions = ['admin', 'owner', 'reseller', 'member'];
  String selectedRole = 'member';
  int currentPage = 1;
  int itemsPerPage = 25;

  final deleteController = TextEditingController();
  final createUsernameController = TextEditingController();
  final createPasswordController = TextEditingController();
  final createDayController = TextEditingController();
  String newUserRole = 'member';
  bool isLoading = false;

  final Color primaryDark = const Color(0xFF000000);
  final Color cardDark = const Color(0xFF1A1A1A);
  final Color cardDarker = const Color(0xFF0D0D0D);
  final Color accentColor = const Color(0xFF2D2D2D);
  final Color goldColor = const Color(0xFFFFD700);
  final Color blueColor = const Color(0xFF4A9EFF);

  @override
  void initState() {
    super.initState();
    sessionKey = widget.sessionKey;
    currentUserRole = widget.currentUserRole;
    _fetchUsers();
  }

  bool _canCreateRole(String role) {
    if (currentUserRole == 'reseller') {
      return !['reseller', 'admin', 'owner'].contains(role);
    } else if (currentUserRole == 'admin') {
      return !['admin', 'owner'].contains(role);
    } else if (currentUserRole == 'owner') {
      return role != 'owner';
    }
    return true;
  }

  bool _canDeleteRole(String role) {
    if (currentUserRole == 'reseller') {
      return !['reseller', 'admin', 'owner'].contains(role);
    } else if (currentUserRole == 'admin') {
      return !['admin', 'owner'].contains(role);
    } else if (currentUserRole == 'owner') {
      return role != 'owner';
    }
    return true;
  }

  Future<void> _fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/listUsers?key=$sessionKey'),
      );
      final data = jsonDecode(res.body);
      if (data['valid'] == true && data['authorized'] == true) {
        fullUserList = data['users'] ?? [];
        _filterAndPaginate();
      } else {
        _showDialog("⚠️ Error", data['message'] ?? 'Tidak diizinkan melihat daftar user.');
      }
    } catch (_) {
      _showDialog("🌐 Error", "Gagal memuat user list.");
    }
    setState(() => isLoading = false);
  }

  void _filterAndPaginate() {
    setState(() {
      currentPage = 1;
      filteredList = fullUserList.where((u) => u['role'] == selectedRole).toList();
    });
  }

  List<dynamic> _getCurrentPageData() {
    final start = (currentPage - 1) * itemsPerPage;
    final end = (start + itemsPerPage);
    return filteredList.sublist(start, end > filteredList.length ? filteredList.length : end);
  }

  int get totalPages => (filteredList.length / itemsPerPage).ceil();

  Future<void> _deleteUser() async {
    final username = deleteController.text.trim();
    if (username.isEmpty) {
      _showDialog("⚠️ Error", "Masukkan username yang ingin dihapus.");
      return;
    }

    final targetUser = fullUserList.firstWhere((u) => u['username'] == username, orElse: () => {});
    if (targetUser.isNotEmpty) {
      final targetRole = targetUser['role'];
      if (!_canDeleteRole(targetRole)) {
        _showDialog("❌ Ditolak", "Anda tidak memiliki izin untuk menghapus user dengan role $targetRole.");
        return;
      }
    }

    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/deleteUser?key=$sessionKey&username=$username'),
      );
      final data = jsonDecode(res.body);
      if (data['deleted'] == true) {
        _showDialog("✅ Berhasil", "User '${data['user']['username']}' telah dihapus.");
        deleteController.clear();
        _fetchUsers();
      } else {
        _showDialog("❌ Gagal", data['message'] ?? 'Gagal menghapus user.');
      }
    } catch (_) {
      _showDialog("🌐 Error", "Tidak dapat menghubungi server.");
    }
    setState(() => isLoading = false);
  }

  Future<void> _createAccount() async {
    final username = createUsernameController.text.trim();
    final password = createPasswordController.text.trim();
    final day = createDayController.text.trim();

    if (username.isEmpty || password.isEmpty || day.isEmpty) {
      _showDialog("⚠️ Error", "Semua field wajib diisi.");
      return;
    }

    if (!_canCreateRole(newUserRole)) {
      _showDialog("❌ Ditolak", "Anda tidak memiliki izin untuk membuat user dengan role $newUserRole.");
      return;
    }

    setState(() => isLoading = true);
    try {
      final url = Uri.parse(
        'http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/userAdd?key=$sessionKey&username=$username&password=$password&day=$day&role=$newUserRole',
      );
      final res = await http.get(url);
      final data = jsonDecode(res.body);

      if (data['created'] == true) {
        _showDialog("✅ Sukses", "Akun '${data['user']['username']}' berhasil dibuat.");
        createUsernameController.clear();
        createPasswordController.clear();
        createDayController.clear();
        newUserRole = 'member';
        _fetchUsers();
      } else {
        _showDialog("❌ Gagal", data['message'] ?? 'Gagal membuat akun.');
      }
    } catch (_) {
      _showDialog("🌐 Error", "Gagal menghubungi server.");
    }
    setState(() => isLoading = false);
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AlertDialog(
          backgroundColor: cardDarker,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: goldColor.withOpacity(0.3), width: 1.5),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: goldColor,
            ),
          ),
          content: Text(message, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK", style: TextStyle(color: goldColor)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 25,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildUserItem(Map user) {
    final canDelete = _canDeleteRole(user['role']);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: cardDarker,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor,
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: goldColor.withOpacity(0.4)),
          ),
          child: Icon(Icons.person, color: goldColor, size: 20),
        ),
        title: Text(
          user['username'],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "Role: ${user['role']} | Exp: ${user['expiredDate']}",
              style: TextStyle(color: blueColor, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              "Parent: ${user['parent'] ?? 'SYSTEM'}",
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
        trailing: canDelete ? Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.withOpacity(0.4)),
          ),
          child: IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: AlertDialog(
                    backgroundColor: cardDarker,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: Colors.red.withOpacity(0.3), width: 1.5),
                    ),
                    title: const Text(
                      "Konfirmasi",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    content: Text(
                      "Yakin ingin menghapus user '${user['username']}'?",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text("Batal", style: TextStyle(color: goldColor)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Hapus", style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                ),
              );

              if (confirm == true) {
                deleteController.text = user['username'];
                _deleteUser();
              }
            },
          ),
        ) : Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withOpacity(0.4)),
          ),
          child: IconButton(
            icon: const Icon(Icons.block, color: Colors.grey, size: 20),
            onPressed: null,
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Wrap(
      spacing: 8,
      children: List.generate(totalPages, (index) {
        final page = index + 1;
        return Container(
          decoration: BoxDecoration(
            color: currentPage == page
                ? goldColor.withOpacity(0.8)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: currentPage == page ? goldColor : Colors.white.withOpacity(0.3),
            ),
          ),
          child: ElevatedButton(
            onPressed: () => setState(() => currentPage = page),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "$page",
              style: TextStyle(
                color: currentPage == page ? Colors.black : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRoleOptions = roleOptions.where(_canCreateRole).toList();
    
    return Scaffold(
      backgroundColor: primaryDark,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    goldColor.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    blueColor.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildGlassCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.admin_panel_settings, color: goldColor, size: 32),
                          const SizedBox(width: 12),
                          Text(
                            "ADMIN PANEL",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: goldColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: cardDarker,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: goldColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              currentUserRole.toUpperCase(),
                              style: TextStyle(
                                color: blueColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.delete, color: goldColor),
                              const SizedBox(width: 8),
                              Text(
                                "DELETE USER",
                                style: TextStyle(
                                  color: goldColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildGlassInputField(
                            controller: deleteController,
                            label: "Username untuk dihapus",
                            icon: Icons.person,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [Colors.red.withOpacity(0.8), Colors.redAccent.withOpacity(0.8)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _deleteUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.delete, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "DELETE USER",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person_add, color: goldColor),
                              const SizedBox(width: 8),
                              Text(
                                "CREATE ACCOUNT",
                                style: TextStyle(
                                  color: goldColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          _buildGlassInputField(
                            controller: createUsernameController,
                            label: "Username",
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 12),

                          _buildGlassInputField(
                            controller: createPasswordController,
                            label: "Password",
                            icon: Icons.lock_outline,
                          ),
                          const SizedBox(height: 12),

                          _buildGlassInputField(
                            controller: createDayController,
                            label: "Durasi (hari)",
                            icon: Icons.calendar_today,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),

                          _buildGlassDropdown(
                            value: newUserRole,
                            items: filteredRoleOptions,
                            onChanged: (val) => setState(() => newUserRole = val ?? 'member'),
                            label: "Role",
                          ),
                          const SizedBox(height: 16),

                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [goldColor.withOpacity(0.8), Colors.amber.withOpacity(0.8)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: goldColor.withOpacity(0.3),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _createAccount,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_add, color: Colors.black, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "CREATE ACCOUNT",
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.people, color: goldColor),
                              const SizedBox(width: 8),
                              Text(
                                "USER MANAGEMENT",
                                style: TextStyle(
                                  color: goldColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          _buildGlassDropdown(
                            value: selectedRole,
                            items: roleOptions,
                            onChanged: (val) {
                              if (val != null) {
                                selectedRole = val;
                                _filterAndPaginate();
                              }
                            },
                            label: "Filter Role",
                          ),

                          const SizedBox(height: 20),

                          isLoading
                              ? Center(
                            child: CircularProgressIndicator(color: goldColor),
                          )
                              : Column(
                            children: [
                              ..._getCurrentPageData().map((u) => _buildUserItem(u)).toList(),
                              const SizedBox(height: 20),
                              _buildPagination(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cardDarker,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        cursorColor: goldColor,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: goldColor),
          filled: false,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: accentColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: goldColor, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: accentColor),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildGlassDropdown({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cardDarker,
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: cardDarker,
        icon: Icon(Icons.arrow_drop_down, color: goldColor),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(Icons.people_alt, color: goldColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: accentColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: goldColor, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: accentColor),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: items.map((role) {
          return DropdownMenuItem(
            value: role,
            child: Text(
              role.toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}