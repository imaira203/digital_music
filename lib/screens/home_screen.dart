import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _tabs = <Widget>[
    Center(child: Text('Đề xuất - Dữ liệu từ API')),
    Center(child: Text('Nhạc cục bộ')),
    Center(child: Text('Đã thích')),
    Center(child: Text('Danh sách phát')),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_selectedIndex],
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
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PlayerScreen(videoId: [ 'oLMKcI-VNzc', '8u11maZlGXY'],)));
        },
        child: const Icon(Icons.play_arrow),
      ),
    );
  }
}
