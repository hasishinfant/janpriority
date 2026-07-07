import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/firebase_service.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localState = ref.watch(localDataProvider);
    final metadata = localState.mpMetadata;
    final demographics = localState.demographics;
    final works = localState.mpladsWorks;
    final clusters = localState.clusters;

    // A. Parse MP Fund Information
    final info = metadata['mp_info'] ?? {};
    final summary = metadata['fund_summary'] ?? {};
    final mpName = info['name'] ?? 'Shri Narayana Koragappa';
    final mpHouse = info['house'] ?? 'Rajya Sabha';
    final mpTerm = info['term'] ?? '2020-26';

    final allocated = (summary['allocated_amount_cr'] ?? 19.6).toDouble();
    final spent = (summary['total_expenditure_cr'] ?? 13.0).toDouble();
    final unspent = (summary['unspent_amount_cr'] ?? 6.6).toDouble();
    final paymentGap = (summary['payment_gap_pct'] ?? 79.6).toDouble();

    // B. Calculate SC/ST compliance meter
    double scStSpentLakh = 0.0;
    for (var w in works) {
      if (w['sc_st_tagged'] == true) {
        scStSpentLakh += (w['amount'] ?? 0.0).toDouble();
      }
    }
    final scStSpentCr = scStSpentLakh / 100.0; // 100 lakh = 1 Cr
    final scStCompliancePct = allocated > 0 ? (scStSpentCr / allocated) * 100 : 0.0;

    // C. Silent Signal calculation: Census villages with zero or low complaints
    final silentSignals = demographics.map((village) {
      final name = village['village_name'] as String;
      final code = village['location_code'] as String;
      final scRange = village['sc_population_pct_range'] as String?;
      final stRange = village['st_population_pct_range'] as String?;
      final school = village['schools_in_village_pp_p_m_s'] as String?;
      final medical = village['medical_facility_in_village'] as String?;
      
      // Count citizen submissions matching this village ward
      final reportCount = clusters
          .where((c) => c.ward.toLowerCase() == name.toLowerCase() || c.ward.toLowerCase() == code.toLowerCase())
          .fold<int>(0, (sum, c) => sum + c.submissionCount);

      // Need Indicator: composite index of SC/ST and facilities availability
      double scWeight = 0.0;
      if (scRange != null) {
        if (scRange.contains('21-30')) scWeight = 0.25;
        else if (scRange.contains('11-20')) scWeight = 0.15;
        else if (scRange.contains('5-10')) scWeight = 0.08;
      }
      
      double stWeight = 0.0;
      if (stRange != null && stRange.toLowerCase().contains('less than 5')) {
        stWeight = 0.03;
      }

      final hasNoMedical = medical == 'No';
      final hasNoSchool = school == 'No' || (school != null && school.contains('all 5-10km away'));
      
      // Gap index: no medical (+0.35), no school (+0.25), SC/ST percentage (+0.4)
      final needScore = (hasNoMedical ? 0.35 : 0.05) + 
                         (hasNoSchool ? 0.25 : 0.05) + 
                         ((scWeight + stWeight) * 1.5);
      
      // Participation rate (normalized count, max 100 for scaling)
      final participation = Math.min(reportCount / 100.0, 1.0);
      
      // Silent Signal = high need, low participation (potential digital divide)
      final silentSignalScore = needScore * (1.0 - participation);

      return {
        'name': name,
        'code': code,
        'sc': scRange ?? '0%',
        'st': stRange ?? '0%',
        'medical': medical ?? 'Unknown',
        'school': school ?? 'Unknown',
        'reports': reportCount,
        'score': silentSignalScore,
      };
    }).toList();

    // Sort by silent signal score descending
    silentSignals.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      appBar: AppBar(
        title: Text('$mpName ($mpHouse, $mpTerm)'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. MP Fund Utilization Panel
            Text(
              'MPLADS Fund Utilization Dashboard',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildStatCard(context, 'Allocated Amount', '₹${allocated.toStringAsFixed(2)} CR', Icons.account_balance, Colors.blue),
                _buildStatCard(context, 'Total Expenditure', '₹${spent.toStringAsFixed(2)} CR', Icons.trending_up, Colors.green),
                _buildStatCard(context, 'Unspent Balance', '₹${unspent.toStringAsFixed(2)} CR', Icons.account_balance_wallet, Colors.orange),
                _buildStatCard(context, 'Payment Gap', '${paymentGap.toStringAsFixed(1)}%', Icons.hourglass_empty, Colors.red),
              ],
            ),
            const SizedBox(height: 32),

            // 2. SC/ST Mandate Quota Compliance
            _buildComplianceProgressBar(context, scStSpentCr, scStCompliancePct),
            const SizedBox(height: 32),

            // 3. Yearly Trends and Silent Signals Panel
            isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildYearlyTrendsSection(context, metadata['yearly_trends']),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 4,
                        child: _buildSilentSignalsPanel(context, silentSignals),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildYearlyTrendsSection(context, metadata['yearly_trends']),
                      const SizedBox(height: 32),
                      _buildSilentSignalsPanel(context, silentSignals),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 14),
                ),
                Icon(icon, color: color, size: 24),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplianceProgressBar(BuildContext context, double spentCr, double compliancePct) {
    // 15% SC + 7.5% ST = 22.5% combined quota mandate
    const targetPct = 22.5;
    final relativeProgress = Math.min(compliancePct / targetPct, 1.0);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SC/ST Quota Compliance Mandate',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Statutory statutory requirement: 15% SC & 7.5% ST target allocation',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Text(
                  '${compliancePct.toStringAsFixed(2)}% achieved',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: relativeProgress,
              minHeight: 14,
              backgroundColor: Colors.grey[200],
              color: compliancePct >= targetPct ? Colors.green : Colors.indigo,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current Tagged Works: ₹${(spentCr * 100).toStringAsFixed(0)} Lakhs',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  'Statutory Mandate: ₹${(19.6 * 0.225).toStringAsFixed(2)} CR',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigo),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearlyTrendsSection(BuildContext context, List<dynamic>? trends) {
    if (trends == null || trends.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(child: Text('Yearly trends not available.')),
      );
    }

    final barGroups = List.generate(trends.length, (index) {
      final t = trends[index];
      final double works = (t['works'] as num).toDouble();
      final double amount = (t['amount_cr'] as num).toDouble();
      return BarChartGroupData(
        x: t['year'] as int,
        barRods: [
          BarChartRodData(toY: works, color: Colors.blue, width: 16, borderRadius: BorderRadius.circular(2)),
          BarChartRodData(toY: amount * 10.0, color: Colors.green, width: 16, borderRadius: BorderRadius.circular(2)), // Scale amount for visual balance
        ],
      );
    });

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yearly Performance & Spending Trends',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Comparing completed works count (Blue) vs Amount spent in CR x10 (Green)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  alignment: BarChartAlignment.spaceEvenly,
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(value.toInt().toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSilentSignalsPanel(BuildContext context, List<Map<String, dynamic>> signals) {
    // Filter down to the real "Silent Signals" — high need, zero complaints
    final filteredSignals = signals.where((s) => s['reports'] == 0).toList();

    return Card(
      elevation: 2,
      color: Colors.red[50]?.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red[100]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Silent Signal Panel',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.red[850]),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Hyperlocal Census gaps flagging underserved, low visibility areas with zero citizen submissions:',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const Divider(height: 24),
            filteredSignals.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: Text('No underserved areas flagged with zero complaints.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: Math.min(filteredSignals.length.toDouble(), 4).toInt(),
                    itemBuilder: (context, idx) {
                      final s = filteredSignals[idx];
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.gpp_maybe, color: Colors.red[800], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s['name'],
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[950], fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'SC Population: ${s['sc']} • ST Population: ${s['st']}',
                                    style: TextStyle(fontSize: 11, color: Colors.red[900]),
                                  ),
                                  Text(
                                    'Infrastructure: Medical: ${s['medical']} | School: ${s['school']}',
                                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red[100],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Underserved — Zero Complaints Received',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                                    ),
                                  )
                                ],
                              ),
                            ),
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
}

class Math {
  static double min(double a, double b) => a < b ? a : b;
}
