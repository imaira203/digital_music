import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';

class PlayerScreen extends StatefulWidget {
  final List<String> videoIds;
  final int startIndex;

  const PlayerScreen({
    super.key,
    required this.videoIds,
    this.startIndex = 0,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  Timer? _ticker;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Nếu vào Player mà queue trống -> phát bài đầu vào
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<PlayerProvider>();
      if (p.queue.isEmpty && widget.videoIds.isNotEmpty) {
        await p.playSingleById(widget.videoIds[widget.startIndex]);
      }
    });

    _ticker = Timer.periodic(const Duration(milliseconds: 300), (_) {
      final p = context.read<PlayerProvider>();
      setState(() {
        _pos = p.audioPlayer.position;
        _dur = p.audioPlayer.duration ?? Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        actions: [
          IconButton(
            tooltip: p.liked ? 'Bỏ thích' : 'Thích',
            icon: Icon(p.liked ? Icons.favorite : Icons.favorite_border),
            onPressed: () => p.toggleLike(),
          ),
          IconButton(
            tooltip: 'Thêm vào danh sách',
            icon: const Icon(Icons.playlist_add),
            onPressed: () => _showAddToPlaylist(context),
          ),
          IconButton(
            tooltip: 'Hàng chờ',
            icon: const Icon(Icons.queue_music),
            onPressed: () => _showQueue(context, p),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if ((p.thumbnailUrl ?? '').isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: p.thumbnailUrl!,
                  height: 250,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              p.title ?? 'Đang phát…',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              p.artist ?? '',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const Spacer(),
            Slider(
              value: _pos.inSeconds.toDouble(),
              max: _dur.inSeconds == 0 ? 1 : _dur.inSeconds.toDouble(),
              onChanged: (v) => p.audioPlayer.seek(Duration(seconds: v.toInt())),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(_pos)),
                Text(_fmt(_dur)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 40,
                  onPressed: () async {
                    final ps = p.audioPlayer.processingState;
                    if (ps == ProcessingState.loading || ps == ProcessingState.buffering) return;

                    const threshold = Duration(seconds: 5);
                    final pos = p.audioPlayer.position;

                    if (pos > threshold) {
                      await p.audioPlayer.seek(Duration.zero);
                      return;
                    }
                    if (!await p.playPrevious()) {
                      await p.audioPlayer.seek(Duration.zero);
                    }
                  },
                ),
                IconButton(
                  icon: Icon(p.isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 64,
                  onPressed: () => p.isPlaying ? p.pause() : p.resume(),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  iconSize: 40,
                  onPressed: () async {
                    if (!await p.playNext()) {
                      await p.playFirstInQueue();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showQueue(BuildContext ctx, PlayerProvider p) {
    showModalBottomSheet(
      context: ctx,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView.separated(
          itemCount: p.queue.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final it = p.queue[i];
            final playing = i == p.currentIndex;
            return ListTile(
              leading: playing ? const Icon(Icons.equalizer) : const SizedBox.shrink(),
              title: Text(it['title']?.toString() ?? ''),
              subtitle: Text(it['artist']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () async {
                Navigator.pop(ctx);
                await p.playQueueIndex(i);
              },
            );
          },
        ),
      ),
    );
  }

  void _showAddToPlaylist(BuildContext ctx) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: ctx,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Tên playlist',
                hintText: 'Ví dụ: Yêu thích',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      context.read<PlayerProvider>().addToPlaylist(controller.text.trim());
                      Navigator.pop(ctx);
                    },
                    child: const Text('Thêm vào playlist'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}
