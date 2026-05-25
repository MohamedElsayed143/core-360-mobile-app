import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/presentation/providers/auth_provider.dart';
import 'features/onboarding/presentation/screens/login_screen.dart';
import 'features/onboarding/presentation/screens/onboarding_survey_screen.dart';
import 'features/onboarding/presentation/screens/home_placeholder_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with defensive try/catch to support offline testing mode gracefully.
  bool isFirebaseInitialized = false;
  try {
    await Firebase.initializeApp();
    isFirebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }

  runApp(
    ProviderScope(
      child: MyApp(isFirebaseInitialized: isFirebaseInitialized),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isFirebaseInitialized;
  const MyApp({super.key, required this.isFirebaseInitialized});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Core-360',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: RootAuthBridge(isFirebaseInitialized: isFirebaseInitialized),
    );
  }
}

class RootAuthBridge extends ConsumerWidget {
  final bool isFirebaseInitialized;
  const RootAuthBridge({super.key, required this.isFirebaseInitialized});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If Firebase failed to initialize, render a clean error or offline simulation screen.
    if (!isFirebaseInitialized) {
      return const FirebaseErrorScreen();
    }

    final authState = ref.watch(authProvider);

    if (authState is AuthInitial) {
      return const SplashScreen();
    } else if (authState is Unauthenticated) {
      return const LoginScreen();
    } else if (authState is AuthenticatedWithoutProfile) {
      return const OnboardingSurveyScreen();
    } else if (authState is AuthenticatedWithProfile) {
      return const HomePlaceholderScreen();
    } else if (authState is AuthError) {
      return ErrorScreen(message: authState.message);
    }

    return const SplashScreen();
  }
}

// ─── HIGH-FIDELITY SPLASH / LOADER SCREEN ──────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.darkSurface,
                    border: Border.all(color: AppTheme.cardBorderColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.cyberCyan.withOpacity(0.05 + (_animController.value * 0.1)),
                        blurRadius: 40,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                    child: const Icon(
                      Icons.all_inclusive,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'CORE-360',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 3.0,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'CALIBRATING BIOMETRIC ENGINE...',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppTheme.cyberCyan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PREMIUM ERROR LAYOUT ───────────────────────────────────────────────
class ErrorScreen extends ConsumerWidget {
  final String message;
  const ErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(0.05),
                  blurRadius: 30,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 54,
                ),
                const SizedBox(height: 24),
                Text(
                  'SYSTEM ALERT',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Colors.redAccent, Colors.deepOrange],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(authProvider.notifier).clearError();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'DISMISS & RETRY',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.0,
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

// ─── FIREBASE CONFIGURATION FAULT OVERRIDE SCREEN ──────────────────────────
class FirebaseErrorScreen extends StatelessWidget {
  const FirebaseErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.cardBorderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.cyberCyan.withOpacity(0.04),
                  blurRadius: 30,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off,
                  color: AppTheme.cyberCyan,
                  size: 54,
                ),
                const SizedBox(height: 24),
                Text(
                  'FIREBASE NOT CALIBRATED',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This device requires an active Firebase Google Service profile key to sync data in the cloud.\n\nPlease place your google-services.json (Android) or GoogleService-Info.plist (iOS) configuration files in their respective folders, or use our Unit Test Suit to run local code checks.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(color: AppTheme.cardBorderColor),
                const SizedBox(height: 16),
                Text(
                  'DEVELOPER QUICK RUN CHECK:',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.amethystPurple,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'flutter test test/features/onboarding/auth_provider_test.dart',
                    style: GoogleFonts.firaCode(
                      fontSize: 10,
                      color: AppTheme.cyberCyan,
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
