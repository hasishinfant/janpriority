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
  final String? linkedMpladsWorkId;
  final String? linkedMpladsWorkDesc;
  final double? linkedMpladsWorkDistance;
  final String? linkedMpladsWorkDate;
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
    this.linkedMpladsWorkId,
    this.linkedMpladsWorkDesc,
    this.linkedMpladsWorkDistance,
    this.linkedMpladsWorkDate,
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
      linkedMpladsWorkId: data['linkedMpladsWorkId'],
      linkedMpladsWorkDesc: data['linkedMpladsWorkDesc'],
      linkedMpladsWorkDistance: data['linkedMpladsWorkDistance'] != null 
          ? (data['linkedMpladsWorkDistance'] as num).toDouble() 
          : null,
      linkedMpladsWorkDate: data['linkedMpladsWorkDate'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

