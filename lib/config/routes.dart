import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/home_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/history_screen.dart';
import '../screens/fish_info_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/ml_test_screen.dart';

class AppRoutes {
  // Route names
  static const String splash = '/';
  static const String home = '/home';
  static const String dashboard = '/dashboard';
  static const String history = '/history';
  static const String fishInfo = '/fish-info';
  static const String settings = '/settings';
  static const String mlTest = '/ml-test';

  // Route generator
  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case '/home':
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case '/dashboard':
        return MaterialPageRoute(builder: (_) => const DashboardScreen());

      case '/history':
        return MaterialPageRoute(builder: (_) => const HistoryScreen());

      case '/fish-info':
        return MaterialPageRoute(builder: (_) => const FishInfoScreen());

      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsScreen());

      case '/ml-test':
        return MaterialPageRoute(builder: (_) => const MLTestScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${routeSettings.name}'),
            ),
          ),
        );
    }
  }

  // Route map (alternative to generator)
  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        home: (context) => const HomeScreen(),
        dashboard: (context) => const DashboardScreen(),
        history: (context) => const HistoryScreen(),
        fishInfo: (context) => const FishInfoScreen(),
        settings: (context) => const SettingsScreen(),
        mlTest: (context) => const MLTestScreen(),
      };
}
