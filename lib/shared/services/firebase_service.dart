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
final List<Map<String, dynamic>> staticBangaloreDemographics = [
  {
    'village_name': 'Seshagiripura', 'location_code': '613005', 'population_2011': 246, 'households': 62,
    'sc_population_pct_range': null, 'st_population_pct_range': null,
    'schools_in_village_pp_p_m_s': 'partial (a/a/a/a - all 5-10km away)',
    'medical_facility_in_village': 'No', 'drinking_water_available': 'No', 'electricity_domestic': 'Yes',
    'lat': 12.9080, 'lng': 77.4720
  },
  {
    'village_name': 'Chikkellur', 'location_code': '613006', 'population_2011': 1120, 'households': 252,
    'sc_population_pct_range': null, 'st_population_pct_range': null,
    'schools_in_village_pp_p_m_s': 'yes (2 schools in-village)',
    'medical_facility_in_village': 'Yes', 'drinking_water_available': 'Yes', 'electricity_domestic': 'Yes',
    'lat': 12.9220, 'lng': 77.4350
  },
  {
    'village_name': 'Kenchanapura', 'location_code': '613010', 'population_2011': 769, 'households': 178,
    'sc_population_pct_range': '21-30', 'st_population_pct_range': null,
    'schools_in_village_pp_p_m_s': 'yes (2 schools in-village)',
    'medical_facility_in_village': 'No', 'drinking_water_available': 'Yes', 'electricity_domestic': 'Yes',
    'lat': 12.9192, 'lng': 77.4589
  },
  {
    'village_name': 'Kommaghatta', 'location_code': '613011', 'population_2011': 2950, 'households': 749,
    'sc_population_pct_range': '11-20', 'st_population_pct_range': null,
    'schools_in_village_pp_p_m_s': 'yes (4 schools in-village)',
    'medical_facility_in_village': 'Yes (2 facilities)', 'drinking_water_available': 'Yes', 'electricity_domestic': 'Yes',
    'lat': 12.9145, 'lng': 77.4789
  },
  {
    'village_name': 'Sulikere', 'location_code': '613012', 'population_2011': 1070, 'households': 265,
    'sc_population_pct_range': '21-30', 'st_population_pct_range': 'Less than 5',
    'schools_in_village_pp_p_m_s': 'yes (PP/P/M/S/SS all in-village)',
    'medical_facility_in_village': 'No', 'drinking_water_available': 'Yes', 'electricity_domestic': 'Yes',
    'lat': 12.9126, 'lng': 77.4628
  },
  {
    'village_name': 'Ramohalli', 'location_code': '613016', 'population_2011': 3975, 'households': 982,
    'sc_population_pct_range': '11-20', 'st_population_pct_range': 'Less than 5',
    'schools_in_village_pp_p_m_s': 'yes (6 schools in-village)',
    'medical_facility_in_village': 'No', 'drinking_water_available': 'Yes', 'electricity_domestic': 'Yes',
    'lat': 12.8988, 'lng': 77.4520
  },
  {
    'village_name': 'Bheemanakuppe', 'location_code': '613017', 'population_2011': 3321, 'households': 830,
    'sc_population_pct_range': '5-10', 'st_population_pct_range': 'Less than 5',
    'schools_in_village_pp_p_m_s': 'yes (5 schools in-village)',
    'medical_facility_in_village': 'Yes', 'drinking_water_available': 'Yes', 'electricity_domestic': 'Yes',
    'lat': 12.9056, 'lng': 77.4423
  }
];

