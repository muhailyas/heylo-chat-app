import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'voice_player_service.g.dart';

@riverpod
class VoicePlayerService extends _$VoicePlayerService {
  final AudioPlayer _player = AudioPlayer();
  String? _playingUrl;
  final Map<String, Duration> _positions = {};

  StreamSubscription? _s1, _s2, _s3;

  @override
  VoicePlayerState build() {
    _s1 = _player.playerStateStream.listen((_) => _emit());
    _s2 = _player.positionStream.listen((_) => _emit());
    _s3 = _player.durationStream.listen((_) => _emit());

    ref.onDispose(() {
      _s1?.cancel();
      _s2?.cancel();
      _s3?.cancel();
      _player.dispose();
    });

    return VoicePlayerState(
      isPlaying: false,
      isCompleted: false,
      isBuffering: false,
      positions: {},
    );
  }

  void _emit() {
    final isCompleted = _player.processingState == ProcessingState.completed;

    if (isCompleted) {
      _player.pause();
      _player.seek(Duration.zero);
    }

    state = VoicePlayerState(
      isPlaying: _player.playing,
      isCompleted: isCompleted,
      isBuffering:
          _player.processingState == ProcessingState.buffering ||
          _player.processingState == ProcessingState.loading,
      playingUrl: _playingUrl,
      position: _player.position,
      duration: _player.duration ?? Duration.zero,
      positions: Map.from(_positions),
    );
  }

  Future<void> toggle(String url) async {
    if (_playingUrl == url) {
      if (_player.playing) {
        await _player.pause();
        _positions[url] = _player.position;
      } else {
        await _player.play();
      }
    } else {
      if (_playingUrl != null) {
        _positions[_playingUrl!] = _player.position;
      }

      _playingUrl = url;
      _player.pause();

      try {
        await _player.setUrl(url);
        if (_positions.containsKey(url)) {
          await _player.seek(_positions[url]!);
        }
        await _player.play();
      } catch (e) {
        debugPrint('[VoicePlayerService] Error toggling $url: $e');
        _playingUrl = null;
      }
    }
    _emit();
  }

  Future<void> reset() async {
    await _player.stop();
    _playingUrl = null;
    _positions.clear();
    _emit();
  }

  Future<void> seek(Duration pos) async {
    await _player.seek(pos);
    _emit();
  }

  bool isPlaying(String url) {
    return _playingUrl == url && _player.playing;
  }
}

class VoicePlayerState {
  final bool isPlaying;
  final bool isCompleted;
  final bool isBuffering;
  final String? playingUrl;
  final Duration position;
  final Duration duration;
  final Map<String, Duration> positions;

  VoicePlayerState({
    required this.isPlaying,
    required this.isCompleted,
    required this.isBuffering,
    this.playingUrl,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.positions = const {},
  });
}
