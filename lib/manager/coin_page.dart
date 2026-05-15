import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class CoinPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;
  final int? initialCoins;

  const CoinPage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
    this.initialCoins,
  });

  @override
  State<CoinPage> createState() => _CoinPageState();
}

class _CoinPageState extends State<CoinPage>
    with TickerProviderStateMixin {

  late AnimationController _animationController;
  late AnimationController _coinBounceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _coinBounceAnimation;

  int _currentCoins = 0;
  bool _isLoading = true;
  
  // History data
  List<Map<String, dynamic>> _transactionHistory = [];
  bool _isLoadingHistory = false;

  final TextEditingController _redeemCodeController = TextEditingController();
  final TextEditingController _giftUsernameController = TextEditingController();
  final TextEditingController _giftAmountController = TextEditingController();

  final Color primaryRed = const Color(0xFF8A1E3A);
  final Color accentRed = const Color(0xFFF63B82);
  final Color lightRed = const Color(0xFFFA60A5);
  final Color goldCoin = const Color(0xFFFFD700);
  final Color cardDark = const Color(0xFF1A0A0D);
  final Color cardDarker = const Color(0xFF0F0506);
  final Color backgroundDark = const Color(0xFF0A0304);

  @override
  void initState() {
    super.initState();

    _currentCoins = widget.initialCoins ?? 0;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _coinBounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _coinBounceAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _coinBounceController,
        curve: Curves.elasticOut,
      ),
    );

    _animationController.forward();
    _fetchCoinBalance();
    _loadTransactionHistory();
  }

  Future<void> _fetchCoinBalance() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await http.get(
        Uri.parse('http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/refreshCoins?key=${widget.sessionKey}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['valid'] == true) {
          final newCoins = data['coins'] ?? 0;
          
          if (newCoins != _currentCoins) {
            _coinBounceController.forward(from: 0);
          }
          
          setState(() {
            _currentCoins = newCoins;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
          _showCustomNotification('Fetch Failed', 'Failed to load coin balance', NotificationType.error);
        }
      } else {
        setState(() => _isLoading = false);
        _showCustomNotification('Server Error', 'Failed to connect to server', NotificationType.error);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showCustomNotification('Connection Error', 'Please check your internet connection', NotificationType.error);
    }
  }

  // Load transaction history (mock data for now)
  Future<void> _loadTransactionHistory() async {
    setState(() => _isLoadingHistory = true);
    
    await Future.delayed(Duration(seconds: 1)); // Simulate network delay
    
    // Mock data - ganti dengan API call yang sebenarnya
    setState(() {
      _transactionHistory = [
        {
          'type': 'redeem',
          'amount': 1000,
          'description': 'Redeem code: PROMO2024',
          'date': DateTime.now().subtract(Duration(hours: 2)),
          'status': 'success',
        },
        {
          'type': 'gift_sent',
          'amount': -500,
          'description': 'Gift to username123',
          'date': DateTime.now().subtract(Duration(days: 1)),
          'status': 'success',
        },
        {
          'type': 'gift_received',
          'amount': 750,
          'description': 'Gift from friend456',
          'date': DateTime.now().subtract(Duration(days: 2)),
          'status': 'success',
        },
        {
          'type': 'redeem',
          'amount': 500,
          'description': 'Redeem code: WELCOME500',
          'date': DateTime.now().subtract(Duration(days: 3)),
          'status': 'success',
        },
      ];
      _isLoadingHistory = false;
    });
  }

  Future<void> _redeemCoin() async {
    final code = _redeemCodeController.text.trim().toUpperCase();
    
    if (code.isEmpty) {
      _showCustomNotification('Invalid Code', 'Please enter a redeem code', NotificationType.error);
      return;
    }

    _showEnhancedLoadingDialog('Processing redeem code...', Icons.card_giftcard);

    try {
      final response = await http.get(
        Uri.parse('http://rullofficiall.xpanelprivate.my.id:2002/redeem?key=${widget.sessionKey}&code=$code'),
      );

      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['valid'] == true && data['success'] == true) {
          final amount = data['amount'] ?? 0;
          _redeemCodeController.clear();
          
          _showCustomNotification(
            'Redeem Success!',
            'You received $amount coins! 🎉',
            NotificationType.success,
          );
          
          await Future.delayed(Duration(milliseconds: 500));
          _fetchCoinBalance();
          _loadTransactionHistory();
        } else {
          final message = data['message'] ?? 'Invalid or already used code';
          _showCustomNotification('Redeem Failed', message, NotificationType.error);
        }
      } else {
        _showCustomNotification('Server Error', 'Failed to connect to server', NotificationType.error);
      }
    } catch (e) {
      Navigator.pop(context);
      _showCustomNotification('Connection Error', 'Please check your internet connection', NotificationType.error);
    }
  }

  Future<void> _giftCoin() async {
    final toUsername = _giftUsernameController.text.trim();
    final amountStr = _giftAmountController.text.trim();
    
    if (toUsername.isEmpty || amountStr.isEmpty) {
      _showCustomNotification('Invalid Input', 'Please fill all fields', NotificationType.error);
      return;
    }

    final amount = int.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      _showCustomNotification('Invalid Amount', 'Please enter a valid amount', NotificationType.error);
      return;
    }

    if (amount > _currentCoins) {
      _showCustomNotification('Insufficient Coins', 'You only have $_currentCoins coins', NotificationType.error);
      return;
    }

    if (toUsername.toLowerCase() == widget.username.toLowerCase()) {
      _showCustomNotification('Invalid Recipient', 'Cannot send gift to yourself', NotificationType.error);
      return;
    }

    _showEnhancedLoadingDialog('Sending gift...', Icons.send);

    try {
      final requestBody = {
        'key': widget.sessionKey,
        'fromUsername': widget.username,
        'toUsername': toUsername,
        'amount': amount,
      };

      final response = await http.post(
        Uri.parse('http://rullofficiall.xpanelprivate.my.id:2002/giftCoin'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['valid'] == false) {
          _showCustomNotification('Session Error', data['message'] ?? 'Invalid session key', NotificationType.error);
          return;
        }
        
        if (data['success'] == true) {
          _giftUsernameController.clear();
          _giftAmountController.clear();
          
          _showCustomNotification(
            'Gift Sent!',
            'Successfully sent $amount coins to $toUsername 🎁',
            NotificationType.success,
          );
          
          await Future.delayed(Duration(milliseconds: 500));
          await _fetchCoinBalance();
          _loadTransactionHistory();
        } else {
          final message = data['message'] ?? 'Failed to send gift';
          _showCustomNotification('Gift Failed', message, NotificationType.error);
        }
      } else {
        _showCustomNotification('Server Error', 'Failed to connect to server', NotificationType.error);
      }
    } catch (e) {
      Navigator.pop(context);
      _showCustomNotification('Connection Error', 'Please check your internet connection', NotificationType.error);
    }
  }

  // Enhanced Loading Dialog dengan animasi yang lebih menarik
  void _showEnhancedLoadingDialog(String message, IconData icon) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 40),
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cardDark, cardDarker],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: accentRed.withOpacity(0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: accentRed.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              color: accentRed,
                              strokeWidth: 5,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [accentRed, lightRed],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: Colors.white, size: 32),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      Text(
                        message,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please wait...',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Custom Notification Banner (seperti gambar)
  void _showCustomNotification(String title, String message, NotificationType type) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => _CustomNotificationBanner(
        title: title,
        message: message,
        type: type,
        onDismiss: () {
          overlayEntry.remove();
        },
      ),
    );
    
    overlay.insert(overlayEntry);
    
    Future.delayed(Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  void _showRedeemDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cardDark, cardDarker],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accentRed.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: accentRed.withOpacity(0.2),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [accentRed, lightRed]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: accentRed.withOpacity(0.4),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(Icons.card_giftcard, color: Colors.white, size: 28),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Redeem Code',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Enter your code to claim coins',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 24),
              TextField(
                controller: _redeemCodeController,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'XXXX-XXXX-XXXX',
                  hintStyle: TextStyle(color: Colors.white24, letterSpacing: 2),
                  filled: true,
                  fillColor: backgroundDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: accentRed.withOpacity(0.2), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: accentRed, width: 2),
                  ),
                  prefixIcon: Icon(Icons.vpn_key, color: accentRed, size: 24),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _redeemCoin();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentRed,
                    padding: EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: accentRed.withOpacity(0.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.redeem, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'REDEEM NOW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
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

  void _showGiftDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cardDark, cardDarker],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: lightRed.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: lightRed.withOpacity(0.2),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [lightRed, Color(0xFFFF85B3)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: lightRed.withOpacity(0.4),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(Icons.send, color: Colors.white, size: 28),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send Gift',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Share coins with friends',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 24),
              TextField(
                controller: _giftUsernameController,
                style: TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Username',
                  hintStyle: TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: backgroundDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: lightRed.withOpacity(0.2), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: lightRed, width: 2),
                  ),
                  prefixIcon: Icon(Icons.person_outline, color: lightRed, size: 24),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _giftAmountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Amount',
                  hintStyle: TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: backgroundDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: lightRed.withOpacity(0.2), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: lightRed, width: 2),
                  ),
                  prefixIcon: Icon(Icons.monetization_on_outlined, color: goldCoin, size: 24),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _giftCoin();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lightRed,
                    padding: EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: lightRed.withOpacity(0.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'SEND GIFT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
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

  void _showHistoryDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cardDark, cardDarker],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: goldCoin.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: goldCoin.withOpacity(0.2),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [goldCoin, Color(0xFFFFA500)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: goldCoin.withOpacity(0.4),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(Icons.history, color: Colors.white, size: 28),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transaction History',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'View your coin activity',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Divider(color: Colors.white12, thickness: 1),
              SizedBox(height: 16),
              Expanded(
                child: _isLoadingHistory
                    ? Center(
                        child: CircularProgressIndicator(color: goldCoin),
                      )
                    : _transactionHistory.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox, color: Colors.white38, size: 64),
                                SizedBox(height: 16),
                                Text(
                                  'No transactions yet',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Your transaction history will appear here',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _transactionHistory.length,
                            itemBuilder: (context, index) {
                              final transaction = _transactionHistory[index];
                              return _buildHistoryItem(transaction);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> transaction) {
    final type = transaction['type'] as String;
    final amount = transaction['amount'] as int;
    final description = transaction['description'] as String;
    final date = transaction['date'] as DateTime;
    
    IconData icon;
    Color color;
    String prefix;
    
    switch (type) {
      case 'redeem':
        icon = Icons.card_giftcard;
        color = accentRed;
        prefix = '+';
        break;
      case 'gift_sent':
        icon = Icons.arrow_upward;
        color = Colors.orange;
        prefix = '';
        break;
      case 'gift_received':
        icon = Icons.arrow_downward;
        color = Colors.green;
        prefix = '+';
        break;
      default:
        icon = Icons.monetization_on;
        color = goldCoin;
        prefix = '';
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$prefix$amount',
            style: TextStyle(
              color: amount > 0 ? Colors.green : Colors.orange,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        title: Text(
          'Coin Wallet',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: cardDarker,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: accentRed),
            onPressed: () {
              _fetchCoinBalance();
              _loadTransactionHistory();
            },
            tooltip: 'Refresh Balance',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          color: accentRed,
          backgroundColor: cardDarker,
          onRefresh: () async {
            await _fetchCoinBalance();
            await _loadTransactionHistory();
          },
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildCoinCard('B Coin', _currentCoins, accentRed)),
                    SizedBox(width: 16),
                    Expanded(child: _buildCoinCard('L Coin', 0, lightRed)),
                  ],
                ),
                
                SizedBox(height: 28),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildMenuBanner(
                        'Redeem\nCoin',
                        Icons.card_giftcard,
                        accentRed,
                        _showRedeemDialog,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildMenuBanner(
                        'Gift\nCoin',
                        Icons.send,
                        lightRed,
                        _showGiftDialog,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildMenuBanner(
                        'History',
                        Icons.history,
                        goldCoin,
                        _showHistoryDialog,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 28),
                
                _buildUserInfoCard(),
                
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoinCard(String title, int amount, Color color) {
    return ScaleTransition(
      scale: _coinBounceAnimation,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              color.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: 2,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.monetization_on,
                  color: Colors.white,
                  size: 28,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _isLoading && title == 'B Coin'
                ? SizedBox(
                    height: 30,
                    width: 30,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Text(
                    '$amount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Orbitron',
                    ),
                  ),
            SizedBox(height: 4),
            Text(
              'COINS',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuBanner(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cardDark,
              cardDarker,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color,
                    color.withOpacity(0.7),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cardDark,
            cardDarker,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryRed.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryRed.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryRed, accentRed],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Information',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.username,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [goldCoin, Color(0xFFFFA500)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: goldCoin.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  widget.role.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Divider(color: Colors.white12, thickness: 1),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white38, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Manage your coins and transactions here',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _coinBounceController.dispose();
    _redeemCodeController.dispose();
    _giftUsernameController.dispose();
    _giftAmountController.dispose();
    super.dispose();
  }
}

// Enum untuk tipe notifikasi
enum NotificationType {
  success,
  error,
  warning,
  info,
}

// Custom Notification Banner Widget (seperti gambar)
class _CustomNotificationBanner extends StatefulWidget {
  final String title;
  final String message;
  final NotificationType type;
  final VoidCallback onDismiss;

  const _CustomNotificationBanner({
    required this.title,
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_CustomNotificationBanner> createState() => _CustomNotificationBannerState();
}

class _CustomNotificationBannerState extends State<_CustomNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();

    Future.delayed(Duration(milliseconds: 3500), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case NotificationType.success:
        return Color(0xFF1F2937);
      case NotificationType.error:
        return Color(0xFF1F2937);
      case NotificationType.warning:
        return Color(0xFF1F2937);
      case NotificationType.info:
        return Color(0xFF1F2937);
    }
  }

  Color _getIconColor() {
    switch (widget.type) {
      case NotificationType.success:
        return Colors.green;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.info:
        return Colors.blue;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.error:
        return Icons.cancel;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getIconColor().withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                    offset: Offset(0, 8),
                  ),
                  BoxShadow(
                    color: _getIconColor().withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getIconColor().withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getIconColor().withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _getIcon(),
                      color: _getIconColor(),
                      size: 32,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.message,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white54),
                    onPressed: () {
                      _controller.reverse().then((_) => widget.onDismiss());
                    },
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}