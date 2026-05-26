import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'routes_editor.dart';
import 'drivers_screen.dart';
import 'buses_screen.dart';
import 'students_screen.dart';
import 'approvals_screen.dart';
import 'settings_screen.dart';

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _selected = 0;

  static const _titles = [
    'Dashboard',
    'Routes',
    'Drivers',
    'Buses',
    'Students',
    'Approvals',
    'Settings',
  ];

  late final List<Widget> _screens = [
    const DashboardScreen(),
    const RoutesEditorScreen(),
    const DriversScreen(),
    const BusesScreen(),
    const StudentsScreen(),
    const ApprovalsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selected]),
        backgroundColor: AppTheme.adminEmerald,
      ),
      body: _screens[_selected],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selected,
        selectedItemColor: AppTheme.adminEmerald,
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() => _selected = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dash'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Routes'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Drivers'),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus),
            label: 'Buses',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Students'),
          BottomNavigationBarItem(
            icon: Icon(Icons.pending_actions),
            label: 'Approvals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
