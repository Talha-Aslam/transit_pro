import 'package:flutter/material.dart';
import '../../app/driver_data_service.dart';

class DriversScreen extends StatelessWidget {
  const DriversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = DriverDataService.instance;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ValueListenableBuilder(
        valueListenable: svc.driverInfo,
        builder: (_, driver, _) => ListView(
          children: [
            Card(
              child: ListTile(
                title: Text(driver.name),
                subtitle: Text('${driver.busNumber} · ${driver.route}'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {},
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Location sharing: ${svc.locationSharing.value ? 'ON' : 'OFF'}',
            ),
          ],
        ),
      ),
    );
  }
}
