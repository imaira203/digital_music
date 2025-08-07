import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class PlayerProvider with ChangeNotifier {
  final AudioPlayer audioPlayer = AudioPlayer();
  final YoutubeExplode yt = YoutubeExplode();

  List<String> _queue = [];
  int _currentIndex = 0;

  String? thumbnailUrl;
  String? title;
  String? artist;
  bool isPlaying = false;

  Future<void> play(List<String> videoIdList, {int startIndex = 0}) async {
    _queue = videoIdList;
    _currentIndex = startIndex;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;

    final id = _queue[_currentIndex];
    final video = await yt.videos.get(id);
    final manifest = await yt.videos.streamsClient.getManifest(id);
    final audio = manifest.audioOnly.withHighestBitrate();

    thumbnailUrl = video.thumbnails.standardResUrl;
    title = video.title;
    artist = video.author;
    notifyListeners();

    await audioPlayer.stop();
    await audioPlayer.play(UrlSource(audio.url.toString()));
    isPlaying = true;

    audioPlayer.onPlayerComplete.listen((_) async {
      await playNext();
    });
  }

  Future<void> pause() async {
    await audioPlayer.pause();
    isPlaying = false;
    notifyListeners();
  }

  Future<void> resume() async {
    await audioPlayer.resume();
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
    _currentIndex = 0;
    await _playCurrent();
  }

  Future<void> playLastInQueue() async {
    _currentIndex = _queue.length - 1;
    await _playCurrent();
  }

  void disposePlayer() {
    audioPlayer.dispose();
    yt.close();
  }
}
