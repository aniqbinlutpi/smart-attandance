import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/face_embedding_model.dart';

/// Repository for face recognition data operations
/// Handles all database interactions for face embeddings and scan logs
class FaceRepository {
  final _supabase = Supabase.instance.client;

  // ============================================
  // FACE EMBEDDINGS OPERATIONS
  // ============================================

  /// Save face embeddings to database
  /// This is called after successful face registration
  Future<void> saveFaceEmbeddings(
    String userId,
    List<FaceEmbedding> embeddings,
  ) async {
    try {
      // Convert embeddings to JSON format
      final embeddingsJson = embeddings.map((e) => e.toJson()).toList();

      // Try RPC function first
      try {
        await _supabase.rpc('update_face_embeddings', params: {
          'p_user_id': userId,
          'p_embeddings': embeddingsJson,
        });
        debugPrint('✅ [REPO] Saved via RPC successfully');
        return;
      } catch (rpcError) {
        debugPrint('⚠️ [REPO] RPC failed, trying direct update: $rpcError');
        // Fall back to direct table update
        await _supabase.from('users').update({
          'face_embeddings': embeddingsJson,
          'face_registered': true,
          'face_registered_at': DateTime.now().toIso8601String(),
          'face_registration_count': 1,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
        debugPrint('✅ [REPO] Saved via direct update successfully');
      }
    } catch (e) {
      debugPrint('❌ [REPO] Failed to save face embeddings: $e');
      throw Exception('Failed to save face embeddings: ${e.toString()}');
    }
  }

  /// Get face embeddings from database
  /// Returns null if user has not registered their face
  Future<List<FaceEmbedding>?> getFaceEmbeddings(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('face_embeddings')
          .eq('id', userId)
          .single();

      // Check if embeddings exist
      if (response['face_embeddings'] == null) {
        return null;
      }

      // Parse JSON to FaceEmbedding objects
      final List<dynamic> embeddingsJson = response['face_embeddings'];
      return embeddingsJson
          .map((json) => FaceEmbedding.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get face embeddings: ${e.toString()}');
    }
  }

  /// Check if user has registered their face
  Future<bool> isFaceRegistered(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('face_registered')
          .eq('id', userId)
          .single();

      return response['face_registered'] ?? false;
    } catch (e) {
      throw Exception('Failed to check face registration: ${e.toString()}');
    }
  }

  /// Get face registration status
  Future<FaceRegistrationStatus> getFaceRegistrationStatus(
      String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select(
              'face_registered, face_registered_at, face_registration_count')
          .eq('id', userId)
          .single();

      return FaceRegistrationStatus.fromJson(response);
    } catch (e) {
      throw Exception(
          'Failed to get face registration status: ${e.toString()}');
    }
  }

  /// Delete face embeddings (for re-registration)
  Future<void> deleteFaceEmbeddings(String userId) async {
    try {
      await _supabase.from('users').update({
        'face_embeddings': null,
        'face_registered': false,
        'face_registered_at': null,
      }).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to delete face embeddings: ${e.toString()}');
    }
  }

  // ============================================
  // FACE SCAN LOGS OPERATIONS
  // ============================================

