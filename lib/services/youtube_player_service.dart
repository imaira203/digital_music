import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:audioplayers/audioplayers.dart';

class YoutubePlayerService {
  final _yt = YoutubeExplode();
  final AudioPlayer _player = AudioPlayer();

  Future<String> getAudioUrl(String videoId) async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
    return audioStreamInfo.url.toString();
  }

  Future<void> playFromUrl(String audioUrl) async {
    try {
      await _player.stop();
      await _player.release();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(UrlSource(audioUrl));
    } catch (e) {
      print('Lỗi khi phát nhạc: $e');
    }
  }

  Future<void> playFromVideoId(String videoId) async {
    final url = await getAudioUrl(videoId);
    await playFromUrl(url);
  }

  Future<void> pause() async => await _player.pause();

  Future<void> stop() async => await _player.stop();

  void dispose() {
    _player.dispose();
    _yt.close();
  }
}
