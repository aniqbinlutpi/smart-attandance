# Camera Permission Fix for Face Registration

## Problem
When users tried to register their face, the app would request camera permission. If denied, tapping "Open Settings" would take them to iOS Settings, but after granting permission, they had to manually navigate back to the Face Registration screen.

## Solution
Implemented an improved permission flow that automatically detects when the app returns from Settings and retries camera initialization if permission was granted.

### Key Changes Made

1. **Added WidgetsBindingObserver**
   - The screen now observes app lifecycle changes
   - Detects when the app resumes from background (e.g., returning from Settings)

2. **Permission State Tracking**
   - Added `_permissionDenied` flag to track permission status
   - Allows the app to know when to retry initialization

3. **Automatic Retry Logic**
   - `_retryAfterSettings()` method checks permission status when app resumes
   - Automatically reinitializes camera if permission is now granted
   - Provides seamless UX without requiring manual navigation

4. **Improved Dialog Flow**
   - Removed automatic screen pop when opening Settings
   - User stays on the Face Registration screen
   - App automatically retries when they return

### User Experience Flow

**Before:**
1. User opens Face Registration
2. Permission denied → Dialog appears
3. User taps "Open Settings"
4. App navigates back to previous screen
5. User grants permission in Settings
6. User must manually navigate back to Face Registration
7. User must retry the process

**After:**
1. User opens Face Registration
2. Permission denied → Dialog appears
3. User taps "Open Settings"
4. User grants permission in Settings
5. User returns to app (swipes up or taps app)
6. ✨ Camera automatically initializes
7. User can immediately start registration

### Technical Details

- Uses `WidgetsBindingObserver` to monitor `AppLifecycleState.resumed`
- Checks `PermissionService.isCameraPermissionGranted()` on resume
- Only retries if `_permissionDenied` flag is set (prevents unnecessary checks)
- Properly cleans up observer in `dispose()` to prevent memory leaks

### Testing Recommendations

1. Test permission denial → Settings → grant → return flow
2. Test permission denial → Settings → don't grant → return flow
3. Test permission granted on first request
4. Test app backgrounding/foregrounding during normal use

## Notes

- Location permission already works well (as confirmed by user)
- This fix only affects camera permission flow
- No changes needed to `Info.plist` - permission descriptions are already correct