// Static demographics dataset from demographics_kozhikode.csv
final List<Map<String, dynamic>> staticKozhikodeDemographics = [
  {
    'village_name': 'Onchiam', 'location_code': '627341', 'population_2011': 28650, 'households': 6289,
    'sc_population_pct_range': 'less_than_5', 'st_population_pct_range': 'less_than_5',
    'schools_in_village_pp_p_m_s': 'yes (13 primary, 3 middle, 2 secondary)',
    'medical_facility_in_village': 'Yes', 'drinking_water_available': 'Yes', 'electricity_domestic': 'Yes',
    'lat': 11.7288, 'lng': 75.6104
  },
  {
    'village_name': 'Vanimel', 'location_code': '627342', 'population_2011': 25680, 'households': 5587,
    'sc_population_pct_range': 'less_than_5', 'st_population_pct_range': 'less_than_5',
    'schools_in_village_pp_p_m_s': 'yes (11 primary, 3 middle, 2 secondary)',
    'medical_facility_in_village': 'No', 'drinking_water_available': 'Yes', 'electricity_domestic': 'Yes',
    'lat': 11.7804, 'lng': 75.7204
  },
  {
    'village_name': 'Vilangad', 'location_code': '627343', 'population_2011': 3778, 'households': 916,
    'sc_population_pct_range': 'less_than_5', 'st_population_pct_range': '21_to_30',
    'schools_in_village_pp_p_m_s': 'yes (4 primary, 2 middle, 1 secondary)',
    'medical_facility_in_village': 'No', 'drinking_water_available': 'No', 'electricity_domestic': 'Yes',
    'lat': 11.7904, 'lng': 75.7504
  },
  {
    'village_name': 'Kayakkodi', 'location_code': '627346', 'population_2011': 24578, 'households': 5664,
    'sc_population_pct_range': 'less_than_5', 'st_population_pct_range': 'less_than_5',
    'schools_in_village_pp_p_m_s': 'yes (12 primary, 5 middle, 2 secondary)',
    'medical_facility_in_village': 'Yes', 'drinking_water_available': 'Yes', 'electricity_domestic': 'Yes',
    'lat': 11.6988, 'lng': 75.6904
  },
  {
    'village_name': 'Narippatta', 'location_code': '627347', 'population_2011': 21381, 'households': 4977,
    'sc_population_pct_range': 'less_than_5', 'st_population_pct_range': 'less_than_5',
    'schools_in_village_pp_p_m_s': 'yes (12 primary, 2 middle, 1 secondary)',
    'medical_facility_in_village': 'No', 'drinking_water_available': 'Yes', 'electricity_domestic': 'Yes',
    'lat': 11.7104, 'lng': 75.7104
  }
];

// Static Mumbai slums
final List<Map<String, dynamic>> staticMumbaiSlums = [
  {
    'slum_name': 'RAMABAI NAGAR', 'households_approx': 1182, 'slum_population_approx': 5188,
    'sanitation_gap_ratio': 0.808, 'constituency': 'Mumbai South Central', 'type': 'slum', 'is_rollup': false,
    'electricity_domestic_conn': 1051, 'public_water_tap_points': 355
  },
  {
    'slum_name': 'JAI MALHAR SEVANAGAR GHATKOPAR', 'households_approx': 207, 'slum_population_approx': 940,
    'sanitation_gap_ratio': 0.797, 'constituency': 'Mumbai South Central', 'type': 'slum', 'is_rollup': false,
    'electricity_domestic_conn': 184, 'public_water_tap_points': 63
  },
  {
    'slum_name': 'panchashil nagar bhatwadi', 'households_approx': 415, 'slum_population_approx': 2100,
    'sanitation_gap_ratio': 0.773, 'constituency': 'Mumbai South Central', 'type': 'slum', 'is_rollup': false,
    'electricity_domestic_conn': 369, 'public_water_tap_points': 125
  },
  {
    'slum_name': 'shiv sandesh chawl', 'households_approx': 47, 'slum_population_approx': 210,
    'sanitation_gap_ratio': 0.787, 'constituency': 'Mumbai South Central', 'type': 'slum', 'is_rollup': false,
    'electricity_domestic_conn': 42, 'public_water_tap_points': 15
  },
  {
    'slum_name': 'pawarwadi ambedkar nagar', 'households_approx': 575, 'slum_population_approx': 2520,
    'sanitation_gap_ratio': 0.809, 'constituency': 'Mumbai South Central', 'type': 'slum', 'is_rollup': false,
    'electricity_domestic_conn': 512, 'public_water_tap_points': 173
  },
  {
    'slum_name': 'L ward slum area', 'households_approx': 127348, 'slum_population_approx': 584523,
    'sanitation_gap_ratio': 0.981, 'constituency': 'Mumbai South Central', 'type': 'slum', 'is_rollup': true,
    'electricity_domestic_conn': 118842, 'public_water_tap_points': 16500
  }
];

