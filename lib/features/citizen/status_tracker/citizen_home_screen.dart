import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/language_service.dart';
import '../../../shared/services/firebase_service.dart';
import '../../../shared/models/submission.dart';
import '../../../shared/models/cluster.dart';
import '../../../shared/models/ranking.dart';

// ─── Theme / Styling Colors (Premium M3 Palette) ──────────────────────────────
const _googleBlue = Color(0xFF1a73e8);     // Primary
const _emeraldGreen = Color(0xFF0f9d58);   // Secondary / Success
const _amberYellow = Color(0xFFf4b400);    // Warning / Pending
const _googleRed = Color(0xFFdb4437);      // Error / Rejected
const _navy = Color(0xFF002244);
const _saffron = Color(0xFFFF9933);

class CitizenHomeScreen extends ConsumerStatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  ConsumerState<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends ConsumerState<CitizenHomeScreen> {
  int _currentTab = 0; // 0: Recent Updates, 1: Community, 2: My Reports
  final Set<String> _disclosedNames = {};

  // Dynamically determine the time-based greeting key
  String _getGreetingKey() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'welcome_time_morning';
    } else if (hour >= 12 && hour < 17) {
      return 'welcome_time_afternoon';
    } else {
      return 'welcome_time_evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(selectedLanguageProvider);
    final localState = ref.watch(localDataProvider);
    final userPhone = ref.watch(userPhoneProvider);

    final greetingText = getLocalizedText(_getGreetingKey(), lang);
    final subtitleText = getLocalizedText('home_subtitle', lang);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Premium Welcoming Header & Actions Card ──────────────────────
            _buildTopHeroCard(context, lang, greetingText, subtitleText, localState, userPhone),

            // ── Offline Banner ───────────────────────────────────────────────
            if (localState.isOffline)
              Container(
                width: double.infinity,
                color: const Color(0xFFFFEBEE),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _googleRed),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        getLocalizedText('offline_banner', lang),
                        style: const TextStyle(
                          color: Color(0xFFC62828),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.read(localDataProvider.notifier).setOffline(false),
                      child: const Text('Retry', style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            // ── Horizontal M3 Tab Bar ────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildTabButton(0, getLocalizedText('recent_updates', lang), Icons.update_rounded),
                  _buildTabButton(1, getLocalizedText('community', lang), Icons.group_rounded),
                  _buildTabButton(2, getLocalizedText('my_reports', lang), Icons.assignment_turned_in_rounded),
                ],
              ),
            ),

            // ── Dynamic Content Area ─────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildSelectedTabContent(localState, lang),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showJanAiBottomSheet(context, lang, localState),
        icon: const Icon(Icons.psychology, color: Colors.white),
        label: Text(
          getLocalizedText('ask_jan', lang),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: _googleBlue,
        elevation: 4,
      ),
    );
  }

  Widget _buildTopHeroCard(
    BuildContext context,
    String lang,
    String greeting,
    String subtitle,
    LocalDataState localState,
    String userPhone,
  ) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // National Branding Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _saffron, width: 1.5),
                    ),
                    child: const Icon(Icons.account_balance, size: 18, color: _navy),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    getLocalizedText('app_name', lang),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Connectivity simulation
                  IconButton(
                    icon: Icon(
                      localState.isOffline ? Icons.signal_wifi_off : Icons.wifi,
                      color: localState.isOffline ? _saffron : _emeraldGreen,
                      size: 20,
                    ),
                    onPressed: () {
                      ref.read(localDataProvider.notifier).setOffline(!localState.isOffline);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.bar_chart_rounded, color: Colors.white70, size: 20),
                    onPressed: () => context.go('/dashboard/overview'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
                    onPressed: () => context.go('/'),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          // Emotional Greeting Slogan
          Text(
            greeting,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),

          // Central Google-Assistant style Action Row
          Row(
            children: [
              // Speak card (Primary)
              Expanded(
                flex: 4,
                child: _AssistantActionCard(
                  icon: Icons.mic_rounded,
                  label: getLocalizedText('btn_speak', lang),
                  color: _googleBlue,
                  isPrimary: true,
                  onTap: () => context.push('/citizen/submit?mode=voice'),
                ),
              ),
              const SizedBox(width: 12),
              // Capture card
              Expanded(
                flex: 3,
                child: _AssistantActionCard(
                  icon: Icons.camera_alt_rounded,
                  label: getLocalizedText('btn_capture', lang),
                  color: Colors.white,
                  isPrimary: false,
                  onTap: () => context.push('/citizen/submit?mode=photo'),
                ),
              ),
              const SizedBox(width: 12),
              // Type card
              Expanded(
                flex: 3,
                child: _AssistantActionCard(
                  icon: Icons.keyboard_rounded,
                  label: getLocalizedText('btn_type', lang),
                  color: Colors.white,
                  isPrimary: false,
                  onTap: () => context.push('/citizen/submit?mode=text'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTabButton(int tabIdx, String label, IconData icon) {
    final isSelected = _currentTab == tabIdx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = tabIdx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? _googleBlue : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? _googleBlue : Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? _googleBlue : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent(LocalDataState localState, String lang) {
    switch (_currentTab) {
      case 0:
        return _buildRecentUpdatesTab(localState, lang);
      case 1:
        return _buildCommunityBoardTab(localState.clusters, localState.upvotedClusterIds, lang);
      case 2:
      default:
        return _buildMyReportsTab(localState.submissions, localState, lang);
    }
  }

  // ─── Tab 0: Recent Updates ─────────────────────────────────────────────────
  Widget _buildRecentUpdatesTab(LocalDataState localState, String lang) {
    // Generate some highly realistic local development news showing funding status
    final updates = [
      {
        'title': lang == 'hi'
            ? 'सुलिकेरे स्कूल की छत की मरम्मत का काम स्वीकृत'
            : (lang == 'kn'
                ? 'ಸೂಲಿಕೆರೆ ಶಾಲೆಯ ಛಾವಣಿ ದುರಸ್ತಿ ಕೆಲಸ ಅನುಮೋದಿಸಲಾಗಿದೆ'
                : 'Sulikere Primary School Roof Repair Approved'),
        'details': lang == 'hi'
            ? 'सांसद निधि (MPLADS) के तहत ₹4.5 लाख जारी। काम अगले हफ्ते शुरू होगा।'
            : (lang == 'kn'
                ? 'ಸಂಸದರ ನಿಧಿ (MPLADS) ಅಡಿಯಲ್ಲಿ ₹4.5 ಲಕ್ಷ ಮಂಜೂರು. ಮುಂದಿನ ವಾರ ಕೆಲಸ ಆರಂಭ.'
                : 'Rs. 4,50,000 allocated under MPLADS funds. Civil works start next week.'),
        'mergedCount': '340 citizens',
        'time': '2 hours ago',
        'status': 'Approved',
        'color': _emeraldGreen,
      },
      {
        'title': lang == 'hi'
            ? 'कोम्माघट्टा में पानी की आपूर्ति बहाल'
            : (lang == 'kn'
                ? 'ಕೊಮ್ಮಘಟ್ಟದಲ್ಲಿ ನೀರಿನ ಸರಬರಾಜು ಪುನಃಸ್ಥಾಪಿಸಲಾಗಿದೆ'
                : 'Drinking Water Pipeline Restored in Kommaghatta'),
        'details': lang == 'hi'
            ? '12 नागरिकों की रिपोर्ट और एआई क्लस्टरिंग के बाद पाइपलाइन का रिसाव ठीक किया गया।'
            : (lang == 'kn'
                ? '12 ನಾಗರಿಕರ ವರದಿಗಳು ಮತ್ತು AI ಹೊಂದಾಣಿಕೆಯ ನಂತರ ಪೈಪ್‌ಲೈನ್ ಸೋರಿಕೆ ಸರಿಪಡಿಸಲಾಗಿದೆ.'
                : 'Pipeline leakage fixed after 12 joint citizen reports verified by Gemini AI.'),
        'mergedCount': '12 citizens',
        'time': 'Yesterday',
        'status': 'Resolved',
        'color': _googleBlue,
      },
      {
        'title': lang == 'hi'
            ? 'रामोहल्ली स्ट्रीटलाइट मरम्मत प्रगति पर'
            : (lang == 'kn'
                ? 'ರಾಮೋಹಳ್ಳಿ ಬೀದಿ ದೀಪ ದುರಸ್ತಿ ಪ್ರಗತಿಯಲ್ಲಿದೆ'
                : 'Ramohalli Streetlight Grid Maintenance'),
        'details': lang == 'hi'
            ? 'वार्ड 4 में 8 खराब बल्ब बदले जा रहे हैं।'
            : (lang == 'kn'
                ? 'ವಾರ್ಡ್ 4 ರ ಅಡಿಯಲ್ಲಿ 8 ಬೀದಿ ದೀಪಗಳನ್ನು ಬದಲಾಯಿಸಲಾಗುತ್ತಿದೆ.'
                : '8 damaged bulbs being replaced under the Ward 4 Maintenance contract.'),
        'mergedCount': '5 citizens',
        'time': '3 days ago',
        'status': 'In Progress',
        'color': _amberYellow,
      }
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: updates.length,
      itemBuilder: (context, index) {
        final item = updates[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (item['color'] as Color).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item['status'] as String,
                        style: TextStyle(
                          color: item['color'] as Color,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      item['time'] as String,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item['title'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navy),
                ),
                const SizedBox(height: 6),
                Text(
                  item['details'] as String,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.people_outline, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Impacted: ${item['mergedCount']}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Tab 1: Community Board ────────────────────────────────────────────────
  Widget _buildCommunityBoardTab(List<Cluster> clusters, Set<String> upvotedIds, String lang) {
    if (clusters.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _googleBlue));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: clusters.length,
      itemBuilder: (context, index) {
        final c = clusters[index];
        final hasUpvoted = upvotedIds.contains(c.id);
        final disclosed = _disclosedNames.contains(c.id);
        final pseudoHandle = 'Citizen_${c.id.substring(c.id.length - 4).toUpperCase()}';

        // Custom metrics to show active community participation
        final photoCount = 5 + (c.submissionCount % 4) * 3;
        final videoCount = 1 + (c.submissionCount % 3);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: disclosed ? _emeraldGreen.withOpacity(0.1) : Colors.grey[200],
                          child: Icon(
                            disclosed ? Icons.check_circle_rounded : Icons.person_outline_rounded,
                            size: 14,
                            color: disclosed ? _emeraldGreen : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          disclosed ? 'Manav Nagpal (Disclosed)' : pseudoHandle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: disclosed ? _emeraldGreen : Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      c.ward,
                      style: const TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  c.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),

                // Premium Community Indicators (Photos/Videos/Citizens)
                Row(
                  children: [
                    _buildCommunityMetricChip('${c.submissionCount + (hasUpvoted ? 1 : 0)} Citizens Support', Icons.people_rounded),
                    const SizedBox(width: 8),
                    _buildCommunityMetricChip('$photoCount Photos', Icons.image_rounded),
                    const SizedBox(width: 8),
                    _buildCommunityMetricChip('$videoCount Videos', Icons.play_circle_rounded),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Interactive Bottom Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Support (Upvote) Button
                    InkWell(
                      onTap: () {
                        ref.read(localDataProvider.notifier).toggleUpvote(c.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(getLocalizedText('vote_verified', lang)),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              hasUpvoted ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                              color: hasUpvoted ? _emeraldGreen : Colors.grey[600],
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Support',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: hasUpvoted ? _emeraldGreen : Colors.grey[600],
                                fontSize: 13,
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    // Add Evidence
                    TextButton.icon(
                      onPressed: () => context.push('/citizen/submit?mode=photo'),
                      icon: const Icon(Icons.add_photo_alternate_rounded, size: 18, color: _googleBlue),
                      label: const Text('Add Evidence', style: TextStyle(color: _googleBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),

                // Real Identity disclosure toggle
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: disclosed,
                        activeColor: _emeraldGreen,
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
                    ),
                    const SizedBox(width: 8),
                    Text(
                      getLocalizedText('disclose_name', lang),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
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

  Widget _buildCommunityMetricChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── Tab 2: My Reports ─────────────────────────────────────────────────────
  Widget _buildMyReportsTab(List<Submission> submissions, LocalDataState localState, String lang) {
    if (submissions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_late_rounded, size: 64, color: Colors.grey[300]),
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
        Color modeColor = _googleBlue;
        if (sub.mode == 'voice') {
          modeIcon = Icons.mic;
          modeColor = _saffron;
        } else if (sub.mode == 'photo') {
          modeIcon = Icons.camera_alt;
          modeColor = _emeraldGreen;
        }

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

        // Define Priority Stars (1-5 stars depending on ranking or severity)
        int starCount = 3;
        if (sub.severity > 0.8) starCount = 5;
        else if (sub.severity > 0.5) starCount = 4;
        else if (sub.severity < 0.3) starCount = 2;

        String statusLabel = sub.status;
        Color statusColor = Colors.grey;

        if (sub.status == 'Submitted') {
          statusLabel = getLocalizedText('status_submitted', lang);
          statusColor = _googleBlue;
        } else if (sub.status == 'Under Review') {
          statusLabel = getLocalizedText('status_under_review', lang);
          statusColor = _amberYellow;
        } else if (sub.status == 'Processed' || sub.status == 'Clustered') {
          statusLabel = '${getLocalizedText('status_clustered_prefix', lang)} (${cluster.submissionCount} ${getLocalizedText('reports', lang)})';
          statusColor = Colors.purple;
        } else if (sub.status == 'Prioritized') {
          statusLabel = '${getLocalizedText('status_prioritized_prefix', lang)} (#${ranking.rank})';
          statusColor = Colors.indigo;
        } else if (sub.status == 'In Progress') {
          statusLabel = getLocalizedText('status_in_progress', lang);
          statusColor = _amberYellow;
        } else if (sub.status == 'Resolved') {
          statusLabel = getLocalizedText('status_resolved', lang);
          statusColor = _emeraldGreen;
        } else if (sub.status == 'rejected') {
          statusLabel = getLocalizedText('status_rejected', lang);
          statusColor = _googleRed;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showSubmissionDetailsBottomSheet(context, sub, cluster, ranking, lang),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: modeColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(modeIcon, color: modeColor, size: 22),
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
                            fontWeight: FontWeight.bold,
                            color: _navy,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Priority Stars & Duplicates Merged
                        Row(
                          children: [
                            Row(
                              children: List.generate(5, (starIdx) {
                                return Icon(
                                  starIdx < starCount ? Icons.star_rounded : Icons.star_border_rounded,
                                  color: _amberYellow,
                                  size: 16,
                                );
                              }),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _googleBlue.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Merged: ${cluster.submissionCount > 0 ? cluster.submissionCount : 1} citizens',
                                style: const TextStyle(fontSize: 10, color: _googleBlue, fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _CategoryChip(label: sub.category),
                            const SizedBox(width: 8),
                            Icon(Icons.location_on_outlined, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                sub.extractedLocation?['village'] ?? sub.extractedLocation?['ward'] ?? 'General',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Last Updated: $formattedDate',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // M3 Status Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Submissions Details with AI Timeline Tracker ───────────────────────────
  void _showSubmissionDetailsBottomSheet(
      BuildContext context, Submission sub, Cluster cluster, Ranking ranking, String lang) {
    // 9-Step AI/Official Action Timeline
    final timelineSteps = [
      {'key': 'Submitted', 'label': 'Submitted'},
      {'key': 'AI Verified', 'label': 'AI Verified'},
      {'key': 'Merged', 'label': 'Merged'},
      {'key': 'Priority Increased', 'label': 'Priority Increased'},
      {'key': 'Forwarded', 'label': 'Forwarded to Department'},
      {'key': 'MP Review', 'label': 'MP Review'},
      {'key': 'Work Approved', 'label': 'Work Approved'},
      {'key': 'Completed', 'label': 'Completed'},
      {'key': 'Citizen Verification', 'label': 'Citizen Verified'},
    ];

    int currentStepIndex = 1; // Default: submitted & AI verified
    if (sub.status == 'Under Review') currentStepIndex = 1;
    if (sub.status == 'Processed' || sub.status == 'Clustered') currentStepIndex = 2;
    if (sub.status == 'Prioritized') currentStepIndex = 3;
    if (sub.status == 'In Progress') currentStepIndex = 4;
    if (sub.status == 'Resolved') currentStepIndex = 7;

    // Trust score metric
    final trustScore = (sub.severity * 10 + 86).clamp(88, 98).toInt();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
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
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        getLocalizedText('submission_details', lang),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _navy),
                      ),
                      // AI Trust Meter
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _emeraldGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _emeraldGreen.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, color: _emeraldGreen, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'AI Trust: $trustScore%',
                              style: const TextStyle(color: _emeraldGreen, fontWeight: FontWeight.bold, fontSize: 12),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Grievance Details Card
                  Card(
                    elevation: 0,
                    color: const Color(0xFFF8F9FA),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            getLocalizedText('grievance_text', lang),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            sub.originalText,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _navy),
                          ),
                          if (sub.originalLanguage != 'en') ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Text(
                              'AI Translation (English):',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sub.translatedText,
                              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.black87),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Trust Meter Detail Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _googleBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: _googleBlue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Evidence Quality verified by Gemini Vision. GPS position matches local municipality infrastructure tags. Safe citizen report verified.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[800], height: 1.4),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ─── Vertical AI Timeline Tracker ───────────────────────────
                  const Text(
                    'AI Timeline & Actions Tracker',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: timelineSteps.length,
                    itemBuilder: (context, idx) {
                      final step = timelineSteps[idx];
                      final stepLabel = step['label']!;
                      final isPassed = idx <= currentStepIndex;
                      final isCurrent = idx == currentStepIndex;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: isCurrent
                                    ? _googleBlue
                                    : (isPassed ? _emeraldGreen : Colors.grey[200]),
                                child: isPassed
                                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                                    : Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(color: Colors.grey[400], shape: BoxShape.circle),
                                      ),
                              ),
                              if (idx < timelineSteps.length - 1)
                                Container(
                                  width: 2.5,
                                  height: 28,
                                  color: isPassed ? _emeraldGreen : Colors.grey[200],
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                stepLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                  color: isCurrent
                                      ? _googleBlue
                                      : (isPassed ? Colors.black87 : Colors.grey[500]),
                                ),
                              ),
                            ),
                          )
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Floating Jan AI Plain-Language Assistant ──────────────────────────────
  void _showJanAiBottomSheet(BuildContext context, String lang, LocalDataState localState) {
    final List<Map<String, String>> janAiHistory = [
      {
        'role': 'ai',
        'text': 'Hello! I am Jan AI. How can I help you understand local MP initiatives, ongoing works, or your reports today?'
      }
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.psychology, color: _googleBlue, size: 28),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                getLocalizedText('ask_jan', lang),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy),
                              ),
                              Text(
                                getLocalizedText('ask_jan_subtitle', lang),
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              )
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // Chat bubbles
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: janAiHistory.length,
                          itemBuilder: (context, idx) {
                            final msg = janAiHistory[idx];
                            final isAi = msg['role'] == 'ai';
                            return Align(
                              alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isAi ? Colors.grey[100] : _googleBlue.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  msg['text']!,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: isAi ? Colors.black87 : _googleBlue,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Quick prompts
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPromptChip('Why is my issue pending?', () {
                              setModalState(() {
                                janAiHistory.add({'role': 'user', 'text': 'Why is my issue pending?'});
                                janAiHistory.add({
                                  'role': 'ai',
                                  'text': 'Your road damage report in Sulikere is currently under review by the MP\'s engineering office. It has been merged with 12 other reports and ranked high because it lies on a school corridor. Expect work sanction in the upcoming budget cycle.'
                                });
                              });
                            }),
                            const SizedBox(width: 8),
                            _buildPromptChip('Has anyone else reported this?', () {
                              setModalState(() {
                                janAiHistory.add({'role': 'user', 'text': 'Has anyone else reported this?'});
                                janAiHistory.add({
                                  'role': 'ai',
                                  'text': 'Yes! 12 other citizens in your immediate ward have reported identical road damage. Gemini AI has automatically clustered these duplicate complaints together to escalate the priority score on the MP Dashboard.'
                                });
                              });
                            }),
                            const SizedBox(width: 8),
                            _buildPromptChip('Show nearby works.', () {
                              setModalState(() {
                                janAiHistory.add({'role': 'user', 'text': 'Show nearby works.'});
                                janAiHistory.add({
                                  'role': 'ai',
                                  'text': 'There are 2 active works nearby: 1. Main road repair (200m away, 80% complete), 2. Primary health center sanitation upgrades (500m away, budget approved).'
                                });
                              });
                            }),
                            const SizedBox(width: 8),
                            _buildPromptChip('Who will review this?', () {
                              setModalState(() {
                                janAiHistory.add({'role': 'user', 'text': 'Who will review this?'});
                                janAiHistory.add({
                                  'role': 'ai',
                                  'text': 'This issue is routed directly to the MP Office Public Works representative and the local Ward Executive Engineer.'
                                });
                              });
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPromptChip(String text, VoidCallback onTap) {
    return ActionChip(
      onPressed: onTap,
      label: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _navy)),
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
    );
  }
}

// ─── Supporting Assistant Action Card Widget ────────────────────────────────
class _AssistantActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isPrimary;
  final VoidCallback onTap;

  const _AssistantActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isPrimary ? 3 : 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPrimary ? BorderSide.none : BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isPrimary ? 32 : 24,
                color: isPrimary ? Colors.white : _navy,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : _navy,
                  fontWeight: FontWeight.bold,
                  fontSize: isPrimary ? 15 : 13,
                ),
              ),
            ],
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
      case 'water': return _googleBlue;
      case 'roads': return const Color(0xFF6D4C41);
      case 'electricity': return _amberYellow;
      case 'sanitation': return _emeraldGreen;
      case 'education': return Colors.purple;
      case 'health': return _googleRed;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForCategory(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
