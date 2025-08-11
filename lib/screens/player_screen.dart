import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';

class PlayerScreen extends StatefulWidget {
  final List<String> videoIds;
  final int startIndex;

  const PlayerScreen({
    required this.videoIds,
    required this.startIndex,
    super.key,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  int backPressed = 0;
  DateTime? lastBackPress;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  List<Map<String, dynamic>> _tracks = [];
  bool _loadingFirstTrack = true;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  Timer? _positionUpdateTimer;

  @override
  void initState() {
    super.initState();
    // Chờ frame đầu để context/provider sẵn sàng
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPlayback();
      _startPositionUpdater();
    });
  }

  Future<void> _initPlayback() async {
    final player = Provider.of<PlayerProvider>(context, listen: false);

    final currentIds = player.queue
        .map((e) => e['videoId'] as String?)
        .whereType<String>()
        .toList();

    final sameList = _listEqualsOrdered(currentIds, widget.videoIds);

    if (!sameList) {
      // Danh sách mới khác hoàn toàn → fetch & play lại
      _tracks.clear();
      setState(() => _loadingFirstTrack = true);
      await _fetchFirstTrackAndPlay();
    } else {
      // Danh sách giống nhau → không fetch nữa
      setState(() => _loadingFirstTrack = false);

      // Nhưng nếu startIndex khác thì nhảy tới bài tương ứng
      if (player.currentIndex != widget.startIndex &&
          widget.startIndex >= 0 &&
          widget.startIndex < player.queue.length) {
        // Cách đơn giản: dùng lại play() để set đúng bài (đổi URL, tiêu đề...)
        await player.play(List<Map<String, dynamic>>.from(player.queue),
            startIndex: widget.startIndex);
      }
    }
  }

  bool _listEqualsOrdered(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }


  /// Fetch bài đầu tiên và play ngay
  Future<void> _fetchFirstTrackAndPlay() async {
    try {
      final firstTrack = await _fetchSingleTrack(widget.videoIds[widget.startIndex]);

      setState(() {
        _tracks.add(firstTrack);
        _loadingFirstTrack = false;
      });

      final player = Provider.of<PlayerProvider>(context, listen: false);
      await player.play([firstTrack], startIndex: 0);

      // Load các bài còn lại nền
      final remainingIds = List<String>.from(widget.videoIds)
        ..removeAt(widget.startIndex);
      _fetchRemainingTracks(remainingIds);
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<Map<String, dynamic>> _fetchSingleTrack(String videoId) async {
    final res = await http.get(
      Uri.parse("http://localhost:8789/youtube/audio/$videoId"),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception("Lỗi fetch bài đầu tiên: ${res.body}");
  }

  Future<void> _fetchRemainingTracks(List<String> ids) async {
    if (ids.isEmpty) return;

    final res = await http.post(
      Uri.parse("http://localhost:8789/youtube/audio/batch"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"videoIds": ids}),
    );

    if (res.statusCode == 200) {
      final data = List<Map<String, dynamic>>.from(jsonDecode(res.body));
      setState(() => _tracks.addAll(data));
      // Cập nhật queue cho player nếu cần
      final player = Provider.of<PlayerProvider>(context, listen: false);
      player.addToQueue(data);
    } else {
      print("Lỗi fetch batch: ${res.body}");
    }
  }

  void _startPositionUpdater() {
    final player = Provider.of<PlayerProvider>(context, listen: false);

    // Giảm tần suất update UI xuống mỗi 300ms
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted) {
        setState(() {
          _position = player.audioPlayer.position;
          _duration = player.audioPlayer.duration ?? Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _positionUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);
    final screenW = MediaQuery.of(context).size.width;
    final w = (screenW * 0.9).clamp(280.0, 460.0);

    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _loadingFirstTrack
            ? _buildSkeletonUI()
            : Column(
          children: [
            if (player.thumbnailUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: player.thumbnailUrl!,
                  height: 250,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 250,
                    width: w-15,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              player.title ?? 'Loading...',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              player.artist ?? '',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 40,
                  onPressed: () async {
                    // Tránh nhấn khi đang loading/buffering để khỏi giật
                    final ps = player.audioPlayer.processingState;
                    if (ps == ProcessingState.loading || ps == ProcessingState.buffering) return;

                    const threshold = Duration(seconds: 5);
                    final pos = player.audioPlayer.position;

                    if (pos > threshold) {
                      await player.audioPlayer.seek(Duration.zero); // tua về đầu bài
                      return;
                    }

                    // ≤ threshold: thử lùi bài
                    final moved = await player.playPrevious();
                    if (!moved) {
                      // đang ở bài đầu -> chỉ restart bài hiện tại
                      await player.audioPlayer.seek(Duration.zero);
                    }
                  },
                ),
                IconButton(
                  icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 64,
                  onPressed: () async {
                    if (player.isPlaying) {
                      await player.pause();
                    } else {
                      // Nếu queue hiện tại Không giống videoIds đầu vào -> phát lại theo danh sách mới
                      final currentIds = player.queue
                          .map((e) => e['videoId'] as String?)
                          .whereType<String>()
                          .toList();
                      final sameList = _listEqualsOrdered(currentIds, widget.videoIds);

                      if (sameList && player.queue.isNotEmpty) {
                        await player.resume();
                      } else if (_tracks.isNotEmpty) {
                        await player.play(_tracks, startIndex: 0);
                      } else {
                        // Phòng trường hợp bấm quá sớm khi chưa fetch xong bài đầu
                        await _fetchFirstTrackAndPlay();
                      }
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  iconSize: 40,
                  onPressed: () async {
                    bool success = await player.playNext();
                    if (!success) {
                      await player.playFirstInQueue();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Slider(
              value: _position.inSeconds.toDouble(),
              max: _duration.inSeconds.toDouble().clamp(1.0, double.infinity),
              onChanged: (value) {
                player.audioPlayer.seek(Duration(seconds: value.toInt()));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position)),
                Text(_formatDuration(_duration)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonUI() {
    final screenW = MediaQuery.of(context).size.width;
    final w = (screenW * 0.9).clamp(280.0, 460.0);

    return Align(
      alignment: Alignment.topCenter, // chỉ căn giữa theo chiều ngang
      child: Padding(
        padding: const EdgeInsets.only(top: 16), // cách top nhẹ
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center, // giữa ngang
          children: [
            Container(
              height: 250,
              width: w,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 24,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 16,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }


  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
