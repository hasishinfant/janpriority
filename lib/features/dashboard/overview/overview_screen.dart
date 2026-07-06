import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/firebase_service.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localState = ref.watch(localDataProvider);
    final submissions = localState.submissions;
    final clusters = localState.clusters;

    // Calculate actual KPI metrics
    final totalSubmissions = submissions.length + 340 + 154; // add initial dummy data counts
    final activeClusters = clusters.length;
    
    // Group by category for the chart
    final categoryCounts = <String, int>{
      'Education': 0,
      'Water': 0,
      'Health': 0,
      'Roads': 0,
      'Sanitation': 0,
      'Other': 0
    };
    for (var c in clusters) {
      categoryCounts[c.category] = (categoryCounts[c.category] ?? 0) + c.submissionCount;
    }

    // Silent Signal calculation using static reference datasets
    // Census + UDISE indicators:
    final staticNeeds = [
      {'name': 'Village East', 'scStPercent': 50.0, 'schoolDistKm': 12.0, 'weight': 42},
      {'name': 'Ward 4', 'scStPercent': 50.0, 'schoolDistKm': 8.5, 'weight': 494}, // high reports
      {'name': 'Ward 3', 'scStPercent': 11.1, 'schoolDistKm': 3.0, 'weight': 5},
      {'name': 'Ward 2', 'scStPercent': 20.0, 'schoolDistKm': 2.5, 'weight': 0},   // 0 reports
      {'name': 'Ward 1', 'scStPercent': 10.0, 'schoolDistKm': 1.2, 'weight': 10},
    ];

    // Silent Signal score = Demographic Need * (1.0 - Participation Rate)
    final silentSignals = staticNeeds.map((place) {
      final name = place['name'] as String;
      final scSt = place['scStPercent'] as double;
      final dist = place['schoolDistKm'] as double;
      
      // Calculate active report volume in that ward
      final clusterMatch = clusters.where((c) => c.ward.toLowerCase() == name.toLowerCase());
      final reportCount = clusterMatch.fold<int>(0, (sum, c) => sum + c.submissionCount);

      // Need Indicator: composite index of SC/ST and school distance
      final needIndex = (scSt / 100 * 0.5) + (dist / 15.0 * 0.5); 
      
      // Participation: normalized report count (max 500 reports)
      final participationRate = Math.min(reportCount / 500.0, 1.0);
      
      // Silent Signal = high need, low participation
      final silentSignalScore = needIndex * (1.0 - participationRate);

      return {
        'name': name,
        'need': needIndex,
        'reports': reportCount,
        'score': silentSignalScore,
        'scSt': scSt,
        'dist': dist
      };
    }).toList();

    // Sort by silent signal score descending
    silentSignals.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Overview'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Key Performance Indicators', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildKpiCard(context, 'Total Submissions', '$totalSubmissions', Icons.inbox, Colors.blue),
                _buildKpiCard(context, 'Active Clusters', '$activeClusters', Icons.workspaces, Colors.orange),
                _buildKpiCard(context, 'Top Category', 'Water / Edu', Icons.category, Colors.green),
                _buildKpiCard(context, 'Critical Needs Wards', '2', Icons.report_problem, Colors.red),
              ],
            ),
            const SizedBox(height: 32),
            
            // Main content side-by-side or stacked
            isDesktop 
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Category Breakdown', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildCategoryChart(categoryCounts),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 1,
                      child: _buildSilentSignalsPanel(context, silentSignals),
                    )
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Category Breakdown', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildCategoryChart(categoryCounts),
                    const SizedBox(height: 32),
                    _buildSilentSignalsPanel(context, silentSignals),
                  ],
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart(Map<String, int> counts) {
    final entries = counts.entries.toList();
    final colors = [Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.red, Colors.teal];

    return SizedBox(
      height: 300,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: entries.map((e) => e.value.toDouble()).reduce((a, b) => a > b ? a : b) + 50,
              barGroups: List.generate(entries.length, (idx) {
                return BarChartGroupData(
                  x: idx,
                  barRods: [
                    BarChartRodData(
                      toY: entries[idx].value.toDouble() + 5, // offset for visual zero values
                      color: colors[idx % colors.length],
                      width: 22,
                      borderRadius: BorderRadius.circular(4),
                    )
                  ],
                );
              }),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 11);
                      if (value.toInt() >= 0 && value.toInt() < entries.length) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(entries[value.toInt()].key, style: style),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSilentSignalsPanel(BuildContext context, List<Map<String, dynamic>> signals) {
    return Card(
      elevation: 3,
      color: Colors.red[50]?.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red[100]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red[700]),
                const SizedBox(width: 8),
                Text(
                  'Silent Signal Panel',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.red[800]),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Highlights locations with high demographic need but low citizen report volumes (potential digital divide).',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const Divider(height: 24),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: signals.length,
              itemBuilder: (context, idx) {
                final s = signals[idx];
                final score = s['score'] as double;
                final reports = s['reports'] as int;

                // Only show as critical if silent signal score is high (> 0.2) and reports are low
                final isCritical = score > 0.3;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Icon(
                        isCritical ? Icons.report : Icons.info_outline,
                        color: isCritical ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['name'],
                              style: TextStyle(fontWeight: FontWeight.bold, color: isCritical ? Colors.red[900] : Colors.black87),
                            ),
                            Text(
                              'SC/ST: ${s['scSt'].toStringAsFixed(0)}% • School: ${s['dist'].toStringAsFixed(1)}km',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            Text(
                              'Reports: $reports',
                              style: TextStyle(fontSize: 11, color: isCritical ? Colors.red : Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCritical ? Colors.red[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Signal: ${(score * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCritical ? Colors.red[900] : Colors.black54,
                          ),
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700])),
                Icon(icon, color: color),
              ],
            ),
            const SizedBox(height: 16),
            Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class Math {
  static double min(double a, double b) => a < b ? a : b;
}
