import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/submission.dart';
import '../models/cluster.dart';
import '../models/ranking.dart';

// Check if Firebase is initialized in the app
final firebaseInitializedProvider = Provider<bool>((ref) {
  return Firebase.apps.isNotEmpty;
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  if (ref.watch(firebaseInitializedProvider)) {
    return FirebaseAuth.instance;
  } else {
    return _MockFirebaseAuth();
  }
});

final firestoreProvider = Provider<FirebaseFirestore?>((ref) {
  if (ref.watch(firebaseInitializedProvider)) {
    return FirebaseFirestore.instance;
  }
  return null;
});

// A provider for logged-in user phone number
final userPhoneProvider = StateProvider<String>((ref) => '+91 9876543210');

// Local in-memory repository fallback for Demo mode
class LocalDataState {
  final List<Submission> submissions;
  final List<Cluster> clusters;
  final List<Ranking> rankings;
  final Set<String> upvotedClusterIds;
  final bool isOffline;

  LocalDataState({
    required this.submissions,
    required this.clusters,
    required this.rankings,
    required this.upvotedClusterIds,
    this.isOffline = false,
  });

  LocalDataState copyWith({
    List<Submission>? submissions,
    List<Cluster>? clusters,
    List<Ranking>? rankings,
    Set<String>? upvotedClusterIds,
    bool? isOffline,
  }) {
    return LocalDataState(
      submissions: submissions ?? this.submissions,
      clusters: clusters ?? this.clusters,
      rankings: rankings ?? this.rankings,
      upvotedClusterIds: upvotedClusterIds ?? this.upvotedClusterIds,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class LocalDataNotifier extends StateNotifier<LocalDataState> {
  LocalDataNotifier() : super(LocalDataState(
    submissions: [
      Submission(
        id: 'dummy_sub_1',
        citizenPhone: '******3210',
        mode: 'text',
        originalText: 'Primary school roof is leaking and needs urgent repair.',
        originalLanguage: 'en',
        translatedText: 'Primary school roof is leaking and needs urgent repair.',
        category: 'Education',
        extractedLocation: {'ward': 'Ward 4', 'village': ''},
        severity: 0.75,
        sentiment: -0.4,
        status: 'Processed',
        clusterId: 'dummy_cluster_1',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Submission(
        id: 'dummy_sub_2',
        citizenPhone: '******5555',
        mode: 'voice',
        originalText: 'There is no drinking water in Ward 4 for the last 3 days.',
        originalLanguage: 'en',
        translatedText: 'There is no drinking water in Ward 4 for the last 3 days.',
        category: 'Water',
        extractedLocation: {'ward': 'Ward 4', 'village': ''},
        severity: 0.9,
        sentiment: -0.6,
        status: 'Processed',
        clusterId: 'dummy_cluster_2',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ],
    clusters: [
      Cluster(
        id: 'dummy_cluster_1',
        title: 'Govt School Primary Upgrade',
        category: 'Education',
        ward: 'Ward 4',
        submissionCount: 340,
        representativeSubmissionIds: ['dummy_sub_1'],
        centroid: {'lat': 20.5937, 'lng': 78.9629},
        enrichment: {'scStGap': 0.5, 'schoolGap': 0.56},
        status: 'Under Review',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Cluster(
        id: 'dummy_cluster_2',
        title: 'Drinking Water Pipeline Ward 4',
        category: 'Water',
        ward: 'Ward 4',
        submissionCount: 154,
        representativeSubmissionIds: ['dummy_sub_2'],
        centroid: {'lat': 20.5957, 'lng': 78.9609},
        enrichment: {'scStGap': 0.5, 'schoolGap': 0.23},
        status: 'Under Review',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Cluster(
        id: 'dummy_cluster_3',
        title: 'New PHC at Village East',
        category: 'Health',
        ward: 'Village East',
        submissionCount: 42,
        representativeSubmissionIds: [],
        centroid: {'lat': 20.6937, 'lng': 78.8629},
        enrichment: {'scStGap': 0.5, 'schoolGap': 0.8},
        status: 'Under Review',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ],
    rankings: [
      Ranking(
        clusterId: 'dummy_cluster_1',
        score: 94.2,
        rank: 1,
        explanation: 'Ranked #1 — 340 verified reports across Ward 4; school is 42% over its capacity and SC/ST enrollment is high.',
        weightsUsed: {'w1': 0.3, 'w2': 0.25, 'w3': 0.2, 'w4': 0.15, 'w5': 0.1},
        computedAt: DateTime.now(),
      ),
      Ranking(
        clusterId: 'dummy_cluster_2',
        score: 88.5,
        rank: 2,
        explanation: 'Ranked #2 — 154 reports across Ward 4; critical drinking water access pipeline breakdown.',
        weightsUsed: {'w1': 0.3, 'w2': 0.25, 'w3': 0.2, 'w4': 0.15, 'w5': 0.1},
        computedAt: DateTime.now(),
      ),
      Ranking(
        clusterId: 'dummy_cluster_3',
        score: 76.0,
        rank: 3,
        explanation: 'Ranked #3 — High benchmark gap: nearest primary health clinic is 12.0 km away from Village East.',
        weightsUsed: {'w1': 0.3, 'w2': 0.25, 'w3': 0.2, 'w4': 0.15, 'w5': 0.1},
        computedAt: DateTime.now(),
      ),
    ],
    upvotedClusterIds: {'dummy_cluster_2'},
  )) {
    // Periodically toggle offline state to demonstrate the reconnection banner or keep it static
  }

  void addSubmission(Submission sub) {
    state = state.copyWith(submissions: [sub, ...state.submissions]);
    
    // Simulate clustering locally after 1s
    Future.delayed(const Duration(milliseconds: 500), () {
      _clusterSubmissionLocally(sub);
    });
  }

  void _clusterSubmissionLocally(Submission sub) {
    final list = [...state.clusters];
    bool merged = false;

    // Haversine approx within 1km
    for (int i = 0; i < list.length; i++) {
      final c = list[i];
      if (c.category == sub.category && c.ward == (sub.extractedLocation?['ward'] ?? 'General')) {
        // Match found (mocking high cosine similarity)
        list[i] = Cluster(
          id: c.id,
          title: c.title,
          category: c.category,
          ward: c.ward,
          submissionCount: c.submissionCount + 1,
          representativeSubmissionIds: [...c.representativeSubmissionIds, sub.id],
          centroid: c.centroid,
          enrichment: c.enrichment,
          status: c.status,
          createdAt: c.createdAt,
          updatedAt: DateTime.now(),
        );
        merged = true;
        break;
      }
    }

    if (!merged) {
      final newCluster = Cluster(
        id: 'cluster_${DateTime.now().millisecondsSinceEpoch}',
        title: sub.originalText.length > 30 ? '${sub.originalText.substring(0, 30)}...' : sub.originalText,
        category: sub.category,
        ward: sub.extractedLocation?['ward'] ?? 'General',
        submissionCount: 1,
        representativeSubmissionIds: [sub.id],
        centroid: {'lat': 20.5937, 'lng': 78.9629},
        enrichment: {'scStGap': 0.2, 'schoolGap': 0.1},
        status: 'Under Review',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      list.add(newCluster);
    }

    state = state.copyWith(clusters: list);
    recalculateScores();
  }

  void toggleUpvote(String clusterId) {
    final upvotes = Set<String>.from(state.upvotedClusterIds);
    if (upvotes.contains(clusterId)) {
      upvotes.remove(clusterId);
    } else {
      upvotes.add(clusterId);
    }
    state = state.copyWith(upvotedClusterIds: upvotes);
  }

  void setOffline(bool isOffline) {
    state = state.copyWith(isOffline: isOffline);
  }

  void recalculateScores({Map<String, double>? customWeights}) {
    final weights = customWeights ?? {'w1': 0.3, 'w2': 0.25, 'w3': 0.2, 'w4': 0.15, 'w5': 0.1};
    final List<Ranking> newRankings = [];

    final list = [...state.clusters];
    final scored = list.map((c) {
      final nDemand = c.submissionCount / 300;
      final severity = c.id == 'dummy_cluster_2' ? 0.9 : 0.6;
      
      final scStGap = (c.enrichment?['scStGap'] ?? 0.15) as double;
      final schoolGap = (c.enrichment?['schoolGap'] ?? 0.2) as double;
      final gap = c.category == 'Education' 
          ? (0.7 * schoolGap + 0.3 * scStGap)
          : (0.3 * schoolGap + 0.7 * scStGap);

      final score = (weights['w1']! * nDemand) +
                    (weights['w2']! * severity) +
                    (weights['w3']! * gap) +
                    (weights['w4']! * 0.65) +
                    (weights['w5']! * 0.8);
      
      return {
        'clusterId': c.id,
        'score': score * 100,
        'c': c
      };
    }).toList();

    scored.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    for (int i = 0; i < scored.length; i++) {
      final s = scored[i];
      final c = s['c'] as Cluster;
      final scoreVal = s['score'] as double;
      final rank = i + 1;

      newRankings.add(Ranking(
        clusterId: c.id,
        score: double.parse(scoreVal.toStringAsFixed(1)),
        rank: rank,
        explanation: 'Ranked #$rank — ${c.submissionCount} requests in ${c.ward}; SC/ST population is ${(((c.enrichment?['scStGap'] ?? 0.15) as double) * 100).toStringAsFixed(0)}%.',
        weightsUsed: weights,
        computedAt: DateTime.now(),
      ));
    }

    state = state.copyWith(rankings: newRankings);
  }
}

final localDataProvider = StateNotifierProvider<LocalDataNotifier, LocalDataState>((ref) {
  return LocalDataNotifier();
});

// Mock FirebaseAuth
class _MockFirebaseAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  
  @override
  Stream<User?> authStateChanges() => Stream.value(null);
}

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});
