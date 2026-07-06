import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/language_service.dart';
import '../../../shared/services/firebase_service.dart';
import '../../../shared/models/submission.dart';
import '../../../shared/models/cluster.dart';

class CitizenHomeScreen extends ConsumerStatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  ConsumerState<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends ConsumerState<CitizenHomeScreen> {
  int _currentTab = 0; // 0: My Submissions, 1: Community Board

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
        ),
        actions: [
          // Demo controls for hackathon judges
          TextButton(
            onPressed: () {
              ref.read(localDataProvider.notifier).setOffline(!localState.isOffline);
            },
            child: Row(
              children: [
                Icon(
                  localState.isOffline ? Icons.signal_wifi_off : Icons.wifi,
                  size: 16,
                  color: localState.isOffline ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  localState.isOffline ? 'Offline' : 'Online',
                  style: TextStyle(color: localState.isOffline ? Colors.red : Colors.green),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.dashboard_customize),
            tooltip: 'MP Dashboard',
            onPressed: () => context.go('/dashboard/overview'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.go('/'),
          )
        ],
      ),
      body: Column(
        children: [
          // Poor/No Connectivity reconnecting indicator banner
          if (localState.isOffline)
            Container(
              color: Colors.red[100],
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    getLocalizedText('offline_banner', lang),
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          
          Expanded(
            child: _currentTab == 0
                ? _buildMySubmissionsTab(localState.submissions, lang)
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
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.inbox),
            label: getLocalizedText('my_submissions', lang),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.group),
            label: getLocalizedText('community_board', lang),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showSubmissionModeBottomSheet(context, lang);
        },
        icon: const Icon(Icons.add),
        label: Text(getLocalizedText('new_request', lang)),
      ),
    );
  }

  Widget _buildMySubmissionsTab(List<Submission> submissions, String lang) {
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
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
        Color modeColor = Colors.blue;
        if (sub.mode == 'voice') {
          modeIcon = Icons.mic;
          modeColor = Colors.orange;
        } else if (sub.mode == 'photo') {
          modeIcon = Icons.camera_alt;
          modeColor = Colors.green;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: modeColor.withOpacity(0.1),
              child: Icon(modeIcon, color: modeColor),
            ),
            title: Text(sub.originalText, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(sub.category, style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    Text(sub.extractedLocation?['ward'] ?? 'General', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(formattedDate, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: sub.status == 'Submitted' ? Colors.blue[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                sub.status,
                style: TextStyle(
                  color: sub.status == 'Submitted' ? Colors.blue : Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommunityBoardTab(List<Cluster> clusters, Set<String> upvotedIds, String lang) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: clusters.length,
      itemBuilder: (context, index) {
        final c = clusters[index];
        final hasUpvoted = upvotedIds.contains(c.id);
        
        // Generate pseudo handle for creator anonymity
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
                        Text(pseudoHandle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    ),
                    Text(c.ward, style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(c.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text(c.category, style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.grey[200],
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            hasUpvoted ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                            color: hasUpvoted ? Colors.blue : Colors.grey,
                          ),
                          onPressed: () {
                            ref.read(localDataProvider.notifier).toggleUpvote(c.id);
                          },
                        ),
                        Text(
                          '${c.submissionCount + (hasUpvoted ? 1 : 0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: hasUpvoted ? Colors.blue : Colors.black87,
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
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lang == 'hi' 
                    ? 'आप शिकायत कैसे दर्ज करना चाहेंगे?' 
                    : (lang == 'kn' ? 'ನೀವು ಹೇಗೆ ಸಲ್ಲಿಸಲು ಬಯಸುತ್ತೀರಿ?' : 'How would you like to submit?'),
                style: Theme.of(context).textTheme.titleLarge,
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
                    color: Colors.blue,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
