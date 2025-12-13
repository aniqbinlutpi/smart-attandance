# Smart Attendance - Provider Architecture

## 📁 Folder Structure

```
lib/
├── main.dart                      # App entry point with Provider setup
├── constants/                     # App-wide constants
│   ├── app_colors.dart           # Color palette
│   └── app_strings.dart          # Text strings
├── models/                        # Data models
│   ├── user_model.dart           # User entity
│   └── attendance_model.dart     # Attendance record entity
├── providers/                     # State management (Provider)
│   ├── auth_provider.dart        # Authentication state
│   └── attendance_provider.dart  # Attendance state
├── screens/                       # UI screens
│   ├── auth/                     # Authentication screens
│   │   ├── login_screen.dart
│   │   └── signup_screen.dart    # TODO
│   ├── home/                     # Home/Dashboard
│   │   └── home_screen.dart
│   ├── attendance/               # Attendance features
│   │   ├── check_in_screen.dart  # TODO
│   │   └── history_screen.dart   # TODO
│   ├── profile/                  # User profile
│   │   └── profile_screen.dart   # TODO
│   └── reports/                  # Reports & analytics
│       └── reports_screen.dart   # TODO
├── services/                      # Business logic & API calls
│   ├── auth_service.dart         # Authentication API
│   └── attendance_service.dart   # Attendance API
├── utils/                         # Helper utilities
│   └── date_formatter.dart       # Date/time formatting
└── widgets/                       # Reusable widgets
    ├── common/                    # Common widgets
    │   ├── custom_button.dart    # TODO
    │   └── loading_indicator.dart # TODO
    ├── auth/                      # Auth-specific widgets
    │   └── auth_form.dart        # TODO
    └── attendance/                # Attendance widgets
        └── attendance_card.dart  # TODO
```

## 🏗️ Architecture Pattern: Provider

### Why Provider?

✅ **Simple & Lightweight**: Less boilerplate than BLoC  
✅ **Official Flutter Package**: Recommended by Flutter team  
✅ **Easy to Learn**: Great for beginners and small-to-medium apps  
✅ **Flexible**: Can scale with your app  
✅ **Good Performance**: Efficient rebuilds with ChangeNotifier  

### How It Works

1. **Models** (`lib/models/`): Plain Dart classes representing data
2. **Services** (`lib/services/`): Handle API calls and business logic
3. **Providers** (`lib/providers/`): Manage state using `ChangeNotifier`
4. **Screens** (`lib/screens/`): UI that consumes state using `Consumer` or `Provider.of`

### Example Flow

```dart
// 1. User taps "Sign In" button
LoginScreen (UI)
    ↓
// 2. Screen calls provider method
AuthProvider.signIn()
    ↓
// 3. Provider calls service
AuthService.signIn()
    ↓
// 4. Service makes API call
API Response
    ↓
// 5. Provider updates state
notifyListeners()
    ↓
// 6. UI rebuilds automatically
Consumer<AuthProvider> rebuilds
```

## 🎯 Key Components

### Providers

**AuthProvider** (`lib/providers/auth_provider.dart`)
- Manages user authentication state
- Methods: `signIn()`, `signUp()`, `signOut()`, `checkAuthStatus()`
- Properties: `user`, `isLoading`, `errorMessage`, `isAuthenticated`

**AttendanceProvider** (`lib/providers/attendance_provider.dart`)
- Manages attendance records
- Methods: `fetchAttendance()`, `checkIn()`, `checkOut()`, `getStatistics()`
- Properties: `attendanceList`, `isLoading`, `errorMessage`

### Services

**AuthService** (`lib/services/auth_service.dart`)
- Handles authentication API calls
- TODO: Implement with Firebase Auth or REST API

**AttendanceService** (`lib/services/attendance_service.dart`)
- Handles attendance API calls
- TODO: Implement with Firebase Firestore or REST API

### Models

**UserModel** (`lib/models/user_model.dart`)
- Properties: `id`, `name`, `email`, `role`, `photoUrl`, `department`, `studentId`
- Methods: `fromJson()`, `toJson()`, `copyWith()`

