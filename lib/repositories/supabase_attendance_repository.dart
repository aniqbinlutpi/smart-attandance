import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance_model.dart';
import '../config/supabase_config.dart';
import 'attendance_repository.dart';

/// Implementasi AttendanceRepository menggunakan Supabase
/// Bila nak tukar ke SQL Server, buat class baru: SqlServerAttendanceRepository
class SupabaseAttendanceRepository implements AttendanceRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<List<AttendanceModel>> getAttendance(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Build query based on filters
      final queryBuilder = _supabase
          .from(SupabaseConfig.attendanceTable)
          .select()
          .eq('user_id', userId);

      // Apply date filters if provided
      dynamic query = queryBuilder;

      if (startDate != null) {
        query = query.gte('check_in_time', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('check_in_time', endDate.toIso8601String());
      }

      // Apply ordering and execute
      final data = await query.order('check_in_time', ascending: false);

      return (data as List)
          .map((json) => AttendanceModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal dapatkan attendance: ${e.toString()}');
    }
  }

  @override
  Future<AttendanceModel> checkIn({
    required String userId,
    required String userName,
    String? location,
    String? courseId,
    String? courseName,
  }) async {
    try {
      final now = DateTime.now();
      final attendanceMap = {
        'user_id': userId,
        'user_name': userName,
        'check_in_time': now.toIso8601String(),
        'status': _determineStatus(now),
        'location': location,
        'course_id': courseId,
        'course_name': courseName,
        'created_at': now.toIso8601String(),
      };

      final data = await _supabase
          .from(SupabaseConfig.attendanceTable)
          .insert(attendanceMap)
          .select()
          .single();

      return AttendanceModel.fromJson(data);
    } catch (e) {
      throw Exception('Check in gagal: ${e.toString()}');
    }
  }

  @override
  Future<AttendanceModel> checkOut(String attendanceId) async {
    try {
      final now = DateTime.now();
      final data = await _supabase
          .from(SupabaseConfig.attendanceTable)
          .update({
            'check_out_time': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', attendanceId)
          .select()
          .single();

      return AttendanceModel.fromJson(data);
    } catch (e) {
      throw Exception('Check out gagal: ${e.toString()}');
    }
  }

  @override
  Future<AttendanceModel?> getTodayAttendance(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final data = await _supabase
          .from(SupabaseConfig.attendanceTable)
          .select()
          .eq('user_id', userId)
          .filter('check_in_time', 'gte', startOfDay.toIso8601String())
          .filter('check_in_time', 'lt', endOfDay.toIso8601String())
          .maybeSingle();

      if (data == null) return null;
      return AttendanceModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> getStatistics(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final attendances = await getAttendance(
        userId,
        startDate: startDate,
        endDate: endDate,
      );

      final total = attendances.length;
      final present = attendances.where((a) => a.status == 'present').length;
      final late = attendances.where((a) => a.status == 'late').length;
      final absent = attendances.where((a) => a.status == 'absent').length;

      return {
        'total': total,
        'present': present,
        'late': late,
        'absent': absent,
        'attendanceRate': total > 0
            ? ((present + late) / total * 100).toStringAsFixed(1)
            : '0.0',
      };
    } catch (e) {
      throw Exception('Gagal dapatkan statistik: ${e.toString()}');
    }
  }

  @override
  Future<AttendanceModel> updateAttendance(AttendanceModel attendance) async {
    try {
      final attendanceMap = attendance.toJson();
      attendanceMap['updated_at'] = DateTime.now().toIso8601String();

      final data = await _supabase
          .from(SupabaseConfig.attendanceTable)
          .update(attendanceMap)
          .eq('id', attendance.id)
          .select()
          .single();

      return AttendanceModel.fromJson(data);
    } catch (e) {
      throw Exception('Update attendance gagal: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteAttendance(String attendanceId) async {
    try {
      await _supabase
          .from(SupabaseConfig.attendanceTable)
          .delete()
          .eq('id', attendanceId);
    } catch (e) {
      throw Exception('Delete attendance gagal: ${e.toString()}');
    }
  }

  /// Helper: Tentukan status berdasarkan masa check in
  String _determineStatus(DateTime checkInTime) {
    final hour = checkInTime.hour;
    final minute = checkInTime.minute;

    // Contoh: Lewat jika selepas 8:30 pagi
    if (hour > 8 || (hour == 8 && minute > 30)) {
      return 'late';
    }
    return 'present';
  }
}
