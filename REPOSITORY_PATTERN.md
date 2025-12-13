# 🏗️ Repository Pattern + Supabase Setup Guide

## ✅ Apa Yang Telah Dibuat

Struktur app anda sekarang menggunakan **Repository Pattern** yang membolehkan anda tukar dari **Supabase** ke **SQL Server** dengan mudah bila masa tiba!

---

## 📊 Struktur Baru (Repository Pattern)

```
lib/
├── config/
│   └── supabase_config.dart          # Supabase credentials
│
├── repositories/                      # ⭐ REPOSITORY LAYER
│   ├── auth_repository.dart          # Interface (abstract class)
│   ├── attendance_repository.dart    # Interface (abstract class)
│   ├── supabase_auth_repository.dart # Supabase implementation
│   └── supabase_attendance_repository.dart
│
├── services/                          # Service layer (guna repository)
│   ├── auth_service.dart
│   └── attendance_service.dart
│
└── ... (providers, models, screens, dll)
```

---

## 🎯 Kenapa Repository Pattern?

### Masalah Tanpa Repository Pattern:
```dart
// ❌ Service terus guna Supabase
class AuthService {
  final supabase = Supabase.instance.client;
  
  Future<User> signIn() {
    return supabase.auth.signIn(...); // Locked to Supabase!
  }
}
```

**Bila nak tukar ke SQL Server**: Kena ubah SEMUA service files! 😱

### Penyelesaian Dengan Repository Pattern:
```dart
// ✅ Service guna interface
class AuthService {
  final AuthRepository repository = SupabaseAuthRepository();
  
  Future<User> signIn() {
    return repository.signIn(...); // Boleh tukar backend!
  }
}
```

**Bila nak tukar ke SQL Server**: Tukar 1 line je! 🎉

```dart
// Tukar dari:
final AuthRepository repository = SupabaseAuthRepository();

// Kepada:
final AuthRepository repository = SqlServerAuthRepository();
```

---

## 🔄 Cara Kerja Repository Pattern

```
┌─────────────────────────────────────────────────┐
│              SCREEN (UI)                        │
│         login_screen.dart                       │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│              PROVIDER                           │
│         auth_provider.dart                      │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│              SERVICE                            │
│         auth_service.dart                       │
│  final AuthRepository repo = ...;               │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│          REPOSITORY INTERFACE                   │
│         auth_repository.dart                    │
│  abstract class AuthRepository {                │
│    Future<User> signIn(...);                    │
│  }                                              │
└─────────────────┬───────────────────────────────┘
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
┌──────────────────┐  ┌──────────────────┐
│   SUPABASE       │  │   SQL SERVER     │
│   (Sekarang)     │  │   (Masa Depan)   │
│                  │  │                  │
│ Supabase         │  │ SqlServer        │
│ AuthRepository   │  │ AuthRepository   │
└──────────────────┘  └──────────────────┘
```

---

## 🚀 Setup Supabase (Langkah Demi Langkah)

### 1. Create Supabase Project (PERCUMA!)

1. Pergi ke https://app.supabase.com
2. Click **"New Project"**
3. Isi details:
   - **Name**: smart-attendance
   - **Database Password**: (simpan password ni!)
   - **Region**: Southeast Asia (Singapore)
4. Click **"Create new project"** (tunggu 2-3 minit)

### 2. Dapatkan API Credentials

1. Pergi ke **Settings** > **API**
2. Copy 2 values ni:
   - **Project URL** (contoh: `https://xxxxx.supabase.co`)
   - **anon public** key (panjang, starts with `eyJ...`)

### 3. Update Config File

Buka `lib/config/supabase_config.dart` dan paste:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://xxxxx.supabase.co'; // Paste URL anda
  static const String supabaseAnonKey = 'eyJxxx...'; // Paste anon key anda
  
  // ... rest of code
}
```

### 4. Setup Database

1. Pergi ke **SQL Editor** di Supabase
2. Click **"New query"**
3. Copy SEMUA content dari file `supabase_setup.sql`
4. Paste dalam SQL Editor
5. Click **"Run"** (atau tekan F5)

✅ Done! Database tables, indexes, dan security policies semua dah setup!

### 5. Test Connection

Run app:
```bash
flutter run
```

Kalau tak ada error, Supabase dah connected! 🎉

---

## 📝 Struktur Database

### Table: `users`
```sql
- id (UUID, primary key)
- email (TEXT, unique)
- name (TEXT)
- role (TEXT: 'student', 'teacher', 'admin')
- department (TEXT, optional)
- student_id (TEXT, optional)
- photo_url (TEXT, optional)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

