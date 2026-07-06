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
  final LatLng _center = const LatLng(20.5937, 78.9629);

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    final localState = ref.watch(localDataProvider);
    final clusters = localState.clusters;

    // Dynamically build markers from local database clusters
    final Set<Marker> markers = clusters.map((c) {
      final lat = (c.centroid?['lat'] ?? 20.5937) as double;
      final lng = (c.centroid?['lng'] ?? 78.9629) as double;
      return Marker(
        markerId: MarkerId(c.id),
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(
          title: c.title,
          snippet: '${c.category} • ${c.submissionCount} requests',
        ),
      );
    }).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demand Hotspots'),
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
          // Google Map with dynamic markers
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 10.0,
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
                      'Currently tracking ${clusters.length} active demand clusters across Ward 4, Ward 1, and Village East.',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.circle, size: 12, color: Colors.red),
                        const SizedBox(width: 4),
                        const Text('High Priority (>80)'),
                        const SizedBox(width: 16),
                        Icon(Icons.circle, size: 12, color: Colors.orange[400]),
                        const SizedBox(width: 4),
                        const Text('Medium Priority'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search wards or villages...',
                          border: InputBorder.none,
                        ),
                        onChanged: (val) {
                          // Search filters can be implemented here
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
