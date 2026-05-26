import 'package:flutter/material.dart';
import '../../app/missed_bus_service.dart';

class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = MissedBusService.instance;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Driver incoming requests',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ValueListenableBuilder<List>(
              valueListenable: svc.driverIncomingRequests,
              builder: (_, list, _) {
                if (list.isEmpty) return const Text('No requests');
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final r = list[i];
                    return Card(
                      child: ListTile(
                        title: Text(r.studentName ?? 'Unknown'),
                        subtitle: Text('${r.currentStop} → ${r.destination}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => svc.acceptRequest(r.id),
                              child: const Text('Accept'),
                            ),
                            TextButton(
                              onPressed: () => svc.declineRequest(r.id),
                              child: const Text('Decline'),
                            ),
                          ],
                        ),
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
}
