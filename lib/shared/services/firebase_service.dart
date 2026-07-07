import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

// Static demographics dataset from demographics_bangalore_south.csv
final List<Map<String, dynamic>> staticDemographics = [
  {
    'village_name': 'Seshagiripura',
    'location_code': '613005',
    'area_ha': 40.6,
    'population_2011': 246,
    'households': 62,
    'sc_population_pct_range': null,
    'st_population_pct_range': null,
    'schools_in_village_pp_p_m_s': 'partial (a/a/a/a - all 5-10km away)',
    'higher_ed_available_in_village': 'No',
    'medical_facility_in_village': 'No',
    'drinking_water_available': 'No',
    'electricity_domestic': 'Yes',
    'nearest_town': 'BBMP',
    'nearest_town_distance_km_range': '10+',
    'lat': 12.9080, 'lng': 77.4720
  },
  {
    'village_name': 'Chikkellur',
    'location_code': '613006',
    'area_ha': 243.1,
    'population_2011': 1120,
    'households': 252,
    'sc_population_pct_range': null,
    'st_population_pct_range': null,
    'schools_in_village_pp_p_m_s': 'yes (2 schools in-village)',
    'higher_ed_available_in_village': 'No',
    'medical_facility_in_village': 'Yes',
    'drinking_water_available': 'Yes',
    'electricity_domestic': 'Yes',
    'nearest_town': 'BBMP',
    'nearest_town_distance_km_range': '10+',
    'lat': 12.9220, 'lng': 77.4350
  },
  {
    'village_name': 'Chikkellur Venkatapura',
    'location_code': '613007',
    'area_ha': 51.8,
    'population_2011': 15,
    'households': 5,
    'sc_population_pct_range': null,
    'st_population_pct_range': null,
    'schools_in_village_pp_p_m_s': 'partial',
    'higher_ed_available_in_village': 'No',
    'medical_facility_in_village': 'No',
    'drinking_water_available': 'No',
    'electricity_domestic': 'Yes',
    'nearest_town': 'BBMP',
    'nearest_town_distance_km_range': '10+',
    'lat': 12.9230, 'lng': 77.4370
  },
  {
    'village_name': 'Chikkellur Ramapura',
    'location_code': '613008',
    'area_ha': 65.8,
    'population_2011': 63,
    'households': 14,
    'sc_population_pct_range': null,
    'st_population_pct_range': null,
    'schools_in_village_pp_p_m_s': 'partial',
    'higher_ed_available_in_village': 'No',
    'medical_facility_in_village': 'No',
    'drinking_water_available': 'No',
    'electricity_domestic': 'Yes',
    'nearest_town': 'BBMP',
    'nearest_town_distance_km_range': '10+',
    'lat': 12.9210, 'lng': 77.4390
  },
  {
    'village_name': 'M.Krishnasagara',
    'location_code': '613009',
    'area_ha': 89.9,
    'population_2011': 403,
    'households': 98,
    'sc_population_pct_range': '21-30',
    'st_population_pct_range': null,
    'schools_in_village_pp_p_m_s': 'partial (all 5-10km)',
    'higher_ed_available_in_village': 'No',
    'medical_facility_in_village': 'No',
    'drinking_water_available': 'Yes',
    'electricity_domestic': 'Yes',
    'nearest_town': 'BBMP',
    'nearest_town_distance_km_range': '10+',
    'lat': 12.8856, 'lng': 77.4423
  },
  {
    'village_name': 'Kenchanapura',
    'location_code': '613010',
    'area_ha': 283.1,
    'population_2011': 769,
    'households': 178,
    'sc_population_pct_range': '21-30',
    'st_population_pct_range': null,
    'schools_in_village_pp_p_m_s': 'yes (2 schools in-village)',
    'higher_ed_available_in_village': 'No',
    'medical_facility_in_village': 'No',
    'drinking_water_available': 'Yes',
    'electricity_domestic': 'Yes',
    'nearest_town': 'BBMP',
    'nearest_town_distance_km_range': '5-10',
    'lat': 12.9192, 'lng': 77.4589
  },
  {
    'village_name': 'Kommaghatta',
    'location_code': '613011',
    'area_ha': 649.0,
    'population_2011': 2950,
    'households': 749,
    'sc_population_pct_range': '11-20',
    'st_population_pct_range': null,
    'schools_in_village_pp_p_m_s': 'yes (4 schools in-village)',
    'higher_ed_available_in_village': 'No',
    'medical_facility_in_village': 'Yes (2 facilities)',
    'drinking_water_available': 'Yes',
    'electricity_domestic': 'Yes',
    'nearest_town': 'BBMP',
    'nearest_town_distance_km_range': '<5',
    'lat': 12.9145, 'lng': 77.4789
  },
  {
    'village_name': 'Sulikere',
    'location_code': '613012',
    'area_ha': 392.0,
    'population_2011': 1070,
    'households': 265,
    'sc_population_pct_range': '21-30',
    'st_population_pct_range': 'Less than 5',
    'schools_in_village_pp_p_m_s': 'yes (PP/P/M/S/SS all in-village)',
    'higher_ed_available_in_village': 'No (5-10km away)',
    'medical_facility_in_village': 'No',
    'drinking_water_available': 'Yes',
    'electricity_domestic': 'Yes',
    'nearest_town': 'BBMP',
    'nearest_town_distance_km_range': '5-10',
    'lat': 12.9126, 'lng': 77.4628
  },
  {
    'village_name': 'Maragondanahalli',
    'location_code': '613013',
    'area_ha': 392.7,
    'population_2011': 1133,
    'households': 260,
    'sc_population_pct_range': '21-30',
    'st_population_pct_range': 'Less than 5',
    'schools_in_village_pp_p_m_s': 'yes (3 schools in-village)',
    'higher_ed_available_in_village': 'No',
    'medical_facility_in_village': 'Yes',
    'drinking_water_available': 'Yes',
    'electricity_domestic': 'Yes',
    'nearest_town': 'BBMP',
    'nearest_town_distance_km_range': '10+',
    'lat': 12.8640, 'lng': 77.4680
  },
  {
    'village_name': 'Maligondanahalli',
    'location_code': '613015',
    'area_ha': 278.0,
    'population_2011': 928,
    'households': 216,
    'sc_population_pct_range': null,
    'st_population_pct_range': 'Less than 5',
    'schools_in_village_pp_p_m_s': 'partial',
    'higher_ed_available_in_village': 'No',
    'medical_facility_in_village': 'No',
    'drinking_water_available': 'Yes',
    'electricity_domestic': 'Yes',
    'nearest_town': 'BBMP',
    'nearest_town_distance_km_range': '10+',
    'lat': 12.8710, 'lng': 77.4750
  },
  {
    'village_name': 'Ramohalli',
    'location_code': '613016',
    'area_ha': 422.9,
    'population_2011': 3975,
    'households': 982,
    'sc_population_pct_range': '11-20',
    'st_population_pct_range': 'Less than 5',
    'schools_in_village_pp_p_m_s': 'yes (6 schools in-village)',
    'higher_ed_available_in_village': 'No',
    'medical_facility_in_village': 'No',
    'drinking_water_available': 'Yes',
    'electricity_domestic': 'Yes',
    'nearest_town': 'BBMP',
    'nearest_town_distance_km_range': '10+',
    'lat': 12.8988, 'lng': 77.4520
  },
  {
    'village_name': 'Bheemanakuppe',
    'location_code': '613017',
    'area_ha': 520.7,
    'population_2011': 3321,
    'households': 830,
    'sc_population_pct_range': '5-10',
    'st_population_pct_range': 'Less than 5',
    'schools_in_village_pp_p_m_s': 'yes (5 schools in-village)',
    'higher_ed_available_in_village': 'No',
    'medical_facility_in_village': 'Yes',
    'drinking_water_available': 'Yes',
    'electricity_domestic': 'Yes',
    'nearest_town': 'BBMP',
    'nearest_town_distance_km_range': '10+',
    'lat': 12.9056, 'lng': 77.4423
  }
];

