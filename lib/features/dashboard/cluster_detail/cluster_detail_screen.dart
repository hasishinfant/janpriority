import 'package:flutter/material.dart';

class ClusterDetailScreen extends StatelessWidget {
  const ClusterDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cluster Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Govt School Primary Upgrade', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            const Text('AI Explanation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Ranked #1 because 340 citizens raised this, the school is 42% over its rated capacity, and no funds are currently allocated to address it. Most requests came from parents in Ward 4 highlighting lack of clean water.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Evidence & Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• 340 Citizen mentions'),
                    Text('• Nearest alternative school: 8km away'),
                    Text('• Ward Budget remaining: ₹40,00,000'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(onPressed: () {}, child: const Text('Mark Under Review')),
                const SizedBox(width: 16),
                FilledButton(onPressed: () {}, child: const Text('Approve Project')),
              ],
            )
          ],
        ),
      ),
    );
  }
}
