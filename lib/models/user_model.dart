class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'student', 'teacher', 'admin'
  final String? photoUrl;
  final String? department;
  final String? studentId;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.photoUrl,
    this.department,
    this.studentId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      // Support both snake_case (Supabase) and camelCase
      photoUrl: json['photo_url'] ?? json['photoUrl'],
      department: json['department'],
      studentId: json['student_id'] ?? json['studentId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'photo_url': photoUrl, // Supabase uses snake_case
      'department': department,
      'student_id': studentId, // Supabase uses snake_case
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? photoUrl,
    String? department,
    String? studentId,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      department: department ?? this.department,
      studentId: studentId ?? this.studentId,
    );
  }
}
