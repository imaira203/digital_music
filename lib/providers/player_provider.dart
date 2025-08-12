import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

class PlayerProvider with ChangeNotifier {
  final AudioPlayer audioPlayer = AudioPlayer();

  // Queue & trạng thái
  final List<Map<String, dynamic>> _queue = [];
  List<Map<String, dynamic>> get queue => List.unmodifiable(_queue);

  int _currentIndex = -1;
  int get currentIndex => _currentIndex;

  String? thumbnailUrl;
  String? title;
  String? artist;
  bool isPlaying = false;

  // Radio mode (related)
  bool _radioMode = false;
  final Set<String> _seen = {}; // tránh lặp
  final Map<String, List<Map<String, dynamic>>> _relatedCache = {};
  final Map<String, int> _relatedCursor = {}; // videoId -> con trỏ

  // UX / an toàn luồng
  bool _advancing = false;                    // chặn next trùng
  bool _switching = false;                    // đang _playCurrent
  DateTime? _lastAutoAdvance;                 // hãm đúp khi completed
  static const _autoAdvanceCooldown = Duration(milliseconds: 400);

  // Lookahead: luôn giữ sẵn >= N bài phía sau khi radio mode
  final int _lookahead = 4;

  // Gom nhiều lần bấm Next liên tiếp
  int _pendingNextTaps = 0;
  Timer? _nextDebounce;