  /// Log a face scan attempt
  /// This is called every time a face scan is performed (registration or attendance)
  Future<String> logFaceScan({
    required String userId,
    required String scanType, // 'registration' or 'attendance'
    required bool success,
    double? similarityScore,
    String? errorMessage,
    double? locationLat,
    double? locationLng,
  }) async {
    try {
      // Try RPC function first
      try {
        final response = await _supabase.rpc('log_face_scan', params: {
          'p_user_id': userId,
          'p_scan_type': scanType,
          'p_success': success,
          'p_similarity_score': similarityScore,
          'p_error_message': errorMessage,
          'p_location_lat': locationLat,
          'p_location_lng': locationLng,
        });
        debugPrint('✅ [REPO] Logged face scan via RPC');
        return response as String;
      } catch (rpcError) {
        debugPrint(
            '⚠️ [REPO] RPC log_face_scan failed, trying direct insert: $rpcError');
        // Fall back to direct table insert
        final response = await _supabase
            .from('face_scan_logs')
            .insert({
              'user_id': userId,
              'scan_type': scanType,
              'success': success,
              'similarity_score': similarityScore,
              'error_message': errorMessage,
              'location_lat': locationLat,
              'location_lng': locationLng,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();
        debugPrint('✅ [REPO] Logged face scan via direct insert');
        return response['id'] as String;
      }
    } catch (e) {
      debugPrint('❌ [REPO] Failed to log face scan: $e');
      // Don't throw - logging failure shouldn't block registration
      return '';
    }
  }

  /// Get face scan logs for a user
  /// Returns list of scan logs, ordered by most recent first
  Future<List<FaceScanLog>> getFaceScanLogs(
    String userId, {
    int limit = 50,
    String? scanType, // Filter by 'registration' or 'attendance'
  }) async {
    try {
      dynamic query = _supabase
          .from('face_scan_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      // Add scan type filter if specified
      if (scanType != null) {
        query = query.eq('scan_type', scanType);
      }

      final response = await query;

      return (response as List)
          .map((json) => FaceScanLog.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get face scan logs: ${e.toString()}');
    }
  }

  /// Get recent failed scan attempts
  /// Used for security monitoring and rate limiting
  Future<int> getRecentFailedScans(String userId, {int minutes = 30}) async {
    try {
      final response = await _supabase.rpc('get_recent_failed_scans', params: {
        'p_user_id': userId,
        'p_minutes': minutes,
      });

      return response as int;
    } catch (e) {
      throw Exception('Failed to get recent failed scans: ${e.toString()}');
    }
  }

  /// Get face scan statistics for a user
  /// Returns summary of scan attempts
  Future<Map<String, dynamic>> getFaceScanStats(String userId) async {
    try {
      final logs = await getFaceScanLogs(userId, limit: 1000);

      final totalScans = logs.length;
      final successfulScans = logs.where((log) => log.success).length;
      final failedScans = logs.where((log) => !log.success).length;
      final registrationScans =
          logs.where((log) => log.scanType == 'registration').length;
      final attendanceScans =
          logs.where((log) => log.scanType == 'attendance').length;

      // Calculate success rate
      final successRate =
          totalScans > 0 ? (successfulScans / totalScans * 100) : 0.0;

      // Get average similarity score for successful scans
      final successfulWithScore = logs
          .where((log) => log.success && log.similarityScore != null)
          .toList();
      final avgSimilarity = successfulWithScore.isNotEmpty
          ? successfulWithScore
                  .map((log) => log.similarityScore!)
                  .reduce((a, b) => a + b) /
              successfulWithScore.length
          : 0.0;

      return {
        'totalScans': totalScans,
        'successfulScans': successfulScans,
        'failedScans': failedScans,
        'registrationScans': registrationScans,
        'attendanceScans': attendanceScans,
        'successRate': successRate,
        'averageSimilarity': avgSimilarity,
        'lastScanAt': logs.isNotEmpty ? logs.first.createdAt : null,
      };
    } catch (e) {
      throw Exception('Failed to get face scan stats: ${e.toString()}');
    }
  }

  // ============================================
  // ATTENDANCE WITH FACE VERIFICATION
  // ============================================

  /// Record attendance with face verification
  /// This is called after successful face recognition
  Future<String> recordAttendanceWithFace({
    required String userId,
    required String userName,
    required String status, // 'present', 'late', etc.
    required String location,
    required double faceSimilarityScore,
    required String faceScanLogId,
    double? locationLat,
    double? locationLng,
  }) async {
    try {
      // Try RPC function first
      try {
        final response =
            await _supabase.rpc('record_attendance_with_face', params: {
          'p_user_id': userId,
          'p_user_name': userName,
          'p_status': status,
          'p_location': location,
          'p_face_similarity_score': faceSimilarityScore,
          'p_face_scan_log_id': faceScanLogId,
          'p_location_lat': locationLat,
          'p_location_lng': locationLng,
        });
        debugPrint('✅ [REPO] Recorded attendance via RPC');
        return response as String;
      } catch (rpcError) {
        debugPrint(
            '⚠️ [REPO] RPC record_attendance_with_face failed, trying direct insert: $rpcError');
        // Fall back to direct table insert
        final response = await _supabase
            .from('attendance')
            .insert({
              'user_id': userId,
              'user_name': userName,
              'check_in_time': DateTime.now().toUtc().toIso8601String(),
              'status': status,
              'location': location,
              'face_verified': true,
              'face_similarity_score': faceSimilarityScore,
              'face_scan_log_id':
                  faceScanLogId.isNotEmpty ? faceScanLogId : null,
            })
            .select('id')
            .single();
        debugPrint('✅ [REPO] Recorded attendance via direct insert');
        return response['id'] as String;
      }
    } catch (e) {
      debugPrint('❌ [REPO] Failed to record attendance: $e');
      throw Exception('Failed to record attendance: ${e.toString()}');
    }
  }

  /// Check if user has already checked in today
  Future<bool> hasCheckedInToday(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final response = await _supabase
          .from('attendance')
          .select('id')
          .eq('user_id', userId)
          .gte('check_in_time', startOfDay.toIso8601String())
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check attendance status: ${e.toString()}');
    }
  }

  /// Check if user has an active check-in (checked in but not checked out)
  Future<bool> hasActiveCheckIn(String userId) async {
    try {
      final latestRecord = await getTodayAttendance(userId);
      return latestRecord != null && latestRecord['check_out_time'] == null;
    } catch (e) {
      throw Exception('Failed to check active session: ${e.toString()}');
    }
  }

  /// Get today's attendance record
  Future<Map<String, dynamic>?> getTodayAttendance(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final response = await _supabase
          .from('attendance')
          .select()
          .eq('user_id', userId)
          .gte('check_in_time', startOfDay.toIso8601String())
          .order('check_in_time', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        return null;
      }

      return response.first;
    } catch (e) {
      throw Exception('Failed to get today\'s attendance: ${e.toString()}');
    }
  }

  /// Update check-out time for today's attendance
  Future<void> checkOut(String attendanceId) async {
    try {
      await _supabase.from('attendance').update({
        'check_out_time': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', attendanceId);
    } catch (e) {
      throw Exception('Failed to check out: ${e.toString()}');
    }
  }

  /// Get attendance history for a user
  /// Returns list of attendance records, ordered by most recent first
  Future<List<Map<String, dynamic>>> getAttendanceHistory(
    String userId, {
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase.from('attendance').select().eq('user_id', userId);

      if (startDate != null) {
        query = query.gte('check_in_time', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('check_in_time', endDate.toIso8601String());
      }

      final response =
          await query.order('check_in_time', ascending: false).limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ [REPO] Failed to get attendance history: $e');
      throw Exception('Failed to get attendance history: ${e.toString()}');
    }
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  /// Get current user ID from Supabase auth
  String? getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }

  /// Get current user data
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final userId = getCurrentUserId();
    if (userId == null) return null;

    try {
      final response =
          await _supabase.from('users').select().eq('id', userId).single();

      return response;
    } catch (e) {
      throw Exception('Failed to get current user: ${e.toString()}');
    }
  }

  /// Check if database connection is working
  Future<bool> testConnection() async {
    try {
      await _supabase.from('users').select('id').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }
}
