import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== USER PROFILE PAGE ====================
class UserProfilePage extends StatefulWidget {
  final String username;
  final String? currentUser;
  final String baseUrl;

  const UserProfilePage({
    super.key,
    required this.username,
    this.currentUser,
    required this.baseUrl,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  final Color _primaryPink = const Color(0xFFFF4081);
  final Color _bgDark = const Color(0xFF120509);
  final Color _cardDark = const Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadProfileImage();
  }

  Future<void> _loadUserData() async {
    try {
      final response = await http.get(
        Uri.parse("${widget.baseUrl}/get-user-profile?username=${widget.username}"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _userData = data['user'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
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

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && widget.currentUser == widget.username) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_${widget.username}', image.path);
      setState(() {
        _profileImage = File(image.path);
      });
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("${widget.baseUrl}/update-profile-picture"),
      );
      request.fields['username'] = widget.username;
      request.files.add(await http.MultipartFile.fromPath('avatar', image.path));
      await request.send();
    }
  }

  Future<void> _updateBio(String newBio) async {
    try {
      final response = await http.post(
        Uri.parse("${widget.baseUrl}/update-bio"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'username': widget.username,
          'bio': newBio,
        }),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _userData['bio'] = newBio;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bio berhasil diperbarui"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal update bio: $e"), backgroundColor: Colors.red),
      );
    }
  }

  String _formatDate(String date) {
    if (date.isEmpty) return "Belum diketahui";
    final parts = date.split('-');
    if (parts.length == 3) {
      return "${parts[2]}/${parts[1]}/${parts[0]}";
    }
    return date;
  }

  void _showEditBioDialog() {
    final TextEditingController bioController = TextEditingController(
      text: _userData['bio'] ?? "",
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardDark,
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
              borderSide: const BorderSide(color: Color(0xFFFF4081)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF4081)),
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
            style: ElevatedButton.styleFrom(backgroundColor: _primaryPink),
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _userData['name'] ?? widget.username,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          if (widget.currentUser == widget.username)
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFFFF4081)),
              onPressed: _showEditBioDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF4081)))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _primaryPink, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryPink.withOpacity(0.3),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: Colors.grey[800],
                              backgroundImage: _profileImage != null
                                  ? FileImage(_profileImage!)
                                  : null,
                              child: _profileImage == null
                                  ? Text(
                                      widget.username.isNotEmpty
                                          ? widget.username[0].toUpperCase()
                                          : "?",
                                      style: const TextStyle(
                                        fontSize: 36,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          if (widget.currentUser == widget.username)
                            GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _primaryPink,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _primaryPink.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _userData['role']?.toUpperCase() ?? "MEMBER",
                          style: TextStyle(
                            color: _primaryPink,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          if (widget.currentUser == widget.username) {
                            _showEditBioDialog();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: _cardDark,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.white54, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _userData['bio'] ?? "Halo! Saya pengguna Public Lounge",
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ),
                              if (widget.currentUser == widget.username)
                                const Icon(Icons.edit, color: Colors.white54, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: Icon(Icons.calendar_today, color: _primaryPink, size: 22),
                        title: const Text("Bergabung", style: TextStyle(color: Colors.white70, fontSize: 13)),
                        subtitle: Text(_formatDate(_userData['join_date'] ?? ""), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      ListTile(
                        leading: Icon(Icons.message, color: _primaryPink, size: 22),
                        title: const Text("Total Pesan", style: TextStyle(color: Colors.white70, fontSize: 13)),
                        subtitle: Text("${_userData['total_messages'] ?? 0} pesan", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      ListTile(
                        leading: Icon(Icons.photo_library, color: _primaryPink, size: 22),
                        title: const Text("Media Terkirim", style: TextStyle(color: Colors.white70, fontSize: 13)),
                        subtitle: Text("${_userData['total_media'] ?? 0} media", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      const Divider(color: Colors.white12, height: 1),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}


// ==================== PUBLIC CHAT PAGE ====================
class PublicChatPage extends StatefulWidget {
  final String username;
  final String? role;
  const PublicChatPage({super.key, required this.username, this.role});

  @override
  State<PublicChatPage> createState() => _PublicChatPageState();
}

class _PublicChatPageState extends State<PublicChatPage> {
  final String baseUrl = "http://suikaxmaxxxmangyannxbrock.cloudnesia.my.id:3323";

  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _messages = [];
  Timer? _refreshTimer;
  bool _isSending = false;
  
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordTimer;
  bool _hasPermission = false;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentPlayingId;
  
  Map<String, dynamic>? _replyTo;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  final String _adminKey = 'rahasiaadmin123';
  
  final Map<String, String?> _avatarCache = {};

  final Color _primaryPink = const Color(0xFFFF4081);
  final Color _softPink = const Color(0xFFFF80AB);
  final Color _bgDark = const Color(0xFF120509);
  final Color _bubbleMe = const Color(0xFFFF4081).withOpacity(0.8);
  final Color _bubbleOther = const Color(0xFF2C2C2C);

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _requestPermissions();
    _fetchMessages();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchMessages();
    });
  }

  Future<void> _initRecorder() async {
    _hasPermission = await _recorder.hasPermission();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.storage,
      Permission.photos,
      Permission.camera,
    ].request();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<String?> _getUserAvatar(String username) async {
    if (_avatarCache.containsKey(username)) return _avatarCache[username];
    
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_$username');
    if (path != null && File(path).existsSync()) {
      _avatarCache[username] = path;
      return path;
    }
    _avatarCache[username] = null;
    return null;
  }

  void _navigateToProfile(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          username: username,
          currentUser: widget.username,
          baseUrl: baseUrl,
        ),
      ),
    );
  }

  Future<void> _fetchMessages() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/get-public-chat"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          List newMsgs = data['messages'];
          bool shouldScroll = newMsgs.length > _messages.length;

          if (mounted) {
            setState(() {
              _messages = newMsgs;
            });
            if (shouldScroll) _scrollToBottom();
          }
        }
      }
    } catch (e) {}
  }

  Future<void> _sendMessage({String? text, String? mediaPath, String? mediaType}) async {
    if ((text == null || text.isEmpty) && mediaPath == null) return;
    
    setState(() => _isSending = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/send-public-chat"),
      );
      
      request.fields['username'] = widget.username;
      if (text != null && text.isNotEmpty) {
        request.fields['message'] = text;
      }
      
      if (_replyTo != null) {
        request.fields['reply_to_id'] = _replyTo!['id'].toString();
        request.fields['reply_to_username'] = _replyTo!['username'];
        request.fields['reply_to_message'] = _replyTo!['message'] ?? '[Media]';
        setState(() => _replyTo = null);
      }
      
      if (mediaPath != null && File(mediaPath).existsSync()) {
        request.files.add(
          await http.MultipartFile.fromPath('file', mediaPath),
        );
        request.fields['media_type'] = mediaType ?? _getMediaType(mediaPath);
      }
      
      final response = await request.send();
      if (response.statusCode == 200) {
        _msgController.clear();
        await _fetchMessages();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengirim: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteMessage(String messageId, {bool forEveryone = false}) async {
    try {
      final url = forEveryone 
          ? "$baseUrl/delete-public-chat/$messageId?adminKey=$_adminKey"
          : "$baseUrl/delete-my-chat/$messageId?username=${widget.username}";
      
      final response = await http.delete(Uri.parse(url));
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        await _fetchMessages();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal hapus: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      final dir = await getExternalStorageDirectory();
      final file = File('${dir!.path}/$fileName');
      final response = await http.get(Uri.parse('$baseUrl$url'));
      
      await file.writeAsBytes(response.bodyBytes);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download selesai: ${file.path}"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal download: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _playAudio(String url) async {
    if (_currentPlayingId == url) {
      await _audioPlayer.stop();
      setState(() => _currentPlayingId = null);
    } else {
      await _audioPlayer.play(UrlSource('$baseUrl$url'));
      setState(() => _currentPlayingId = url);
      
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) setState(() => _currentPlayingId = null);
      });
    }
  }

  void _showImageFullscreen(String imageUrl) {
    final fullUrl = imageUrl.startsWith('http') ? imageUrl : '$baseUrl$imageUrl';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(fullUrl, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "Tap to zoom • ${fullUrl.split('.').last.toUpperCase()}",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVideoPlayer(String videoUrl) {
    final fullUrl = videoUrl.startsWith('http') ? videoUrl : '$baseUrl$videoUrl';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(videoUrl: fullUrl),
      ),
    );
  }

  String _getMediaType(String path) {
    if (path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png') || path.endsWith('.gif')) {
      return 'image';
    } else if (path.endsWith('.mp4') || path.endsWith('.mov')) {
      return 'video';
    } else if (path.endsWith('.mp3') || path.endsWith('.m4a') || path.endsWith('.wav')) {
      return 'audio';
    }
    return 'file';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _sendMessage(mediaPath: image.path, mediaType: 'image');
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      await _sendMessage(mediaPath: photo.path, mediaType: 'image');
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      await _sendMessage(mediaPath: video.path, mediaType: 'video');
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      String path = result.files.single.path!;
      await _sendMessage(mediaPath: path, mediaType: 'file');
    }
  }

  Future<void> _startRecording() async {
    if (!_hasPermission) {
      _hasPermission = await _recorder.hasPermission();
      if (!_hasPermission) return;
    }
    
    final dir = await getTemporaryDirectory();
    _recordingPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    
    await _recorder.start(
      RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100),
      path: _recordingPath!,
    );
    
    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
    });
    
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isRecording) {
        setState(() => _recordingDuration += const Duration(seconds: 1));
      }
    });
  }

  Future<void> _stopRecording() async {
    if (_isRecording) {
      _recordTimer?.cancel();
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      
      if (path != null && _recordingDuration.inSeconds > 1) {
        await _sendMessage(mediaPath: path, mediaType: 'audio');
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_replyTo != null) _buildReplyBar(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isMe = msg['username'] == widget.username;
                  final isAdmin = widget.role == 'admin';
                  return Dismissible(
                    key: Key(msg['id'].toString()),
                    direction: DismissDirection.startToEnd,
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      decoration: BoxDecoration(
                        color: _primaryPink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.reply, color: Colors.white, size: 30),
                    ),
                    onDismissed: (direction) {
                      setState(() {
                        _replyTo = {
                          'id': msg['id'],
                          'username': msg['username'],
                          'message': msg['message'] ?? '[Media]',
                        };
                      });
                      _scrollToBottom();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Replying to ${msg['username']}"),
                          duration: const Duration(seconds: 1),
                          backgroundColor: _primaryPink,
                        ),
                      );
                    },
                    child: _buildChatBubble(msg, isMe, isAdmin),
                  );
                },
              ),
            ),
            _buildInputArea(),
            if (_isRecording) _buildRecordingIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _primaryPink.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: _primaryPink, width: 4)),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, color: _primaryPink, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Replying to ${_replyTo!['username']}", 
                  style: TextStyle(color: _primaryPink, fontSize: 10)),
                Text(_replyTo!['message']?.toString() ?? '[Media]', 
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _replyTo = null),
            child: const Icon(Icons.close, color: Colors.white54, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _bgDark,
        border: Border(bottom: BorderSide(color: _primaryPink.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_rounded, color: _softPink),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("PUBLIC LOUNGE", 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _primaryPink, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text("Live • ${_messages.length} messages", 
                    style: TextStyle(color: _softPink.withOpacity(0.7), fontSize: 11)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(dynamic msg, bool isMe, bool isAdmin) {
    final hasMedia = msg['media_url'] != null && msg['media_url'].isNotEmpty;
    final mediaType = msg['media_type'] ?? '';
    final hasReply = msg['reply_to'] != null;
    
    return GestureDetector(
      onLongPress: () {
        if (isMe || isAdmin) {
          _showDeleteOptions(msg['id'].toString(), isMe, isAdmin);
        }
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe)
                GestureDetector(
                  onTap: () => _navigateToProfile(msg['username']),
                  child: FutureBuilder<String?>(
                    future: _getUserAvatar(msg['username']),
                    builder: (context, snapshot) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: _primaryPink.withOpacity(0.3),
                          backgroundImage: snapshot.data != null
                              ? FileImage(File(snapshot.data!))
                              : null,
                          child: snapshot.data == null
                              ? Text(
                                  msg['username'].isNotEmpty
                                      ? msg['username'][0].toUpperCase()
                                      : "?",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              
              if (isMe) const Spacer(),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: GestureDetector(
                          onTap: () => _navigateToProfile(msg['username']),
                          child: Text(
                            msg['username'],
                            style: TextStyle(
                              color: _softPink,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    
                    if (hasReply)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border(left: BorderSide(color: _primaryPink, width: 3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg['reply_to']['username'],
                              style: TextStyle(
                                color: _primaryPink,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              msg['reply_to']['message'] ?? '[Media]',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isMe ? _bubbleMe : _bubbleOther,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isMe ? 20 : 5),
                          bottomRight: Radius.circular(isMe ? 5 : 20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (msg['message'] != null && msg['message'].toString().isNotEmpty)
                            Text(msg['message'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                          
                          if (hasMedia) _buildMediaContent(msg, mediaType),
                          
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(msg['time'] ?? "", 
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
                              if (isMe)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(Icons.done_all, color: Colors.white38, size: 12),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              if (isMe)
                GestureDetector(
                  onTap: () => _navigateToProfile(widget.username),
                  child: FutureBuilder<String?>(
                    future: _getUserAvatar(widget.username),
                    builder: (context, snapshot) {
                      return Container(
                        margin: const EdgeInsets.only(left: 8),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: _primaryPink.withOpacity(0.3),
                          backgroundImage: snapshot.data != null
                              ? FileImage(File(snapshot.data!))
                              : null,
                          child: snapshot.data == null
                              ? Text(
                                  widget.username.isNotEmpty
                                      ? widget.username[0].toUpperCase()
                                      : "?",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              
              if (!isMe) const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaContent(dynamic msg, String mediaType) {
    final mediaUrl = msg['media_url'];
    final fullUrl = mediaUrl.startsWith('http') ? mediaUrl : '$baseUrl$mediaUrl';
    
    if (mediaType == 'image') {
      return GestureDetector(
        onTap: () => _showImageFullscreen(mediaUrl),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              fullUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 200,
                color: Colors.grey[900],
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 50),
                ),
              ),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 200,
                  color: Colors.grey[900],
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF4081)),
                  ),
                );
              },
            ),
          ),
        ),
      );
    } else if (mediaType == 'video') {
      return GestureDetector(
        onTap: () => _showVideoPlayer(mediaUrl),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  color: Colors.black45,
                  child: const Center(
                    child: Icon(Icons.play_circle_filled, color: Colors.white, size: 60),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text("Video", style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (mediaType == 'audio') {
      final isPlaying = _currentPlayingId == mediaUrl;
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _playAudio(mediaUrl),
                child: Icon(
                  isPlaying ? Icons.stop_circle : Icons.play_circle_filled,
                  color: _primaryPink,
                  size: 40,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(msg['file_name'] ?? "Voice Message",
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isPlaying)
                      const SizedBox(height: 4),
                    if (isPlaying)
                      LinearProgressIndicator(color: _primaryPink),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _downloadFile(mediaUrl, msg['file_name'] ?? 'audio.m4a'),
                child: const Icon(Icons.download, color: Colors.white54, size: 24),
              ),
            ],
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg['file_name'] ?? "File",
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (msg['file_size'] != null)
                      Text(
                        msg['file_size'],
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _downloadFile(mediaUrl, msg['file_name'] ?? 'file'),
                child: const Icon(Icons.download, color: Colors.white54, size: 24),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showDeleteOptions(String messageId, bool isMe, bool isAdmin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text("Hapus untuk saya", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(messageId, forEveryone: false);
              },
            ),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text("Hapus untuk semua orang", style: TextStyle(color: Colors.white)),
                subtitle: const Text("Admin only", style: TextStyle(color: Colors.white54, fontSize: 10)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(messageId, forEveryone: true);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F0A10),
        border: Border(top: BorderSide(color: _primaryPink.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          PopupMenuButton<String>(
            icon: Icon(Icons.add_circle, color: _softPink, size: 28),
            color: _bgDark,
            onSelected: (value) {
              switch (value) {
                case 'image': _pickImage(); break;
                case 'camera': _takePhoto(); break;
                case 'video': _pickVideo(); break;
                case 'file': _pickFile(); break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'image', child: Row(children: [Icon(Icons.photo), SizedBox(width: 10), Text("Galeri")])),
              const PopupMenuItem(value: 'camera', child: Row(children: [Icon(Icons.camera_alt), SizedBox(width: 10), Text("Kamera")])),
              const PopupMenuItem(value: 'video', child: Row(children: [Icon(Icons.videocam), SizedBox(width: 10), Text("Video")])),
              const PopupMenuItem(value: 'file', child: Row(children: [Icon(Icons.attach_file), SizedBox(width: 10), Text("File")])),
            ],
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onLongPress: _startRecording,
            onLongPressUp: _stopRecording,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red : _softPink.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(_isRecording ? Icons.mic : Icons.mic_none, 
                color: _isRecording ? Colors.white : _softPink, size: 22),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _primaryPink.withOpacity(0.3)),
              ),
              child: TextField(
                controller: _msgController,
                style: const TextStyle(color: Colors.white),
                cursorColor: _primaryPink,
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: TextStyle(color: _softPink.withOpacity(0.4)),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(text: _msgController.text),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isSending ? null : () => _sendMessage(text: _msgController.text),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isSending ? Colors.grey : _primaryPink,
                shape: BoxShape.circle,
              ),
              child: Icon(_isSending ? Icons.hourglass_top_rounded : Icons.send_rounded, 
                color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Text("Merekam... ${_formatDuration(_recordingDuration)}",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        ],
      ),
    );
  }
}

// ==================== VIDEO PLAYER SCREEN ====================
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller.initialize().then((_) {
      setState(() => _isInitialized = true);
      _controller.play();
      _controller.setLooping(true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(color: Color(0xFFFF4081)),
          ),
          if (_isInitialized)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  VideoProgressIndicator(_controller, allowScrubbing: true,
                    colors: const VideoProgressColors(playedColor: Color(0xFFFF4081))),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () {
                          setState(() {
                            _controller.value.isPlaying
                                ? _controller.pause()
                                : _controller.play();
                          });
                        },
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        icon: const Icon(Icons.fullscreen, color: Colors.white, size: 28),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}