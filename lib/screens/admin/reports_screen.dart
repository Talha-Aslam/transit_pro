import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ListView(
        children: [
          const ListTile(title: Text('Trip Metrics')),
          Card(
            child: ListTile(
              title: const Text('Export trip history (CSV)'),
              trailing: ElevatedButton(
                onPressed: () {},
                child: const Text('Export'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Attendance & payments'),
              trailing: ElevatedButton(
                onPressed: () {},
                child: const Text('Generate'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
