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

  LatLng _getCenter(String constituency) {
    switch (constituency) {
      case 'Bangalore South': return const LatLng(12.9126, 77.4628);
      case 'Kozhikode': return const LatLng(11.2588, 75.7804);
      case 'Mumbai South Central': return const LatLng(19.0178, 72.8478);
      case 'Chennai North': return const LatLng(13.1145, 80.2878);
      default: return const LatLng(12.9126, 77.4628);
    }
  }

  double _getZoom(String constituency) {
    switch (constituency) {
      case 'Bangalore South': return 12.5;
      case 'Kozhikode': return 12.0;
      case 'Mumbai South Central': return 12.0;
      case 'Chennai North': return 12.0;
      default: return 12.5;
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    final localState = ref.watch(localDataProvider);
    final constituency = localState.activeConstituency;
    final clusters = localState.clusters;
    final mpladsWorks = localState.mpladsWorks;

    // Reactively listen to constituency switches to pan the camera
    ref.listen<LocalDataState>(localDataProvider, (prev, next) {
      if (prev?.activeConstituency != next.activeConstituency) {
        final LatLng target = _getCenter(next.activeConstituency);
        final double zoom = _getZoom(next.activeConstituency);
        mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
      }
    });

    final Set<Marker> markers = {};

    // 1. Build markers for Citizen submission clusters
    for (var c in clusters) {
      final lat = (c.centroid?['lat'] ?? _getCenter(constituency).latitude) as double;
      final lng = (c.centroid?['lng'] ?? _getCenter(constituency).longitude) as double;
      
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
        title: Text('Demand Hotspots: $constituency'),
        actions: [
          // Constituency Selector Dropdown
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.teal[200]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: constituency,
                dropdownColor: Colors.white,
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[900], fontSize: 14),
                items: ['Bangalore South', 'Kozhikode', 'Mumbai South Central', 'Chennai North']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(localDataProvider.notifier).setConstituency(val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _getCenter(constituency),
              zoom: _getZoom(constituency),
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
                      'Displaying ${clusters.length} Citizen Grievance Hotspots alongside ${mpladsWorks.where((w) => w['lat'] != null).length} geocoded MPLADS Projects for $constituency.',
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
