import '../models/attendance_model.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/supabase_attendance_repository.dart';

/// Service layer untuk attendance
/// Guna Repository Pattern - mudah tukar backend nanti
class AttendanceService {
  // Guna interface AttendanceRepository, bukan direct implementation
  // Bila nak tukar ke SQL Server, tukar line ni je:
  // final AttendanceRepository _repository = SqlServerAttendanceRepository();
  final AttendanceRepository _repository = SupabaseAttendanceRepository();

  Future<List<AttendanceModel>> getAttendance(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _repository.getAttendance(
      userId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<AttendanceModel> checkIn({
    required String userId,
    required String userName,
    String? location,
    String? courseId,
    String? courseName,
  }) async {
    return await _repository.checkIn(
      userId: userId,
      userName: userName,
      location: location,
      courseId: courseId,
      courseName: courseName,
    );
  }

  Future<AttendanceModel> checkOut(String attendanceId) async {
    return await _repository.checkOut(attendanceId);
  }

  Future<AttendanceModel?> getTodayAttendance(String userId) async {
    return await _repository.getTodayAttendance(userId);
  }

  Future<Map<String, dynamic>> getStatistics(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _repository.getStatistics(
      userId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<AttendanceModel> updateAttendance(AttendanceModel attendance) async {
    return await _repository.updateAttendance(attendance);
  }

  Future<void> deleteAttendance(String attendanceId) async {
    await _repository.deleteAttendance(attendanceId);
  }
}
