import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../login_page.dart';

class CoinManagePage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;

  const CoinManagePage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
  });

  @override
  State<CoinManagePage> createState() => _CoinManagePageState();
}

class _CoinManagePageState extends State<CoinManagePage> {
  final Color primaryDark = const Color(0xFF000000);
  final Color cardDark = const Color(0xFF1A1A1A);
  final Color cardDarker = const Color(0xFF0D0D0D);
  final Color accentColor = const Color(0xFF2D2D2D);
  final Color goldColor = const Color(0xFFFFD700);
  final Color blueColor = const Color(0xFF4A9EFF);

  TextEditingController _redeemCodeController = TextEditingController();
  TextEditingController _giftUsernameController = TextEditingController();
  TextEditingController _giftAmountController = TextEditingController();

  int bCoinBalance = 0;
  int lCoinBalance = 0;
  bool isLoadingBalance = false;
  bool isLoadingRedeem = false;
  bool isLoadingGift = false;

  List<Map<String, dynamic>> transactionHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchCoinBalance();
    _loadTransactionHistory();
  }

  Future<void> _fetchCoinBalance() async {
    if (isLoadingBalance) return;

    setState(() => isLoadingBalance = true);

    try {
      final response = await http.get(
        Uri.parse('http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/refreshCoins?key=${widget.sessionKey}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['valid'] == true) {
          setState(() {
            bCoinBalance = data['bCoins'] ?? 0;
            lCoinBalance = data['lCoins'] ?? 0;
            isLoadingBalance = false;
          });
        } else {
          _handleSessionExpired();
        }
      }
    } catch (e) {
      setState(() => isLoadingBalance = false);
      _showNotification('Error', 'Failed to fetch balance', NotificationType.error);
    }
  }

  Future<void> _saveTransactionHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('transaction_history', jsonEncode(transactionHistory));
  }

  Future<void> _loadTransactionHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('transaction_history');
    
    if (historyJson != null) {
      try {
        final List<dynamic> historyList = jsonDecode(historyJson);
        setState(() {
          transactionHistory = historyList.map((item) => Map<String, dynamic>.from(item)).toList();
        });
      } catch (e) {
        print('Error loading transaction history: $e');
      }
    }
  }

  void _addToHistory(Map<String, dynamic> transaction) {
    transaction['timestamp'] = DateTime.now().toIso8601String();
    transactionHistory.insert(0, transaction);
    
    if (transactionHistory.length > 50) {
      transactionHistory = transactionHistory.sublist(0, 50);
    }
    
    _saveTransactionHistory();
    setState(() {});
  }

  Future<void> _redeemCoin() async {
  final code = _redeemCodeController.text.trim().toUpperCase();

  if (code.isEmpty) {
    _showNotification('Invalid Code', 'Please enter a redeem code', NotificationType.error);
    return;
  }

  setState(() => isLoadingRedeem = true);

  try {
    final response = await http.get(
      Uri.parse('http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/redeem?key=${widget.sessionKey}&code=$code'),
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Request timeout'),
    );

    setState(() => isLoadingRedeem = false);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['valid'] == false) {
        _handleSessionExpired();
        return;
      }

      if (data['success'] == true) {
        final amount = data['amount'] ?? 0;
        _redeemCodeController.clear();

        // Tambahkan ke history
        _addToHistory({
          'type': 'redeem',
          'amount': amount,
          'code': code,
          'description': 'Redeemed code: $code',
        });

        await _showSuccessDialog(
          'Redeem Success!',
          'You received $amount coins 🎉',
          Icons.card_giftcard,
          goldColor,
        );

        await _fetchCoinBalance();
      } else {
        final message = data['message'] ?? 'Invalid or already used code';
        _showNotification('Redeem Failed', message, NotificationType.error);
      }
    } else {
      _showNotification('Server Error', 'Failed to connect to server (${response.statusCode})', NotificationType.error);
    }
  } catch (e) {
    setState(() => isLoadingRedeem = false);
    _showNotification('Connection Error', 'Please check your internet connection', NotificationType.error);
  }
}

  Future<void> _giftCoin() async {
    final toUsername = _giftUsernameController.text.trim();
    final amountStr = _giftAmountController.text.trim();
    
    if (toUsername.isEmpty || amountStr.isEmpty) {
      _showNotification('Invalid Input', 'Please fill all fields', NotificationType.error);
      return;
    }

    final amount = int.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      _showNotification('Invalid Amount', 'Please enter a valid amount', NotificationType.error);
      return;
    }

    if (amount > bCoinBalance) {
      _showNotification('Insufficient Coins', 'You only have $bCoinBalance coins', NotificationType.error);
      return;
    }

    if (toUsername.toLowerCase() == widget.username.toLowerCase()) {
      _showNotification('Invalid Recipient', 'Cannot send gift to yourself', NotificationType.error);
      return;
    }

    setState(() => isLoadingGift = true);

    try {
      final requestBody = {
        'key': widget.sessionKey,
        'fromUsername': widget.username,
        'toUsername': toUsername,
        'amount': amount,
      };

      print('📤 Gift Request: $requestBody');

      final response = await http.post(
        Uri.parse('http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/giftCoin'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      setState(() => isLoadingGift = false);

      print('📥 Gift Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['valid'] == false) {
          _handleSessionExpired();
          return;
        }
        
        if (data['success'] == true) {
          _giftUsernameController.clear();
          _giftAmountController.clear();
          
          _addToHistory({
            'type': 'gift',
            'amount': -amount,
            'to': toUsername,
            'description': 'Gifted $amount coins to $toUsername',
          });
          
          await _showSuccessDialog(
            'Gift Sent!',
            'Successfully sent $amount coins to $toUsername 🎁',
            Icons.send,
            blueColor,
          );
          
          await _fetchCoinBalance();
        } else {
          final message = data['message'] ?? 'Failed to send gift';
          _showNotification('Gift Failed', message, NotificationType.error);
        }
      } else {
        _showNotification('Server Error', 'Failed to connect to server (${response.statusCode})', NotificationType.error);
      }
    } catch (e) {
      setState(() => isLoadingGift = false);
      print('❌ Gift error: $e');
      _showNotification('Connection Error', 'Please check your internet connection', NotificationType.error);
    }
  }

  void _handleSessionExpired() async {
    _showNotification(
      'Session Expired',
      'Your session has expired. Please login again.',
      NotificationType.error,
    );
    
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _showSuccessDialog(String title, String message, IconData icon, Color color) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: cardDarker,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.2),
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotification(String title, String message, NotificationType type) {
    final color = type == NotificationType.error ? Colors.red : Colors.green;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: cardDark,
        content: Row(
          children: [
            Icon(
              type == NotificationType.error ? Icons.error : Icons.check_circle,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    message,
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Balance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: _fetchCoinBalance,
                icon: Icon(Icons.refresh, color: goldColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardDarker,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: goldColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(FontAwesomeIcons.bitcoin, color: goldColor, size: 24),
                      const SizedBox(height: 8),
                      Text(
                        'B Coins',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bCoinBalance.toString(),
                        style: TextStyle(color: goldColor, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardDarker,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: blueColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(FontAwesomeIcons.coins, color: blueColor, size: 24),
                      const SizedBox(height: 8),
                      Text(
                        'L Coins',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lCoinBalance.toString(),
                        style: TextStyle(color: blueColor, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.card_giftcard, color: goldColor),
              const SizedBox(width: 12),
              Text(
                'Redeem Code',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _redeemCodeController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter redeem code',
              hintStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: goldColor),
              ),
              filled: true,
              fillColor: cardDarker,
              prefixIcon: Icon(Icons.code, color: goldColor),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoadingRedeem ? null : _redeemCoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: goldColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: isLoadingRedeem
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : Text(
                      'Redeem Now',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.send, color: blueColor),
              const SizedBox(width: 12),
              Text(
                'Send Gift',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _giftUsernameController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Recipient username',
              hintStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: blueColor),
              ),
              filled: true,
              fillColor: cardDarker,
              prefixIcon: Icon(Icons.person, color: blueColor),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _giftAmountController,
            style: TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Amount',
              hintStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: blueColor),
              ),
              filled: true,
              fillColor: cardDarker,
              prefixIcon: Icon(Icons.attach_money, color: blueColor),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoadingGift ? null : _giftCoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: blueColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: isLoadingGift
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : Text(
                      'Send Gift',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: goldColor),
              const SizedBox(width: 12),
              Text(
                'Transaction History',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (transactionHistory.isNotEmpty)
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: cardDarker,
                        title: Text('Clear History?', style: TextStyle(color: Colors.white)),
                        content: Text('Are you sure you want to clear all transaction history?', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel', style: TextStyle(color: Colors.white70)),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.remove('transaction_history');
                              setState(() => transactionHistory.clear());
                            },
                            child: Text('Clear', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(
                    'Clear',
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (transactionHistory.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.history_toggle_off, color: Colors.white54, size: 60),
                  const SizedBox(height: 12),
                  Text(
                    'No transactions yet',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactionHistory.length,
              separatorBuilder: (context, index) => Divider(color: accentColor, height: 20),
              itemBuilder: (context, index) {
                final transaction = transactionHistory[index];
                final isRedeem = transaction['type'] == 'redeem';
                final amount = transaction['amount'] ?? 0;
                final timestamp = transaction['timestamp'] != null
                    ? DateTime.parse(transaction['timestamp'])
                    : DateTime.now();
                
                final day = timestamp.day;
                final month = _getMonthAbbreviation(timestamp.month);
                final hour = timestamp.hour.toString().padLeft(2, '0');
                final minute = timestamp.minute.toString().padLeft(2, '0');
                
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardDarker,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isRedeem ? goldColor.withOpacity(0.2) : blueColor.withOpacity(0.2),
                        ),
                        child: Icon(
                          isRedeem ? Icons.card_giftcard : Icons.send,
                          color: isRedeem ? goldColor : blueColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction['description'] ?? 'Transaction',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$month $day, $hour:$minute',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${amount > 0 ? '+' : ''}$amount',
                        style: TextStyle(
                          color: amount > 0 ? goldColor : blueColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _getMonthAbbreviation(int month) {
    switch (month) {
      case 1: return 'Jan';
      case 2: return 'Feb';
      case 3: return 'Mar';
      case 4: return 'Apr';
      case 5: return 'May';
      case 6: return 'Jun';
      case 7: return 'Jul';
      case 8: return 'Aug';
      case 9: return 'Sep';
      case 10: return 'Oct';
      case 11: return 'Nov';
      case 12: return 'Dec';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        title: Text(
          'Coin Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryDark,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildBalanceCard(),
            _buildRedeemSection(),
            _buildGiftSection(),
            _buildTransactionHistory(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

enum NotificationType { success, error }