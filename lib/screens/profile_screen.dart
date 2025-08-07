import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        CircleAvatar(radius: 50, backgroundColor: Colors.red),
        SizedBox(height: 16),
        Center(child: Text('Tên tài khoản', style: TextStyle(fontSize: 18))),
        Divider(),
        ListTile(
          leading: Icon(Icons.favorite),
          title: Text('Danh sách đã thích'),
        ),
        ListTile(
          leading: Icon(Icons.queue_music),
          title: Text('Danh sách phát đã tạo'),
        ),
        ListTile(
          leading: Icon(Icons.add),
          title: Text('Tạo danh sách mới'),
        ),
      ],
    );
  }
}
