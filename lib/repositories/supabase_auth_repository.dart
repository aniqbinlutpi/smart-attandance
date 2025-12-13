import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../config/supabase_config.dart';
import 'auth_repository.dart';

/// Implementasi AuthRepository menggunakan Supabase
/// Bila nak tukar ke SQL Server, buat class baru: SqlServerAuthRepository
class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<UserModel> signIn(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Sign in gagal');
      }

      // Dapatkan user data dari table users
      final userData = await _supabase
          .from(SupabaseConfig.usersTable)
          .select()
          .eq('id', response.user!.id)
          .single();

      return UserModel.fromJson(userData);
    } catch (e) {
      throw Exception('Sign in gagal: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? department,
    String? studentId,
  }) async {
    try {
      // 1. Create auth user dengan metadata
      // Trigger database akan auto-create profile dalam table users
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': role,
          'department': department,
          'student_id': studentId,
        },
      );

      if (response.user == null) {
        throw Exception('Sign up gagal');
      }

      // 2. Tunggu sikit untuk trigger complete
      await Future.delayed(const Duration(milliseconds: 500));

      // 3. Fetch user profile yang dah auto-created oleh trigger
      final userData = await _supabase
          .from(SupabaseConfig.usersTable)
          .select()
          .eq('id', response.user!.id)
          .single();

      return UserModel.fromJson(userData);
    } catch (e) {
      throw Exception('Sign up gagal: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Sign out gagal: ${e.toString()}');
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final userData = await _supabase
          .from(SupabaseConfig.usersTable)
          .select()
          .eq('id', user.id)
          .single();

      return UserModel.fromJson(userData);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<UserModel> updateUser(UserModel user) async {
    try {
      final userMap = user.toJson();
      userMap['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from(SupabaseConfig.usersTable)
          .update(userMap)
          .eq('id', user.id);

      return user;
    } catch (e) {
      throw Exception('Update user gagal: ${e.toString()}');
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('Reset password gagal: ${e.toString()}');
    }
  }

  @override
  Future<bool> isEmailExists(String email) async {
    try {
      final result = await _supabase
          .from(SupabaseConfig.usersTable)
          .select('id')
          .eq('email', email)
          .maybeSingle();

      return result != null;
    } catch (e) {
      return false;
    }
  }
}
