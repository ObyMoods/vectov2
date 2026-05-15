import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class BugSenderPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;

  const BugSenderPage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
  });

  @override
  State<BugSenderPage> createState() => _BugSenderPageState();
}

class _BugSenderPageState extends State<BugSenderPage> {
  List<dynamic> senderList = [];
  bool isLoading = false;
  bool isRefreshing = false;
  String? errorMessage;

  final Color primaryDark = Colors.black;
  final Color primaryWhite = Colors.white;
  final Color accentPurple = Colors.redAccent;
  final Color cardDark = const Color(0xFF1A1A1A);
  final Color successGreen = Colors.greenAccent;
  final Color warningOrange = Colors.orangeAccent;
  final Color errorRed = Colors.redAccent;

  @override
  void initState() {
    super.initState();
    _fetchSenders();
  }

  Future<void> _fetchSenders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse("http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/mySender?key=${widget.sessionKey}"),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["valid"] == true) {
          setState(() {
            senderList = data["connections"] ?? [];
          });
        } else {
          setState(() {
            errorMessage = data["message"] ?? "Failed to fetch senders";
          });
        }
      } else {
        setState(() {
          errorMessage = "Server error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Connection failed: $e";
      });
    } finally {
      setState(() {
        isLoading = false;
        isRefreshing = false;
      });
    }
  }

  Future<void> _refreshSenders() async {
    setState(() => isRefreshing = true);
    await _fetchSenders();
  }

  void _showAddSenderDialog() {
    final phoneController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.add_circle, color: accentPurple),
            const SizedBox(width: 12),
            Text("Add New Sender",
                style: TextStyle(color: primaryWhite, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: primaryWhite),
              decoration: InputDecoration(
                labelText: "Phone Number",
                labelStyle: TextStyle(color: accentPurple),
                hintText: "62xxx",
                hintStyle: TextStyle(color: Colors.white54),
                prefixIcon: Icon(Icons.phone, color: accentPurple),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentPurple),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentPurple),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: TextStyle(color: errorRed)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final number = phoneController.text.trim();
              final name = nameController.text.trim();

              if (number.isEmpty) {
                _showSnackBar("Please enter phone number", isError: true);
                return;
              }

              Navigator.pop(context);
              await _addSender(number, name);
            },
            child: Text("ADD SENDER", style: TextStyle(color: primaryWhite)),
          ),
        ],
      ),
    );
  }

  Future<void> _addSender(String number, String name) async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse("http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/getPairing?key=${widget.sessionKey}&number=$number"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["valid"] == true) {
          _showPairingCodeDialog(number, data['pairingCode'], name);
          _showSnackBar("Pairing code generated successfully!", isError: false);
        } else {
          _showSnackBar(data['message'] ?? "Failed to generate pairing code", isError: true);
        }
      } else {
        _showSnackBar("Server error: ${response.statusCode}", isError: true);
      }
    } catch (e) {
      _showSnackBar("Connection failed: $e", isError: true);
    } finally {
      setState(() => isLoading = false);
      _fetchSenders();
    }
  }

  void _showPairingCodeDialog(String number, String code, String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(Icons.qr_code_2, color: accentPurple, size: 50),
            const SizedBox(height: 10),
            Text("Pairing Required",
                style: TextStyle(color: primaryWhite, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentPurple.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (name.isNotEmpty) ...[
                Text("Name: $name",
                    style: TextStyle(color: primaryWhite, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
              ],
              Text("Number: $number", style: TextStyle(color: primaryWhite)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentPurple),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    color: accentPurple,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    fontFamily: 'Courier',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Open WhatsApp → Settings → Linked Devices → Link a Device\nEnter this code to complete pairing",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CLOSE", style: TextStyle(color: primaryWhite)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentPurple),
            onPressed: () {
              Navigator.pop(context);
              _fetchSenders();
            },
            child: Text("REFRESH LIST", style: TextStyle(color: primaryWhite)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSender(String senderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning, color: warningOrange),
            const SizedBox(width: 12),
            Text("Confirm Delete", style: TextStyle(color: primaryWhite)),
          ],
        ),
        content: Text(
          "Are you sure you want to delete this sender? This action cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("CANCEL", style: TextStyle(color: primaryWhite)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: errorRed),
            onPressed: () => Navigator.pop(context, true),
            child: Text("DELETE", style: TextStyle(color: primaryWhite)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => isLoading = true);

      try {
        // Ganti dengan endpoint delete yang sesuai
        final response = await http.delete(
          Uri.parse("http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/deleteSender?key=${widget.sessionKey}&id=$senderId"),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data["valid"] == true) {
            _showSnackBar("Sender deleted successfully!", isError: false);
            _fetchSenders();
          } else {
            _showSnackBar(data["message"] ?? "Failed to delete sender", isError: true);
          }
        } else {
          _showSnackBar("Server error: ${response.statusCode}", isError: true);
        }
      } catch (e) {
        _showSnackBar("Connection failed: $e", isError: true);
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? errorRed : successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSenderCard(Map<String, dynamic> sender, int index) {
    final name = sender['sessionName'] ?? 'Unnamed';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.phone_android, color: accentPurple),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: primaryWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Status Info
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.refresh, size: 16),
                    label: Text("REFRESH"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentPurple,
                      side: BorderSide(color: accentPurple),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _refreshSenders(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.delete, size: 16),
                    label: Text("DELETE"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: errorRed.withOpacity(0.2),
                      foregroundColor: errorRed,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _deleteSender(sender['id']),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone_iphone, color: accentPurple, size: 80),
          const SizedBox(height: 20),
          Text(
            "No Senders Found",
            style: TextStyle(color: primaryWhite, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            "Add your first WhatsApp sender to get started",
            style: TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text("ADD FIRST SENDER"),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentPurple,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _showAddSenderDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: errorRed, size: 80),
          const SizedBox(height: 20),
          Text(
            "Failed to Load",
            style: TextStyle(color: primaryWhite, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            errorMessage ?? "Unknown error occurred",
            style: TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            icon: Icon(Icons.refresh),
            label: Text("TRY AGAIN"),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentPurple,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            onPressed: _fetchSenders,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        title: Text(
          "Manage Bug Sender",
          style: TextStyle(
            color: primaryWhite,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryWhite),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: accentPurple),
            onPressed: isLoading ? null : _refreshSenders,
          ),
        ],
      ),
      body: isLoading && senderList.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : errorMessage != null && senderList.isEmpty
          ? _buildErrorState()
          : senderList.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        color: accentPurple,
        backgroundColor: cardDark,
        onRefresh: _refreshSenders,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: senderList.length,
          itemBuilder: (context, index) => _buildSenderCard(
            Map<String, dynamic>.from(senderList[index]),
            index,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accentPurple,
        onPressed: _showAddSenderDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