**AttendanceModel** (`lib/models/attendance_model.dart`)
- Properties: `id`, `userId`, `checkInTime`, `checkOutTime`, `status`, `location`
- Methods: `fromJson()`, `toJson()`, computed `duration` and `isPresent`

## 🚀 Getting Started

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Run the App

```bash
flutter run
```

### 3. Implement Backend

Currently, the services use placeholder data. You need to implement one of:

**Option A: Firebase**
```bash
# Add Firebase packages
flutter pub add firebase_core firebase_auth cloud_firestore
```

**Option B: REST API**
```bash
# Add HTTP package
flutter pub add http
```

## 📝 TODO List

### High Priority
- [ ] Implement actual authentication (Firebase/REST API)
- [ ] Implement attendance API calls
- [ ] Create SignUp screen
- [ ] Create Check-In screen with location
- [ ] Create Attendance History screen

### Medium Priority
- [ ] Add profile editing functionality
- [ ] Create reports/analytics screen
- [ ] Add push notifications
- [ ] Implement offline support
- [ ] Add biometric authentication

### Low Priority
- [ ] Add dark mode
- [ ] Create custom widgets library
- [ ] Add unit tests
- [ ] Add integration tests
- [ ] Implement CI/CD

## 🎨 Design System

### Colors
- **Primary**: Indigo (#6366F1)
- **Secondary**: Green (#10B981)
- **Success**: Green (#10B981)
- **Warning**: Amber (#F59E0B)
- **Error**: Red (#EF4444)
- **Info**: Blue (#3B82F6)

### Status Colors
- **Present**: Green (#10B981)
- **Late**: Amber (#F59E0B)
- **Absent**: Red (#EF4444)
- **Excused**: Blue (#3B82F6)

## 🔐 Authentication Flow

```
App Start
    ↓
Check Auth Status
    ↓
    ├─ Authenticated → HomeScreen
    └─ Not Authenticated → LoginScreen
         ↓
    User Signs In
         ↓
    AuthProvider updates
         ↓
    Navigate to HomeScreen
```

## 📱 Screen Navigation

```
HomeScreen (Bottom Navigation)
├── Dashboard Tab
│   ├── Welcome Card
│   └── Statistics Cards
├── Attendance Tab
│   ├── Check In/Out
│   └── Today's Records
└── Profile Tab
    ├── User Info
    └── Settings
```

## 🛠️ Development Tips

### Adding a New Feature

1. **Create Model** (if needed): `lib/models/feature_model.dart`
2. **Create Service**: `lib/services/feature_service.dart`
3. **Create Provider**: `lib/providers/feature_provider.dart`
4. **Register Provider** in `main.dart`:
   ```dart
   MultiProvider(
     providers: [
       ChangeNotifierProvider(create: (_) => FeatureProvider()),
     ],
   )
   ```
5. **Create Screen**: `lib/screens/feature/feature_screen.dart`
6. **Use Provider** in screen:
   ```dart
   Consumer<FeatureProvider>(
     builder: (context, provider, _) {
       return YourWidget();
     },
   )
   ```

### Best Practices

✅ Keep providers focused (single responsibility)  
✅ Use `const` constructors where possible  
✅ Dispose controllers in `dispose()` method  
✅ Handle loading and error states  
✅ Use meaningful variable names  
✅ Add comments for complex logic  
✅ Keep widgets small and reusable  

## 📚 Resources

- [Provider Documentation](https://pub.dev/packages/provider)
- [Flutter State Management](https://docs.flutter.dev/development/data-and-backend/state-mgmt/intro)
- [Firebase Flutter Setup](https://firebase.google.com/docs/flutter/setup)
- [Material Design](https://m3.material.io/)

## 🤝 Contributing

When adding new features:
1. Follow the existing folder structure
2. Use Provider for state management
3. Keep services separate from UI
4. Add proper error handling
5. Update this documentation

---

**Happy Coding! 🎉**
