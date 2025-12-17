# Android Testing Checklist

This document provides a comprehensive checklist for testing the Smart Attendance app on Android devices.

## 📱 Pre-Testing Setup

### Device Requirements
- [ ] Android device running Android 5.0 (API 21) or higher
- [ ] Device has a front-facing camera
- [ ] GPS/Location services are available
- [ ] Minimum 100MB free storage space
- [ ] Internet connection available

### Development Setup
- [ ] Android SDK installed and up to date
- [ ] USB debugging enabled on test device
- [ ] Device connected and recognized by ADB (`adb devices`)
- [ ] Flutter SDK installed (`flutter doctor` passes)

## 🔧 Build Testing

### Debug Build
- [ ] Run `flutter clean`
- [ ] Run `flutter pub get`
- [ ] Run `flutter build apk --debug`
- [ ] Verify APK builds without errors
- [ ] Check APK size is reasonable (~50-80MB)

### Release Build
- [ ] Run `flutter build apk --release`
- [ ] Verify release APK builds successfully
- [ ] Install release APK on device
- [ ] Verify app launches correctly

## 📸 Face Registration Testing

### Initial Setup
- [ ] Launch app and navigate to face registration
- [ ] App requests camera permission
- [ ] Camera permission is granted successfully
- [ ] Front camera preview is displayed correctly

### Registration Process
- [ ] Camera preview shows user's face clearly
- [ ] Face detection circle is visible
- [ ] Instructions appear for each angle:
  - [ ] Center position
  - [ ] Turn left
  - [ ] Turn right
  - [ ] Look up
  - [ ] Look down
- [ ] Face position feedback is accurate
- [ ] "Hold still" message appears when face is in position
- [ ] Capture happens automatically after holding position
- [ ] Progress indicators update for each completed angle
- [ ] All 5 angles are captured successfully
- [ ] Success dialog appears after completion
- [ ] Face data is saved to Supabase

### Error Handling
- [ ] "No face detected" message when face is not visible
- [ ] "Multiple faces detected" when more than one person
- [ ] Proper error message if camera fails
- [ ] Retry option works after errors
- [ ] Can exit registration and restart

## 🔐 Face Scanning (Check-In/Out) Testing

### Pre-Scan Checks
- [ ] App requests location permission
- [ ] Location permission is granted
- [ ] GPS is enabled and working
- [ ] App validates user is within office radius
- [ ] Mock location detection works (if fake GPS app is running)

### Check-In Process
- [ ] Navigate to Check-In screen
- [ ] Camera initializes successfully
- [ ] Face detection works in real-time
- [ ] "Blink or Smile to verify" prompt appears
- [ ] Liveness detection works:
  - [ ] Detects blinking
  - [ ] Detects smiling
- [ ] Face verification process starts after liveness
- [ ] Shows "Verifying face..." message
- [ ] Successful match shows success dialog
- [ ] Attendance is recorded in Supabase
- [ ] Returns to home screen after success

### Check-Out Process
- [ ] Cannot check-out without an active check-in
- [ ] Check-out process follows same flow as check-in
- [ ] Check-out time is recorded correctly
- [ ] Can view completed attendance record

### Error Scenarios
- [ ] "Face not registered" error if no face data exists
- [ ] "Already checked in" error prevents duplicate check-ins
- [ ] "Not checked in" error prevents invalid check-outs
- [ ] "Outside radius" error when too far from office
- [ ] Face mismatch shows appropriate error
- [ ] Retry mechanism works (up to 3 attempts)

## 📍 Location Services Testing

### GPS Functionality
- [ ] App can get current GPS coordinates
- [ ] Location accuracy is acceptable (< 20m)
- [ ] Distance calculation is correct
- [ ] Geo-fencing works (within/outside radius)

### Mock Location Detection
- [ ] Install a fake GPS app
- [ ] Enable mock locations
- [ ] App detects and rejects mock locations
- [ ] Proper error message for mock location

### Permission Handling
- [ ] Location permission request works
- [ ] "Permission denied" handled gracefully
- [ ] "Open settings" option works
- [ ] App recovers when permission is granted in settings

## 🔋 Performance Testing

