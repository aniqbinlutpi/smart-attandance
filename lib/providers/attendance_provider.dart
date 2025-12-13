import 'package:flutter/foundation.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';

class AttendanceProvider with ChangeNotifier {
  List<AttendanceModel> _attendanceList = [];
  bool _isLoading = false;
  String? _errorMessage;
  final AttendanceService _attendanceService = AttendanceService();

  List<AttendanceModel> get attendanceList => _attendanceList;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get attendance records for a user
  Future<void> fetchAttendance(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _attendanceList = await _attendanceService.getAttendance(
        userId,
        startDate: startDate,
        endDate: endDate,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check in
  Future<bool> checkIn({
    required String userId,
    required String userName,
    String? location,
    String? courseId,
    String? courseName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final attendance = await _attendanceService.checkIn(
        userId: userId,
        userName: userName,
        location: location,
        courseId: courseId,
        courseName: courseName,
      );

      _attendanceList.insert(0, attendance);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Check out
  Future<bool> checkOut(String attendanceId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedAttendance = await _attendanceService.checkOut(attendanceId);

      final index = _attendanceList.indexWhere((a) => a.id == attendanceId);
      if (index != -1) {
        _attendanceList[index] = updatedAttendance;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Get attendance statistics
  Map<String, dynamic> getStatistics() {
    final total = _attendanceList.length;
    final present = _attendanceList.where((a) => a.status == 'present').length;
    final late = _attendanceList.where((a) => a.status == 'late').length;
    final absent = _attendanceList.where((a) => a.status == 'absent').length;

    return {
      'total': total,
      'present': present,
      'late': late,
      'absent': absent,
      'attendanceRate': total > 0
          ? ((present + late) / total * 100).toStringAsFixed(1)
          : '0.0',
    };
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
