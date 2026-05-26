import 'package:flutter/material.dart';
import '../../app/parent_data_service.dart';

class StudentsScreen extends StatelessWidget {
  const StudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = ParentDataService.instance;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ValueListenableBuilder<List>(
        valueListenable: svc.children,
        builder: (_, list, __) {
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final c = list[i];
              return Card(
                child: ListTile(
                  title: Text(c.name),
                  subtitle: Text('${c.grade} · ${c.school}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
