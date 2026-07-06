import 'package:cloud_firestore/cloud_firestore.dart';

class Ranking {
  final String clusterId;
  final double score;
  final Map<String, dynamic> weightsUsed; // w1..w5
  final String explanation;
  final int rank;
  final DateTime computedAt;

  Ranking({
    required this.clusterId,
    required this.score,
    required this.weightsUsed,
    required this.explanation,
    required this.rank,
    required this.computedAt,
  });

  factory Ranking.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Ranking(
      clusterId: doc.id,
      score: (data['score'] ?? 0.0).toDouble(),
      weightsUsed: data['weightsUsed'] ?? {},
      explanation: data['explanation'] ?? '',
      rank: data['rank'] ?? 0,
      computedAt: (data['computedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
