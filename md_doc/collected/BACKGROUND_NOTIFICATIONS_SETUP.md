# QUICK SETUP - Background Notifications (Android WorkManager)

## 🚀 Steps to Apply Fixes

### 1. Rebuild the App
Since we modified AndroidManifest.xml, you need to rebuild:

```bash
# Clean old build
flutter clean

# Get dependencies
flutter pub get

# Build new APK
flutter build apk --release
```

### 2. Install on Phone
```bash
# Find APK location
# build/app/outputs/flutter-apk/app-release.apk

# Install on connected device
flutter install

# OR transfer APK to phone and install manually
```

### 3. Grant Permissions
When you first open the app after reinstalling:
1. Allow notification permission when prompted
2. If not prompted, go to:
   - Settings > Apps > SWAI Dashboard > Notifications
   - Enable all notification channels

### 4. Disable Battery Optimization (Important!)
For background monitoring to work reliably:

**On Most Android Phones:**
1. Go to Settings > Battery > Battery Optimization
2. Find "SWAI Dashboard"
3. Select "Don't optimize"

**On Samsung:**
1. Settings > Apps > SWAI Dashboard
2. Battery > Optimize battery usage
3. Turn OFF for SWAI Dashboard

**On Xiaomi/MIUI:**
1. Settings > Apps > Manage Apps > SWAI Dashboard
2. Battery Saver > No restrictions
3. Autostart > Enable

### 5. Test Background Notifications

**Important (Android):** WorkManager periodic jobs have a **minimum interval of 15 minutes** and are not exact; the OS may delay them depending on battery/idle.

**Option A: Wait for Real Data**
1. Close app completely
2. Wait 15+ minutes
3. Check if you get notifications for critical readings

**Option B: Force Test (Recommended)**
1. Open app
2. Look at debug console/logs
3. Should see: "Starting monitoring..." and WorkManager registration logs
4. Close app
5. Check logs after 15+ minutes for: "🔍 Checking water quality (background)..."

**Option C: Run One-Off Task (Fastest)**
- Call `WorkmanagerService.runOneOffWaterQualityCheck()` from a debug button or temporary code path.
- This triggers a background run ASAP (still subject to OS scheduling).

### 6. Test Auto-Refresh
1. Open app on dashboard
2. Press home button (minimize app)
3. Wait 10 seconds
4. Reopen app
5. **Should see**: "📱 App resumed - refreshing data..." in logs
6. Dashboard updates immediately

## ✅ Verification Checklist

- [ ] App rebuilt with `flutter build apk --release`
- [ ] New APK installed on phone
- [ ] Notification permission granted
- [ ] Battery optimization disabled
- [ ] Background monitoring starts (check logs)
- [ ] Auto-refresh works when reopening app
- [ ] Notifications work when app is closed

## 🐛 If Issues Persist

### Notifications Still Not Working?
```bash
# Run in debug mode to see logs
flutter run --release

# Watch for these messages:
# ✓ Notifications initialized
# 🔄 Starting background monitoring
# 🔍 Checking water quality...
# 🚨 CRITICAL reading detected!
```

### Check Logs After 5 Minutes:
```dart
// Should see in console:
🔍 Checking water quality...
✅ New reading: pH=7.2, Temp=28.5°C, TDS=250
✅ Water quality is good

// OR if critical:
🔍 Checking water quality...
✅ New reading: pH=4.5, Temp=28.5°C, TDS=250
🚨 CRITICAL reading detected!
```

## 📝 Notes

- Android background checks use WorkManager (minimum 15 minutes)
- Notifications only sent for NEW critical readings (not repeated)
- Auto-refresh happens instantly when app resumes
- Real-time stream works when app is open
- Background monitoring works when app is closed

## 🎯 Expected Behavior

**When App Opens:**
- Fetches latest data immediately
- Starts background monitoring
- Connects to real-time stream

**When Using App:**
- Real-time updates from Supabase stream
- Immediate notifications for critical readings
- Manual refresh button available

**When App Minimized/Closed:**
- Background monitor checks every 5 minutes
- Sends notifications if critical conditions found
- No need to keep app open

**When App Resumes:**
- Lifecycle observer detects resume
- Fetches fresh data immediately
- Updates dashboard automatically

Everything should work automatically now! 🎉
