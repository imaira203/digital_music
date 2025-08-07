import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/music_api_service.dart';

class MusicProvider extends ChangeNotifier {
  List<Song> _songs = [];
  bool _isLoading = false;

  List<Song> get songs => _songs;
  bool get isLoading => _isLoading;

  Future<void> fetchSongs() async {
    _isLoading = true;
    notifyListeners();

    try {
      _songs = await MusicApiService.getAllSongs();
    } catch (e) {
      debugPrint('Lỗi khi tải bài hát: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}