### Table: `attendance`
```sql
- id (UUID, primary key)
- user_id (UUID, foreign key to users)
- user_name (TEXT)
- check_in_time (TIMESTAMP)
- check_out_time (TIMESTAMP, optional)
- status (TEXT: 'present', 'late', 'absent', 'excused')
- location (TEXT, optional)
- notes (TEXT, optional)
- course_id (UUID, optional)
- course_name (TEXT, optional)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

---

## 🔐 Security (Row Level Security)

Supabase guna RLS untuk security:

- ✅ Users boleh view/update profile sendiri je
- ✅ Users boleh view/create attendance sendiri je
- ✅ Teachers & admins boleh view semua attendance
- ✅ Auto-create user profile bila sign up

---

## 🔄 Cara Tukar Ke SQL Server Nanti

### Step 1: Buat SQL Server Repository

```dart
// lib/repositories/sqlserver_auth_repository.dart
class SqlServerAuthRepository implements AuthRepository {
  @override
  Future<UserModel> signIn(String email, String password) async {
    // Guna SQL Server connection
    final conn = await SqlConnection.connect(...);
    // ... SQL Server logic
  }
  
  // Implement semua methods dari AuthRepository interface
}
```

### Step 2: Tukar Service

```dart
// lib/services/auth_service.dart
class AuthService {
  // Tukar line ni je:
  // final AuthRepository _repository = SupabaseAuthRepository(); // Old
  final AuthRepository _repository = SqlServerAuthRepository(); // New
  
  // Semua code lain TAK PERLU UBAH!
}
```

### Step 3: Done!

Semua Provider, Screen, Widget - **TAK PERLU UBAH LANGSUNG!** 🎉

---

## 💡 Kelebihan Approach Ini

### ✅ Untuk Demo (Sekarang)
- Guna Supabase (percuma, cepat, mudah)
- Boleh demo kat boss dengan real data
- Tak perlu setup server sendiri
- Automatic backups & scaling

### ✅ Untuk Production (Masa Depan)
- Bila boss approve, tukar ke SQL Server syarikat
- Cuma tukar repository implementation
- Kod lain semua sama
- Migration mudah

### ✅ Untuk Development
- Test dengan Supabase (development)
- Deploy dengan SQL Server (production)
- Boleh maintain 2 backend serentak!

---

## 📚 File-File Penting

### Repository Interfaces (Abstract Classes)
- `lib/repositories/auth_repository.dart` - Define contract untuk auth
- `lib/repositories/attendance_repository.dart` - Define contract untuk attendance

### Supabase Implementations
- `lib/repositories/supabase_auth_repository.dart` - Implement auth dengan Supabase
- `lib/repositories/supabase_attendance_repository.dart` - Implement attendance dengan Supabase

### Services (Guna Repository)
- `lib/services/auth_service.dart` - Auth business logic
- `lib/services/attendance_service.dart` - Attendance business logic

### Config
- `lib/config/supabase_config.dart` - Supabase credentials & table names
- `supabase_setup.sql` - Database setup script

---

## 🎯 Next Steps

1. ✅ Setup Supabase account
2. ✅ Run SQL setup script
3. ✅ Update config dengan credentials
4. ✅ Test sign up & sign in
5. ✅ Test check in/out
6. ✅ Demo kat boss
7. 🔜 Bila boss approve, buat SQL Server repository

---

## 🆘 Troubleshooting

### Error: "Invalid API key"
- Check `supabase_config.dart` - pastikan URL dan key betul
- Key mesti start dengan `eyJ`

### Error: "Table doesn't exist"
- Run `supabase_setup.sql` dalam SQL Editor
- Check table ada ke tak di Table Editor

### Error: "Row Level Security policy violation"
- User mesti sign up dulu sebelum boleh access data
- Check RLS policies dalam SQL Editor

### Sign up tak berfungsi
- Check email confirmation settings di Supabase
- Pergi ke Authentication > Settings
- Disable "Confirm email" untuk testing

---

## 📖 Dokumentasi Tambahan

- [Supabase Docs](https://supabase.com/docs)
- [Supabase Flutter](https://supabase.com/docs/reference/dart/introduction)
- [Repository Pattern](https://medium.com/flutter-community/repository-pattern-in-flutter-2c8f8c9b3c5d)

---

**Selamat coding! Bila boss approve, kita sambung dengan SQL Server! 🚀**
