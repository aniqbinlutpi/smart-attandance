import '../models/user_model.dart';

/// Interface untuk Authentication Repository
/// Ini membolehkan kita tukar dari Supabase ke SQL Server dengan mudah
abstract class AuthRepository {
  /// Sign in dengan email dan password
  Future<UserModel> signIn(String email, String password);

  /// Sign up pengguna baru
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? department,
    String? studentId,
  });

  /// Sign out
  Future<void> signOut();

  /// Dapatkan pengguna semasa
  Future<UserModel?> getCurrentUser();

  /// Update profil pengguna
  Future<UserModel> updateUser(UserModel user);

  /// Reset password
  Future<void> resetPassword(String email);

  /// Check jika email sudah wujud
  Future<bool> isEmailExists(String email);
}
