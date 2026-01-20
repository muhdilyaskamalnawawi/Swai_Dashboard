# Routing Design & Icon Configuration

## Overview
The SWAI Dashboard now uses a centralized routing system with named routes and a professional splash screen that initializes all services before the app loads.

## Architecture

### Routing System
**File**: [lib/config/routes.dart](lib/config/routes.dart)

- **Named Routes**: All screens are accessible via named routes (e.g., `AppRoutes.home`, `AppRoutes.dashboard`)
- **Route Generator**: Provides both map-based and generator-based routing for flexibility
- **Navigation**: Use `Navigator.pushNamed(context, AppRoutes.screenName)` instead of direct widget navigation

Available Routes:
- `/` - Splash Screen (initial route)
- `/home` - Home Screen (bottom navigation container)
- `/dashboard` - Dashboard Screen (direct access)
- `/history` - History Screen (direct access)
- `/fish-info` - Fish Info Screen (direct access)
- `/settings` - Settings Screen (direct access)

### Splash Screen
**File**: [lib/screens/splash_screen.dart](lib/screens/splash_screen.dart)

**Features**:
- Animated logo reveal with fade and scale transitions
- Progressive initialization status messages
- Service initialization sequence:
  1. Supabase database connection
  2. Local notifications setup
  3. ML model loading (TensorFlow Lite)
  4. Gemini AI initialization
- Error handling with retry logic
- Auto-navigation to home screen on completion

**Design**:
- Gradient background (#0EA5E9 sky blue theme)
- Large centered `swai_icon.png` logo
- Loading spinner and status text
- Version number display

### Icon Usage

#### App Icon & Splash (swai_icon.png)
Used for:
- Android launcher icon
- iOS app icon
- Native splash screen
- Splash screen logo display

Configuration in `pubspec.yaml`:
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/swai_icon.png"
  adaptive_icon_background: "#0EA5E9"
  adaptive_icon_foreground: "assets/swai_icon.png"

flutter_native_splash:
  color: "#0EA5E9"
  image: assets/swai_icon.png
```

#### In-App Logo (swai_inapp.png)
Used for:
- AppBar logo in [lib/screens/home_screen.dart](lib/screens/home_screen.dart)
- Branding within the app interface
- Navigation bar branding (if needed)

## Screen Structure

### Home Screen
**File**: [lib/screens/home_screen.dart](lib/screens/home_screen.dart)

- **Top-level Container**: Provides AppBar and bottom navigation
- **AppBar**: Displays `swai_inapp.png` logo + current screen title
- **Bottom Navigation**: 4 tabs (Dashboard, History, Fish Info, Settings)
- **Screen Titles**: Dynamic based on selected tab

### Child Screens
All child screens ([dashboard_screen.dart](lib/screens/dashboard_screen.dart), [history_screen.dart](lib/screens/history_screen.dart), [fish_info_screen.dart](lib/screens/fish_info_screen.dart), [settings_screen.dart](lib/screens/settings_screen.dart)):
- **No AppBar**: HomeScreen provides the AppBar
- **Body Only**: Each screen returns a Scaffold with just a body
- **Refresh Control**: Dashboard has FloatingActionButton for manual refresh

## Navigation Flow

```
App Launch
    ↓
SplashScreen (/)
    ↓ Initialize services
    ↓ Show progress
    ↓
HomeScreen (/home)
    ↓
    ├─ Dashboard (tab 0)
    ├─ History (tab 1)
    ├─ Fish Info (tab 2)
    └─ Settings (tab 3)
```

## Implementation Details

### Service Initialization
Moved from `main.dart` to `splash_screen.dart`:
- **Before**: Services initialized in `main()`, blocking app startup
- **After**: Services initialized asynchronously in splash screen with visual feedback

### Theme Configuration
**File**: [lib/main.dart](lib/main.dart)

```dart
theme: ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF0EA5E9), // SWAI brand color
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0EA5E9),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
),
```

### Assets Configuration
**File**: `pubspec.yaml`

```yaml
flutter:
  assets:
    - assets/swai_icon.png      # App icon & splash
    - assets/swai_inapp.png     # In-app logo
```

## Usage Examples

### Navigate to a Screen
```dart
// From any screen
Navigator.pushNamed(context, AppRoutes.settings);
```

### Replace Current Screen
```dart
// Used in splash screen
Navigator.pushReplacementNamed(context, AppRoutes.home);
```

### Direct Navigation (Alternative)
```dart
// If you need to pass complex data
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const SettingsScreen(),
  ),
);
```

## Customization

### Change Splash Duration
Edit [lib/screens/splash_screen.dart](lib/screens/splash_screen.dart):
```dart
await Future.delayed(const Duration(milliseconds: 500)); // Adjust per step
```

### Update App Icon
1. Replace `assets/swai_icon.png` with new icon (1024x1024 recommended)
2. Run: `flutter pub run flutter_launcher_icons`
3. Run: `dart run flutter_native_splash:create`

### Update In-App Logo
1. Replace `assets/swai_inapp.png` with new logo
2. Restart app (no rebuild needed)

### Add New Route
In [lib/config/routes.dart](lib/config/routes.dart):
```dart
static const String myNewScreen = '/my-screen';

// Add to routes map
static Map<String, WidgetBuilder> get routes => {
  // ... existing routes
  myNewScreen: (context) => const MyNewScreen(),
};
```

## Benefits of This Design

1. **Centralized Navigation**: All routes defined in one place
2. **Better UX**: Splash screen provides feedback during initialization
3. **Error Resilience**: Services can fail without crashing the app
4. **Consistent Branding**: Logo appears consistently across the app
5. **Easy Maintenance**: Change routing logic in one file
6. **Deep Linking Ready**: Named routes support URL-based navigation

## Troubleshooting

### Splash Screen Doesn't Appear
- Ensure `initialRoute: AppRoutes.splash` in `MaterialApp`
- Check that splash screen is the first route in the map

### Icons Not Updating
```bash
flutter clean
flutter pub get
flutter pub run flutter_launcher_icons
dart run flutter_native_splash:create
flutter run
```

### AppBar Shows Duplicate Logo
- Verify child screens don't have their own AppBar
- Only HomeScreen should have AppBar

### Navigation Not Working
- Use `AppRoutes.screenName` constants, not hardcoded strings
- Ensure routes are registered in `routes.dart`

## Files Modified
- ✅ [lib/main.dart](lib/main.dart) - Added routing configuration
- ✅ [lib/config/routes.dart](lib/config/routes.dart) - NEW: Route definitions
- ✅ [lib/screens/splash_screen.dart](lib/screens/splash_screen.dart) - NEW: Splash with initialization
- ✅ [lib/screens/home_screen.dart](lib/screens/home_screen.dart) - Added AppBar with logo
- ✅ [lib/screens/dashboard_screen.dart](lib/screens/dashboard_screen.dart) - Removed AppBar
- ✅ [lib/screens/history_screen.dart](lib/screens/history_screen.dart) - Removed AppBar
- ✅ [lib/screens/fish_info_screen.dart](lib/screens/fish_info_screen.dart) - Removed AppBar
- ✅ [lib/screens/settings_screen.dart](lib/screens/settings_screen.dart) - Removed AppBar
- ✅ `pubspec.yaml` - Updated icon/splash configuration

## Next Steps

To test the routing system:
```bash
flutter run
```

The app will now:
1. Show splash screen with animated logo
2. Initialize all services with status updates
3. Navigate to home screen automatically
4. Display consistent AppBar with logo across all tabs
