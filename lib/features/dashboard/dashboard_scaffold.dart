import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardScaffold extends StatelessWidget {
  final Widget child;
  const DashboardScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Basic responsive layout
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _buildNavigationRail(context),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('JanPriority Dashboard')),
      drawer: Drawer(child: _buildNavigationList(context)),
      body: child,
    );
  }

  Widget _buildNavigationRail(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return NavigationRail(
      selectedIndex: _getSelectedIndex(location),
      onDestinationSelected: (idx) => _navigateToIndex(context, idx),
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Overview')),
        NavigationRailDestination(icon: Icon(Icons.map), label: Text('Hotspots')),
        NavigationRailDestination(icon: Icon(Icons.format_list_numbered), label: Text('Rankings')),
      ],
    );
  }

  Widget _buildNavigationList(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _getSelectedIndex(location);

    return ListView(
      children: [
        const DrawerHeader(child: Center(child: Text('MP Office\nJanPriority', textAlign: TextAlign.center, style: TextStyle(fontSize: 24)))),
        ListTile(
          leading: const Icon(Icons.dashboard),
          title: const Text('Overview'),
          selected: selectedIndex == 0,
          onTap: () { Navigator.pop(context); _navigateToIndex(context, 0); },
        ),
        ListTile(
          leading: const Icon(Icons.map),
          title: const Text('Hotspots'),
          selected: selectedIndex == 1,
          onTap: () { Navigator.pop(context); _navigateToIndex(context, 1); },
        ),
        ListTile(
          leading: const Icon(Icons.format_list_numbered),
          title: const Text('Rankings'),
          selected: selectedIndex == 2,
          onTap: () { Navigator.pop(context); _navigateToIndex(context, 2); },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.swap_horiz),
          title: const Text('Go to Citizen App'),
          onTap: () { Navigator.pop(context); context.go('/citizen/home'); },
        ),
      ],
    );
  }

  int _getSelectedIndex(String location) {
    if (location.startsWith('/dashboard/overview')) return 0;
    if (location.startsWith('/dashboard/hotspots')) return 1;
    if (location.startsWith('/dashboard/rankings')) return 2;
    return 0;
  }

  void _navigateToIndex(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/dashboard/overview'); break;
      case 1: context.go('/dashboard/hotspots'); break;
      case 2: context.go('/dashboard/rankings'); break;
    }
  }
}
