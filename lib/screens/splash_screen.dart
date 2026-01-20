import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../services/notification_service.dart';
import '../services/prediction_service.dart';
import '../services/gemini_service.dart';
import '../services/background_monitor_service.dart';
import '../services/workmanager_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  String _statusMessage = 'Initializing...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      // Step 1: Initialize Supabase
      _updateStatus('Connecting to database...');
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseKey,
      );
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 2: Initialize notifications
      _updateStatus('Setting up notifications...');
      await NotificationService.initialize();
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 3: Initialize ML model
      _updateStatus('Loading ML model...');
      try {
        await PredictionService.initializeModel(AppConfig.mlModelPath);
      } catch (e) {
        debugPrint('ML Model initialization skipped: $e');
      }
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 4: Initialize Gemini AI
      _updateStatus('Initializing AI recommendations...');
      try {
        await GeminiService.initialize();
      } catch (e) {
        debugPrint('Gemini initialization skipped: $e');
      }
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 5: Start background monitoring
      _updateStatus('Starting monitoring...');
      try {
        if (!kIsWeb && Platform.isAndroid) {
          await WorkmanagerService.registerPeriodicWaterQualityCheck(
            frequency: const Duration(minutes: 15),
          );
        } else {
          await BackgroundMonitorService.startMonitoring(
            interval: const Duration(minutes: 5),
          );
        }
      } catch (e) {
        debugPrint('Background monitoring setup skipped: $e');
      }
      await Future.delayed(const Duration(milliseconds: 300));

      // Step 6: Complete
      _updateStatus('Ready!');
      await Future.delayed(const Duration(milliseconds: 800));

      // Navigate to home
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _statusMessage = 'Initialization failed: $e';
      });
      debugPrint('Initialization error: $e');

      // Retry after delay or navigate anyway
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  void _updateStatus(String message) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0EA5E9), // Sky blue
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0EA5E9),
              const Color(0xFF0284C7),
              theme.colorScheme.primary,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Logo with animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: size.width * 0.5,
                      height: size.width * 0.5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(40),
                      child: Image.asset(
                        'assets/swai_icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // App name
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        'SWAI',
                        style: theme.textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Smart WaterGuard Ai',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // Loading indicator and status
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      if (!_hasError)
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: Image.asset(
                            'assets/2.gif',
                            fit: BoxFit.contain,
                          ),
                        ),
                      if (_hasError)
                        Icon(
                          Icons.error_outline,
                          size: 40,
                          color: Colors.red.shade200,
                        ),
                      const SizedBox(height: 20),
                      Text(
                        _statusMessage,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // Version info
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'v1.0.0',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
