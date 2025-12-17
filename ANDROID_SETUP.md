# Android Setup Guide for Smart Attendance

This guide covers Android-specific setup and compatibility requirements for the Smart Attendance app.

## ✅ Android Compatibility Features

The app has been configured to work seamlessly on Android devices with the following features:

### 1. **Face Recognition on Android**
- ✅ TensorFlow Lite model support with proper asset loading
- ✅ Google ML Kit Face Detection integration
- ✅ CPU-based inference (fast and reliable)
- ✅ Multi-architecture support (armeabi-v7a, arm64-v8a, x86, x86_64)

### 2. **Camera Access**
- ✅ Front camera support for face scanning
- ✅ Camera autofocus support
- ✅ Runtime permission handling
- ✅ Camera preview optimization

### 3. **Location Services**
- ✅ GPS location access for attendance verification
- ✅ Mock location detection (prevents fake GPS)
- ✅ Geo-fencing support (radius-based check-in)
- ✅ Location permission handling

### 4. **Required Permissions**
The following permissions are configured in AndroidManifest.xml:
- `CAMERA` - For face scanning and recognition
- `ACCESS_FINE_LOCATION` - For accurate GPS location
- `ACCESS_COARSE_LOCATION` - For approximate location
- `INTERNET` - For Supabase backend communication

## 📱 Android Version Requirements

- **Minimum SDK**: 21 (Android 5.0 Lollipop)
- **Target SDK**: 34 (Android 14)
- **Compile SDK**: 34

This ensures compatibility with ~99% of Android devices in use.

## 🔧 Android Build Configuration

### TFLite Model Loading
The build configuration includes special handling for TensorFlow Lite models:

```kotlin
// In android/app/build.gradle.kts
androidResources {
    noCompress("tflite")
}
```

This prevents Android from compressing `.tflite` files, ensuring proper model loading.

### Native Library Support
The app supports multiple Android architectures:

```kotlin
ndk {
    abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64"))
}
```

## 🚀 Building for Android

### Debug Build
```bash
flutter build apk --debug
```

### Release Build
```bash
flutter build apk --release
```

### App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

## ⚠️ Common Android Issues & Solutions

### Issue 1: Camera not working
**Solution**: Ensure camera permissions are granted at runtime. The app will request them automatically.

### Issue 2: TFLite model not loading
**Solution**: This is already fixed with the `noCompress` configuration. If you still face issues:
1. Clean build: `flutter clean`
2. Rebuild: `flutter build apk`

### Issue 3: Location not working
**Solutions**:
- Enable GPS in device settings
- Grant location permissions when prompted
- Ensure you're testing on a real device (emulators may have GPS issues)

### Issue 4: Mock location detected
**Solution**: Disable any fake GPS apps. The app includes mock location detection for security.

## 🔐 Security Features on Android

### 1. Mock Location Detection
The app uses `Position.isMocked` to detect fake GPS applications, preventing attendance fraud.

### 2. Hardware Acceleration
Hardware acceleration is enabled for better face recognition performance:
```xml
android:hardwareAccelerated="true"
```

### 3. Face Recognition Security
- Multi-angle face registration (5 angles: center, left, right, up, down)
- High similarity threshold (65%) for matching
- TensorFlow Lite MobileFaceNet model for deep learning embeddings

## 📊 Performance Optimization

### Camera Performance
- Uses `ResolutionPreset.medium` for optimal balance
- Implements frame throttling to prevent overheating
- Automatic camera lifecycle management

### Location Performance
- High accuracy GPS settings
- 10-second timeout for location requests
- Efficient distance calculation using Geolocator

### Face Recognition Performance
- Hardware acceleration support (optional GPU delegate)
- Efficient face detection with ML Kit
- Optimized TFLite inference

## 🧪 Testing on Android

### Emulator Testing
1. Use Android emulator with API level 21 or higher
2. Enable camera in emulator settings
3. Use extended controls to set GPS location

**Note**: Face recognition works best on real devices. Emulator cameras may have limitations.

### Real Device Testing
1. Enable Developer Options on your Android device
2. Enable USB Debugging
3. Connect device via USB
4. Run: `flutter run`

## 📝 Android-Specific Notes

### Minimum Requirements for Face Recognition
- Android 5.0+ (API 21)
- Front-facing camera
- ~20MB storage for TFLite model

### Minimum Requirements for Location
- GPS hardware (available on all modern Android devices)
- Location services enabled
- Internet connection for accuracy improvements (A-GPS)

### Battery Optimization
The app is optimized for battery efficiency:
- Camera only active during face scanning
- Location accessed only when checking in/out
- No background services running

## 🔄 Updating Android Configuration

If you need to modify Android-specific settings:

1. **Build configuration**: Edit `android/app/build.gradle.kts`
2. **Permissions**: Edit `android/app/src/main/AndroidManifest.xml`
3. **Native code**: Edit `android/app/src/main/kotlin/.../MainActivity.kt`

## 🆘 Need Help?

If you encounter Android-specific issues:

1. Check Flutter doctor: `flutter doctor -v`
2. Clean and rebuild: `flutter clean && flutter build apk`
3. Check Android Studio logs for detailed error messages
4. Ensure all Android SDK components are up to date

## 📚 Additional Resources

- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)
- [Android Permissions Guide](https://developer.android.com/guide/topics/permissions/overview)
- [TensorFlow Lite on Android](https://www.tensorflow.org/lite/android)
- [Google ML Kit](https://developers.google.com/ml-kit)

---

**Last Updated**: December 2024
**Flutter Version**: 3.5.0+
**Android Target**: API 34
