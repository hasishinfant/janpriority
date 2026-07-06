import 'package:cloud_firestore/cloud_firestore.dart';

class Cluster {
  final String id;
  final String title;
  final String category;
  final String ward;
  final int submissionCount;
  final List<String> representativeSubmissionIds;
  final Map<String, dynamic>? centroid; // lat, lng
  final Map<String, dynamic>? enrichment; // census, infra, devPlan
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Cluster({
    required this.id,
    required this.title,
    required this.category,
    required this.ward,
    required this.submissionCount,
    required this.representativeSubmissionIds,
    this.centroid,
    this.enrichment,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Cluster.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Cluster(
      id: doc.id,
      title: data['title'] ?? '',
      category: data['category'] ?? '',
      ward: data['ward'] ?? '',
      submissionCount: data['submissionCount'] ?? 0,
      representativeSubmissionIds: List<String>.from(data['representativeSubmissionIds'] ?? []),
      centroid: data['centroid'],
      enrichment: data['enrichment'],
      status: data['status'] ?? 'Under Review',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
