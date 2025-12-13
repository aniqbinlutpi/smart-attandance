class AttendanceModel {
  final String id;
  final String userId;
  final String userName;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String status; // 'present', 'late', 'absent', 'excused'
  final String? location;
  final String? notes;
  final String? courseId;
  final String? courseName;

  AttendanceModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.checkInTime,
    this.checkOutTime,
    required this.status,
    this.location,
    this.notes,
    this.courseId,
    this.courseName,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      userName: json['user_name'] ?? json['userName'] ?? '',
      checkInTime: DateTime.parse(json['check_in_time'] ?? json['checkInTime']),
      checkOutTime:
          json['check_out_time'] != null || json['checkOutTime'] != null
              ? DateTime.parse(json['check_out_time'] ?? json['checkOutTime'])
              : null,
      status: json['status'] ?? 'absent',
      location: json['location'],
      notes: json['notes'],
      courseId: json['course_id'] ?? json['courseId'],
      courseName: json['course_name'] ?? json['courseName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'check_in_time': checkInTime.toIso8601String(),
      'check_out_time': checkOutTime?.toIso8601String(),
      'status': status,
      'location': location,
      'notes': notes,
      'course_id': courseId,
      'course_name': courseName,
    };
  }

  Duration? get duration {
    if (checkOutTime == null) return null;
    return checkOutTime!.difference(checkInTime);
  }

  bool get isPresent => status == 'present' || status == 'late';
}
