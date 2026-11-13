import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/trip_session.dart';
import '../../map/trip_map_view.dart';
import '../../theme/app_theme.dart';
import 'trip_panel.dart';

/// The driver's round on the whole screen, with the next stop — or the
/// arrival card — over the bottom of the map, so a driver can run the round
/// from here without going back to the list.
class DriverTripMapScreen extends StatelessWidget {
  const DriverTripMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = TripSession.instance.controller;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live route'),
        backgroundColor: context.cardBgElevated,
        foregroundColor: context.textPrimary,
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          if (!c.isRunning) {
            return Center(
              child: Text(
                'No route running.',
                style: TextStyle(color: context.textSecondary),
              ),
            );
          }
          final arrived = c.phase == TripPhase.arrivedInstitute;
          return Stack(
            children: [
              Positioned.fill(
                child: TripMapView(controller: c, bottomPadding: 200),
              ),
              Positioned(
                left: 12,
                right: 12,
                top: 12,
                child: TripStatusBanners(controller: c),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  child: arrived
                      ? const _ArrivedNote()
                      : c.arrival != null
                      ? ArrivalCard(controller: c)
                      : NextStopCard(controller: c),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ArrivedNote extends StatelessWidget {
  const _ArrivedNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.success),
      ),
      child: Text(
        'Arrived at school. End the route from the Route tab.',
        style: TextStyle(color: context.textPrimary, fontSize: 13),
      ),
    );
  }
}
