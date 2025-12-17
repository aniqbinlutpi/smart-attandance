# Android Troubleshooting Guide

Quick reference for solving common Android issues with the Smart Attendance app.

## 🚨 Build Issues

### Issue: "Execution failed for task ':app:mergeDebugAssets'"
**Cause**: TFLite model file compression issue

**Solution**:
This has been fixed in the latest build configuration. If you still encounter this:
```bash
flutter clean
cd android && ./gradlew clean && cd ..
flutter pub get
flutter build apk
```

The fix in `android/app/build.gradle.kts`:
```kotlin
androidResources {
    noCompress("tflite")
}
```

### Issue: "Unsupported class file major version 61"
**Cause**: Java version mismatch

**Solution**:
Ensure Java 11 is being used:
```bash
# Check Java version
java -version

# If needed, set JAVA_HOME to Java 11
export JAVA_HOME=/path/to/java11
```

### Issue: Build fails with "NDK not configured"
**Cause**: NDK version mismatch

**Solution**:
The app is configured to use the Flutter-specified NDK version:
```kotlin
ndkVersion = flutter.ndkVersion
```

If issues persist:
1. Open Android Studio
2. Go to SDK Manager → SDK Tools
3. Install NDK version specified in `gradle.properties`

## 📸 Camera Issues

### Issue: Camera preview is black/frozen
**Cause**: Camera permission not granted or camera in use

**Solution**:
1. Check camera permission is granted
2. Restart the app
3. Ensure no other app is using the camera
4. Check logs: `flutter logs | grep CAMERA`

### Issue: "No camera found" error
**Cause**: Device doesn't have a camera or camera API issue

**Solution**:
```dart
// In face_registration_screen.dart and face_scan_screen.dart
// The app handles this automatically and shows an error
```

For developers: Ensure you're testing on a real device, not an emulator without camera support.

### Issue: Camera rotation is incorrect
**Cause**: Sensor orientation not properly handled

**Solution**:
This is handled in the code with:
```dart
final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation)
```

If issues persist, check device's auto-rotate settings.

## 🤖 TFLite Model Issues

### Issue: "Failed to load model" error
**Cause**: Model file not found or corrupted

**Solutions**:
1. Verify model exists: `ls assets/models/mobilefacenet.tflite`
2. Check pubspec.yaml includes:
   ```yaml
   flutter:
     assets:
       - assets/models/
   ```
3. Rebuild: `flutter clean && flutter build apk`

### Issue: NNAPI delegate not available
**Symptom**: Warning in logs: "NNAPI delegate not available"

**Solution**:
This is normal on some devices. The app automatically falls back to CPU inference, which is still fast for MobileFaceNet.

To check if NNAPI is being used:
```bash
flutter logs | grep NNAPI
```

### Issue: Face recognition is slow
**Causes & Solutions**:

1. **Low-end device**: 
   - Expected on devices with weak CPUs
   - NNAPI should help if available

2. **Debug mode**:
   - Use release build for better performance
   - `flutter build apk --release`

3. **Too many embeddings**:
   - The app limits to 5 angles, which is optimal
   - If you modified this, reduce the number

## 📍 Location Issues

### Issue: "Location services disabled" error
**Cause**: GPS is turned off

**Solution**:
1. Enable GPS in device settings:
   - Settings → Location → Turn ON
2. App will automatically detect when GPS is enabled

### Issue: "Permission denied" for location
**Cause**: User denied location permission

**Solution**:
1. Grant permission when prompted
2. If already denied, tap "Open Settings" button
3. Or manually: Settings → Apps → Smart Attendance → Permissions → Location → Allow

### Issue: "Mock location detected"
**Cause**: Fake GPS app is running

**Solution**:
1. Disable/uninstall fake GPS apps
2. In Developer Options, turn off "Allow mock locations"
3. Restart the app

For developers: This is a security feature to prevent attendance fraud.

### Issue: "Outside radius" error when actually at office
**Causes & Solutions**:

1. **GPS accuracy**:
   - Wait for better GPS signal
   - Move to area with clear sky view
   - GPS accuracy improves over time

2. **Wrong office coordinates**:
   - Update in `lib/services/location_service.dart`:
     ```dart
     static const double officeLat = YOUR_LAT;
     static const double officeLng = YOUR_LNG;
     ```

3. **Radius too small**:
   - Adjust in `lib/services/location_service.dart`:
     ```dart
     static const double allowedRadius = 500.0; // meters
     ```

## 🔐 Permission Issues

### Issue: Permissions not being requested
**Cause**: Permission already denied or system issue

**Solution**:
1. Clear app data: Settings → Apps → Smart Attendance → Storage → Clear Data
2. Reinstall app
3. Ensure AndroidManifest.xml has permissions (already configured)

### Issue: "Permission permanently denied"
**Cause**: User selected "Don't ask again" when denying

