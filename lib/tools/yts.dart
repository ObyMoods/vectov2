import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

class YouTubeS extends StatefulWidget {
  const YouTubeS({super.key});

  @override
  State<YouTubeS> createState() => _YouTubeSState();
}

class _YouTubeSState extends State<YouTubeS> {
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoading = false;
  bool _isPlaying = false;
  bool _hasSearchResult = false;
  List<dynamic> _searchResults = [];
  Map<String, dynamic>? _selectedTrack;
  Map<String, dynamic>? _trackData;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  int _currentTrackIndex = -1;
  Map<String, dynamic>? _lyricsData;
  bool _loadingLyrics = false;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _audioPlayer.onComplete.listen((event) {
      if (mounted && _searchResults.isNotEmpty && _currentTrackIndex < _searchResults.length - 1) {
        _playNextTrack();
      }
    });
  }

  Future<void> _searchTrack() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _showError('Masukkan judul lagu atau nama artis');
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearchResult = false;
      _searchResults = [];
      _selectedTrack = null;
      _trackData = null;
      _currentTrackIndex = -1;
      _isPlaying = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _lyricsData = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://api.siputzx.my.id/api/s/youtube?query=${Uri.encodeComponent(query)}'),
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['data'] != null) {
          final results = data['data'];
          if (results.isNotEmpty) {
            setState(() {
              _searchResults = results;
              _hasSearchResult = true;
            });
          } else {
            _showError('Tidak ada hasil ditemukan untuk "$query"');
          }
        } else {
          _showError('Gagal mendapatkan hasil pencarian');
        }
      } else {
        _showError('Gagal menghubungi server (${response.statusCode})');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectTrack(Map<String, dynamic> track, int index) async {
    setState(() {
      _selectedTrack = track;
      _currentTrackIndex = index;
      _isLoading = true;
      _isPlaying = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _lyricsData = null;
    });

    try {
      final audioUrl = await _getAudioUrl(track['url']);
      
      if (audioUrl != null) {
        setState(() {
          _trackData = {
            'title': track['title'],
            'thumbnail': track['thumbnail'] ?? track['image'],
            'download_url': audioUrl,
            'quality': 'MP3',
            'size': _formatFileSize(track['views'] ?? 0),
            'duration': track['duration']['timestamp'] ?? track['timestamp'],
            'views': track['views'],
            'ago': track['ago'],
            'author': track['author']['name'],
          };
        });
        await _fetchLyrics(track['title']);
        await _playTrack();
      } else {
        _showError('Gagal mendapatkan audio URL');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _getAudioUrl(String videoUrl) async {
    final List<Map<String, String>> apis = [
      {
        'url': 'https://api.deline.web.id/downloader/ytmp3?url=${Uri.encodeComponent(videoUrl)}',
        'path': 'result/dlink',
      },
      {
        'url': 'https://api.ryzendesu.vip/api/downloader/ytmp3?url=${Uri.encodeComponent(videoUrl)}',
        'path': 'data/dlink',
      },
      {
        'url': 'https://api.zenzxz.my.id/api/downloader/ytmp3?url=${Uri.encodeComponent(videoUrl)}',
        'path': 'result/dlink',
      },
    ];

    for (var api in apis) {
      try {
        final response = await http.get(
          Uri.parse(api['url']!),
          headers: {'User-Agent': 'Mozilla/5.0'},
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final pathParts = api['path']!.split('/');
          dynamic result = data;
          for (var part in pathParts) {
            result = result[part];
            if (result == null) break;
          }
          if (result != null && result.toString().startsWith('http')) {
            return result.toString();
          }
        }
      } catch (e) {
        print('Download API failed: $e');
        continue;
      }
    }
    return null;
  }

  String _formatFileSize(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }

  Future<void> _fetchLyrics(String title) async {
    setState(() {
      _loadingLyrics = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://api.deline.web.id/tools/lyrics?title=${Uri.encodeComponent(title)}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['result'] != null && data['result'].isNotEmpty) {
          if (mounted) {
            setState(() {
              _lyricsData = data['result'][0];
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching lyrics: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingLyrics = false;
        });
      }
    }
  }

  void _playPreviousTrack() {
    if (_searchResults.isNotEmpty && _currentTrackIndex > 0) {
      _selectTrack(_searchResults[_currentTrackIndex - 1], _currentTrackIndex - 1);
    }
  }

  void _playNextTrack() {
    if (_searchResults.isNotEmpty && _currentTrackIndex < _searchResults.length - 1) {
      _selectTrack(_searchResults[_currentTrackIndex + 1], _currentTrackIndex + 1);
    }
  }

  Future<void> _playTrack() async {
    if (_trackData != null && _trackData!['download_url'] != null) {
      try {
        await _audioPlayer.play(UrlSource(_trackData!['download_url']));
      } catch (e) {
        _showError('Gagal memutar audio');
      }
    }
  }

  Future<void> _pauseTrack() async {
    await _audioPlayer.pause();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          'YouTube Music',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 16),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Cari lagu atau artis...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) => _searchTrack(),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFDC143C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.search, color: Colors.white),
            onPressed: _isLoading ? null : _searchTrack,
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading && _selectedTrack == null) {
      return _buildLoadingState('Mencari lagu...');
    }
    
    if (_hasSearchResult && _searchResults.isNotEmpty && _selectedTrack == null) {
      return _buildSearchResults();
    }
    
    if (_selectedTrack != null && _trackData != null) {
      return _buildPlayerView();
    }
    
    if (_isLoading && _selectedTrack != null) {
      return _buildLoadingState('Mendownload track...');
    }
    
    return _buildEmptyState();
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFFDC143C),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note,
            color: Colors.grey.shade600,
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            'Cari lagu favoritmu',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Masukkan judul lagu atau nama artis',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final track = _searchResults[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                track['thumbnail'] ?? track['image'] ?? '',
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 60,
                  height: 60,
                  color: const Color(0xFF2A2A2A),
                  child: const Icon(Icons.music_note, color: Colors.grey),
                ),
              ),
            ),
            title: Text(
              track['title'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  track['author']['name'],
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.grey.shade500, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      track['duration']['timestamp'] ?? track['timestamp'] ?? 'Unknown',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.visibility, color: Colors.grey.shade500, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _formatViews(track['views']),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.play_arrow, color: Color(0xFFDC143C)),
            onTap: () => _selectTrack(track, index),
          ),
        );
      },
    );
  }

  Widget _buildPlayerView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildTrackInfo(),
          const SizedBox(height: 16),
          _buildPlayerControls(),
          const SizedBox(height: 16),
          _buildLyricsView(),
          const SizedBox(height: 16),
          _buildBackButton(),
        ],
      ),
    );
  }

  Widget _buildTrackInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _trackData!['thumbnail'],
              width: double.infinity,
              height: 280,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 200,
                height: 200,
                color: const Color(0xFF2A2A2A),
                child: const Icon(Icons.music_note, color: Colors.grey, size: 60),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _trackData!['title'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _trackData!['author'],
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.visibility, color: Colors.grey, size: 14),
              const SizedBox(width: 4),
              Text(
                _formatViews(_trackData!['views']),
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.access_time, color: Colors.grey, size: 14),
              const SizedBox(width: 4),
              Text(
                _trackData!['duration'],
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.music_note, color: Colors.grey, size: 14),
              const SizedBox(width: 4),
              Text(
                _trackData!['quality'],
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Slider(
            value: _position.inSeconds.toDouble(),
            min: 0,
            max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1,
            onChanged: (value) async {
              await _audioPlayer.seek(Duration(seconds: value.toInt()));
            },
            activeColor: const Color(0xFFDC143C),
            inactiveColor: Colors.grey.shade700,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white, size: 30),
                onPressed: _currentTrackIndex > 0 ? _playPreviousTrack : null,
              ),
              const SizedBox(width: 16),
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFDC143C),
                ),
                child: IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                  onPressed: _isPlaying ? _pauseTrack : _playTrack,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white, size: 30),
                onPressed: _currentTrackIndex < _searchResults.length - 1 ? _playNextTrack : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsView() {
    if (_loadingLyrics) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: Color(0xFFDC143C)),
              SizedBox(height: 8),
              Text(
                'Mencari lirik...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_lyricsData != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.library_music, color: Color(0xFFDC143C)),
                const SizedBox(width: 8),
                const Text(
                  'Lirik Lagu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_lyricsData!['artistName'] != null)
                  Text(
                    _lyricsData!['artistName'],
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _lyricsData!['plainLyrics'] ?? 'Lirik tidak tersedia',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildBackButton() {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedTrack = null;
          _trackData = null;
          _currentTrackIndex = -1;
          _audioPlayer.stop();
          _position = Duration.zero;
          _duration = Duration.zero;
          _isPlaying = false;
          _lyricsData = null;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.search, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Cari Lagu Lain',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }
}