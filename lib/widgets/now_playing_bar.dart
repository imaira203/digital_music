import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../screens/player_screen.dart';

class NowPlayingBar extends StatefulWidget {
  const NowPlayingBar({super.key});

  @override
  State<NowPlayingBar> createState() => _NowPlayingBarState();
}

class _NowPlayingBarState extends State<NowPlayingBar> {
  Timer? _ticker;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
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
    final hasTrack = (p.title ?? '').isNotEmpty || (p.thumbnailUrl ?? '').isNotEmpty;
    if (!hasTrack) return const SizedBox.shrink();

    final progress = (_dur.inMilliseconds == 0)
        ? 0.0
        : (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0);

    return SafeArea(
      top: false,
      child: Material(
        elevation: 6,
        color: Theme.of(context).colorScheme.surface,
        child: InkWell(
          onTap: () {
            // Mở full player
            final ids = p.queue.map((e) => e['videoId']?.toString()).whereType<String>().toList();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlayerScreen(videoIds: ids, startIndex: p.currentIndex.clamp(0, ids.length - 1)),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // thumbnail
                if ((p.thumbnailUrl ?? '').isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(p.thumbnailUrl!, width: 48, height: 48, fit: BoxFit.cover),
                  ),
                const SizedBox(width: 12),
                // title/artist + progress
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(p.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: progress),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(p.isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: () => p.isPlaying ? p.pause() : p.resume(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
