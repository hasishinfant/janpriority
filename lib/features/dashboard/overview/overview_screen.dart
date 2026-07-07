import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/firebase_service.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localState = ref.watch(localDataProvider);
    final constituency = localState.activeConstituency;
    final metadata = localState.mpMetadata;
    final demographics = localState.demographics;
    final works = localState.mpladsWorks;

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

    // B. Calculate SC/ST quota tagged works
    double scStSpentLakh = 0.0;
    for (var w in works) {
      if (w['sc_st_tagged'] == true) {
        scStSpentLakh += (w['amount'] ?? 0.0).toDouble();
      }
    }
    final scStSpentCr = scStSpentLakh / 100.0; // 100 Lakh = 1 Cr
    final scStCompliancePct = allocated > 0 ? (scStSpentCr / allocated) * 100 : 0.0;

    // C. Check if Urban or Rural Constituency
    final isUrban = constituency == 'Mumbai South Central' || constituency == 'Chennai North';

    final List<Map<String, dynamic>> silentSignals = [];
    if (isUrban) {
      // Slum-level sanitation gap Silent Signal panel
      for (var row in demographics) {
        if (row['type'] == 'slum') {
          silentSignals.add({
            'name': row['slum_name'] ?? 'Unknown Slum',
            'households': row['households_approx'] ?? 0,
            'population': row['slum_population_approx'] ?? 0,
            'gap_ratio': (row['sanitation_gap_ratio'] ?? 0.0).toDouble(),
            'is_rollup': row['is_rollup'] == true,
            'electricity': row['electricity_domestic_conn'] ?? 0,
            'water': row['public_water_tap_points'] ?? 0,
          });
        }
      }
      // Sort by sanitation gap ratio descending
      silentSignals.sort((a, b) => (b['gap_ratio'] as double).compareTo(a['gap_ratio'] as double));
    } else {
      // Village-level demographic gaps
      for (var row in demographics) {
        if (row['type'] != 'slum') {
          final name = row['village_name'] as String? ?? 'Unknown Village';
          final code = row['location_code'] as String? ?? '';
          final scRange = row['sc_population_pct_range'] as String?;
          final stRange = row['st_population_pct_range'] as String?;
          final school = row['schools_in_village_pp_p_m_s'] as String?;
          final medical = row['medical_facility_in_village'] as String?;

          double scWeight = 0.0;
          if (scRange != null) {
            if (scRange.contains('21-30') || scRange.contains('21_to_30')) scWeight = 0.25;
            else if (scRange.contains('11-20')) scWeight = 0.15;
            else if (scRange.contains('5-10') || scRange.contains('5_to_10')) scWeight = 0.08;
          }
          double stWeight = 0.0;
          if (stRange != null && (stRange.toLowerCase().contains('less than 5') || stRange.contains('less_than_5'))) {
            stWeight = 0.03;
          } else if (stRange != null && stRange.contains('21_to_30')) {
            stWeight = 0.25;
          }

          final hasNoMedical = medical == 'No';
          final hasNoSchool = school == 'No' || (school != null && school.contains('all 5-10km away')) || school == 'not_found_in_extracted_range';

          final needScore = (hasNoMedical ? 0.35 : 0.05) + 
                             (hasNoSchool ? 0.25 : 0.05) + 
                             ((scWeight + stWeight) * 1.5);

          silentSignals.add({
            'name': name,
            'code': code,
            'sc': scRange ?? '0%',
            'st': stRange ?? '0%',
            'medical': medical ?? 'Unknown',
            'school': school ?? 'Unknown',
            'score': needScore,
          });
        }
      }
      // Sort by need score descending
      silentSignals.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    }

    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      appBar: AppBar(
        title: Text('$mpName ($mpHouse)'),
        centerTitle: false,
        actions: [
          // Constituency Selector Dropdown
          Container(
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
            _buildComplianceProgressBar(context, scStSpentCr, scStCompliancePct, allocated),
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
                        child: _buildSilentSignalsPanel(context, silentSignals, isUrban),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildYearlyTrendsSection(context, metadata['yearly_trends']),
                      const SizedBox(height: 32),
                      _buildSilentSignalsPanel(context, silentSignals, isUrban),
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

  Widget _buildComplianceProgressBar(BuildContext context, double spentCr, double compliancePct, double allocated) {
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
                  'Statutory Mandate: ₹${(allocated * 0.225).toStringAsFixed(2)} CR',
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
        child: Card(
          child: Center(
            child: Text(
              'Yearly trends not available for this MP.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ),
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
          BarChartRodData(toY: amount * 10.0, color: Colors.green, width: 16, borderRadius: BorderRadius.circular(2)),
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

  Widget _buildSilentSignalsPanel(BuildContext context, List<Map<String, dynamic>> signals, bool isUrban) {
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
            Text(
              isUrban
                  ? 'Sanitation gap analysis: Slums with highest latrine deficit and zero complaints:'
                  : 'Census infrastructure gap analysis: Wards/Villages with highest priority need scores and zero complaints:',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const Divider(height: 24),
            signals.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: Text('No underserved areas flagged with zero complaints.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: Math.min(signals.length.toDouble(), 5).toInt(),
                    itemBuilder: (context, idx) {
                      final s = signals[idx];
                      
                      if (isUrban) {
                        final isRollup = s['is_rollup'] == true;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(isRollup ? Icons.domain : Icons.gpp_maybe, color: Colors.red[850], size: 20),
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
                                      'Households: ${s['households']} • Population: ${s['population']}',
                                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                                    ),
                                    Text(
                                      'Water points: ${s['water']} | Electricity: ${s['electricity']}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isRollup ? Colors.orange[100] : Colors.red[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isRollup 
                                            ? 'Ward-Level Rollup Bucket — Sanitation Gap: ${(s['gap_ratio'] * 100).toStringAsFixed(1)}%'
                                            : 'Sanitation Deficit: ${(s['gap_ratio'] * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 10, 
                                          fontWeight: FontWeight.bold, 
                                          color: isRollup ? Colors.orange[850] : Colors.red
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
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
                                      child: Text(
                                        'Underserved Village — Gap Priority: ${(s['score'] * 10).toStringAsFixed(1)}/10',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
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
