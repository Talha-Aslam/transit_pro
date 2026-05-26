import 'package:flutter/material.dart';
import '../../app/route_service.dart';
import 'reports_screen.dart';
import 'roles_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _keyCtrl.text = RouteService.instance.apiKey ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          TextField(
            controller: _keyCtrl,
            decoration: const InputDecoration(labelText: 'Google Maps API Key'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              RouteService.instance.apiKey = _keyCtrl.text;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('API key saved (frontend-only)')),
              );
            },
            child: const Text('Save'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ReportsScreen())),
            child: const Text('Reports'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const RolesScreen())),
            child: const Text('User Roles'),
          ),
        ],
      ),
    );
  }
}
