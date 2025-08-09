import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class MusicApiService {
  static const String baseUrl = 'http://localhost:8789'; // thay bằng IP backend thực tế khi build mobile

  static Future<List<Song>> getAllSongs() async {
    final response = await http.get(Uri.parse('$baseUrl/songs'));

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((json) => Song.fromJson(json)).toList();
    } else {
      throw Exception('Lỗi khi tải danh sách bài hát');
    }
  }

  static Future<List<Song>> getLikedSongs() async {
    final response = await http.get(Uri.parse('$baseUrl/songs/liked'));

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((json) => Song.fromJson(json)).toList();
    } else {
      throw Exception('Lỗi khi tải danh sách yêu thích');
    }
  }

  static Future<void> likeSong(String id) async {
    final response = await http.post(Uri.parse('$baseUrl/songs/$id/like'));

    if (response.statusCode != 200) {
      throw Exception('Không thể thích bài hát');
    }
  }

  static Future<void> unlikeSong(String id) async {
    final response = await http.post(Uri.parse('$baseUrl/songs/$id/unlike'));

    if (response.statusCode != 200) {
      throw Exception('Không thể bỏ thích bài hát');
    }
  }
}
