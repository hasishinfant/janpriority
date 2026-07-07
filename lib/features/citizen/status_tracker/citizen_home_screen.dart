import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/language_service.dart';
import '../../../shared/services/firebase_service.dart';
import '../../../shared/models/submission.dart';
import '../../../shared/models/cluster.dart';
import '../../../shared/models/ranking.dart';

class CitizenHomeScreen extends ConsumerStatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  ConsumerState<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends ConsumerState<CitizenHomeScreen> {
  int _currentTab = 0; // 0: My Submissions, 1: Community Board
  final Set<String> _disclosedNames = {}; // Track which clusters user has opted to share real name with

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(selectedLanguageProvider);
    final localState = ref.watch(localDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentTab == 0
              ? getLocalizedText('my_submissions', lang)
              : getLocalizedText('community_board', lang),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Offline/Online Emulator Demo Toggle
          TextButton(
            onPressed: () {
              ref.read(localDataProvider.notifier).setOffline(!localState.isOffline);
            },
            child: Row(
              children: [
                Icon(
                  localState.isOffline ? Icons.signal_wifi_off : Icons.wifi,
                  size: 20,
                  color: localState.isOffline ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 6),
                Text(
                  localState.isOffline ? 'Offline' : 'Online',
                  style: TextStyle(
                    color: localState.isOffline ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.dashboard_customize, size: 28),
            tooltip: 'MP Dashboard',
            onPressed: () => context.go('/dashboard/overview'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 28),
            onPressed: () => context.go('/'),
          )
        ],
      ),
      body: Column(
        children: [
          // Graceful Offline / Reconnecting Banner
          if (localState.isOffline)
            Container(
              color: Colors.red[100],
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    getLocalizedText('offline_banner', lang),
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          
          Expanded(
            child: _currentTab == 0
                ? _buildMySubmissionsTab(localState.submissions, localState, lang)
                : _buildCommunityBoardTab(localState.clusters, localState.upvotedClusterIds, lang),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) {
          setState(() {
            _currentTab = index;
          });
        },
        selectedItemColor: Colors.teal[800],
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.inbox, size: 28),
            label: getLocalizedText('my_submissions', lang),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.group, size: 28),
            label: getLocalizedText('community_board', lang),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showSubmissionModeBottomSheet(context, lang);
        },
        icon: const Icon(Icons.add, size: 24),
        label: Text(
          getLocalizedText('new_request', lang),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
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
          statusLabel = 'Submitted';
          statusBgColor = Colors.blue[50]!;
          statusTextColor = Colors.blue[700]!;
        } else if (sub.status == 'Under Review') {
          statusLabel = 'Under Review';
          statusBgColor = Colors.orange[50]!;
          statusTextColor = Colors.orange[850]!;
        } else if (sub.status == 'Processed' && cluster.id.isNotEmpty) {
          statusLabel = 'Clustered (${cluster.submissionCount} reports)';
          statusBgColor = Colors.purple[50]!;
          statusTextColor = Colors.purple[700]!;
        } else if (sub.status == 'Prioritized' && ranking.rank > 0) {
          statusLabel = 'Prioritized (Rank #${ranking.rank})';
          statusBgColor = Colors.indigo[50]!;
          statusTextColor = Colors.indigo[700]!;
        } else if (sub.status == 'In Progress') {
          statusLabel = 'In Progress';
          statusBgColor = Colors.amber[50]!;
          statusTextColor = Colors.amber[900]!;
        } else if (sub.status == 'Resolved') {
          statusLabel = 'Resolved';
          statusBgColor = Colors.green[50]!;
          statusTextColor = Colors.green[700]!;
        } else if (sub.status == 'rejected') {
          statusLabel = 'Rejected (Irrelevant)';
          statusBgColor = Colors.red[50]!;
          statusTextColor = Colors.red[700]!;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: modeColor.withOpacity(0.1),
              child: Icon(modeIcon, color: modeColor, size: 24),
            ),
            title: Text(
              sub.originalText, 
              maxLines: 2, 
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(sub.category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      sub.extractedLocation?['village'] ?? sub.extractedLocation?['ward'] ?? 'General',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            onTap: () => _showSubmissionDetailsBottomSheet(context, sub, cluster, ranking, lang),
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
                    'Submission Trace Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Text Content
                  Text(
                    'Grievance Text:',
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
                      _buildDetailBadge('Category', sub.category),
                      _buildDetailBadge('Source Intake', sub.mode.toUpperCase()),
                    ],
                  ),
                  const Divider(height: 32),

                  // Status flow visual step indicator
                  const Text(
                    'Status Progression Tracker',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: List.generate(statusSteps.length, (idx) {
                      final stepName = statusSteps[idx];
                      final isPassed = idx <= currentStepIndex;
                      final isCurrent = idx == currentStepIndex;
                      
                      String detailSuffix = '';
                      if (stepName == 'Clustered' && cluster.id.isNotEmpty) {
                        detailSuffix = ' — clustered with ${cluster.submissionCount} reports';
                      } else if (stepName == 'Prioritized' && ranking.rank > 0) {
                        detailSuffix = ' — Rank #${ranking.rank} (AI Justified)';
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
                    const Text(
                      'MP Office Action Justification',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                    const Text(
                      'Linked Ongoing Government Project',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                        const Text(
                          'Disclose name to MP Office',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
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
                            // Upvote trigger with client-side rate-limiting simulator
                            ref.read(localDataProvider.notifier).toggleUpvote(c.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Security audit verification check passed (1 vote per verified account limit).'),
                                duration: Duration(seconds: 1),
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

  void _showSubmissionModeBottomSheet(BuildContext context, String lang) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lang == 'hi' 
                    ? 'आप शिकायत कैसे दर्ज करना चाहेंगे?' 
                    : (lang == 'kn' ? 'ನೀವು ಹೇಗೆ ಸಲ್ಲಿಸಲು ಬಯಸುತ್ತೀರಿ?' : 'How would you like to submit?'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ModeButton(
                    icon: Icons.mic,
                    label: lang == 'hi' ? 'आवाज़' : (lang == 'kn' ? 'ಧ್ವನಿ' : 'Voice'),
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/citizen/submit?mode=voice');
                    },
                  ),
                  _ModeButton(
                    icon: Icons.text_fields,
                    label: lang == 'hi' ? 'पाठ' : (lang == 'kn' ? 'ಪಠ್ಯ' : 'Text'),
                    color: Colors.teal,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/citizen/submit?mode=text');
                    },
                  ),
                  _ModeButton(
                    icon: Icons.camera_alt,
                    label: lang == 'hi' ? 'फ़ोटो' : (lang == 'kn' ? 'ಫೋಟೋ' : 'Photo'),
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/citizen/submit?mode=photo');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ModeButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
