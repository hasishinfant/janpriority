import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/language_service.dart';
import '../../../shared/services/firebase_service.dart';
import '../../../shared/models/submission.dart';
import '../../../shared/models/cluster.dart';
import '../../../shared/models/ranking.dart';

// ─── Design Tokens ───────────────────────────────────────────────────────────
const _navy = Color(0xFF002244);
const _saffron = Color(0xFFFF9933);

class CitizenHomeScreen extends ConsumerStatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  ConsumerState<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends ConsumerState<CitizenHomeScreen> {
  int _currentTab = 0; // 0: My Submissions, 1: Community Board
  final Set<String> _disclosedNames = {};

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(selectedLanguageProvider);
    final localState = ref.watch(localDataProvider);
    final userPhone = ref.watch(userPhoneProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Government-Grade Header ──────────────────────────────────────
            _buildHeader(context, lang, localState, userPhone),

            // ── Offline / Reconnecting Banner ────────────────────────────────
            if (localState.isOffline)
              Container(
                width: double.infinity,
                color: const Color(0xFFFFEBEE),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        getLocalizedText('offline_banner', lang),
                        style: const TextStyle(
                          color: Color(0xFFC62828),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.read(localDataProvider.notifier).setOffline(false),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          color: Color(0xFFC62828),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Tab Bar ──────────────────────────────────────────────────────
            Container(
              color: Colors.white,
              child: Row(
                children: [
                  _TabItem(
                    label: getLocalizedText('my_submissions', lang),
                    icon: Icons.inbox_outlined,
                    isSelected: _currentTab == 0,
                    onTap: () => setState(() => _currentTab = 0),
                  ),
                  _TabItem(
                    label: getLocalizedText('community_board', lang),
                    icon: Icons.people_outline,
                    isSelected: _currentTab == 1,
                    onTap: () => setState(() => _currentTab = 1),
                  ),
                ],
              ),
            ),

            // ── Content Area ─────────────────────────────────────────────────
            Expanded(
              child: _currentTab == 0
                  ? _buildMySubmissionsTab(localState.submissions, localState, lang)
                  : _buildCommunityBoardTab(localState.clusters, localState.upvotedClusterIds, lang),
            ),

            // ── Bottom Action Bar (one-handed, 56dp min touch target) ─────────
            _buildBottomActionBar(context, lang, localState),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String lang,
    LocalDataState localState,
    String userPhone,
  ) {
    return Container(
      color: _navy,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          // Emblem
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _saffron, width: 2),
            ),
            child: const Icon(Icons.account_balance, size: 22, color: _navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'JanPriority',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  userPhone,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Connectivity Toggle (demo)
          Semantics(
            label: localState.isOffline ? 'Currently offline. Tap to go online.' : 'Currently online. Tap to simulate offline.',
            button: true,
            child: IconButton(
              icon: Icon(
                localState.isOffline ? Icons.signal_wifi_off : Icons.wifi,
                color: localState.isOffline ? _saffron : Colors.greenAccent,
                size: 22,
              ),
              tooltip: localState.isOffline ? getLocalizedText('offline', lang) : getLocalizedText('online', lang),
              onPressed: () {
                ref.read(localDataProvider.notifier).setOffline(!localState.isOffline);
              },
            ),
          ),
          // MP Dashboard
          Semantics(
            label: getLocalizedText('mp_dashboard', lang),
            button: true,
            child: IconButton(
              icon: const Icon(Icons.bar_chart_rounded, color: Colors.white70, size: 22),
              tooltip: getLocalizedText('mp_dashboard', lang),
              onPressed: () => context.go('/dashboard/overview'),
            ),
          ),
          // Logout
          Semantics(
            label: getLocalizedText('logout', lang),
            button: true,
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white70, size: 22),
              tooltip: getLocalizedText('logout', lang),
              onPressed: () => context.go('/'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context, String lang, LocalDataState localState) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Voice button — primary CTA
          Expanded(
            flex: 3,
            child: _ActionButton(
              icon: Icons.mic,
              label: getLocalizedText('voice', lang),
              color: const Color(0xFFE65100),
              filled: true,
              onTap: () => context.push('/citizen/submit?mode=voice'),
            ),
          ),
          const SizedBox(width: 10),
          // Text button
          Expanded(
            flex: 2,
            child: _ActionButton(
              icon: Icons.edit_outlined,
              label: getLocalizedText('text', lang),
              color: _navy,
              filled: false,
              onTap: () => context.push('/citizen/submit?mode=text'),
            ),
          ),
          const SizedBox(width: 10),
          // Photo button
          Expanded(
            flex: 2,
            child: _ActionButton(
              icon: Icons.camera_alt_outlined,
              label: getLocalizedText('photo', lang),
              color: _navy,
              filled: false,
              onTap: () => context.push('/citizen/submit?mode=photo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMySubmissionsTab(List<Submission> submissions, LocalDataState localState, String lang) {
    if (submissions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                getLocalizedText('no_submissions', lang),
                style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                getLocalizedText('no_submissions_hint', lang),
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: submissions.length,
      itemBuilder: (context, index) {
        final sub = submissions[index];
        final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(sub.createdAt);
        
        IconData modeIcon = Icons.text_fields;
        Color modeColor = Colors.teal;
        if (sub.mode == 'voice') {
          modeIcon = Icons.mic;
          modeColor = Colors.orange;
        } else if (sub.mode == 'photo') {
          modeIcon = Icons.camera_alt;
          modeColor = Colors.green;
        }

        // Find associated cluster and ranking to compute details
        final cluster = localState.clusters.firstWhere(
          (c) => c.id == sub.clusterId,
          orElse: () => Cluster(
            id: '', title: '', category: '', ward: '', submissionCount: 0,
            representativeSubmissionIds: [], status: '', createdAt: DateTime.now(), updatedAt: DateTime.now()
          )
        );

        final ranking = localState.rankings.firstWhere(
          (r) => r.clusterId == sub.clusterId,
          orElse: () => Ranking(
            clusterId: '', score: 0, rank: 0, explanation: '', weightsUsed: {}, computedAt: DateTime.now()
          )
        );

        // Determine Status Badge & Label
        String statusLabel = sub.status;
        Color statusBgColor = Colors.grey[100]!;
        Color statusTextColor = Colors.grey[700]!;

        if (sub.status == 'Submitted') {
          statusLabel = getLocalizedText('status_submitted', lang);
          statusBgColor = Colors.blue[50]!;
          statusTextColor = Colors.blue[700]!;
        } else if (sub.status == 'Under Review') {
          statusLabel = getLocalizedText('status_under_review', lang);
          statusBgColor = Colors.orange[50]!;
          statusTextColor = Colors.orange[800]!;
        } else if (sub.status == 'Processed' && cluster.id.isNotEmpty) {
          statusLabel = '${getLocalizedText('status_clustered_prefix', lang)} (${cluster.submissionCount} ${getLocalizedText('reports', lang)})';
          statusBgColor = Colors.purple[50]!;
          statusTextColor = Colors.purple[700]!;
        } else if (sub.status == 'Prioritized' && ranking.rank > 0) {
          statusLabel = '${getLocalizedText('status_prioritized_prefix', lang)} (#${ranking.rank})';
          statusBgColor = Colors.indigo[50]!;
          statusTextColor = Colors.indigo[700]!;
        } else if (sub.status == 'In Progress') {
          statusLabel = getLocalizedText('status_in_progress', lang);
          statusBgColor = Colors.amber[50]!;
          statusTextColor = Colors.amber[900]!;
        } else if (sub.status == 'Resolved') {
          statusLabel = getLocalizedText('status_resolved', lang);
          statusBgColor = Colors.green[50]!;
          statusTextColor = Colors.green[700]!;
        } else if (sub.status == 'rejected') {
          statusLabel = getLocalizedText('status_rejected', lang);
          statusBgColor = Colors.red[50]!;
          statusTextColor = Colors.red[700]!;
        }

        return Semantics(
          label: 'Submission: ${sub.originalText}. Status: $statusLabel.',
          button: true,
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            color: Colors.white,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showSubmissionDetailsBottomSheet(context, sub, cluster, ranking, lang),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mode icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: modeColor.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(modeIcon, color: modeColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.originalText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _CategoryChip(label: sub.category),
                              const SizedBox(width: 8),
                              Icon(Icons.location_on_outlined,
                                  size: 13, color: Colors.grey[500]),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  sub.extractedLocation?['village'] ??
                                      sub.extractedLocation?['ward'] ??
                                      'General',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formattedDate,
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSubmissionDetailsBottomSheet(
      BuildContext context, Submission sub, Cluster cluster, Ranking ranking, String lang) {
    final statusSteps = ['Submitted', 'Under Review', 'Clustered', 'Prioritized', 'In Progress', 'Resolved'];
    int currentStepIndex = 0;
    
    if (sub.status == 'Under Review') currentStepIndex = 1;
    else if (sub.status == 'Processed' || sub.status == 'Clustered') currentStepIndex = 2;
    else if (sub.status == 'Prioritized') currentStepIndex = 3;
    else if (sub.status == 'In Progress') currentStepIndex = 4;
    else if (sub.status == 'Resolved') currentStepIndex = 5;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    getLocalizedText('submission_details', lang),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Text Content
                  Text(
                    getLocalizedText('grievance_text', lang),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub.originalText,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),

                  // Metadata cards
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDetailBadge(getLocalizedText('category', lang), sub.category),
                      _buildDetailBadge(getLocalizedText('source_intake', lang), sub.mode.toUpperCase()),
                    ],
                  ),
                  const Divider(height: 32),

                  // Status flow visual step indicator
                  Text(
                    getLocalizedText('status_tracker', lang),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: List.generate(statusSteps.length, (idx) {
                      final stepName = statusSteps[idx];
                      final isPassed = idx <= currentStepIndex;
                      final isCurrent = idx == currentStepIndex;
                      
                      String detailSuffix = '';
                      if (stepName == 'Clustered' && cluster.id.isNotEmpty) {
                        detailSuffix = ' — ${getLocalizedText('reports', lang)}: ${cluster.submissionCount}';
                      } else if (stepName == 'Prioritized' && ranking.rank > 0) {
                        detailSuffix = ' — ${getLocalizedText('rank', lang)} #${ranking.rank} (${getLocalizedText('ai_justified', lang)})';
                      }

                      return Row(
                        children: [
                          Column(
                            children: [
                              Icon(
                                isPassed ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: isCurrent ? Colors.teal : (isPassed ? Colors.green : Colors.grey),
                                size: 24,
                              ),
                              if (idx < statusSteps.length - 1)
                                Container(width: 2, height: 24, color: isPassed ? Colors.green : Colors.grey[300]),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '$stepName$detailSuffix',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                color: isCurrent ? Colors.teal[800] : (isPassed ? Colors.black87 : Colors.grey),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                  const Divider(height: 32),

                  // AI Rank & justification detail
                  if (ranking.rank > 0) ...[
                    Text(
                      getLocalizedText('mp_justification', lang),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        ranking.explanation,
                        style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.purple[900]),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Linked pending MPLADS project alert
                  if (cluster.linkedMpladsWorkId != null) ...[
                    Text(
                      getLocalizedText('linked_project', lang),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        'Note: This request is located ${(cluster.linkedMpladsWorkDistance! * 1000).toStringAsFixed(0)}m from a pending MPLADS work: "${cluster.linkedMpladsWorkDesc}" (pending since ${cluster.linkedMpladsWorkDate}).',
                        style: TextStyle(fontSize: 14, color: Colors.amber[900]),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailBadge(String label, String value) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildCommunityBoardTab(List<Cluster> clusters, Set<String> upvotedIds, String lang) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: clusters.length,
      itemBuilder: (context, index) {
        final c = clusters[index];
        final hasUpvoted = upvotedIds.contains(c.id);
        final disclosed = _disclosedNames.contains(c.id);
        
        final pseudoHandle = 'Citizen_${c.id.substring(c.id.length - 4).toUpperCase()}';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_circle, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          disclosed ? 'Manav Nagpal (Disclosed)' : pseudoHandle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            color: disclosed ? Colors.teal[800] : Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Text(c.ward, style: TextStyle(color: Colors.teal[800], fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  c.title, 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                
                // Real Identity disclosure toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: disclosed,
                          activeColor: Colors.teal[800],
                          onChanged: (val) {
                            setState(() {
                              if (disclosed) {
                                _disclosedNames.remove(c.id);
                              } else {
                                _disclosedNames.add(c.id);
                              }
                            });
                          },
                        ),
                        Text(
                          getLocalizedText('disclose_name', lang),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                        ),
                      ],
                    ),
                    
                    // Voting Trigger with lightweight anti-astroturfing indicator
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            hasUpvoted ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                            color: hasUpvoted ? Colors.teal[800] : Colors.grey,
                            size: 24,
                          ),
                          onPressed: () {
                            ref.read(localDataProvider.notifier).toggleUpvote(c.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(getLocalizedText('vote_verified', lang)),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        Text(
                          '${c.submissionCount + (hasUpvoted ? 1 : 0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: hasUpvoted ? Colors.teal[800] : Colors.black87,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}

// ─── Supporting Widgets ───────────────────────────────────────────────────────

class _TabItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? _navy : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? _navy : Colors.grey[500],
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? _navy : Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label — submit $label complaint',
      button: true,
      child: Material(
        color: filled ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 56, // minimum 56dp touch target
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: filled ? null : Border.all(color: color.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: filled ? Colors.white : color, size: 20),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: filled ? Colors.white : color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  const _CategoryChip({required this.label});

  Color _colorForCategory(String cat) {
    switch (cat.toLowerCase()) {
      case 'water': return const Color(0xFF1565C0);
      case 'roads': return const Color(0xFF6D4C41);
      case 'electricity': return const Color(0xFFF57F17);
      case 'sanitation': return const Color(0xFF2E7D32);
      case 'education': return const Color(0xFF6A1B9A);
      case 'health': return const Color(0xFFC62828);
      default: return const Color(0xFF37474F);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForCategory(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

// _ModeButton removed — replaced by _ActionButton in the persistent bottom bar
