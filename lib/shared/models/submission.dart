import 'package:cloud_firestore/cloud_firestore.dart';

class Submission {
  final String id;
  final String citizenPhone; // Hashed for privacy
  final String mode; // voice | text | photo
  final String? rawAudioUrl;
  final String? rawPhotoUrl;
  final String originalText;
  final String originalLanguage;
  final String translatedText;
  final String category;
  final Map<String, dynamic>? extractedLocation; // lat, lng, ward, village
  final double severity;
  final double sentiment;
  final String status;
  final String? clusterId;
  final DateTime createdAt;

  Submission({
    required this.id,
    required this.citizenPhone,
    required this.mode,
    this.rawAudioUrl,
    this.rawPhotoUrl,
    required this.originalText,
    required this.originalLanguage,
    required this.translatedText,
    required this.category,
    this.extractedLocation,
    required this.severity,
    required this.sentiment,
    required this.status,
    this.clusterId,
    required this.createdAt,
  });

  factory Submission.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Submission(
      id: doc.id,
      citizenPhone: data['phone'] ?? '',
      mode: data['mode'] ?? 'text',
      rawAudioUrl: data['rawAudioUrl'],
      rawPhotoUrl: data['rawPhotoUrl'],
      originalText: data['originalText'] ?? '',
      originalLanguage: data['originalLanguage'] ?? 'en',
      translatedText: data['translatedText'] ?? '',
      category: data['category'] ?? 'Other',
      extractedLocation: data['extractedLocation'],
      severity: (data['severity'] ?? 0.0).toDouble(),
      sentiment: (data['sentiment'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'Submitted',
      clusterId: data['clusterId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phone': citizenPhone,
      'mode': mode,
      'rawAudioUrl': rawAudioUrl,
      'rawPhotoUrl': rawPhotoUrl,
      'originalText': originalText,
      'originalLanguage': originalLanguage,
      'translatedText': translatedText,
      'category': category,
      'extractedLocation': extractedLocation,
      'severity': severity,
      'sentiment': sentiment,
      'status': status,
      'clusterId': clusterId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
