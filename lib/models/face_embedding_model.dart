/// Face Embedding Model
/// Represents face data extracted from ML Kit face detection
class FaceEmbedding {
  final List<double> embedding;
  final DateTime timestamp;

  FaceEmbedding({
    required this.embedding,
    required this.timestamp,
  });

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() => {
        'embedding': embedding,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Create from JSON retrieved from database
  factory FaceEmbedding.fromJson(Map<String, dynamic> json) => FaceEmbedding(
        embedding: List<double>.from(json['embedding']),
        timestamp: DateTime.parse(json['timestamp']),
      );

  /// Create a copy with updated values
  FaceEmbedding copyWith({
    List<double>? embedding,
    DateTime? timestamp,
  }) {
    return FaceEmbedding(
      embedding: embedding ?? this.embedding,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'FaceEmbedding(embedding: ${embedding.length} values, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FaceEmbedding &&
        other.embedding.length == embedding.length &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => embedding.hashCode ^ timestamp.hashCode;
}

/// Face Scan Log Model
/// Tracks all face scan attempts for security and debugging
class FaceScanLog {
  final String id;
  final String userId;
  final String scanType; // 'registration' or 'attendance'
  final bool success;
  final double? similarityScore;
  final String? errorMessage;
  final double? locationLat;
  final double? locationLng;
  final DateTime createdAt;

  FaceScanLog({
    required this.id,
    required this.userId,
    required this.scanType,
    required this.success,
    this.similarityScore,
    this.errorMessage,
    this.locationLat,
    this.locationLng,
    required this.createdAt,
  });

  /// Create from JSON retrieved from database
  factory FaceScanLog.fromJson(Map<String, dynamic> json) => FaceScanLog(
        id: json['id'],
        userId: json['user_id'],
        scanType: json['scan_type'],
        success: json['success'],
        similarityScore: json['similarity_score']?.toDouble(),
        errorMessage: json['error_message'],
        locationLat: json['location_lat']?.toDouble(),
        locationLng: json['location_lng']?.toDouble(),
        createdAt: DateTime.parse(json['created_at']),
      );

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'scan_type': scanType,
        'success': success,
        'similarity_score': similarityScore,
        'error_message': errorMessage,
        'location_lat': locationLat,
        'location_lng': locationLng,
        'created_at': createdAt.toIso8601String(),
      };

  /// Create a copy with updated values
  FaceScanLog copyWith({
    String? id,
    String? userId,
    String? scanType,
    bool? success,
    double? similarityScore,
    String? errorMessage,
    double? locationLat,
    double? locationLng,
    DateTime? createdAt,
  }) {
    return FaceScanLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      scanType: scanType ?? this.scanType,
      success: success ?? this.success,
      similarityScore: similarityScore ?? this.similarityScore,
      errorMessage: errorMessage ?? this.errorMessage,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Check if this is a registration scan
  bool get isRegistration => scanType == 'registration';

  /// Check if this is an attendance scan
  bool get isAttendance => scanType == 'attendance';

  /// Get formatted similarity score (e.g., "85.5%")
  String get formattedSimilarityScore {
    if (similarityScore == null) return 'N/A';
    return '${(similarityScore! * 100).toStringAsFixed(1)}%';
  }

  /// Get formatted location
  String? get formattedLocation {
    if (locationLat == null || locationLng == null) return null;
    return '${locationLat!.toStringAsFixed(6)}, ${locationLng!.toStringAsFixed(6)}';
  }

  @override
  String toString() {
    return 'FaceScanLog(id: $id, scanType: $scanType, success: $success, similarity: $formattedSimilarityScore)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FaceScanLog &&
        other.id == id &&
        other.userId == userId &&
        other.scanType == scanType &&
        other.success == success;
  }

  @override
  int get hashCode {
    return id.hashCode ^ userId.hashCode ^ scanType.hashCode ^ success.hashCode;
  }
}

/// Face Registration Status
/// Represents the current face registration status of a user
class FaceRegistrationStatus {
  final bool isRegistered;
  final DateTime? registeredAt;
  final int registrationCount;

  FaceRegistrationStatus({
    required this.isRegistered,
    this.registeredAt,
    this.registrationCount = 0,
  });

  /// Create from JSON retrieved from database
  factory FaceRegistrationStatus.fromJson(Map<String, dynamic> json) =>
      FaceRegistrationStatus(
        isRegistered: json['face_registered'] ?? false,
        registeredAt: json['face_registered_at'] != null
            ? DateTime.parse(json['face_registered_at'])
            : null,
        registrationCount: json['face_registration_count'] ?? 0,
      );

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'face_registered': isRegistered,
        'face_registered_at': registeredAt?.toIso8601String(),
        'face_registration_count': registrationCount,
      };

  /// Get status message for UI
  String get statusMessage {
    if (!isRegistered) return 'Face not registered';
    if (registeredAt == null) return 'Face registered';

    final now = DateTime.now();
    final difference = now.difference(registeredAt!);

    if (difference.inDays > 0) {
      return 'Registered ${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return 'Registered ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return 'Registered ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just registered';
    }
  }

  @override
  String toString() {
    return 'FaceRegistrationStatus(isRegistered: $isRegistered, registeredAt: $registeredAt, count: $registrationCount)';
  }
}
