import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/supabase_auth_repository.dart';

/// Service layer untuk authentication
/// Guna Repository Pattern - mudah tukar backend nanti
class AuthService {
  // Guna interface AuthRepository, bukan direct implementation
  // Bila nak tukar ke SQL Server, tukar line ni je:
  // final AuthRepository _repository = SqlServerAuthRepository();
  final AuthRepository _repository = SupabaseAuthRepository();

  Future<UserModel> signIn(String email, String password) async {
    return await _repository.signIn(email, password);
  }

  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? department,
    String? studentId,
  }) async {
    return await _repository.signUp(
      email: email,
      password: password,
      name: name,
      role: role,
      department: department,
      studentId: studentId,
    );
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }

  Future<UserModel?> getCurrentUser() async {
    return await _repository.getCurrentUser();
  }

  Future<UserModel> updateUser(UserModel user) async {
    return await _repository.updateUser(user);
  }

  Future<void> resetPassword(String email) async {
    await _repository.resetPassword(email);
  }

  Future<bool> isEmailExists(String email) async {
    return await _repository.isEmailExists(email);
  }
}
