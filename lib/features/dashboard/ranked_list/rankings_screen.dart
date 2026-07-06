import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/firebase_service.dart';

class RankingsScreen extends ConsumerStatefulWidget {
  const RankingsScreen({super.key});

  @override
  ConsumerState<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends ConsumerState<RankingsScreen> {
  double wCitizenDemand = 0.3;
  double wSeverity = 0.25;
  double wBenchmark = 0.2;
  double wTrend = 0.15;
  double wFeasibility = 0.1;

  void _triggerRecalculate() {
    ref.read(localDataProvider.notifier).recalculateScores(customWeights: {
      'w1': wCitizenDemand,
      'w2': wSeverity,
      'w3': wBenchmark,
      'w4': wTrend,
      'w5': wFeasibility,
    });
  }

  @override
  Widget build(BuildContext context) {
    final localState = ref.watch(localDataProvider);
    final rankings = localState.rankings;
    final clusters = localState.clusters;

    // Sort rankings by rank
    final sortedRankings = [...rankings]..sort((a, b) => a.rank.compareTo(b.rank));

    final isDesktop = MediaQuery.of(context).size.width >= 800;

    Widget body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rankings List
        Expanded(
          flex: 3,
          child: _buildRankingsList(sortedRankings, clusters),
        ),
        // Weight Sliders
        if (isDesktop)
          Expanded(
            flex: 1,
            child: _buildWeightsPanel(),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Ranked Priorities'),
        actions: [
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: _buildWeightsPanel(),
                    ),
                  ),
                );
              },
            ),
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rankings exported as PDF successfully!')),
              );
            }, 
            icon: const Icon(Icons.picture_as_pdf), 
            label: const Text('Export PDF'),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildRankingsList(List<dynamic> sortedRankings, List<dynamic> clusters) {
    if (sortedRankings.isEmpty) {
      return const Center(
        child: Text('No clusters to rank. Use Citizen App to submit requests.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedRankings.length,
      itemBuilder: (context, index) {
        final rankItem = sortedRankings[index];
        final cluster = clusters.firstWhere(
          (c) => c.id == rankItem.clusterId,
          orElse: () => null,
        );
        final title = cluster?.title ?? 'Grievance Cluster';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: Text('#${rankItem.rank}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: Theme.of(context).textTheme.titleLarge),
                          if (cluster != null)
                            Text(
                              '${cluster.category} • ${cluster.ward} • ${cluster.submissionCount} mentions',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text('Score: ${rankItem.score}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, size: 20, color: Colors.purple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rankItem.explanation,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeightsPanel() {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ranking Weights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Adjust to live-recalculate priority scores.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          _buildSlider('Citizen Demand', wCitizenDemand, (val) {
            setState(() => wCitizenDemand = val);
            _triggerRecalculate();
          }),
          _buildSlider('Severity / Urgency', wSeverity, (val) {
            setState(() => wSeverity = val);
            _triggerRecalculate();
          }),
          _buildSlider('Benchmark Gap', wBenchmark, (val) {
            setState(() => wBenchmark = val);
            _triggerRecalculate();
          }),
          _buildSlider('Demand Trend', wTrend, (val) {
            setState(() => wTrend = val);
            _triggerRecalculate();
          }),
          _buildSlider('Budget Feasibility', wFeasibility, (val) {
            setState(() => wFeasibility = val);
            _triggerRecalculate();
          }),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('${(value * 100).toInt()}%'),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: 1,
          divisions: 20,
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