// Static Chennai slums
final List<Map<String, dynamic>> staticChennaiSlums = [
  {
    'slum_name': 'SARMA NAGAR', 'households_approx': 1200, 'slum_population_approx': 5040,
    'sanitation_gap_ratio': 0.25, 'constituency': 'Chennai North', 'type': 'slum', 'is_rollup': false,
    'electricity_domestic_conn': 1080, 'public_water_tap_points': 80
  },
  {
    'slum_name': 'RAJARATHNAM NAGAR', 'households_approx': 325, 'slum_population_approx': 1365,
    'sanitation_gap_ratio': 0.249, 'constituency': 'Chennai North', 'type': 'slum', 'is_rollup': false,
    'electricity_domestic_conn': 293, 'public_water_tap_points': 22
  },
  {
    'slum_name': 'NAVALAR KUDIYIRUPPU', 'households_approx': 450, 'slum_population_approx': 1890,
    'sanitation_gap_ratio': 0.249, 'constituency': 'Chennai North', 'type': 'slum', 'is_rollup': false,
    'electricity_domestic_conn': 405, 'public_water_tap_points': 30
  },
  {
    'slum_name': 'VINOBHA NAGAR', 'households_approx': 750, 'slum_population_approx': 3150,
    'sanitation_gap_ratio': 0.249, 'constituency': 'Chennai North', 'type': 'slum', 'is_rollup': false,
    'electricity_domestic_conn': 675, 'public_water_tap_points': 50
  },
  {
    'slum_name': 'PATEL NAGAR', 'households_approx': 525, 'slum_population_approx': 2205,
    'sanitation_gap_ratio': 0.25, 'constituency': 'Chennai North', 'type': 'slum', 'is_rollup': false,
    'electricity_domestic_conn': 473, 'public_water_tap_points': 35
  }
];

// Static MPLADS works details matching existing JSON formats
final List<Map<String, dynamic>> staticBangaloreWorks = [
  {
    'id': 'BLR_W001', 'category': 'Roads', 'work_description': 'Construction of drain and gutter work near Ramesh home, Sulikere Dananayakanahalli',
    'village_area': 'Sulikere Dananayakanahalli', 'matched_census_village': 'Sulikere', 'matched_census_location_code': '613012',
    'amount': 5.0, 'status': 'completed', 'date': '2026-07-02', 'sc_st_tagged': false, 'lat': 12.9126, 'lng': 77.4628
  },
  {
    'id': 'BLR_W009', 'category': 'Roads', 'work_description': 'Construction of CC roads up to Haliyuru boundary in Sundaresh Ashraya Layout, Galihalli (SC/ST colony)',
    'village_area': 'Galihalli', 'matched_census_village': null, 'matched_census_location_code': null,
    'amount': 30.0, 'status': 'recommended', 'date': '2026-05-16', 'sc_st_tagged': true, 'lat': 12.7234, 'lng': 77.2912
  }
];

final List<Map<String, dynamic>> staticKozhikodeWorks = [
  {
    'id': 'KZ-C01', 'category': 'Roads', 'work_description': 'Construction of Kuruvachal Thanikuzhi Road',
    'village_area': 'Kuruvachal Thanikuzhi', 'matched_census_village': null, 'matched_census_location_code': null,
    'amount': 3.2, 'status': 'completed', 'date': '2026-03-07', 'sc_st_tagged': false, 'lat': 11.7288, 'lng': 75.6104
  },
  {
    'id': 'KZ-R02', 'category': 'Roads', 'work_description': 'Construction of Poolakkottuthazham Poolakkottumeethal SC Nagar Road',
    'village_area': 'Poolakkottuthazham SC Nagar', 'matched_census_village': null, 'matched_census_location_code': null,
    'amount': 10.0, 'status': 'recommended', 'date': '2026-02-27', 'sc_st_tagged': true, 'lat': 11.6988, 'lng': 75.6904
  }
];

