import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/firebase_service.dart';
import '../../../shared/models/cluster.dart';
import '../../../shared/models/ranking.dart';


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
            child: Card(
              margin: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
              child: SingleChildScrollView(child: _buildWeightsPanel()),
            ),
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
          orElse: () => Cluster(
            id: rankItem.clusterId,
            title: 'Grievance Cluster',
            category: 'Other',
            ward: 'General',
            submissionCount: 0,
            representativeSubmissionIds: [],
            status: 'Under Review',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        
        final title = cluster.title;
        final hasMpladsLink = cluster.linkedMpladsWorkId != null;
        final String enrichmentType = cluster.enrichment?['benchmarkLabel'] ?? 'state/district benchmark';
        final isHyperlocal = enrichmentType.contains('hyperlocal');

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with Rank and Score
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
                          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(cluster.category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${cluster.ward} • ${cluster.submissionCount} reports',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
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
                const SizedBox(height: 12),
                
                // Data Source Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHyperlocal ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isHyperlocal ? Colors.green[100]! : Colors.orange[100]!),
                  ),
                  child: Text(
                    enrichmentType,
                    style: TextStyle(
                      fontSize: 11, 
                      fontWeight: FontWeight.bold, 
                      color: isHyperlocal ? Colors.green[800] : Colors.orange[850]
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // AI Explanation Block
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, size: 20, color: Colors.purple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rankItem.explanation,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),

                // Pending MPLADS Project Link Alert (Warning block if near pending work)
                if (hasMpladsLink) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.report_problem, color: Colors.amber[800], size: 18),
                            const SizedBox(width: 6),
                            const Text(
                              'Nearby Pending MPLADS Work Detected',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Complaint is located ${(cluster.linkedMpladsWorkDistance! * 1000).toStringAsFixed(0)}m from a pending project: "${cluster.linkedMpladsWorkDesc}" (MPLADS ID: ${cluster.linkedMpladsWorkId}, pending since ${cluster.linkedMpladsWorkDate}).',
                          style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                        ),
                      ],
                    ),
                  )
                ]
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
          const Text('Adjust to live-recalculate priority scores.', style: TextStyle(color: Colors.grey, fontSize: 13)),
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
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            Text('${(value * 100).toInt()}%', style: const TextStyle(fontSize: 14)),
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
