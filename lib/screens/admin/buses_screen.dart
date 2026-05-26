import 'package:flutter/material.dart';
import '../../models/route_data.dart';

class BusesScreen extends StatelessWidget {
  const BusesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final route = MockRouteBuilder.buildMorningRoute();
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ListView(
        children: [
          Card(
            child: ListTile(
              title: Text(route.busNumber),
              subtitle: Text(route.driverName),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {},
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Assigned route: ${route.name}'),
        ],
      ),
    );
  }
}
