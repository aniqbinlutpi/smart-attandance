import '../models/attendance_model.dart';

/// Interface untuk Attendance Repository
/// Boleh tukar dari Supabase ke SQL Server tanpa ubah kod lain
abstract class AttendanceRepository {
  /// Dapatkan senarai attendance untuk user
  Future<List<AttendanceModel>> getAttendance(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Check in
  Future<AttendanceModel> checkIn({
    required String userId,
    required String userName,
    String? location,
    String? courseId,
    String? courseName,
  });

  /// Check out
  Future<AttendanceModel> checkOut(String attendanceId);

  /// Dapatkan attendance hari ini
  Future<AttendanceModel?> getTodayAttendance(String userId);

  /// Dapatkan statistik attendance
  Future<Map<String, dynamic>> getStatistics(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Update attendance record
  Future<AttendanceModel> updateAttendance(AttendanceModel attendance);

  /// Delete attendance record
  Future<void> deleteAttendance(String attendanceId);
}
