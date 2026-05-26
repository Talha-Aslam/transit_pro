import 'package:flutter/material.dart';
import '../../models/route_data.dart';

class RoutesEditorScreen extends StatefulWidget {
  const RoutesEditorScreen({super.key});

  @override
  State<RoutesEditorScreen> createState() => _RoutesEditorScreenState();
}

class _RoutesEditorScreenState extends State<RoutesEditorScreen> {
  late RouteData _route;

  @override
  void initState() {
    super.initState();
    _route = MockRouteBuilder.buildMorningRoute();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            title: Text(_route.name),
            subtitle: Text('${_route.busNumber} — ${_route.driverName}'),
          ),
        ),
        const SizedBox(height: 12),
        ..._route.stops.map(
          (s) => Card(
            child: ListTile(
              title: Text(s.name),
              subtitle: Text('${s.scheduledTime} · ${s.studentCount} students'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editStop(s),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _editStop(StopData stop) {
    final nameCtrl = TextEditingController(text: stop.name);
    final timeCtrl = TextEditingController(text: stop.scheduledTime);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Stop'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: timeCtrl,
              decoration: const InputDecoration(labelText: 'Time'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                // Replace the stop immutably since StopData fields are final.
                final idx = _route.stops.indexWhere(
                  (s) =>
                      s.name == stop.name &&
                      s.scheduledTime == stop.scheduledTime,
                );
                if (idx >= 0) {
                  final updatedStop = StopData(
                    name: nameCtrl.text,
                    location: stop.location,
                    scheduledTime: timeCtrl.text,
                    studentCount: stop.studentCount,
                    note: stop.note,
                    status: stop.status,
                  );
                  final newStops = List<StopData>.from(_route.stops)
                    ..removeAt(idx)
                    ..insert(idx, updatedStop);
                  _route = RouteData(
                    id: _route.id,
                    name: _route.name,
                    busNumber: _route.busNumber,
                    driverName: _route.driverName,
                    stops: newStops,
                    polylinePoints: _route.polylinePoints,
                  );
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