// Static MPLADS works details matching mplads_works.json
final List<Map<String, dynamic>> staticMpladsWorks = [
  {
    'id': 'W001',
    'category': 'Roads', // Clean category
    'work_description': 'Construction of drain and gutter work near Ramesh home, Sulikere Dananayakanahalli',
    'village_area': 'Sulikere Dananayakanahalli',
    'matched_census_village': 'Sulikere',
    'matched_census_location_code': '613012',
    'amount': 5.0, // lakh
    'status': 'completed',
    'date': '2026-07-02',
    'sc_st_tagged': false,
    'lat': 12.9126, 'lng': 77.4628
  },
  {
    'id': 'W002',
    'category': 'Roads',
    'work_description': 'Construction of drain and gutter work near Manjunatha home, Sulikere Dananayakanahalli',
    'village_area': 'Sulikere Dananayakanahalli',
    'matched_census_village': 'Sulikere',
    'matched_census_location_code': '613012',
    'amount': 5.0,
    'status': 'completed',
    'date': '2026-07-02',
    'sc_st_tagged': false,
    'lat': 12.9126, 'lng': 77.4628
  },
  {
    'id': 'W003',
    'category': 'Roads',
    'work_description': 'Construction of drain and gutter work near Krishnamurthy home, Sulikere Dananayakanahalli',
    'village_area': 'Sulikere Dananayakanahalli',
    'matched_census_village': 'Sulikere',
    'matched_census_location_code': '613012',
    'amount': 5.0,
    'status': 'completed',
    'date': '2026-07-02',
    'sc_st_tagged': false,
    'lat': 12.9126, 'lng': 77.4628
  },
  {
    'id': 'W004',
    'category': 'Roads',
    'work_description': 'Construction of drain and gutter work near Rajendra home, Sulikere Dananayakanahalli',
    'village_area': 'Sulikere Dananayakanahalli',
    'matched_census_village': 'Sulikere',
    'matched_census_location_code': '613012',
    'amount': 5.0,
    'status': 'completed',
    'date': '2026-07-02',
    'sc_st_tagged': false,
    'lat': 12.9126, 'lng': 77.4628
  },
  {
    'id': 'W005',
    'category': 'Roads',
    'work_description': 'Construction of CC road work from Thimma Shetty home to Nagaraja home',
    'village_area': 'Not Available',
    'matched_census_village': null,
    'matched_census_location_code': null,
    'amount': 5.0,
    'status': 'completed',
    'date': '2026-04-18',
    'sc_st_tagged': false,
    'lat': null, 'lng': null
  },
  {
    'id': 'W006',
    'category': 'Roads',
    'work_description': 'Construction of CC road from Devrndrappa Master home to B G Vijay Kumar home',
    'village_area': 'Not Available',
    'matched_census_village': null,
    'matched_census_location_code': null,
    'amount': 7.0,
    'status': 'recommended',
    'date': '2026-06-13',
    'sc_st_tagged': false,
    'lat': null, 'lng': null
  },
  {
    'id': 'W007',
    'category': 'Roads',
    'work_description': 'Construction of CC road from K R Rangaswamy home to B M Venkatesh home',
    'village_area': 'Not Available',
    'matched_census_village': null,
    'matched_census_location_code': null,
    'amount': 8.0,
    'status': 'recommended',
    'date': '2026-06-13',
    'sc_st_tagged': false,
    'lat': null, 'lng': null
  },
  {
    'id': 'W008',
    'category': 'Roads',
    'work_description': 'Construction of CC road from Parashivappa home to Sangameshwara temple',
    'village_area': 'Not Available',
    'matched_census_village': null,
    'matched_census_location_code': null,
    'amount': 13.0,
    'status': 'recommended',
    'date': '2026-05-22',
    'sc_st_tagged': false,
    'lat': null, 'lng': null
  },
  {
    'id': 'W009',
    'category': 'Roads',
    'work_description': 'Construction of CC roads for the cross roads up to Haliyuru boundary in Sundaresh Ashraya Layout, located in Galihalli, where Scheduled Caste Scheduled Tribe people are residing',
    'village_area': 'Galihalli',
    'matched_census_village': null,
    'matched_census_location_code': null,
    'amount': 30.0,
    'status': 'recommended',
    'date': '2026-05-16',
    'sc_st_tagged': true,
    'lat': 12.7234, 'lng': 77.2912
  },
  {
    'id': 'W010',
    'category': 'Roads',
    'work_description': 'Construction of CC road from Dr Nadaf home to Subhash home',
    'village_area': 'Not Available',
    'matched_census_village': null,
    'matched_census_location_code': null,
    'amount': 6.0,
    'status': 'recommended',
    'date': '2026-04-08',
    'sc_st_tagged': false,
    'lat': null, 'lng': null
  }
];

