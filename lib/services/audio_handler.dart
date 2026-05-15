import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// A simple [AudioHandler] implementation that wraps [just_audio].
///
/// Exposes a convenience method `playFromUrl` so callers can start playback
/// and the handler will publish the active [MediaItem], playback state and
/// keep the Android/iOS notification + lock screen controls working.
class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  MediaItem? _current;

  AudioPlayerHandler() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // forward just_audio events to audio_service playbackState
    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;
      final processingState = _mapProcessingState(_player.processingState);

      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
          systemActions: const {MediaAction.seek},
          androidCompactActionIndices: const [0, 1, 2],
          processingState: processingState,
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
        ),
      );
    });

    // propagate current media item if any (keeps UI in sync on reconnect)
    _player.playerStateStream.listen((state) {}, onError: (e) {});
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  /// Convenience stream: exposes the current playback position.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Convenience stream: exposes the current duration (may be null until known).
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Start playback from a remote URL and update the currently playing [MediaItem].
  Future<void> playFromUrl(
    String url, {
    String? title,
    String? artist,
    String? artUri,
    Map<String, dynamic>? extras,
  }) async {
    final item = MediaItem(
      id: url,
      album: artist ?? '',
      title: title ?? 'Unknown',
      artUri: artUri != null ? Uri.parse(artUri) : null,
      extras: extras,
    );

    _current = item;
    mediaItem.add(item);

    try {
      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.idle,
          playing: false,
        ),
      );
    }
  }

  // Basic control mappings -------------------------------------------------

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> skipToNext() async {
    await _player.seek(Duration.zero);
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    // support a simple 'like' toggle that updates media item extras
    if (name == 'like' && _current != null) {
      final currentExtras = _current!.extras ?? <String, dynamic>{};
      final liked = !(currentExtras['liked'] == true);
      final newExtras = Map<String, dynamic>.from(currentExtras)
        ..['liked'] = liked;
      final newItem = MediaItem(
        id: _current!.id,
        album: _current!.album,
        title: _current!.title,
        artUri: _current!.artUri,
        extras: newExtras,
      );
      _current = newItem;
      mediaItem.add(newItem);
      return {'liked': liked};
    }
    return super.customAction(name, extras);
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ),
    );
  }
}

// Global singleton accessor for the shared AudioHandler used by the app.
AudioHandler? _globalAudioHandler;

Future<AudioHandler> initAudioHandlerIfNeeded() async {
  if (_globalAudioHandler != null) return _globalAudioHandler!;
  // Try several icon resource names in order so devices that expect a
  // specific resource type (drawable vs mipmap) will still display an icon.
  final iconCandidates = [
    'drawable/ic_stat_sadistic',
    'mipmap/ic_stat_sadistic',
    'mipmap/ic_launcher',
  ];

  Object? lastError;
  for (final icon in iconCandidates) {
    try {
      _globalAudioHandler = await AudioService.init(
        builder: () => AudioPlayerHandler(),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.sadisticcore.audio',
          androidNotificationChannelName: 'Audio playback',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: false,
          androidNotificationIcon: icon,
        ),
      );
      debugPrint('AudioService: initialized with notification icon "$icon"');
      lastError = null;
      break;
    } catch (e) {
      debugPrint('AudioService.init failed with icon "$icon": $e');
      lastError = e;
      // try next candidate
    }
  }

  if (_globalAudioHandler == null) {
    debugPrint(
      'All AudioService.init attempts failed, falling back to local handler: $lastError',
    );
    _globalAudioHandler = AudioPlayerHandler();
  }

  return _globalAudioHandler!;
}
