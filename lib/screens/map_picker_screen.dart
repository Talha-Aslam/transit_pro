import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initial;
  const MapPickerScreen({super.key, this.initial});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late LatLng _selected;
  GoogleMapController? _controller;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _selected =
        widget.initial ?? const LatLng(31.5204, 74.3587); // default Lahore
  }

  void _onMapTap(LatLng pos) {
    setState(() => _selected = pos);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select location'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            child: Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _selected, zoom: 15),
            onMapCreated: (c) async {
              _controller = c;
              // Try to query visible region to determine if tiles are available.
              try {
                await _controller!.getVisibleRegion();
                if (mounted) setState(() => _mapReady = true);
              } catch (_) {
                if (mounted) setState(() => _mapReady = false);
              }
            },
            onTap: _onMapTap,
            markers: {
              Marker(markerId: const MarkerId('selected'), position: _selected),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          if (!_mapReady)
            Positioned(
              left: 16,
              right: 16,
              top: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Map tiles not available. Ensure your Google Maps API key and billing are configured for this app.',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_selected.latitude.toStringAsFixed(6)}, ${_selected.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