final List<Map<String, dynamic>> staticMumbaiWorks = [
  {
    'id': 'MSC-R01', 'category': 'Sanitation', 'work_description': 'Construction of drains and passage',
    'village_area': null, 'matched_census_village': null, 'matched_census_location_code': null,
    'amount': 20.0, 'status': 'recommended', 'date': '2025-09-18', 'sc_st_tagged': false, 'lat': 19.0178, 'lng': 72.8478
  },
  {
    'id': 'MSC-R02', 'category': 'Roads', 'work_description': 'Providing and laying paver blocks',
    'village_area': null, 'matched_census_village': null, 'matched_census_location_code': null,
    'amount': 25.0, 'status': 'recommended', 'date': '2025-09-18', 'sc_st_tagged': false, 'lat': 19.0200, 'lng': 72.8500
  }
];

final List<Map<String, dynamic>> staticChennaiWorks = [
  {
    'id': 'CHN-C01', 'category': 'Water', 'work_description': 'Construction of sump and water supply arrangement at Bharathi Nagar 4th Street',
    'village_area': 'Bharathi Nagar 4th Street', 'matched_census_village': null, 'matched_census_location_code': null,
    'amount': 24.6, 'status': 'completed', 'date': '2026-05-15', 'sc_st_tagged': false, 'lat': 13.1145, 'lng': 80.2878
  },
  {
    'id': 'CHN-C02', 'category': 'Roads', 'work_description': 'Proposed construction of road side park at VOC Nagar South Street',
    'village_area': 'VOC Nagar South Street', 'matched_census_village': null, 'matched_census_location_code': null,
    'amount': 5.9, 'status': 'completed', 'date': '2026-05-15', 'sc_st_tagged': false, 'lat': 13.1200, 'lng': 80.2900
  }
];

final Map<String, Map<String, dynamic>> staticConstituencyMpMetadata = {
  'Bangalore South': {
    'mp_info': {'name': 'Shri Narayana Koragappa', 'term': '2020-26', 'house': 'Rajya Sabha', 'state': 'Karnataka', 'status': 'Sitting'},
    'fund_summary': {
      'allocated_amount_cr': 19.6, 'total_expenditure_cr': 13.0, 'fund_utilization_pct': 66.2, 'unspent_amount_cr': 6.6,
      'payment_gap_pct': 79.6, 'total_works': 174, 'works_completed': 38, 'pending_works_note_2': 98
    },
    'yearly_trends': [
      { 'year': 2024, 'works': 34, 'amount_cr': 3.4 },
      { 'year': 2025, 'works': 72, 'amount_cr': 8.2 },
      { 'year': 2026, 'works': 32, 'amount_cr': 4.0 }
    ]
  },
  'Kozhikode': {
    'mp_info': {'name': 'Shri M K Raghavan', 'term': '2019-24', 'house': 'Lok Sabha', 'state': 'Kerala', 'status': 'Sitting'},
    'fund_summary': {
      'allocated_amount_cr': 14.7, 'total_expenditure_cr': 0.399, 'fund_utilization_pct': 2.7, 'unspent_amount_cr': 14.3,
      'payment_gap_pct': 64.2, 'total_works': 271, 'works_completed': 4, 'pending_works_note_2': 267
    },
    'yearly_trends': [
      { 'year': 2025, 'works': 69, 'amount_cr': 2.5 },
      { 'year': 2026, 'works': 35, 'amount_cr': 1.8 }
    ]
  },
  'Mumbai South Central': {
    'mp_info': {'name': 'Shri Anil Yeshwant Desai', 'term': '2024-30', 'house': 'Lok Sabha', 'state': 'Maharashtra', 'status': 'Sitting'},
    'fund_summary': {
      'allocated_amount_cr': 14.7, 'total_expenditure_cr': 0.59, 'fund_utilization_pct': 4.0, 'unspent_amount_cr': 14.1,
      'payment_gap_pct': 100.0, 'total_works': 34, 'works_completed': 0, 'pending_works_note_2': 34
    },
    'yearly_trends': [
      { 'year': 2025, 'works': 34, 'amount_cr': 8.3 }
    ]
  },
  'Chennai North': {
    'mp_info': {'name': 'Dr. Kalanidhi Veeraswamy', 'term': '2019-24', 'house': 'Lok Sabha', 'state': 'Tamil Nadu', 'status': 'Sitting'},
    'fund_summary': {
      'allocated_amount_cr': 17.2, 'total_expenditure_cr': 8.0, 'fund_utilization_pct': 46.9, 'unspent_amount_cr': 9.1,
      'payment_gap_pct': 91.4, 'total_works': 74, 'works_completed': 7, 'pending_works_note_2': 60
    },
    'yearly_trends': [
      { 'year': 2024, 'works': 1, 'amount_cr': 1.0 },
      { 'year': 2025, 'works': 52, 'amount_cr': 9.0 },
      { 'year': 2026, 'works': 21, 'amount_cr': 2.1 }
    ]
  }
};

