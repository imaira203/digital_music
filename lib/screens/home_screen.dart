import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'profile_screen.dart';
import 'player_screen.dart';

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

  Uri get _songsUri => Uri.parse('$_apiBase/songs');

  // --- State ---
  int _selectedIndex = 0;
  late Future<List<dynamic>> _songsFuture;

  // Danh sách videoId đã loại trùng (giữ thứ tự xuất hiện)
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
    _songsFuture = fetchSongs();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  // Kéo-để-làm-mới
  Future<void> _refresh() async {
    setState(() {
      _songsFuture = fetchSongs(force: true);
    });
    await _songsFuture;
  }

  Future<List<dynamic>> fetchSongs({bool force = false}) async {
    try {
      final response = await _client
          .get(_songsUri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final sections = _extractSections(decoded); // <- luôn trả List<dynamic>

      // Thu thập tất cả videoId từ ITEM type SONG, bỏ các section video/live
      final ids = LinkedHashSet<String>();
      for (final sec in sections) {
        final section = (sec as Map?) ?? const {};
        final title = section['title']?.toString() ?? '';
        if (title == "Music videos for you" || title == "Live performances") {
          continue;
        }
        final contents = section['contents'];
        final List listContents =
        contents is List ? contents : const <dynamic>[];

        for (final raw in listContents) {
          final item = (raw as Map?) ?? const {};
          if (item['type'] == 'SONG') {
            final vid = item['videoId']?.toString();
            if (vid != null && vid.isNotEmpty) {
              ids.add(vid);
            }
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

  /// Chuẩn hoá mọi kiểu JSON trả về về List<dynamic> các "section"
  List<dynamic> _extractSections(dynamic decoded) {
    if (decoded is List) return decoded;

    if (decoded is Map) {
      // Thử các key phổ biến như data/sections/items/contents
      for (final key in const ['sections', 'data', 'items', 'contents', 'result']) {
        final v = decoded[key];
        if (v is List) return v;
      }
      // Trường hợp server trả một section đơn lẻ: { title, contents: [...] }
      final hasSectionShape =
          decoded.containsKey('title') && decoded.containsKey('contents');
      if (hasSectionShape) return [decoded];
    }

    // Debug gợi ý dạng dữ liệu nhận về
    throw FormatException(
      'Phản hồi /songs không đúng định dạng mong đợi: ${decoded.runtimeType}',
    );
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
                _songsFuture = fetchSongs(force: true);
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

  Widget buildHomeTab(List<dynamic> sections) {
    final filteredSections = sections
        .where((s) =>
    s['title'] != "Music videos for you" &&
        s['title'] != "Live performances")
        .toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        key: _homeListKey,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filteredSections.length,
        itemBuilder: (context, index) {
          final section = filteredSections[index] as Map;
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
                    final name = item['name']?.toString() ?? '';
                    final artistName =
                        (item['artist'] as Map?)?['name']?.toString() ?? '';
                    final thumbs = (item['thumbnails'] as List?) ?? const [];
                    final thumbUrl = thumbs.isNotEmpty
                        ? (thumbs.last as Map)['url']?.toString() ?? ''
                        : '';
                    final videoId = item['videoId']?.toString();
                    final playlistId = item['playlistId']?.toString();

                    return GestureDetector(
                      onTap: () async {
                        if (type == 'SONG') {
                          if (videoId == null || videoId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Không tìm thấy videoId')),
                            );
                            return;
                          }
                          if (allVideoIds.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Chưa có danh sách phát')),
                            );
                            return;
                          }

                          // Tạo sublist quanh bài chọn
                          final songIndex = allVideoIds.indexOf(videoId);
                          if (songIndex < 0) {
                            // fallback: phát từ đầu danh sách
                            await _safePush(PlayerScreen(
                              videoIds: allVideoIds.take(10).toList(),
                              startIndex: 0,
                            ));
                            return;
                          }

                          final start =
                          (songIndex - 5).clamp(0, allVideoIds.length - 1);
                          final end =
                          (songIndex + 5).clamp(0, allVideoIds.length - 1);
                          final subList = allVideoIds.sublist(start, end + 1);
                          final newIndex = subList.indexOf(videoId);

                          await _safePush(
                            PlayerScreen(
                              videoIds: subList,
                              startIndex: newIndex,
                            ),
                          );
                        } else if (type == 'ALBUM' && playlistId != null) {
                          // TODO: Gọi API playlist để lấy danh sách videoId thực tế
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tính năng ALBUM sẽ sớm có 👀'),
                            ),
                          );
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
                                  onTap: () {
                                    Navigator.pop(context);
                                    if (videoId != null &&
                                        videoId.isNotEmpty) {
                                      _safePush(PlayerScreen(
                                          videoIds: [videoId],
                                          startIndex: 0));
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
          ? FutureBuilder<List<dynamic>>(
        future: _songsFuture,
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
      bottomNavigationBar: BottomNavigationBar(
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
      floatingActionButton: GestureDetector(
        onLongPress: () {
          // Long-press = Shuffle 10 bài
          if (allVideoIds.isEmpty) return;
          final take = allVideoIds.length >= 10 ? 10 : allVideoIds.length;
          final list = List<String>.from(allVideoIds)..shuffle();
          _safePush(
            PlayerScreen(videoIds: list.take(take).toList(), startIndex: 0),
          );
        },
        child: FloatingActionButton.extended(
          tooltip: 'Nhấn giữ để phát ngẫu nhiên',
          onPressed: () {
            if (allVideoIds.isNotEmpty) {
              _safePush(
                PlayerScreen(
                  videoIds: allVideoIds.take(10).toList(),
                  startIndex: 0,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chưa có dữ liệu bài hát')),
              );
            }
          },
          icon: const Icon(Icons.play_arrow),
          label: const Text('Phát'),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