### Battery Usage
- [ ] App doesn't drain battery excessively
- [ ] Camera releases resources when not in use
- [ ] No background processes running when app is closed

### Memory Usage
- [ ] No memory leaks during extended use
- [ ] App memory usage is reasonable (< 200MB)
- [ ] Camera frames are properly disposed

### CPU Usage
- [ ] Face detection doesn't cause excessive CPU usage
- [ ] Device doesn't overheat during face scanning
- [ ] Frame processing is throttled appropriately

### Model Loading
- [ ] TFLite model loads successfully
- [ ] Model loading time is acceptable (< 3 seconds)
- [ ] NNAPI delegate is enabled (check logs)
- [ ] Face recognition is fast (< 2 seconds)

## 🔄 Lifecycle Testing

### App Backgrounding
- [ ] Camera stops when app goes to background
- [ ] Camera resumes when app returns to foreground
- [ ] No crashes when switching apps
- [ ] Proper cleanup when app is killed

### Screen Rotation
- [ ] Camera adjusts to orientation changes
- [ ] UI remains usable in landscape/portrait
- [ ] No crashes during rotation

### Low Memory Scenarios
- [ ] App handles low memory gracefully
- [ ] Proper error messages if resources unavailable
- [ ] App doesn't crash under memory pressure

## 🌐 Network Testing

### Supabase Connection
- [ ] App connects to Supabase successfully
- [ ] Face data uploads correctly
- [ ] Attendance records are saved
- [ ] Error handling for network failures

### Offline Scenarios
- [ ] Proper error when no internet during sign-up/login
- [ ] Face registration fails gracefully without internet
- [ ] Attendance submission fails gracefully
- [ ] User is informed about network requirements

## 🔐 Security Testing

### Permissions
- [ ] Only required permissions are requested
- [ ] Permissions are requested at appropriate times
- [ ] No unnecessary background permissions

### Data Security
- [ ] Face embeddings are stored securely
- [ ] No sensitive data in logs (release build)
- [ ] Location data is properly handled
- [ ] No face images stored locally

### Anti-Fraud
- [ ] Mock location detection works
- [ ] Photos/videos don't work for face recognition
- [ ] Multiple face detection prevents spoofing
- [ ] Liveness detection (blink/smile) works

## 📊 Android Version Testing

Test on different Android versions:

### Android 5-7 (API 21-24)
- [ ] App installs and runs
- [ ] All features work correctly
- [ ] No compatibility issues

### Android 8-9 (API 26-28)
- [ ] Runtime permissions work correctly
- [ ] Background limitations respected
- [ ] All features functional

### Android 10-11 (API 29-30)
- [ ] Scoped storage doesn't affect app
- [ ] Location permissions work (background/foreground)
- [ ] All features functional

### Android 12+ (API 31+)
- [ ] New permission model works
- [ ] Camera and location permissions granted correctly
- [ ] All features functional

## 🎨 UI/UX Testing

### Face Registration UI
- [ ] Camera preview is clear and centered
- [ ] Face detection circle is visible
- [ ] Instructions are clear and readable
- [ ] Progress indicators are visible
- [ ] Success/error dialogs are styled correctly

### Face Scan UI
- [ ] Oval overlay is properly positioned
- [ ] Status messages are readable
- [ ] Loading indicators are visible
- [ ] Success/error dialogs work correctly

### General UI
- [ ] No UI elements are cut off
- [ ] Text is readable on all screen sizes
- [ ] Buttons are easily tappable
- [ ] Navigation works smoothly

## 🐛 Known Issues & Workarounds

Document any issues found during testing:

### Issue Template
```
**Issue**: Brief description
**Steps to Reproduce**: 
1. Step 1
2. Step 2
3. ...

**Expected Behavior**: What should happen
**Actual Behavior**: What actually happens
**Workaround**: If any
**Priority**: High/Medium/Low
```

## ✅ Sign-Off

### Tester Information
- **Tester Name**: _______________
- **Test Date**: _______________
- **Android Version**: _______________
- **Device Model**: _______________

### Test Results
- [ ] All critical features working
- [ ] No blocking issues found
- [ ] Performance is acceptable
- [ ] Ready for deployment

### Notes
Additional observations or comments:

---

**Testing Completed**: _______________
**Approved By**: _______________