class LocalDataState {
  final String activeConstituency;
  final List<Submission> submissions;
  final List<Cluster> clusters;
  final List<Ranking> rankings;
  final Set<String> upvotedClusterIds;
  final List<Map<String, dynamic>> demographics;
  final List<Map<String, dynamic>> mpladsWorks;
  final Map<String, dynamic> mpMetadata;
  final bool isOffline;

  LocalDataState({
    required this.activeConstituency,
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
    String? activeConstituency,
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
      activeConstituency: activeConstituency ?? this.activeConstituency,
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

final Map<String, List<Map<String, dynamic>>> staticConstituencyDemographics = {
  'Bangalore South': staticBangaloreDemographics,
  'Kozhikode': staticKozhikodeDemographics,
  'Mumbai South Central': staticMumbaiSlums,
  'Chennai North': staticChennaiSlums,
};

final Map<String, List<Map<String, dynamic>>> staticConstituencyMpladsWorks = {
  'Bangalore South': staticBangaloreWorks,
  'Kozhikode': staticKozhikodeWorks,
  'Mumbai South Central': staticMumbaiWorks,
  'Chennai North': staticChennaiWorks,
};

class LocalDataNotifier extends StateNotifier<LocalDataState> {
  StreamSubscription? _subsSubscription;
  StreamSubscription? _clustersSubscription;
  StreamSubscription? _rankingsSubscription;
  final FirebaseFirestore? _firestore;

  LocalDataNotifier(this._firestore) : super(LocalDataState(
    activeConstituency: 'Bangalore South',
    submissions: [
      Submission(
        id: 'dummy_sub_1', citizenPhone: '******3210', mode: 'text',
        originalText: 'Primary school roof is leaking and needs urgent repair in Sulikere.',
        originalLanguage: 'en', translatedText: 'Primary school roof is leaking and needs urgent repair in Sulikere.',
        category: 'Education', extractedLocation: {'ward': 'General', 'village': 'Sulikere'},
        severity: 0.75, sentiment: -0.4, status: 'Processed', clusterId: 'dummy_cluster_1',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Submission(
        id: 'dummy_sub_2', citizenPhone: '******5555', mode: 'voice',
        originalText: 'There is no drinking water in Kommaghatta for the last 3 days.',
        originalLanguage: 'en', translatedText: 'There is no drinking water in Kommaghatta for the last 3 days.',
        category: 'Water', extractedLocation: {'ward': 'General', 'village': 'Kommaghatta'},
        severity: 0.9, sentiment: -0.6, status: 'Processed', clusterId: 'dummy_cluster_2',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ],
    clusters: [
      Cluster(
        id: 'dummy_cluster_1', title: 'Govt School Primary Upgrade', category: 'Education', ward: 'Sulikere',
        submissionCount: 340, representativeSubmissionIds: ['dummy_sub_1'], centroid: {'lat': 12.9126, 'lng': 77.4628},
        enrichment: {
          'scStGap': 0.25, 'schoolGap': 0.56, 'scPopulationRange': '21-30',
          'schoolStatus': 'yes (PP/P/M/S/SS all in-village)', 'medicalStatus': 'No', 'waterStatus': 'Yes',
          'benchmarkLabel': 'hyperlocal census data'
        },
        status: 'Prioritized', linkedMpladsWorkId: 'BLR_W001',
        linkedMpladsWorkDesc: 'Construction of drain and gutter work near Ramesh home, Sulikere Dananayakanahalli',
        linkedMpladsWorkDistance: 0.05, linkedMpladsWorkDate: '2026-07-02',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Cluster(
        id: 'dummy_cluster_2', title: 'Drinking Water Pipeline Kommaghatta', category: 'Water', ward: 'Kommaghatta',
        submissionCount: 154, representativeSubmissionIds: ['dummy_sub_2'], centroid: {'lat': 12.9145, 'lng': 77.4789},
        enrichment: {
          'scStGap': 0.15, 'schoolGap': 0.23, 'scPopulationRange': '11-20',
          'schoolStatus': 'yes (4 schools in-village)', 'medicalStatus': 'Yes (2 facilities)', 'waterStatus': 'Yes',
          'benchmarkLabel': 'hyperlocal census data'
        },
        status: 'Prioritized', createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ],
    rankings: [
      Ranking(
        clusterId: 'dummy_cluster_1', score: 94.2, rank: 1,
        explanation: 'Ranked #1 — 340 verified reports across Sulikere; area has 21-30% SC population and a pending drain project completed recently.',
        weightsUsed: {'w1': 0.3, 'w2': 0.25, 'w3': 0.2, 'w4': 0.15, 'w5': 0.1}, computedAt: DateTime.now(),
      ),
      Ranking(
        clusterId: 'dummy_cluster_2', score: 88.5, rank: 2,
        explanation: 'Ranked #2 — 154 reports across Kommaghatta; critical drinking water access pipeline breakdown.',
        weightsUsed: {'w1': 0.3, 'w2': 0.25, 'w3': 0.2, 'w4': 0.15, 'w5': 0.1}, computedAt: DateTime.now(),
      ),
    ],
    upvotedClusterIds: {'dummy_cluster_2'},
    demographics: staticBangaloreDemographics,
    mpladsWorks: staticBangaloreWorks,
    mpMetadata: staticConstituencyMpMetadata['Bangalore South']!,
  )) {
    _initFirestoreListeners();
  }

  void setConstituency(String constituency) {
    // 1. Load corresponding static datasets
    final dem = staticConstituencyDemographics[constituency] ?? staticMumbaiSlums;
    final wrk = staticConstituencyMpladsWorks[constituency] ?? staticMumbaiWorks;
    final meta = staticConstituencyMpMetadata[constituency] ?? staticConstituencyMpMetadata['Bangalore South']!;

    // 2. Load representative dummy clusters & rankings for Kozhikode, Mumbai & Chennai
    List<Cluster> dummyClusters = [];
    List<Ranking> dummyRankings = [];

    if (constituency == 'Kozhikode') {
      dummyClusters = [
        Cluster(
          id: 'dummy_cluster_koz_1', title: 'Onchiam Primary School Drinking Water', category: 'Water', ward: 'Onchiam',
          submissionCount: 120, representativeSubmissionIds: [], centroid: {'lat': 11.7288, 'lng': 75.6104},
          enrichment: {
            'scStGap': 0.05, 'schoolGap': 0.1, 'scPopulationRange': 'less_than_5',
            'schoolStatus': 'yes (13 primary)', 'medicalStatus': 'Yes', 'waterStatus': 'Yes',
            'benchmarkLabel': 'hyperlocal census data'
          },
          status: 'Prioritized', linkedMpladsWorkId: 'KZ-C01',
          linkedMpladsWorkDesc: 'Construction of Kuruvachal Thanikuzhi Road',
          linkedMpladsWorkDistance: 0.15, linkedMpladsWorkDate: '2026-03-07',
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        ),
        Cluster(
          id: 'dummy_cluster_koz_2', title: 'Vilangad SC Colony Electrification', category: 'Other', ward: 'Vilangad',
          submissionCount: 75, representativeSubmissionIds: [], centroid: {'lat': 11.7904, 'lng': 75.7504},
          enrichment: {
            'scStGap': 0.45, 'schoolGap': 0.7, 'scPopulationRange': '21_to_30',
            'schoolStatus': 'yes (4 primary)', 'medicalStatus': 'No', 'waterStatus': 'No',
            'benchmarkLabel': 'hyperlocal census data'
          },
          status: 'Prioritized', linkedMpladsWorkId: 'KZ-R02',
          linkedMpladsWorkDesc: 'Construction of Poolakkottuthazham Poolakkottumeethal SC Nagar Road',
          linkedMpladsWorkDistance: 0.08, linkedMpladsWorkDate: '2026-02-27',
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        )
      ];
      dummyRankings = [
        Ranking(
          clusterId: 'dummy_cluster_koz_2', score: 92.5, rank: 1,
          explanation: 'Ranked #1 — High demographic gap: Vilangad village has 21-30% Scheduled Tribe population and lacks regular medical facilities.',
          weightsUsed: {'w1': 0.3, 'w2': 0.25, 'w3': 0.2, 'w4': 0.15, 'w5': 0.1}, computedAt: DateTime.now(),
        ),
        Ranking(
          clusterId: 'dummy_cluster_koz_1', score: 81.0, rank: 2,
          explanation: 'Ranked #2 — 120 verified complaints in Onchiam requesting drinking water support near Kuruvachal road.',
          weightsUsed: {'w1': 0.3, 'w2': 0.25, 'w3': 0.2, 'w4': 0.15, 'w5': 0.1}, computedAt: DateTime.now(),
        )
      ];
    } else if (constituency == 'Mumbai South Central') {
      dummyClusters = [
        Cluster(
          id: 'dummy_cluster_mum_1', title: 'Ramabai Nagar Slum Toilet Repairs', category: 'Sanitation', ward: 'RAMABAI NAGAR',
          submissionCount: 240, representativeSubmissionIds: [], centroid: {'lat': 19.0178, 'lng': 72.8478},
          enrichment: {
            'scStGap': 0.3, 'schoolGap': 0.8, 'scPopulationRange': '30%',
            'schoolStatus': 'N.A.', 'medicalStatus': 'No', 'waterStatus': 'No',
            'benchmarkLabel': 'slum sanitation index'
          },
          status: 'Prioritized', linkedMpladsWorkId: 'MSC-R01',
          linkedMpladsWorkDesc: 'Construction of drains and passage',
          linkedMpladsWorkDistance: 0.05, linkedMpladsWorkDate: '2025-09-18',
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        )
      ];
      dummyRankings = [
        Ranking(
          clusterId: 'dummy_cluster_mum_1', score: 96.4, rank: 1,
          explanation: 'Ranked #1 — Critical sanitation gap: Ramabai Nagar slum has an 80.8% sanitation deficit (households without private toilets) with 240 complaints.',
          weightsUsed: {'w1': 0.3, 'w2': 0.25, 'w3': 0.2, 'w4': 0.15, 'w5': 0.1}, computedAt: DateTime.now(),
        )
      ];
    } else if (constituency == 'Chennai North') {
      dummyClusters = [
        Cluster(
          id: 'dummy_cluster_chn_1', title: 'Sarma Nagar Community Latrine Block', category: 'Sanitation', ward: 'SARMA NAGAR',
          submissionCount: 180, representativeSubmissionIds: [], centroid: {'lat': 13.1145, 'lng': 80.2878},
          enrichment: {
            'scStGap': 0.25, 'schoolGap': 0.5, 'scPopulationRange': '25%',
            'schoolStatus': 'N.A.', 'medicalStatus': 'No', 'waterStatus': 'Yes',
            'benchmarkLabel': 'slum sanitation index'
          },
          status: 'Prioritized', linkedMpladsWorkId: 'CHN-C01',
          linkedMpladsWorkDesc: 'Construction of sump and water supply arrangement at Bharathi Nagar',
          linkedMpladsWorkDistance: 0.12, linkedMpladsWorkDate: '2026-05-15',
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        )
      ];
      dummyRankings = [
        Ranking(
          clusterId: 'dummy_cluster_chn_1', score: 88.2, rank: 1,
          explanation: 'Ranked #1 — Sarma Nagar slum registers a 25.0% sanitation gap with 180 complaints; Bharathi Nagar water sump project sits nearby.',
          weightsUsed: {'w1': 0.3, 'w2': 0.25, 'w3': 0.2, 'w4': 0.15, 'w5': 0.1}, computedAt: DateTime.now(),
        )
      ];
    } else {
      // Default Bangalore
      dummyClusters = state.clusters;
      dummyRankings = state.rankings;
    }

    state = state.copyWith(
      activeConstituency: constituency,
      demographics: dem,
      mpladsWorks: wrk,
      mpMetadata: meta,
      clusters: dummyClusters.isNotEmpty ? dummyClusters : state.clusters,
      rankings: dummyRankings.isNotEmpty ? dummyRankings : state.rankings,
    );

    // 3. Trigger Firestore updates if online
    if (_firestore != null && !state.isOffline) {
      _fetchFirestoreConstituencyData(constituency);
    }
  }

  void _fetchFirestoreConstituencyData(String constituency) {
    if (_firestore == null) return;

    // Fetch demographics for this constituency
    _firestore.collection('demographics')
        .where('constituency', isEqualTo: constituency)
        .get()
        .then((snap) {
      if (snap.docs.isNotEmpty) {
        final list = snap.docs.map((doc) => doc.data()).toList();
        state = state.copyWith(demographics: list);
      }
    });

    // Fetch slums for this constituency
    _firestore.collection('slum_localities')
        .where('constituency', isEqualTo: constituency)
        .get()
        .then((snap) {
      if (snap.docs.isNotEmpty) {
        final list = snap.docs.map((doc) => doc.data()).toList();
        state = state.copyWith(demographics: list); // Merge or overwrite demographics list in state
      }
    });

    // Fetch works for this constituency
    _firestore.collection('mplads_works')
        .where('constituency', isEqualTo: constituency)
        .get()
        .then((snap) {
      if (snap.docs.isNotEmpty) {
        final list = snap.docs.map((doc) => doc.data()).toList();
        state = state.copyWith(mpladsWorks: list);
      }
    });

    // Fetch MP Profile for this constituency
    final mpDocId = _getMpDocId(constituency);
    _firestore.collection('mp_profile').doc(mpDocId).get().then((doc) {
      if (doc.exists && doc.data() != null) {
        state = state.copyWith(mpMetadata: doc.data()!);
      }
    });
  }

  String _getMpDocId(String constituency) {
    switch (constituency) {
      case 'Bangalore South': return 'narayana_koragappa';
      case 'Kozhikode': return 'mk_raghavan';
      case 'Mumbai South Central': return 'anil_yeshwant_desai';
      case 'Chennai North': return 'kalanidhi_veeraswamy';
      default: return 'narayana_koragappa';
    }
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
        list[i] = Cluster(
          id: c.id, title: c.title, category: c.category, ward: c.ward,
          submissionCount: c.submissionCount + 1,
          representativeSubmissionIds: [...c.representativeSubmissionIds, sub.id],
          centroid: c.centroid, enrichment: c.enrichment, status: c.status,
          linkedMpladsWorkId: closestWork != null ? closestWork['id'] : c.linkedMpladsWorkId,
          linkedMpladsWorkDesc: closestWork != null ? closestWork['work_description'] : c.linkedMpladsWorkDesc,
          linkedMpladsWorkDistance: closestWork != null ? closestWorkDist : c.linkedMpladsWorkDistance,
          linkedMpladsWorkDate: closestWork != null ? closestWork['date'] : c.linkedMpladsWorkDate,
          createdAt: c.createdAt, updatedAt: DateTime.now(),
        );
        merged = true;
        break;
      }
    }

    if (!merged) {
      list.add(Cluster(
        id: 'cluster_${DateTime.now().millisecondsSinceEpoch}',
        title: sub.originalText.length > 30 ? '${sub.originalText.substring(0, 30)}...' : sub.originalText,
        category: sub.category, ward: sub.extractedLocation?['village'] ?? 'General',
        submissionCount: 1, representativeSubmissionIds: [sub.id], centroid: {'lat': subLat, 'lng': subLng},
        enrichment: {
          'scStGap': 0.25, 'schoolGap': 0.35, 'scPopulationRange': '21-30',
          'schoolStatus': 'yes (PP/P/M/S/SS all in-village)', 'medicalStatus': 'No', 'waterStatus': 'Yes',
          'benchmarkLabel': 'hyperlocal census data'
        },
        status: 'Under Review',
        linkedMpladsWorkId: closestWork != null ? closestWork['id'] : null,
        linkedMpladsWorkDesc: closestWork != null ? closestWork['work_description'] : null,
        linkedMpladsWorkDistance: closestWork != null ? closestWorkDist : null,
        linkedMpladsWorkDate: closestWork != null ? closestWork['date'] : null,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ));
    }

    state = state.copyWith(clusters: list);
    recalculateScores();
  }

  double _getDistance(double lat1, double lon1, double lat2, double lon2) {
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    return dLat * dLat + dLon * dLon * 111.0;
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
