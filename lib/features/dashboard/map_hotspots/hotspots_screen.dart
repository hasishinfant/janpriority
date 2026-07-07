import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../shared/services/firebase_service.dart';

class HotspotsScreen extends ConsumerStatefulWidget {
  const HotspotsScreen({super.key});

  @override
  ConsumerState<HotspotsScreen> createState() => _HotspotsScreenState();
}

class _HotspotsScreenState extends ConsumerState<HotspotsScreen> {
  GoogleMapController? mapController;
  
  // Center camera on Sulikere / Kommaghatta, Bangalore South area where census villages are located
  final LatLng _center = const LatLng(12.9126, 77.4628);

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    final localState = ref.watch(localDataProvider);
    final clusters = localState.clusters;
    final mpladsWorks = localState.mpladsWorks;

    final Set<Marker> markers = {};

    // 1. Build markers for Citizen submission clusters
    for (var c in clusters) {
      final lat = (c.centroid?['lat'] ?? 12.9126) as double;
      final lng = (c.centroid?['lng'] ?? 77.4628) as double;
      
      markers.add(
        Marker(
          markerId: MarkerId('cluster_${c.id}'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: 'Citizen Demand: ${c.title}',
            snippet: '${c.category} • ${c.submissionCount} requests here',
          ),
        ),
      );
    }

    // 2. Build markers for MPLADS Works (color-coded by status)
    for (var w in mpladsWorks) {
      final lat = w['lat'] as double?;
      final lng = w['lng'] as double?;
      if (lat == null || lng == null) continue;

      final status = w['status'] as String? ?? 'recommended';
      final String id = w['id'] as String? ?? '';
      final String desc = w['work_description'] as String? ?? '';
      final String category = w['category'] as String? ?? '';
      final double amount = (w['amount'] ?? 0.0).toDouble();

      double hue = BitmapDescriptor.hueRed;
      if (status == 'completed') {
        hue = BitmapDescriptor.hueGreen;
      } else if (status == 'in_progress') {
        hue = BitmapDescriptor.hueOrange;
      }

      markers.add(
        Marker(
          markerId: MarkerId('mplads_$id'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: 'MPLADS: $id (${status.toUpperCase()})',
            snippet: '$category • ₹${amount.toStringAsFixed(0)} Lakhs • $desc',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('MPLADS & Citizen Hotspots'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 12.5,
            ),
            markers: markers,
          ),
          
          // Map overlay card to show stats
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interactive Heatmap Density',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Displaying ${clusters.length} Citizen Grievance Hotspots alongside ${mpladsWorks.where((w) => w['lat'] != null).length} geocoded MPLADS Projects.',
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildLegendItem(Icons.circle, Colors.blueAccent, 'Citizen Grievances'),
                        _buildLegendItem(Icons.circle, Colors.green, 'Completed Works'),
                        _buildLegendItem(Icons.circle, Colors.orange, 'In-Progress Works'),
                        _buildLegendItem(Icons.circle, Colors.red, 'Pending Recommended'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
