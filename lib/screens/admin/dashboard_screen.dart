import 'package:flutter/material.dart';
import '../../app/admin_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    AdminService.instance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final svc = AdminService.instance;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: svc.totalDrivers,
                  builder: (_, val, __) => _kpiCard('Drivers', val.toString()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: svc.totalBuses,
                  builder: (_, val, __) => _kpiCard('Buses', val.toString()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: svc.totalStudents,
                  builder: (_, val, __) => _kpiCard('Students', val.toString()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Pending pickup requests',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ValueListenableBuilder<List>(
              valueListenable: svc.pendingRequests,
              builder: (_, list, __) {
                if (list.isEmpty) return const Text('No pending requests');
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final item = list[i];
                    return Card(
                      child: ListTile(
                        title: Text(item.studentName ?? 'Unknown'),
                        subtitle: Text(item.currentStop ?? ''),
                        trailing: Text(item.status.toString().split('.').last),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
