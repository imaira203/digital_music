import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'profile_screen.dart';
import 'player_screen.dart';
import '../widgets/now_playing_bar.dart';
import '../providers/player_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin<HomeScreen> {
  // --- Networking ---
  final http.Client _client = http.Client();

  static String get _apiBase {
    // Android emulator không truy cập được localhost của máy host => dùng 10.0.2.2
    if (kIsWeb) return 'http://localhost:8789';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8789';
    } catch (_) {}
    return 'http://localhost:8789';
  }

  Uri get _homeUri => Uri.parse('$_apiBase/songs');

  // --- State ---
  int _selectedIndex = 0;
  late Future<List<Map<String, dynamic>>> _sectionsFuture;

  // Dùng để random nhanh, thu từ các item type SONG
  List<String> allVideoIds = [];

  // Chống double-tap khi push màn Player
  bool _navigating = false;

  static const List<Widget> _tabsPlaceholder = <Widget>[
    Center(child: Text('Đang tải…')),
    Center(child: Text('Nhạc cục bộ')),
    Center(child: Text('Đã thích')),
    Center(child: Text('Danh sách phát')),
    ProfileScreen(),
  ];

  // Giữ vị trí cuộn giữa các lần chuyển tab
  final PageStorageKey _homeListKey = const PageStorageKey('home_list');

  @override
  void initState() {
    super.initState();
    _sectionsFuture = fetchHome();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  // Kéo-để-làm-mới
  Future<void> _refresh() async {
    setState(() {
      _sectionsFuture = fetchHome(force: true);
    });
    await _sectionsFuture;
  }

  Future<List<Map<String, dynamic>>> fetchHome({bool force = false}) async {
    try {
      final response = await _client
          .get(_homeUri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final sections = _normalizeHomePayload(decoded); // [{title, contents: [...]}]

      // Thu thập tất cả videoId từ ITEM type SONG
      final ids = LinkedHashSet<String>();
      for (final sec in sections) {
        final contents = (sec['contents'] is List) ? sec['contents'] as List : const [];
        for (final raw in contents) {
          final item = (raw as Map?) ?? const {};
          if (item['type'] == 'SONG') {
            final vid = (item['id'] ?? item['videoId'])?.toString();
            if (vid != null && vid.isNotEmpty) ids.add(vid);
          }
        }
      }
      allVideoIds = ids.toList(growable: false);

      return sections;
    } on TimeoutException {
      throw Exception('Hết thời gian chờ');
    } catch (e) {
      throw Exception('Lỗi tải dữ liệu: $e');
    }
  }

  /// Map payload Hydralerne ({picks, albums}) -> sections [{title, contents: [...] }]
  List<Map<String, dynamic>> _normalizeHomePayload(dynamic decoded) {
    // Nếu backend đã trả sẵn sections theo format cũ -> giữ nguyên
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }

    final List<Map<String, dynamic>> sections = [];

    if (decoded is Map) {
      // picks -> SONG section
      if (decoded['picks'] is List) {
        final picks = (decoded['picks'] as List).whereType<Map>();
        final contents = picks.map((p) {
          final poster = (p['posterLarge'] ?? p['poster'])?.toString() ?? '';
          return <String, dynamic>{
            'type': 'SONG',
            'id': p['id']?.toString(), // videoId
            'title': p['title']?.toString() ?? '',
            'artist': {'name': p['artist']?.toString() ?? ''},
            'thumbnails': [
              {'url': poster}
            ],
          };
        }).toList();
        sections.add({
          'title': 'Picks for you',
          'contents': contents,
        });
      }

      // albums -> ALBUM section
      if (decoded['albums'] is List) {
        final albums = (decoded['albums'] as List).whereType<Map>();
        final contents = albums.map((a) {
          final poster = (a['posterLarge'] ?? a['poster'])?.toString() ?? '';
          return <String, dynamic>{
            'type': 'ALBUM',
            'albumId': a['id']?.toString(),
            'playlistId': a['playlistID']?.toString(),
            'title': a['title']?.toString() ?? '',
            'artist': {'name': a['artist']?.toString() ?? ''},
            'thumbnails': [
              {'url': poster}
            ],
          };
        }).toList();
        sections.add({
          'title': 'Albums for you',
          'contents': contents,
        });
      }
    }

    if (sections.isEmpty) {
      // Fallback giữ nguyên extractor cũ
      return _extractSections(decoded)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    }
    return sections;
  }

  /// Chuẩn hoá format cũ -> List<dynamic> các "section"
  List<dynamic> _extractSections(dynamic decoded) {
    if (decoded is List) return decoded;

    if (decoded is Map) {
      for (final key in const ['sections', 'data', 'items', 'contents', 'result']) {
        final v = decoded[key];
        if (v is List) return v;
      }
      final hasSectionShape =
          decoded.containsKey('title') && decoded.containsKey('contents');
      if (hasSectionShape) return [decoded];
    }

    throw FormatException(
      'Phản hồi /youtube/home không đúng định dạng mong đợi: ${decoded.runtimeType}',
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPlaylist(String playlistId) async {
    final uri = Uri.parse('$_apiBase/youtube/playlist/$playlistId');
    final res = await _client.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final data = jsonDecode(res.body);

    // Kỳ vọng backend trả { id, title, songs: [{videoId,title,artist,thumbnailUrl}, ...] }
    final List songs = (data['songs'] as List?) ?? const [];
    return songs.map<Map<String, dynamic>>((e) {
      final m = (e as Map).cast<String, dynamic>();
      final vid = (m['videoId'] ?? m['id'])?.toString();
      return {
        'videoId': vid,
        'title': m['title'] ?? m['name'] ?? '',
        'artist': m['artist'] ?? (m['artistName'] ?? ''),
        'thumbnailUrl': m['thumbnailUrl'] ?? (vid != null ? 'https://i.ytimg.com/vi/$vid/hq720.jpg' : ''),
        // audioUrl sẽ được resolve khi phát
      };
    }).toList();
  }

  // UI lỗi có nút Retry
  Widget _buildErrorUI(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48),
            const SizedBox(height: 12),
            Text(
              'Không thể tải dữ liệu',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() {
                _sectionsFuture = fetchHome(force: true);
              }),
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  // Card item (ảnh + tên + nghệ sĩ) với loading/error builder
  Widget _buildThumbCard({
    required String? imageUrl,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl == null || imageUrl.isEmpty
                ? Container(color: Colors.black12)
                : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              // Hiệu ứng loading đơn giản
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.black12),
                    const Center(child: CircularProgressIndicator()),
                  ],
                );
              },
              // Hiển thị khi lỗi ảnh
              errorBuilder: (_, __, ___) => Container(
                color: Colors.black12,
                child: const Center(child: Icon(Icons.broken_image)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  // Điều hướng an toàn (chống double-tap)
  Future<void> _safePush(Widget page) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    } finally {
      _navigating = false;
    }
  }

  Widget buildHomeTab(List<Map<String, dynamic>> sections) {
    final filteredSections = sections; // có thể lọc thêm nếu muốn

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        key: _homeListKey,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filteredSections.length,
        itemBuilder: (context, index) {
          final section = filteredSections[index];
          final title = section['title']?.toString() ?? '';
          final contents = (section['contents'] is List) ? section['contents'] as List : const [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              // Horizontal list
              SizedBox(
                height: 210,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: contents.length,
                  itemBuilder: (context, idx) {
                    final item = (contents[idx] as Map?) ?? const {};
                    final type = item['type']?.toString();
                    final name = item['title']?.toString() ?? item['name']?.toString() ?? '';
                    final artistName =
                        (item['artist'] as Map?)?['name']?.toString() ?? '';
                    final thumbs = (item['thumbnails'] as List?) ?? const [];
                    final thumbUrl = thumbs.isNotEmpty
                        ? (thumbs.last as Map)['url']?.toString() ?? ''
                        : '';
                    final videoId = (item['id'] ?? item['videoId'])?.toString();
                    final playlistId = item['playlistId']?.toString();

                    return GestureDetector(
                      onTap: () async {
                        final provider = context.read<PlayerProvider>();

                        if (type == 'SONG') {
                          if (videoId == null || videoId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Không tìm thấy videoId')),
                            );
                            return;
                          }
                          // Phát 1 bài (radio mode: on)
                          await provider.playSingleById(videoId);

                          // Mở full player
                          await _safePush(
                            PlayerScreen(
                              videoIds: [videoId],
                              startIndex: 0,
                            ),
                          );
                        } else if (type == 'ALBUM' && playlistId != null) {
                          // Phát toàn bộ playlist (radio mode: off)
                          try {
                            final tracks = await _fetchPlaylist(playlistId);
                            if (tracks.isEmpty) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Playlist chưa có bài hoặc backend chưa trả songs[]'),
                                ),
                              );
                              return;
                            }
                            await provider.playPlaylist(tracks, startIndex: 0);
                            await _safePush(
                              PlayerScreen(
                                videoIds: tracks
                                    .map((e) => e['videoId'] as String)
                                    .toList(),
                                startIndex: 0,
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Lỗi tải playlist: $e')),
                            );
                          }
                        }
                      },
                      onLongPress: () {
                        // Quick actions
                        showModalBottomSheet(
                          context: context,
                          showDragHandle: true,
                          builder: (_) => SafeArea(
                            child: Wrap(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.play_arrow),
                                  title: const Text('Phát ngay'),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    final provider = context.read<PlayerProvider>();
                                    if (videoId != null && videoId.isNotEmpty) {
                                      await provider.playSingleById(videoId);
                                      if (context.mounted) {
                                        _safePush(PlayerScreen(
                                            videoIds: [videoId], startIndex: 0));
                                      }
                                    }
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.shuffle),
                                  title: const Text('Phát ngẫu nhiên 10 bài'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    if (allVideoIds.isNotEmpty) {
                                      final take = allVideoIds.length >= 10
                                          ? 10
                                          : allVideoIds.length;
                                      final list =
                                      List<String>.from(allVideoIds)
                                        ..shuffle();
                                      _safePush(PlayerScreen(
                                          videoIds: list.take(take).toList(),
                                          startIndex: 0));
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 148,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: _buildThumbCard(
                          imageUrl: thumbUrl,
                          title: name,
                          subtitle: artistName,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // for AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: () => _refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _selectedIndex == 0
          ? FutureBuilder<List<Map<String, dynamic>>>(
        future: _sectionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            // Loader full-screen lần đầu
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return _buildErrorUI(snapshot.error!);
          } else {
            final sections = snapshot.data!;
            return buildHomeTab(sections);
          }
        },
      )
          : _tabsPlaceholder[_selectedIndex],
      // Gộp NowPlayingBar + BottomNavigationBar (thay cho FAB)
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NowPlayingBar(), // thanh thông tin bài đang phát
          BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: Colors.redAccent,
            unselectedItemColor: Colors.grey,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
              BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Cục bộ'),
              BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Đã thích'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.queue_music), label: 'Danh sách'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Tài khoản'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