class LocalDataState {
  final List<Submission> submissions;
  final List<Cluster> clusters;
  final List<Ranking> rankings;
  final Set<String> upvotedClusterIds;
  final List<Map<String, dynamic>> demographics;
  final List<Map<String, dynamic>> mpladsWorks;
  final Map<String, dynamic> mpMetadata;
  final bool isOffline;

  LocalDataState({
    required this.submissions,
    required this.clusters,
    required this.rankings,
    required this.upvotedClusterIds,
    required this.demographics,
    required this.mpladsWorks,
    required this.mpMetadata,
    this.isOffline = false,
  });

  LocalDataState copyWith({
    List<Submission>? submissions,
    List<Cluster>? clusters,
    List<Ranking>? rankings,
    Set<String>? upvotedClusterIds,
    List<Map<String, dynamic>>? demographics,
    List<Map<String, dynamic>>? mpladsWorks,
    Map<String, dynamic>? mpMetadata,
    bool? isOffline,
  }) {
    return LocalDataState(
      submissions: submissions ?? this.submissions,
      clusters: clusters ?? this.clusters,
      rankings: rankings ?? this.rankings,
      upvotedClusterIds: upvotedClusterIds ?? this.upvotedClusterIds,
      demographics: demographics ?? this.demographics,
      mpladsWorks: mpladsWorks ?? this.mpladsWorks,
      mpMetadata: mpMetadata ?? this.mpMetadata,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class LocalDataNotifier extends StateNotifier<LocalDataState> {
  StreamSubscription? _subsSubscription;
  StreamSubscription? _clustersSubscription;
  StreamSubscription? _rankingsSubscription;
  final FirebaseFirestore? _firestore;

  LocalDataNotifier(this._firestore) : super(LocalDataState(
    submissions: [
      Submission(
        id: 'dummy_sub_1',
        citizenPhone: '******3210',
        mode: 'text',
        originalText: 'Primary school roof is leaking and needs urgent repair in Sulikere.',
        originalLanguage: 'en',
        translatedText: 'Primary school roof is leaking and needs urgent repair in Sulikere.',
        category: 'Education',
        extractedLocation: {'ward': 'General', 'village': 'Sulikere'},
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
        originalText: 'There is no drinking water in Kommaghatta for the last 3 days.',
        originalLanguage: 'en',
        translatedText: 'There is no drinking water in Kommaghatta for the last 3 days.',
        category: 'Water',
        extractedLocation: {'ward': 'General', 'village': 'Kommaghatta'},
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
        ward: 'Sulikere',
        submissionCount: 340,
        representativeSubmissionIds: ['dummy_sub_1'],
        centroid: {'lat': 12.9126, 'lng': 77.4628},
        enrichment: {
          'scStGap': 0.25, 
          'schoolGap': 0.56, 
          'scPopulationRange': '21-30', 
          'schoolStatus': 'yes (PP/P/M/S/SS all in-village)',
          'medicalStatus': 'No',
          'waterStatus': 'Yes',
          'benchmarkLabel': 'hyperlocal census data'
        },
        status: 'Prioritized',
        linkedMpladsWorkId: 'W001',
        linkedMpladsWorkDesc: 'Construction of drain and gutter work near Ramesh home, Sulikere Dananayakanahalli',
        linkedMpladsWorkDistance: 0.05,
        linkedMpladsWorkDate: '2026-07-02',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Cluster(
        id: 'dummy_cluster_2',
        title: 'Drinking Water Pipeline Kommaghatta',
        category: 'Water',
        ward: 'Kommaghatta',
        submissionCount: 154,
        representativeSubmissionIds: ['dummy_sub_2'],
        centroid: {'lat': 12.9145, 'lng': 77.4789},
        enrichment: {
          'scStGap': 0.15, 
          'schoolGap': 0.23, 
          'scPopulationRange': '11-20', 
          'schoolStatus': 'yes (4 schools in-village)',
          'medicalStatus': 'Yes (2 facilities)',
          'waterStatus': 'Yes',
          'benchmarkLabel': 'hyperlocal census data'
        },
        status: 'Prioritized',
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
        centroid: {'lat': 12.6937, 'lng': 77.8629},
        enrichment: {
          'scStGap': 0.12, 
          'schoolGap': 0.8, 
          'scPopulationRange': '10-15', 
          'schoolStatus': 'partial', 
          'medicalStatus': 'No',
          'waterStatus': 'No',
          'isFallbackBenchmark': true,
          'benchmarkLabel': 'state/district benchmark'
        },
        status: 'Prioritized',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ],
    rankings: [
      Ranking(
        clusterId: 'dummy_cluster_1',
        score: 94.2,
        rank: 1,
        explanation: 'Ranked #1 — 340 verified reports across Sulikere; area has 21-30% SC population and a pending drain project completed recently.',
        weightsUsed: {'w1': 0.3, 'w2': 0.25, 'w3': 0.2, 'w4': 0.15, 'w5': 0.1},
        computedAt: DateTime.now(),
      ),
      Ranking(
        clusterId: 'dummy_cluster_2',
        score: 88.5,
        rank: 2,
        explanation: 'Ranked #2 — 154 reports across Kommaghatta; critical drinking water access pipeline breakdown.',
        weightsUsed: {'w1': 0.3, 'w2': 0.25, 'w3': 0.2, 'w4': 0.15, 'w5': 0.1},
        computedAt: DateTime.now(),
      ),
      Ranking(
        clusterId: 'dummy_cluster_3',
        score: 76.0,
        rank: 3,
        explanation: 'Ranked #3 — High benchmark gap: nearest primary health clinic is 12.0 km away from Village East. (state/district benchmark)',
        weightsUsed: {'w1': 0.3, 'w2': 0.25, 'w3': 0.2, 'w4': 0.15, 'w5': 0.1},
        computedAt: DateTime.now(),
      ),
    ],
    upvotedClusterIds: {'dummy_cluster_2'},
    demographics: staticDemographics,
    mpladsWorks: staticMpladsWorks,
    mpMetadata: {
      'mp_info': {
        'name': 'Shri Narayana Koragappa',
        'term': '2020-26',
        'house': 'Rajya Sabha',
        'state': 'Karnataka',
        'status': 'Sitting'
      },
      'fund_summary': {
        'allocated_amount_cr': 19.6,
        'total_expenditure_cr': 13.0,
        'fund_utilization_pct': 66.2,
        'unspent_amount_cr': 6.6,
        'in_progress_payments_cr': 10.3,
        'payment_gap_pct': 79.6,
        'total_works': 174,
        'completion_rate_pct': 21.8,
        'works_completed': 38,
        'pending_works_note_1': 136,
        'pending_works_note_2': 98
      },
      'yearly_trends': [
        { 'year': 2024, 'works': 34, 'amount_cr': 3.4 },
        { 'year': 2025, 'works': 72, 'amount_cr': 8.2 },
        { 'year': 2026, 'works': 32, 'amount_cr': 4.0 }
      ]
    },
  )) {
    _initFirestoreListeners();
  }

  void _initFirestoreListeners() {
    if (_firestore == null) return;

    // Listen to Submissions
    _subsSubscription = _firestore.collection('submissions').orderBy('createdAt', descending: true).snapshots().listen((snap) {
      if (snap.docs.isNotEmpty) {
        final list = snap.docs.map((doc) => Submission.fromFirestore(doc)).toList();
        state = state.copyWith(submissions: list);
      }
    }, onError: (err) => debugPrint('Error reading submissions from firestore: $err'));

    // Listen to Clusters
    _clustersSubscription = _firestore.collection('clusters').orderBy('createdAt', descending: true).snapshots().listen((snap) {
      if (snap.docs.isNotEmpty) {
        final list = snap.docs.map((doc) => Cluster.fromFirestore(doc)).toList();
        state = state.copyWith(clusters: list);
      }
    }, onError: (err) => debugPrint('Error reading clusters from firestore: $err'));

    // Listen to Rankings
    _rankingsSubscription = _firestore.collection('rankings').orderBy('rank', descending: false).snapshots().listen((snap) {
      if (snap.docs.isNotEmpty) {
        final list = snap.docs.map((doc) {
          final d = doc.data();
          return Ranking(
            clusterId: d['clusterId'] ?? doc.id,
            score: (d['score'] ?? 0.0).toDouble(),
            rank: d['rank'] ?? 0,
            explanation: d['explanation'] ?? '',
            weightsUsed: Map<String, double>.from(d['weightsUsed'] ?? {}),
            computedAt: (d['computedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
        }).toList();
        state = state.copyWith(rankings: list);
      }
    }, onError: (err) => debugPrint('Error reading rankings from firestore: $err'));

    // Fetch demographics once
    _firestore.collection('demographics').get().then((snap) {
      if (snap.docs.isNotEmpty) {
        final list = snap.docs.map((doc) => doc.data()).toList();
        state = state.copyWith(demographics: list);
      }
    });

    // Fetch MPLADS works once
    _firestore.collection('mplads_works').get().then((snap) {
      if (snap.docs.isNotEmpty) {
        final list = snap.docs.map((doc) => doc.data()).toList();
        state = state.copyWith(mpladsWorks: list);
      }
    });

    // Fetch MP metadata once
    _firestore.collection('mp_metadata').doc('sitting_mp').get().then((doc) {
      if (doc.exists && doc.data() != null) {
        state = state.copyWith(mpMetadata: doc.data()!);
      }
    });
  }

  @override
  void dispose() {
    _subsSubscription?.cancel();
    _clustersSubscription?.cancel();
    _rankingsSubscription?.cancel();
    super.dispose();
  }

  void addSubmission(Submission sub) {
    if (_firestore != null && !state.isOffline) {
      // In online mode, save directly to Firestore
      _firestore.collection('submissions').doc(sub.id).set(sub.toMap());
    } else {
      // Offline / Fallback mode
      state = state.copyWith(submissions: [sub, ...state.submissions]);
      Future.delayed(const Duration(milliseconds: 500), () {
        _clusterSubmissionLocally(sub);
      });
    }
  }

  void _clusterSubmissionLocally(Submission sub) {
    final list = [...state.clusters];
    bool merged = false;

    // Scan nearby pending/in-progress works from static works list
    Map<String, dynamic>? closestWork;
    double closestWorkDist = 1.0; // 1km limit

    final subLat = sub.extractedLocation?['lat'] ?? 12.9126;
    final subLng = sub.extractedLocation?['lng'] ?? 77.4628;

    for (var w in state.mpladsWorks) {
      if (w['status'] == 'completed') continue;
      final lat = w['lat'];
      final lng = w['lng'];
      if (lat != null && lng != null) {
        // Haversine approximation
        final double dist = _getDistance(subLat, subLng, lat, lng);
        if (dist < closestWorkDist) {
          closestWorkDist = dist;
          closestWork = w;
        }
      }
    }

    for (int i = 0; i < list.length; i++) {
      final c = list[i];
      if (c.category == sub.category && c.ward == (sub.extractedLocation?['village'] ?? 'General')) {
        // Merge
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
          linkedMpladsWorkId: closestWork != null ? closestWork['id'] : c.linkedMpladsWorkId,
          linkedMpladsWorkDesc: closestWork != null ? closestWork['work_description'] : c.linkedMpladsWorkDesc,
          linkedMpladsWorkDistance: closestWork != null ? closestWorkDist : c.linkedMpladsWorkDistance,
          linkedMpladsWorkDate: closestWork != null ? closestWork['date'] : c.linkedMpladsWorkDate,
          createdAt: c.createdAt,
          updatedAt: DateTime.now(),
        );
        merged = true;
        break;
      }
    }

    if (!merged) {
      list.add(Cluster(
        id: 'cluster_${DateTime.now().millisecondsSinceEpoch}',
        title: sub.originalText.length > 30 ? '${sub.originalText.substring(0, 30)}...' : sub.originalText,
        category: sub.category,
        ward: sub.extractedLocation?['village'] ?? 'General',
        submissionCount: 1,
        representativeSubmissionIds: [sub.id],
        centroid: {'lat': subLat, 'lng': subLng},
        enrichment: {
          'scStGap': 0.25, 
          'schoolGap': 0.35, 
          'scPopulationRange': '21-30', 
          'schoolStatus': 'yes (PP/P/M/S/SS all in-village)',
          'medicalStatus': 'No',
          'waterStatus': 'Yes',
          'benchmarkLabel': 'hyperlocal census data'
        },
        status: 'Under Review',
        linkedMpladsWorkId: closestWork != null ? closestWork['id'] : null,
        linkedMpladsWorkDesc: closestWork != null ? closestWork['work_description'] : null,
        linkedMpladsWorkDistance: closestWork != null ? closestWorkDist : null,
        linkedMpladsWorkDate: closestWork != null ? closestWork['date'] : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    state = state.copyWith(clusters: list);
    recalculateScores();
  }

  double _getDistance(double lat1, double lon1, double lat2, double lon2) {
    // Simple Euclidean distance approximation in coordinates
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    return dLat * dLat + dLon * dLon * 111.0; // very raw, sufficient for fallback sorting
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
  final firestore = ref.watch(firestoreProvider);
  return LocalDataNotifier(firestore);
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
