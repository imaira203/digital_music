class Song {
  final String id;
  final String title;
  final String artist;
  final String thumbnailUrl;
  // final String audioUrl;
  final Duration duration;
  final String videoID;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    // required this.audioUrl,
    required this.duration,
    required this.videoID
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      thumbnailUrl: json['thumbnailUrl'],
      // audioUrl: json['audioUrl'],
      duration: Duration(seconds: json['duration'] ?? 0),
      videoID: json['videoID']
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'thumbnailUrl': thumbnailUrl,
      // 'audioUrl': audioUrl,
      'duration': duration.inSeconds,
    };
  }
}
