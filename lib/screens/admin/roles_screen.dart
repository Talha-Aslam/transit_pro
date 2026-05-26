import 'package:flutter/material.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  final _users = [
    {'name': 'Sarah Johnson', 'role': 'parent'},
    {'name': 'Ahmed Raza', 'role': 'driver'},
    {'name': 'Admin User', 'role': 'admin'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (_, i) {
          final u = _users[i];
          return Card(
            child: ListTile(
              title: Text(u['name']!),
              subtitle: Text('Role: ${u['role']}'),
              trailing: PopupMenuButton<String>(
                onSelected: (sel) => setState(() => u['role'] = sel),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'parent', child: Text('parent')),
                  PopupMenuItem(value: 'driver', child: Text('driver')),
                  PopupMenuItem(value: 'student', child: Text('student')),
                  PopupMenuItem(value: 'admin', child: Text('admin')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
