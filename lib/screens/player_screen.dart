import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';

class PlayerScreen extends StatefulWidget {
  final List<String> videoIds; // kiểu rõ ràng
  final int startIndex;

  const PlayerScreen({required this.videoIds, required this.startIndex, super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  int backPressed = 0;
  DateTime? lastBackPress;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  List<Map<String, dynamic>> _tracks = [];
  bool _loading = true;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  @override
  void initState() {
    super.initState();

    final player = Provider.of<PlayerProvider>(context, listen: false);

    if (player.queue.isEmpty) {
      // Chưa có track nào → fetch và play
      _fetchTrackData();
    } else {
      // Đã có track → chỉ hiển thị
      setState(() => _loading = false);
    }

    _startPositionUpdater();
  }

  Future<void> _fetchTrackData() async {
    try {
      // Gọi API lấy list object audio từ videoIds
      final res = await http.post(
        Uri.parse("http://localhost:8789/youtube/audio/batch"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"videoIds": widget.videoIds}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // đảm bảo là List<Map<String, dynamic>>
        _tracks = List<Map<String, dynamic>>.from(data);
        setState(() => _loading = false);

        // tự động play ngay bài đầu
        if (_tracks.isNotEmpty) {
          final player = Provider.of<PlayerProvider>(context, listen: false);
          await player.play(_tracks, startIndex: widget.startIndex);
        }
      } else {
        print("Lỗi fetch: ${res.body}");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  void _startPositionUpdater() {
    final player = Provider.of<PlayerProvider>(context, listen: false);

    _positionSub = player.audioPlayer.positionStream.listen((pos) {
      if (mounted) {
        setState(() => _position = pos);
      }
    });

    _durationSub = player.audioPlayer.durationStream.listen((dur) {
      if (mounted) {
        setState(() => _duration = dur ?? Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            if (player.thumbnailUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  player.thumbnailUrl!,
                  height: 250,
                  fit: BoxFit.cover,
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
                    final now = DateTime.now();
                    if (lastBackPress == null ||
                        now.difference(lastBackPress!) > const Duration(seconds: 2)) {
                      backPressed = 1;
                    } else {
                      backPressed++;
                    }
                    lastBackPress = now;

                    if (backPressed >= 2) {
                      bool success = await player.playPrevious();
                      if (!success){
                        await player.playFirstInQueue();
                      }
                      backPressed = 0;
                    } else {
                      await player.audioPlayer.seek(Duration.zero);
                    }
                  },
                ),
                IconButton(
                  icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 64,
                  onPressed: () {
                    if (player.isPlaying) {
                      player.pause();
                    } else {
                      player.play(_tracks, startIndex: player.currentIndex);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  iconSize: 40,
                  onPressed: () async {
                    bool success = await player.playNext();
                    if (!success){
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