**Solution**:
1. App shows "Open Settings" option
2. Manually grant permissions in Settings

### Issue: Permissions reset after reinstall
**Cause**: Expected Android behavior

**Solution**:
This is normal. Grant permissions again when prompted.

## 🎨 UI Issues

### Issue: UI elements cut off on small screens
**Cause**: Layout not properly responsive

**Solution**:
The app is designed for screens 5" and larger. For smaller screens:
- Rotate to landscape for better view
- If you're a developer, adjust padding in the respective screen files

### Issue: Status messages not visible
**Cause**: Contrast issue or overlapping elements

**Solution**:
Check your device's display settings:
- Disable any blue light filters
- Adjust brightness
- Check if any accessibility features are interfering

## 🔄 State Management Issues

### Issue: "Already checked in" when not checked in
**Cause**: Database state mismatch

**Solution**:
1. Check Supabase dashboard for your attendance records
2. If stuck, manually update the record to add check_out_time
3. Or wait until the next day

For developers: The app checks `hasActiveCheckIn()` which looks for records without check_out_time.

### Issue: Face registration data lost
**Cause**: User ID mismatch or database issue

**Solution**:
1. Check if user is logged in
2. Re-register face
3. Check Supabase logs for errors

## 🚀 Performance Issues

### Issue: App crashes during face scanning
**Causes & Solutions**:

1. **Memory leak**:
   ```bash
   # Check logs
   flutter logs | grep "Out of memory"
   ```
   - Close other apps
   - Restart device
   - Use release build

2. **Frame processing overload**:
   - This is prevented by throttling in code
   - If you modified the code, check `_lastProcessTime` logic

### Issue: Device overheating
**Cause**: Continuous camera use and ML processing

**Solution**:
- Take breaks between scans
- Ensure device has good ventilation
- Close other apps
- In release builds, performance is better

## 📱 Android Version Specific

### Android 5-6 (API 21-23)
**Issue**: Some features may be slower

**Solution**: Use release build for better performance

### Android 10+ (API 29+)
**Issue**: Scoped storage restrictions

**Solution**: Already handled in code. No action needed.

### Android 11+ (API 30+)
**Issue**: Location permission dialog shows "Precise" vs "Approximate"

**Solution**: 
- Always choose "Precise" for accurate attendance
- The app requires fine location for geo-fencing

### Android 12+ (API 31+)
**Issue**: New permission dialogs

**Solution**: Grant both camera and location when prompted

## 🛠️ Developer Tools

### Enable Debug Logging
```bash
# View all logs
flutter logs

# Filter by tag
flutter logs | grep "CAMERA"
flutter logs | grep "TFLite"
flutter logs | grep "SCAN"
```

### Check Permissions via ADB
```bash
# List all permissions
adb shell dumpsys package com.smartattendance.smart_attendance | grep permission

# Grant permission manually
adb shell pm grant com.smartattendance.smart_attendance android.permission.CAMERA
adb shell pm grant com.smartattendance.smart_attendance android.permission.ACCESS_FINE_LOCATION
```

### Clear App Data
```bash
# Via ADB
adb shell pm clear com.smartattendance.smart_attendance
```

### Force Stop App
```bash
adb shell am force-stop com.smartattendance.smart_attendance
```

## 📋 Pre-Deployment Checklist

Before releasing to users, verify:

- [ ] All permissions work correctly
- [ ] Face registration completes successfully
- [ ] Face scanning works (check-in/out)
- [ ] Location validation works
- [ ] Mock location detection works
- [ ] Release build is optimized
- [ ] No excessive battery drain
- [ ] Works on different Android versions
- [ ] Works on different screen sizes
- [ ] Tested on real devices (not just emulator)

## 🆘 Getting Help

If none of the above solutions work:

1. **Check Flutter logs**:
   ```bash
   flutter logs > logs.txt
   ```

2. **Check Android logcat**:
   ```bash
   adb logcat > logcat.txt
   ```

3. **Verify configuration**:
   - AndroidManifest.xml has all permissions
   - build.gradle.kts has proper configuration
   - Assets are properly included in pubspec.yaml

4. **Clean build**:
   ```bash
   flutter clean
   cd android && ./gradlew clean && cd ..
   rm -rf build/
   flutter pub get
   flutter build apk --release
   ```

5. **Report issue** with:
   - Device model and Android version
   - Flutter version (`flutter --version`)
   - Complete error logs
   - Steps to reproduce

## 📚 Additional Resources

- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)
- [Android Permissions Guide](https://developer.android.com/guide/topics/permissions/overview)
- [TensorFlow Lite Android](https://www.tensorflow.org/lite/android)
- [Camera Plugin Issues](https://github.com/flutter/plugins/tree/main/packages/camera)
- [Geolocator Issues](https://github.com/baseflow/flutter-geolocator)

---

**Last Updated**: December 2024
