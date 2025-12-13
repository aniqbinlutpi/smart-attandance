class SupabaseConfig {
  // TODO: Ganti dengan credentials Supabase anda
  // Dapatkan dari: https://app.supabase.com/project/_/settings/api

  static const String supabaseUrl = 'https://mrtgvyvektvfmalfyswd.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ydGd2eXZla3R2Zm1hbGZ5c3dkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU2MzE5OTEsImV4cCI6MjA4MTIwNzk5MX0.YvXfo0LBLK5rQEJvhYPi7vNHN5IzndOXCsiLRdPPW7A';

  // Nama table di Supabase
  static const String usersTable = 'users';
  static const String attendanceTable = 'attendance';
  static const String coursesTable = 'courses';

  // Storage buckets
  static const String profilePhotosBucket = 'profile_photos';
}

// Setup instructions:
// 1. Pergi ke https://app.supabase.com
// 2. Create new project (percuma)
// 3. Pergi ke Settings > API
// 4. Copy URL dan anon key ke atas
// 5. Run SQL script di Supabase SQL Editor (lihat setup_supabase.sql)
