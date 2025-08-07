import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../providers/player_provider.dart';

class PlayerScreen extends StatefulWidget {
  final List videoId;

  const PlayerScreen({required this.videoId, super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  int backPressed = 0;
  DateTime? lastBackPress;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startPositionUpdater();
  }

  void _startPositionUpdater() {
    final player = Provider.of<PlayerProvider>(context, listen: false);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final pos = await player.audioPlayer.getCurrentPosition();
      final dur = await player.audioPlayer.getDuration();

      setState(() {
        _position = pos ?? Duration.zero;
        _duration = dur ?? Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);

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
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () {
                    // TODO: Thêm vào liked-songs.json
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.playlist_add),
                  onPressed: () {
                    // TODO: Thêm vào playlist
                  },
                ),
              ],
            ),
            const Spacer(),

            /// --- Nút điều khiển ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 40,
                  onPressed: () async {
                    final now = DateTime.now();

                    if (lastBackPress == null || now.difference(lastBackPress!) > const Duration(seconds: 2)) {
                      backPressed = 1;
                    } else {
                      backPressed++;
                    }

                    lastBackPress = now;

                    if (backPressed >= 2) {
                      final success = await player.playPrevious();
                      if (!success) {
                        await player.playLastInQueue(); // Phát lại từ cuối danh sách
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
                      player.play(widget.videoId.cast<String>());
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  iconSize: 40,
                  onPressed: () async {
                    final success = await player.playNext();
                    if (!success) {
                      await player.playFirstInQueue(); // Phát lại từ đầu
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            /// --- Slider và thời gian ---
            Column(
              children: [
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
