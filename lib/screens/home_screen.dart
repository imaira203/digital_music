import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'profile_screen.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late Future<List<dynamic>> _songsFuture;

  // Lưu tất cả videoIds từ dữ liệu
  List<String> allVideoIds = [];

  static final List<Widget> _tabsPlaceholder = <Widget>[
    Center(child: CircularProgressIndicator()), // Sẽ thay khi load xong
    Center(child: Text('Nhạc cục bộ')),
    Center(child: Text('Đã thích')),
    Center(child: Text('Danh sách phát')),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _songsFuture = fetchSongs();
  }

  Future<List<dynamic>> fetchSongs() async {
    final response = await http.get(Uri.parse('http://localhost:8789/songs'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Thu thập tất cả videoId từ SONG
      allVideoIds.clear();
      for (var section in data) {
        if (section['title'] != "Music videos for you" && section['title'] != "Live performances") {
          for (var item in section['contents']) {
            if (item['type'] == 'SONG' && item['videoId'] != null) {
              allVideoIds.add(item['videoId']);
            }
          }
        }
      }

      return data;
    } else {
      throw Exception('Failed to load songs');
    }
  }

  Widget buildHomeTab(List<dynamic> sections) {
    final filteredSections = sections.where((s) => s['title'] != "Music videos for you" && s['title'] != "Live performances").toList();
    return ListView.builder(
      itemCount: filteredSections.length,
      itemBuilder: (context, index) {
        final section = filteredSections[index];
        final title = section['title'];
        final contents = section['contents'] as List<dynamic>;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: contents.length,
                itemBuilder: (context, idx) {
                  final item = contents[idx];
                  final name = item['name'];
                  final artistName = item['artist']?['name'] ?? '';
                  final thumbUrl = (item['thumbnails'] as List).isNotEmpty
                      ? item['thumbnails'].last['url']
                      : '';

                  return GestureDetector(
                    onTap: () {
                      if (item['type'] == 'SONG' && item['videoId'] != null) {
                        // Trường hợp 2: User chọn một bài bất kỳ
                        final songIndex = allVideoIds.indexOf(item['videoId']);
                        final start = (songIndex - 5).clamp(0, allVideoIds.length - 1);
                        final end = (songIndex + 5).clamp(0, allVideoIds.length - 1);

                        // Danh sách 11 bài xung quanh bài đã chọn
                        final subList = allVideoIds.sublist(start, end + 1);

                        // Vị trí startIndex mới trong subList
                        final newIndex = subList.indexOf(item['videoId']);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlayerScreen(
                              videoIds: subList,
                              startIndex: newIndex, // ✅ đúng vị trí trong danh sách mới
                            ),
                          ),
                        );
                      } else if (item['type'] == 'ALBUM' &&
                          item['playlistId'] != null) {

                        // TODO: fetch playlist details để lấy videoIds thực tế
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlayerScreen(
                              videoIds: [], // Load playlist thực tế ở đây
                              startIndex: 0,
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                thumbUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            artistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedIndex == 0
          ? FutureBuilder<List<dynamic>>(
        future: _songsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
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
          BottomNavigationBarItem(icon: Icon(Icons.queue_music), label: 'Danh sách'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Tài khoản'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (allVideoIds.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PlayerScreen(
                      videoIds: allVideoIds.take(10).toList(),
                      startIndex: 0,
                    ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chưa có dữ liệu bài hát')),
            );
          }
        },
        child: const Icon(Icons.play_arrow),
      ),
    );
  }
}