  // API base
  static String get _apiBase {
    if (kIsWeb) return 'http://localhost:8789';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8789';
    } catch (_) {}
    return 'http://localhost:8789';
  }

  PlayerProvider() {
    audioPlayer.playerStateStream.listen(_handlePlayerState);
  }

  // ==================== Player state handler ====================

  void _handlePlayerState(PlayerState state) async {
    if (state.processingState == ProcessingState.completed) {
      // Tránh next 2 lần khi tua sát cuối / sự kiện bắn trùng
      if (_advancing) return;
      final now = DateTime.now();
      if (_lastAutoAdvance != null &&
          now.difference(_lastAutoAdvance!) < _autoAdvanceCooldown) {
        return;
      }
      _lastAutoAdvance = now;

      _advancing = true;
      try {
        final moved = await playNext();
        if (!moved) {
          isPlaying = false;
          notifyListeners();
        }
      } finally {
        // cho just_audio có thời gian reset
        await Future.delayed(const Duration(milliseconds: 50));
        _advancing = false;
      }
    }
  }

  // ==================== Public controls ====================

  /// Phát 1 videoId (radio mode on): phát ngay bài đó,
  /// sau đó fetch related và nhét ít nhất 1 bài tiếp theo (prime).
  Future<void> playSingleById(String videoId) async {
    _radioMode = true;
    _queue.clear();
    _seen.clear();

    final first = await _fetchAudio(videoId);
    _queue.add(first);
    _seen.add(videoId);
    _currentIndex = 0;

    // Prime trước để bấm Next là có bài mới ngay
    await _ensureNextFromRelated(minLookahead: 1);

    await _playCurrent();
  }

  /// Phát playlist/album (radio mode off).
  Future<void> playPlaylist(List<Map<String, dynamic>> tracks,
      {int startIndex = 0}) async {
    _radioMode = false;
    _queue
      ..clear()
      ..addAll(tracks.map((it) {
        final vid = (it['videoId'] ?? it['id'])?.toString();
        return {
          'videoId': vid,
          'title': it['title'] ?? it['name'] ?? '',
          'artist': it['artist'] ?? it['artistName'] ?? '',
          'thumbnailUrl': it['thumbnailUrl'] ?? (vid != null ? _thumbOf(vid) : ''),
          'audioUrl': it['audioUrl'],
        };
      }));
    _seen
      ..clear()
      ..addAll(_queue.map((e) => (e['videoId'] ?? e['id'])?.toString()).whereType<String>());

    _currentIndex = startIndex.clamp(0, _queue.length - 1);
    await _playCurrent();
  }

  /// Thêm nhiều bài vào queue (không ngắt nhạc)
  void addToQueue(List<Map<String, dynamic>> items) {
    for (final it in items) {
      final vid = (it['videoId'] ?? it['id'])?.toString();
      if (vid != null && !_seen.contains(vid)) {
        _queue.add({
          'videoId': vid,
          'title': it['title'] ?? it['name'] ?? '',
          'artist': it['artist'] ?? (it['artistName'] ?? ''),
          'thumbnailUrl': it['thumbnailUrl'] ?? _thumbOf(vid),
          'audioUrl': it['audioUrl'],
        });
        _seen.add(vid);
      }
    }
    notifyListeners();
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

  /// Next ngay 1 bài (đã có chống re-entrancy)
  Future<bool> playNext() => _skipMany(1);

  Future<bool> playPrevious() async {
    if (_switching || _advancing) return false;
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

  /// GOM NHIỀU LẦN BẤM NEXT: gọi hàm này thay vì `playNext()` trong UI
  /// để người dùng bấm liên tiếp vẫn mượt (debounce 120ms).
  void queueNextTap() {
    _pendingNextTaps++;
    _nextDebounce?.cancel();
    _nextDebounce = Timer(const Duration(milliseconds: 120), () async {
      final taps = _pendingNextTaps;
      _pendingNextTaps = 0;
      await _skipMany(taps);
    });
  }

  // ==================== Core playback ====================

  Future<void> _playCurrent() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;

    final current = _queue[_currentIndex];
    final videoId = (current['videoId'] ?? current['id'])?.toString();
    if (videoId == null || videoId.isEmpty) return;

    _switching = true;
    try {
      // Đảm bảo đã có audioUrl + metadata
      String? audioUrl = (current['audioUrl'] as String?);
      if (audioUrl == null || audioUrl.isEmpty) {
        final info = await _fetchAudio(videoId);
        audioUrl = info['audioUrl']?.toString();
        current['audioUrl'] = audioUrl;
        current['title'] ??= info['title'];
        current['artist'] ??= info['artist'];
        current['thumbnailUrl'] ??= info['thumbnailUrl'];
      }

      title = current['title']?.toString();
      artist = current['artist']?.toString();
      thumbnailUrl = current['thumbnailUrl']?.toString();
      notifyListeners();

      debugPrint('[_playCurrent] index=$_currentIndex videoId=$videoId title=${current['title']}');
      await audioPlayer.stop();
      await audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(current['audioUrl'])),
        preload: true,
      );
      await audioPlayer.play();

      isPlaying = true;
      notifyListeners();

      // Sau khi play xong, nếu radio mode: giữ lookahead sẵn
      if (_radioMode) {
        unawaited(_ensureNextFromRelated(minLookahead: _lookahead));
      }
    } catch (e, st) {
      debugPrint("Error playing audio: $e\n$st");
      // Thử skip qua bài sau nếu bài hiện tại hỏng
      if (!await _skipMany(1)) {
        isPlaying = false;
        notifyListeners();
      }
    } finally {
      _switching = false;
    }
  }

  /// Nhảy tới trước `count` bài (gom nhanh), có chống re-entrancy
  Future<bool> _skipMany(int count) async {
    if (count <= 0) return false;
    if (_advancing) return false;

    _advancing = true;
    try {
      // Nếu radio mode: đảm bảo đủ lookahead cho count bước nhảy
      if (_radioMode) {
        final need = count;
        await _ensureNextFromRelated(minLookahead: need);
      }

      // Tính target index
      final target = (_currentIndex + count).clamp(0, _queue.length - 1);
      if (target == _currentIndex) return false;

      _currentIndex = target;
      await _playCurrent();

      // Bổ sung lookahead sau khi đã nhảy
      if (_radioMode) {
        unawaited(_ensureNextFromRelated(minLookahead: _lookahead));
      }
      return true;
    } finally {
      _advancing = false;
    }
  }

  // ==================== Radio (Related) ====================

  /// Đảm bảo cuối queue có ít nhất `minLookahead` bài phía sau current,
  /// ưu tiên dùng audioUrl đã có, nếu thiếu thì fetch audio.
  Future<bool> _ensureNextFromRelated({int minLookahead = 1}) async {
    if (!_radioMode) return false;
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return false;

    bool added = false;

    while ((_queue.length - 1 - _currentIndex) < minLookahead) {
      final current = _queue[_currentIndex];
      final seedId = (current['videoId'] ?? current['id'])?.toString();
      if (seedId == null) break;

      // Lấy list related từ cache hoặc API
      List<Map<String, dynamic>> related = _relatedCache[seedId] ?? [];
      if (related.isEmpty) {
        related = await _fetchRelated(seedId);
        _relatedCache[seedId] = related;
        _relatedCursor[seedId] = 0;
      }

      // Chọn bài đầu tiên chưa thấy
      int cursor = _relatedCursor[seedId] ?? 0;
      bool found = false;
      while (cursor < related.length) {
        final it = related[cursor];
        cursor++;
        final vid = (it['videoId'] ?? it['id'])?.toString();
        if (vid != null && vid.isNotEmpty && !_seen.contains(vid)) {
          _relatedCursor[seedId] = cursor;

          Map<String, dynamic> info;
          final relatedAudio = (it['audioUrl'] as String?);
          if (relatedAudio != null && relatedAudio.isNotEmpty) {
            info = {
              'videoId': vid,
              'title': it['title'] ?? '',
              'artist': it['artist'] ?? '',
              'thumbnailUrl': it['thumbnailUrl'] ?? _thumbOf(vid),
              'audioUrl': relatedAudio,
            };
          } else {
            info = await _fetchAudio(vid);
          }

          _queue.add(info);
          _seen.add(vid);
          notifyListeners();
          added = true;
          found = true;
          break;
        }
      }

      // Hết gợi ý cho seed hiện tại -> thử seed mới ở current (sau khi next)
      if (!found) {
        _relatedCache.remove(seedId);
        _relatedCursor.remove(seedId);
        break;
      }
    }

    return added;
  }

  // ==================== Networking helpers ====================

  String _thumbOf(String videoId) => 'https://i.ytimg.com/vi/$videoId/hq720.jpg';

  /// Luôn trả {videoId,title,artist,thumbnailUrl,audioUrl}
  Future<Map<String, dynamic>> _fetchAudio(String videoId) async {
    final url = '$_apiBase/youtube/audio/$videoId';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('Audio HTTP ${res.statusCode}: ${res.body}');
    }
    final m = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    final audio = (m['audioUrl'] ?? '').toString();
    if (audio.isEmpty) {
      throw Exception('Không nhận được audioUrl');
    }
    return {
      'videoId': m['videoId'] ?? videoId,
      'title': m['title'] ?? '',
      'artist': m['artist'] ?? '',
      'thumbnailUrl': m['thumbnailUrl'] ?? 'https://i.ytimg.com/vi/$videoId/hq720.jpg',
      'audioUrl': audio,
    };
  }

  /// Trả List<{videoId,title,artist,thumbnailUrl(,audioUrl)?}>
  Future<List<Map<String, dynamic>>> _fetchRelated(String videoId) async {
    final res = await http.get(Uri.parse('$_apiBase/youtube/related/$videoId'));
    if (res.statusCode != 200) return [];

    final decoded = jsonDecode(res.body);

    List rawList = const [];
    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map) {
      for (final key in const ['related', 'items', 'contents', 'results', 'data', 'songs']) {
        final v = decoded[key];
        if (v is List) {
          rawList = v;
          break;
        }
      }
      if (rawList.isEmpty) {
        final looksLikeItem = decoded.containsKey('videoId') ||
            decoded.containsKey('id') ||
            decoded.containsKey('title') ||
            decoded.containsKey('audioUrl');
        if (looksLikeItem) rawList = [decoded];
      }
    }

    final list = rawList.whereType<Map>().map<Map<String, dynamic>>((m) {
      final vid = (m['videoId'] ?? m['id'])?.toString();
      final artist = m['artist'] ??
          m['artistName'] ??
          (m['author'] is Map ? m['author']['name'] : null) ??
          (m['channel'] is Map ? m['channel']['name'] : null) ??
          '';
      final thumb = (m['thumbnailUrl'] ?? (vid != null ? _thumbOf(vid) : '')).toString();

      final out = <String, dynamic>{
        'videoId': vid,
        'title': (m['title'] ?? m['name'] ?? '').toString(),
        'artist': artist.toString(),
        'thumbnailUrl': thumb,
      };

      final ra = m['audioUrl'] as String?;
      if (ra != null && ra.isNotEmpty) out['audioUrl'] = ra;
      return out;
    }).where((m) => (m['videoId'] as String?)?.isNotEmpty == true).toList();

    if (list.isNotEmpty) {
      debugPrint('[related] seed=$videoId count=${list.length} first=${list.first['videoId']}');
    } else {
      debugPrint('[related] seed=$videoId empty');
    }

    return list;
  }

  // ---------- Optional: like / add-to-playlist (stub) ----------
  bool liked = false;
  void toggleLike() {
    liked = !liked;
    notifyListeners();
  }

  Future<void> addToPlaylist(String playlistName) async {
    // TODO
  }

  @override
  void dispose() {
    _nextDebounce?.cancel();
    audioPlayer.dispose();
    super.dispose();
  }
}
