import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Service for face recognition using Google ML Kit
/// Handles face detection, embedding extraction, and similarity comparison
class FaceRecognitionService {
  late FaceDetector _faceDetector;

  /// Similarity threshold for face matching (0.0 to 1.0)
  /// Higher value = stricter matching (fewer false positives)
  /// Lower value = more lenient matching (fewer false negatives)
  static const double similarityThreshold = 0.90; // 90% match required check

  FaceRecognitionService() {
    _initializeFaceDetector();
  }

  /// Initialize ML Kit Face Detector with optimal settings
  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableContours: true, // Enable face contours for better accuracy
      enableLandmarks: true, // Enable facial landmarks (eyes, nose, mouth)
      enableClassification: true, // Enable smile/eyes open detection
      enableTracking: true, // Enable face tracking across frames
      minFaceSize: 0.15, // Minimum face size (15% of image)
      performanceMode: FaceDetectorMode.accurate, // Prioritize accuracy
    );
    _faceDetector = FaceDetector(options: options);
  }

  /// Detect faces in an image
  /// Returns list of detected faces
  Future<List<Face>> detectFaces(InputImage inputImage) async {
    try {
      final faces = await _faceDetector.processImage(inputImage);
      return faces;
    } catch (e) {
      throw Exception('Failed to detect faces: ${e.toString()}');
    }
  }

  /// Extract face embeddings based on facial feature ratios (Anthropometry)
  /// This provides better distinction between different faces compared to raw coordinates
  List<double> extractEmbeddings(Face face) {
    // Essential landmarks for ratio calculation
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    final noseBase = face.landmarks[FaceLandmarkType.noseBase];
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth];
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth];
    final bottomMouth = face.landmarks[FaceLandmarkType.bottomMouth];

    // Identify if any key landmark is missing
    if (leftEye == null ||
        rightEye == null ||
        noseBase == null ||
        leftMouth == null ||
        rightMouth == null ||
        bottomMouth == null) {
      return [];
    }

    final pLeftEye = leftEye.position;
    final pRightEye = rightEye.position;
    final pNose = noseBase.position;
    final pLeftMouth = leftMouth.position;
    final pRightMouth = rightMouth.position;
    final pBottomMouth = bottomMouth.position;

    // Calculate base unit distance (Inter-ocular distance) for normalization
    // This makes the measurements scale-invariant
    final double eyeDist = _calculateDistance(pLeftEye, pRightEye);
    if (eyeDist < 10) return []; // Face too far or too small

    final embeddings = <double>[];

    // --- Vertical Distances (normalized by eye distance) ---
    // 1. Eye Center to Nose
    final pEyeCenter = Point(
      (pLeftEye.x + pRightEye.x) / 2,
      (pLeftEye.y + pRightEye.y) / 2,
    );
    embeddings.add(_calculateDistance(pEyeCenter, pNose) / eyeDist);

    // 2. Nose to Mouth Center
    final pMouthCenter = Point(
      (pLeftMouth.x + pRightMouth.x) / 2,
      (pLeftMouth.y + pRightMouth.y) / 2,
    );
    embeddings.add(_calculateDistance(pNose, pMouthCenter) / eyeDist);

    // 3. Mouth Center to Chin (Bottom Mouth)
    embeddings.add(_calculateDistance(pMouthCenter, pBottomMouth) / eyeDist);

    // 4. Eye Center to Mouth Center
    embeddings.add(_calculateDistance(pEyeCenter, pMouthCenter) / eyeDist);

    // --- Horizontal/Diagonal Ratios ---
    // 5. Mouth Width
    embeddings.add(_calculateDistance(pLeftMouth, pRightMouth) / eyeDist);

    // 6. Left Eye to Nose vs Right Eye to Nose (Symmetry check)
    embeddings.add(_calculateDistance(pLeftEye, pNose) / eyeDist);
    embeddings.add(_calculateDistance(pRightEye, pNose) / eyeDist);

    // 7. Left Eye to Left Mouth vs Right Eye to Right Mouth
    embeddings.add(_calculateDistance(pLeftEye, pLeftMouth) / eyeDist);
    embeddings.add(_calculateDistance(pRightEye, pRightMouth) / eyeDist);

    // 8. Nose to Mouth Corners
    embeddings.add(_calculateDistance(pNose, pLeftMouth) / eyeDist);
    embeddings.add(_calculateDistance(pNose, pRightMouth) / eyeDist);

    // Add head rotation angles for 3D context
    if (face.headEulerAngleX != null) {
      embeddings.add(face.headEulerAngleX! / 90.0); // Normalize -90 to 90
    }
    if (face.headEulerAngleY != null) {
      embeddings.add(face.headEulerAngleY! / 90.0);
    }

    return _normalizeEmbeddings(embeddings);
  }

  /// Calculate Euclidean distance between two points
  double _calculateDistance(Point p1, Point p2) {
    return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
  }

  /// Calculate similarity between two face embeddings using Cosine Similarity
  /// Returns a value between 0.0 (completely different) and 1.0 (identical)
  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    // Embeddings must have same length
    if (embedding1.length != embedding2.length) {
      throw Exception(
          'Embeddings must have same length: ${embedding1.length} vs ${embedding2.length}');
    }

    if (embedding1.isEmpty || embedding2.isEmpty) {
      return 0.0;
    }

    // Calculate cosine similarity
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }

    // Avoid division by zero
    if (norm1 == 0 || norm2 == 0) {
      return 0.0;
    }

    // Cosine similarity = dot product / (norm1 * norm2)
    final similarity = dotProduct / (sqrt(norm1) * sqrt(norm2));

    // Clamp to [0, 1] range
    return similarity.clamp(0.0, 1.0);
  }

  /// Average multiple face embeddings
  /// Used during registration to create a robust face template
  List<double> averageEmbeddings(List<List<double>> embeddings) {
    if (embeddings.isEmpty) {
      throw Exception('Cannot average empty embeddings list');
    }

    // All embeddings must have same length
    final length = embeddings.first.length;
    for (final embedding in embeddings) {
      if (embedding.length != length) {
        throw Exception('All embeddings must have same length');
      }
    }

    // Calculate average for each dimension
    final averaged = List<double>.filled(length, 0.0);

    for (final embedding in embeddings) {
      for (int i = 0; i < length; i++) {
        averaged[i] += embedding[i];
      }
    }

    for (int i = 0; i < length; i++) {
      averaged[i] /= embeddings.length;
    }

    return _normalizeEmbeddings(averaged);
  }

  /// Normalize embeddings to unit vector (L2 normalization)
  /// This ensures consistent similarity calculations
  List<double> _normalizeEmbeddings(List<double> embeddings) {
    if (embeddings.isEmpty) return [];

    // Calculate L2 norm (Euclidean length)
    final norm = sqrt(embeddings.fold(0.0, (sum, val) => sum + val * val));

    // Avoid division by zero
    if (norm == 0) return embeddings;

    // Normalize each value
    return embeddings.map((val) => val / norm).toList();
  }

  /// Check if a face matches stored embeddings
  /// Returns true if similarity is above threshold
  bool isMatch(List<double> scannedEmbedding, List<double> storedEmbedding) {
    final similarity = calculateSimilarity(scannedEmbedding, storedEmbedding);
    return similarity >= similarityThreshold;
  }

  /// Find best match from multiple stored embeddings
  /// Returns the highest similarity score and whether it's a match
  Map<String, dynamic> findBestMatch(
    List<double> scannedEmbedding,
    List<List<double>> storedEmbeddings,
  ) {
    if (storedEmbeddings.isEmpty) {
      return {
        'match': false,
        'similarity': 0.0,
        'message': 'No stored embeddings to compare',
      };
    }

    double bestSimilarity = 0.0;

    for (final storedEmbedding in storedEmbeddings) {
      final similarity = calculateSimilarity(scannedEmbedding, storedEmbedding);
      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
      }
    }

    final isMatch = bestSimilarity >= similarityThreshold;

    return {
      'match': isMatch,
      'similarity': bestSimilarity,
      'similarityPercent': (bestSimilarity * 100).toStringAsFixed(1),
      'message': isMatch
          ? 'Face recognized (${(bestSimilarity * 100).toStringAsFixed(1)}% match)'
          : 'Face not recognized (${(bestSimilarity * 100).toStringAsFixed(1)}% match, need ${(similarityThreshold * 100).toStringAsFixed(0)}%)',
    };
  }

  /// Validate face quality for registration
  /// Returns true if face is suitable for registration
  Map<String, dynamic> validateFaceQuality(Face face, {bool checkEyes = true}) {
    final issues = <String>[];

    // Check if face is too small
    final faceSize = face.boundingBox.width * face.boundingBox.height;
    if (faceSize < 10000) {
      // Arbitrary threshold
      issues.add('Face is too small. Move closer to camera.');
    }

    // Check head rotation (should be facing forward)
    if (face.headEulerAngleY != null) {
      final yaw = face.headEulerAngleY!.abs();
      if (yaw > 20) {
        issues.add('Please face the camera directly (head turned too much).');
      }
    }

    if (face.headEulerAngleX != null) {
      final pitch = face.headEulerAngleX!.abs();
      if (pitch > 20) {
        issues.add('Please look straight ahead (head tilted too much).');
      }
    }

    if (checkEyes) {
      // Check if eyes are open (if classification is available)
      if (face.leftEyeOpenProbability != null &&
          face.leftEyeOpenProbability! < 0.3) {
        issues.add('Please keep your eyes open.');
      }

      if (face.rightEyeOpenProbability != null &&
          face.rightEyeOpenProbability! < 0.3) {
        issues.add('Please keep your eyes open.');
      }
    }

    // Check for essential landmarks
    if (face.landmarks[FaceLandmarkType.leftEye] == null ||
        face.landmarks[FaceLandmarkType.rightEye] == null ||
        face.landmarks[FaceLandmarkType.noseBase] == null ||
        face.landmarks[FaceLandmarkType.leftMouth] == null ||
        face.landmarks[FaceLandmarkType.rightMouth] == null) {
      issues.add('Face features not clear. Remove mask or glasses?');
    }

    return {
      'valid': issues.isEmpty,
      'issues': issues,
      'message': issues.isEmpty ? 'Face quality is good' : issues.join(' '),
    };
  }

  /// Clean up resources
  void dispose() {
    _faceDetector.close();
  }

  /// Get face detection statistics for debugging
  Map<String, dynamic> getFaceStats(Face face) {
    return {
      'boundingBox': {
        'left': face.boundingBox.left,
        'top': face.boundingBox.top,
        'width': face.boundingBox.width,
        'height': face.boundingBox.height,
      },
      'landmarks': face.landmarks.length,
      'contours': face.contours.length,
      'headEulerAngleX': face.headEulerAngleX,
      'headEulerAngleY': face.headEulerAngleY,
      'headEulerAngleZ': face.headEulerAngleZ,
      'leftEyeOpenProbability': face.leftEyeOpenProbability,
      'rightEyeOpenProbability': face.rightEyeOpenProbability,
      'smilingProbability': face.smilingProbability,
      'trackingId': face.trackingId,
    };
  }
}
