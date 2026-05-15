import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/audio_handler.dart';

class SpotifyPage extends StatefulWidget {
  const SpotifyPage({super.key});

  @override
  State<SpotifyPage> createState() => _SpotifyPageState();
}

class _SpotifyPageState extends State<SpotifyPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AudioHandler _audioHandler;
  List<Map<String, dynamic>> _searchResults = [];
  StreamSubscription<PlaybackState>? _playbackSub;
  StreamSubscription<MediaItem?>? _mediaItemSub;
  StreamSubscription<Duration>? _positionSub;

  bool _isLoading = false;
  bool _isPlaying = false;
  bool _hasSearchResult = false;
  bool _liked = false;
  Map<String, dynamic>? _trackData;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _initAudioHandler();
  }

  Future<void> _requestNotificationPermissionWithRationale() async {
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final allow = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Izin Notifikasi'),
            content: const Text(
              'Agar kontrol pemutaran muncul di notifikasi dan lock screen, izinkan notifikasi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('Nanti'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('Izinkan'),
              ),
            ],
          ),
        );

        if (allow == true) {
          final res = await Permission.notification.request();
          if (!res.isGranted) {
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifikasi tidak diizinkan')),
              );
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _initAudioHandler() async {
    // Initialize (or reuse) the shared/global audio handler so
    // notifications and lock-screen controls are consistent app-wide.
    _audioHandler = await initAudioHandlerIfNeeded();

    _playbackSub = _audioHandler.playbackState.listen((ps) {
      final playing = ps.playing;
      if (mounted)
        setState(() {
          _isPlaying = playing;
          _position = ps.updatePosition ?? _position;
        });

      if (playing) {
        _rotationController.repeat();
      } else {
        _rotationController.stop(canceled: false);
      }
    });

    _mediaItemSub = _audioHandler.mediaItem.listen((media) {
      if (media != null && mounted) {
        setState(() {
          final oldMeta = _trackData?['result']?['metadata'] ?? {};

          _trackData = {
            'result': {
              'dlink': media.extras?['streamUrl'] ?? '',
              'metadata': {
                'title': media.title,
                'artist': media.extras?['artist'] ?? oldMeta['artist'] ?? '',
                'cover': media.artUri?.toString() ?? oldMeta['cover'] ?? '',
                'duration': _formatDurationString(media.duration),
              },
            },
          };

          _hasSearchResult = true;
          _liked = media.extras?['liked'] == true;
        });
      }
    });

    try {
      final impl = _audioHandler as AudioPlayerHandler;
      _positionSub = impl.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      impl.durationStream.listen((d) {
        if (d != null && mounted) setState(() => _duration = d);
      });
    } catch (_) {}
  }

  Future<void> _searchTrack() async {
  final qRaw = _searchController.text.trim();
  if (qRaw.isEmpty) return;

  setState(() {
    _isLoading = true;
    _hasSearchResult = false;
    _searchResults = [];
  });

  try {
    final q = Uri.encodeComponent(qRaw);
    final url =
        'https://api-faa.my.id/faa/soundcloud-play?query=$q';

    final res = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'Mozilla/5.0',
        'Accept': 'application/json',
      },
    );

    print('STATUS: ${res.statusCode}');
    print('BODY: ${res.body.substring(0, 200)}');

    if (res.statusCode == 200) {
      final data = json.decode(res.body);

      if (data['status'] == true && data['result'] != null) {
        final r = data['result'];

        final item = {
          'dlink': r['download_url'],
          'metadata': {
            'title': r['title'],
            'artist': r['user'],
            'cover': r['thumbnail'],
            'duration': _formatDuration(
              Duration(milliseconds: r['duration'] ?? 0),
            ),
          },
        };

        setState(() {
          _searchResults = [item];
          _hasSearchResult = true;
        });
      } else {
        _showError('Lagu tidak ditemukan');
      }
    } else {
      _showError('Server error (${res.statusCode})');
    }
  } catch (e) {
    _showError('Error jaringan');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  Future<void> _playFromResult(Map<String, dynamic> item) async {
  final meta = item['metadata'];
  final String url = item['dlink'];

  await _requestNotificationPermissionWithRationale();

  _trackData = {
    'result': {'dlink': url, 'metadata': meta},
  };
  setState(() => _hasSearchResult = true);

  final impl = _audioHandler as AudioPlayerHandler;
  await impl.playFromUrl(
  url,
  title: meta['title'],
  artist: meta['artist'],
  artUri: meta['cover']?.toString(),
  extras: {
    'streamUrl': url,
    'liked': _liked,
  },
);
}

  Future<void> _playTrack() async {
    if (_trackData == null) return;

    final url = _trackData!['result']?['dlink'];
    final meta = _trackData!['result']?['metadata'] ?? {};
    if (url == null) return;

    await _requestNotificationPermissionWithRationale();

    try {
      final handler = _audioHandler as AudioPlayerHandler;
      await handler.playFromUrl(
  url,
  title: meta['title']?.toString(),
  artist: meta['artist']?.toString(),
  artUri: meta['cover']?.toString(),
  extras: {
    'streamUrl': url,
    'liked': _liked,
  },
);
    } catch (e) {
      _showError('Gagal memulai pemutaran: $e');
    }
  }

  Future<void> _pauseTrack() async => _audioHandler.pause();
  Future<void> _stopTrack() async => _audioHandler.stop();

  Future<void> _toggleLike() async {
    try {
      final res = await _audioHandler.customAction('like');
      if (res is Map && res.containsKey('liked')) {
        if (mounted) setState(() => _liked = res['liked'] == true);
      }
    } catch (_) {}
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red, content: Text(message)),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  String _formatDurationString(Duration? d) {
    if (d == null) return '00:00';
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  void dispose() {
    try {
      _playbackSub?.cancel();
      _mediaItemSub?.cancel();
      _positionSub?.cancel();
    } catch (_) {}
    _rotationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showExpandedPlayer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final meta = _trackData?['result']?['metadata'] ?? {};
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: ListView(
              controller: controller,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                SizedBox(height: 18),
                Center(
                  child: RotationTransition(
                    turns: _rotationController,
                    child: ClipOval(
                      child: Image.network(
                        meta['cover'] ?? '',
                        width: 260,
                        height: 260,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          width: 260,
                          height: 260,
                          color: Colors.grey.shade900,
                          child: Icon(
                            Icons.music_note,
                            size: 80,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          meta['title'] ?? '',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _liked ? Icons.favorite : Icons.favorite_border,
                        color: _liked ? Colors.pinkAccent : Colors.white70,
                      ),
                      onPressed: _toggleLike,
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Center(
                  child: Text(
                    meta['artist'] ?? '',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                SizedBox(height: 18),
                Slider(
                  value: _position.inSeconds.toDouble().clamp(
                    0,
                    _duration.inSeconds > 0
                        ? _duration.inSeconds.toDouble()
                        : 1,
                  ),
                  min: 0,
                  max: _duration.inSeconds > 0
                      ? _duration.inSeconds.toDouble()
                      : 1,
                  onChanged: (v) =>
                      _audioHandler.seek(Duration(seconds: v.toInt())),
                  activeColor: Color(0xFFEE4266),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.replay_10, color: Colors.white70),
                      onPressed: () => _audioHandler.seek(
                        _position - Duration(seconds: 10) >= Duration.zero
                            ? _position - Duration(seconds: 10)
                            : Duration.zero,
                      ),
                    ),
                    SizedBox(width: 20),
                    GestureDetector(
                      onTap: _isPlaying ? _pauseTrack : _playTrack,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFEE4266), Color(0xFF9B1B6A)],
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black54, blurRadius: 16),
                          ],
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
                    SizedBox(width: 20),
                    IconButton(
                      icon: Icon(Icons.forward_10, color: Colors.white70),
                      onPressed: () => _audioHandler.seek(
                        _position + Duration(seconds: 10) <= _duration
                            ? _position + Duration(seconds: 10)
                            : _duration,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = _trackData?['result']?['metadata'] ?? {};
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Spotify Play',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // blurred background from cover
          if (_hasSearchResult && meta['cover'] != null && meta['cover'] != '')
            Positioned.fill(
              child: Image.network(
                meta['cover'],
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: Colors.black87),
              ),
            ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withOpacity(0.55)),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18.0,
                vertical: 14,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: Colors.white38),
                              SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  style: TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Cari lagu...',
                                    hintStyle: TextStyle(color: Colors.white38),
                                  ),
                                  onSubmitted: (_) => _searchTrack(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      GestureDetector(
                        onTap: _isLoading ? null : _searchTrack,
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFEE4266), Color(0xFF9B1B6A)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(Icons.search, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  Expanded(
                    child: _hasSearchResult
                        ? (_searchResults.isNotEmpty
                              ? Column(
                                  children: [
                                    Expanded(
                                      child: ListView.separated(
                                        itemCount: _searchResults.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(
                                              color: Colors.white12,
                                            ),
                                        itemBuilder: (c, i) {
                                          final item = _searchResults[i];
                                          final meta = item['metadata'] ?? item;
                                          return ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 6,
                                                ),
                                            leading: ClipOval(
                                              child: Image.network(
                                                meta['cover'] ?? '',
                                                width: 48,
                                                height: 48,
                                                fit: BoxFit.cover,
                                                errorBuilder: (c, e, s) =>
                                                    Container(
                                                      width: 48,
                                                      height: 48,
                                                      color: Colors.grey,
                                                    ),
                                              ),
                                            ),
                                            title: Text(
                                              meta['title'] ?? 'Unknown',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            subtitle: Text(
                                              meta['artist'] ?? '',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                            trailing: IconButton(
                                              icon: const Icon(
                                                Icons.play_arrow,
                                                color: Colors.white,
                                              ),
                                              onPressed: () =>
                                                  _playFromResult(item),
                                            ),
                                            onTap: () => _playFromResult(item),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              : _isLoading
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        color: const Color(0xFFEE4266),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Mencari lagu...',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(
                                        Icons.music_note,
                                        color: Colors.white24,
                                        size: 84,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'Cari lagu favoritmu',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 18,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Masukkan judul lagu atau nama artis',
                                        style: TextStyle(color: Colors.white38),
                                      ),
                                    ],
                                  ),
                                ))
                        : _isLoading
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: const Color(0xFFEE4266),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Mencari lagu...',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.music_note,
                                  color: Colors.white24,
                                  size: 84,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Cari lagu favoritmu',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 18,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Masukkan judul lagu atau nama artis',
                                  style: TextStyle(color: Colors.white38),
                                ),
                              ],
                            ),
                          ),
                  ),

                  // mini player
                  if (_trackData != null)
                    GestureDetector(
                      onTap: _showExpandedPlayer,
                      child: Container(
                        margin: EdgeInsets.only(bottom: 6),
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            ClipOval(
                              child: RotationTransition(
                                turns: _rotationController,
                                child: Image.network(
                                  meta['cover'] ?? '',
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    width: 48,
                                    height: 48,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    meta['title'] ?? '',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    meta['artist'] ?? '',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _liked ? Icons.favorite : Icons.favorite_border,
                                color: _liked
                                    ? Colors.pinkAccent
                                    : Colors.white70,
                              ),
                              onPressed: _toggleLike,
                            ),
                            IconButton(
                              icon: Icon(
                                _isPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_fill,
                                color: Colors.white,
                                size: 36,
                              ),
                              onPressed: _isPlaying ? _pauseTrack : _playTrack,
                            ),
                          ],
                        ),
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
}
