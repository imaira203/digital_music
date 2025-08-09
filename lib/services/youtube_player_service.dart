import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';

class YoutubePlayerService {
  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _player = AudioPlayer();

  /// Trả về URL audio chất lượng cao nhất từ video ID
  Future<String> getAudioUrl(String videoId) async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
    return audioStreamInfo.url.toString();
  }

  /// Phát audio từ URL (đã sửa cho just_audio)
  Future<void> playFromUrl(String audioUrl) async {
    try {
      await _player.stop();
      await _player.setUrl(audioUrl); // Chỉ cần setUrl và play
      await _player.play();
    } catch (e) {
      print('Lỗi khi phát nhạc: $e');
    }
  }

  /// Phát nhạc từ videoId (sử dụng YouTube Explode + just_audio)
  Future<void> playFromVideoId(String videoId) async {
    final url = await getAudioUrl(videoId);
    await playFromUrl(url);
  }

  Future<void> pause() async => await _player.pause();

  Future<void> stop() async => await _player.stop();

  Duration get position => _player.position;

  Duration? get duration => _player.duration;

  Future<void> seek(Duration position) async => await _player.seek(position);

  bool get isPlaying => _player.playing;

  void dispose() {
    _player.dispose();
    _yt.close();
  }
}
