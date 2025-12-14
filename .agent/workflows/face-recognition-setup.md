---
description: Setup Face Recognition for Smart Attendance
---

# Face Recognition Setup Guide

This guide explains how to set up the two-step face recognition flow for the Smart Attendance app.

## Overview

The system works in two phases:

### Phase 1: Face Registration (Detailed Scan)
- User scans their face in detail (multiple angles)
- System extracts face embeddings (numerical representation)
- Embeddings are stored in the database linked to user profile
- This is done ONCE during user setup

### Phase 2: Face Recognition (Quick Scan)
- User scans their face for clock in/out
- System extracts embeddings from the scan
- Compares with stored embeddings in database
- If match found → attendance recorded
- If no match → reject with error message

## Step 1: Install Required Dependencies

Add the following packages to `pubspec.yaml`:

```yaml
dependencies:
  # Face Recognition
  google_mlkit_face_detection: ^0.10.0
  camera: ^0.11.0
  
  # Image Processing
  image: ^4.1.7
  path_provider: ^2.1.2
  
  # Location Services (already mentioned in README)
  geolocator: ^11.0.0
  geocoding: ^3.0.0
  
  # Permissions
  permission_handler: ^11.3.0
```

Run:
```bash
flutter pub get
```

## Step 2: Update Database Schema

Run this SQL in your Supabase SQL Editor:

```sql
-- Add face_embeddings column to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS face_embeddings JSONB,
ADD COLUMN IF NOT EXISTS face_registered BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS face_registered_at TIMESTAMP WITH TIME ZONE;

-- Create index for faster face lookup
CREATE INDEX IF NOT EXISTS idx_users_face_registered ON users(face_registered);

-- Add comment for documentation
COMMENT ON COLUMN users.face_embeddings IS 'Stores face embedding vectors as JSON array for face recognition';
```

## Step 3: Configure Platform Permissions

### Android (`android/app/src/main/AndroidManifest.xml`)

Add these permissions:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />

<!-- Prevent mock locations -->
<uses-permission android:name="android.permission.ACCESS_MOCK_LOCATION" 
    tools:ignore="MockLocation,ProtectedPermissions" />
```

### iOS (`ios/Runner/Info.plist`)

Add these keys:
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for face recognition attendance</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to verify you are at the office</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs location access to verify you are at the office</string>
```

## Step 4: Implementation Architecture

### File Structure to Create:

```
lib/
├── services/
│   ├── face_recognition_service.dart    # ML Kit face detection
│   ├── location_service.dart            # GPS & geo-fencing
│   └── permission_service.dart          # Handle permissions
├── repositories/
│   └── face_repository.dart             # Face data CRUD
├── screens/
│   ├── face_registration/
│   │   └── face_registration_screen.dart
│   └── face_scan/
│       └── face_scan_screen.dart
└── models/
    └── face_embedding_model.dart
```

## Step 5: Implementation Flow

### 5.1 Face Registration Flow
1. User navigates to Profile → "Register Face"
2. Camera opens with face detection overlay
3. User captures face from multiple angles (front, left, right)
4. System extracts embeddings from each capture
5. Average embeddings calculated and stored
6. User profile updated with `face_registered = true`

### 5.2 Clock In/Out Flow
1. User taps "Clock In" or "Clock Out"
2. System checks location (geo-fencing)
3. If location valid → open camera
4. User scans face (single capture)
5. System extracts embeddings
6. Compare with stored embeddings (cosine similarity)
7. If match (similarity > 0.85) → record attendance
8. If no match → show error "Face not recognized"

## Step 6: Security Considerations

1. **Liveness Detection**: Implement blink detection or head movement to prevent photo spoofing
2. **Encryption**: Store face embeddings encrypted in database
3. **Mock Location Detection**: Prevent fake GPS apps
4. **Timeout**: Face scan must complete within 30 seconds
5. **Retry Limit**: Maximum 3 failed attempts before lockout

## Step 7: Testing Checklist

- [ ] Face registration works with good lighting
- [ ] Face registration works with poor lighting
- [ ] Face recognition matches correctly
- [ ] Face recognition rejects different person
- [ ] Geo-fencing blocks clock in outside radius
- [ ] Mock location detection works
- [ ] Permissions are requested properly
- [ ] Error messages are clear and helpful

## Step 8: User Experience Flow

### First Time Setup:
```
Sign Up → Login → Profile → "Register Your Face" → 
Camera Opens → Capture Front → Capture Left → Capture Right → 
Processing → Success! → Ready to Clock In/Out
```

### Daily Usage:
```
Open App → Tap "Clock In" → Location Check → 
Camera Opens → Scan Face → Match Found → 
Attendance Recorded → Show Success Message
```

## Next Steps

1. Create the face recognition service
2. Create the face registration screen
3. Create the face scan screen
4. Update the attendance flow to use face recognition
5. Add geo-fencing validation
6. Test thoroughly with multiple users

## Troubleshooting

### Face Not Detected
- Ensure good lighting
- Face should be clearly visible
- Remove glasses/mask if needed
- Hold phone at eye level

### Face Not Recognized
- Re-register face in better lighting
- Ensure face is not obscured
- Check if embeddings are stored correctly

### Location Not Valid
- Enable GPS/Location services
- Ensure you're within office radius
- Check if mock location is disabled

## Resources

- [Google ML Kit Face Detection](https://developers.google.com/ml-kit/vision/face-detection)
- [Flutter Camera Plugin](https://pub.dev/packages/camera)
- [Geolocator Plugin](https://pub.dev/packages/geolocator)
