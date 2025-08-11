import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';


class PlayerProvider with ChangeNotifier {
  final AudioPlayer audioPlayer = AudioPlayer();

  final List<Map<String, dynamic>> _queue = [];
  List<Map<String, dynamic>> get queue => List.unmodifiable(_queue);

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  String? thumbnailUrl;
  String? title;
  String? artist;
  bool isPlaying = false;

  PlayerProvider() {
    audioPlayer.playerStateStream.listen((state) async {
    if (state.processingState == ProcessingState.completed) {
      final moved = await playNext();
      if (!moved) {
        isPlaying = false;
        notifyListeners();
      }
    }
  });
  }

  /// Phát danh sách từ đầu hoặc từ startIndex
  Future<void> play(List<Map<String, dynamic>> items, {int startIndex = 0}) async {
    _queue
      ..clear()
      ..addAll(items);
    _currentIndex = startIndex;
    await _playCurrent();
  }

  /// Thêm nhiều bài vào queue mà không ngắt nhạc đang phát
  void addToQueue(List<Map<String, dynamic>> items) {
    _queue.addAll(items);
    notifyListeners();
  }

  Future<void> _playCurrent() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;

    final current = _queue[_currentIndex];
    final audioUrl = current['audioUrl'];
    if (audioUrl == null) return;

    try {
      title = current['title'];
      artist = current['artist'];
      thumbnailUrl = current['thumbnailUrl'];
      notifyListeners();

      await audioPlayer.stop();
      await audioPlayer.setUrl(audioUrl);
      await audioPlayer.play();

      isPlaying = true;
      notifyListeners();
    } catch (e) {
      print("Error playing audio: $e");
    }
  }

  Future<void> pause() async {
    await audioPlayer.pause();
    isPlaying = false;
    notifyListeners();
  }

  Future<void> resume() async {
    await audioPlayer.play();
    isPlaying = true;
    notifyListeners();
  }

  Future<bool> playNext() async {
    if (_currentIndex + 1 < _queue.length) {
      _currentIndex++;
      await _playCurrent();
      return true;
    }
    return false;
  }

  Future<bool> playPrevious() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await _playCurrent();
      return true;
    }
    return false;
  }

  Future<void> playFirstInQueue() async {
    if (_queue.isNotEmpty) {
      _currentIndex = 0;
      await _playCurrent();
    }
  }

  Future<void> playLastInQueue() async {
    if (_queue.isNotEmpty) {
      _currentIndex = _queue.length - 1;
      await _playCurrent();
    }
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }
}
