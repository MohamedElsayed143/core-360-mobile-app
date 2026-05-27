import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:core_360_app/core/theme/app_theme.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _pulseController;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _fingerprintEnabled = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _checkBiometrics();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    try {
      final savedEnabled = await _secureStorage.read(key: 'fingerprint_enabled');
      final email = await _secureStorage.read(key: 'saved_email');
      final password = await _secureStorage.read(key: 'saved_password');
      if (savedEnabled == 'true' && email != null && password != null) {
        setState(() {
          _fingerprintEnabled = true;
        });
      } else {
        setState(() {
          _fingerprintEnabled = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _authenticateWithBiometrics() async {
    final enabled = await _secureStorage.read(key: 'fingerprint_enabled');
    final email = await _secureStorage.read(key: 'saved_email');
    final password = await _secureStorage.read(key: 'saved_password');
    if (!mounted) return;
    if (enabled != 'true' || email == null || password == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'BIOMETRICS NOT CONFIGURED. PLEASE SIGN IN MANUALLY.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.amethystPurple,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan fingerprint to authenticate secure access to Core-360',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        ref.read(authProvider.notifier).signIn(email, password);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'BIOMETRIC AUTHENTICATION FAILED: $e',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text;
      final password = _passwordController.text;
      ref.read(authProvider.notifier).signIn(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // If an error is caught, show a custom snackbar once and clear it
    ref.listen(authProvider, (previous, next) {
      if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    next.message,
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'DISMISS',
              textColor: Colors.white,
              onPressed: () {
                ref.read(authProvider.notifier).clearError();
              },
            ),
          ),
        );
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // ─── AMBIENT BACKGROUND GLOW ─────────────────────────────────────
          Positioned(
            top: -150,
            left: -150,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 450,
                  height: 450,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.amethystPurple.withValues(alpha: 0.12 + (_pulseController.value * 0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.amethystPurple.withValues(alpha: 0.08),
                        blurRadius: 150,
                        spreadRadius: 80,
                      )
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: -150,
            right: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cyberCyan.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.cyberCyan.withValues(alpha: 0.06),
                    blurRadius: 180,
                    spreadRadius: 80,
                  )
                ],
              ),
            ),
          ),

          // ─── SCROLLABLE FORM LAYOUT ──────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      
                      // ─── PREMIUM CYBER LOGO MARK ───────────────────────────
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.darkSurface,
                            border: Border.all(color: AppTheme.cardBorderColor, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.cyberCyan.withValues(alpha: 0.12),
                                blurRadius: 30,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: ShaderMask(
                            shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                            child: const Icon(
                              Icons.all_inclusive,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── HEADER TYPOGRAPHY ───────────────────────────────
                      Center(
                        child: Text(
                          'CORE-360',
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'NEURAL PERFORMANCE COACHING',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: AppTheme.cyberCyan,
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),

                      // ─── EMAIL INPUT ─────────────────────────────────────
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.outfit(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.mail_outline, color: Colors.white70),
                          hintText: 'name@example.com',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // ─── PASSWORD INPUT ──────────────────────────────────
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: GoogleFonts.outfit(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.white60,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // ─── LOGIN SUBMIT CTA & FACE ID ROW ────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: AppTheme.primaryGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.cyberCyan.withValues(alpha: 0.3),
                                    blurRadius: 18,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: authState is AuthLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'SIGN IN',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_fingerprintEnabled) ...[
                            const SizedBox(width: 12),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppTheme.darkSurface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.cyberCyan.withValues(alpha: 0.8),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.cyberCyan.withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    spreadRadius: 1,
                                  ),
                                  BoxShadow(
                                    color: AppTheme.amethystPurple.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: ShaderMask(
                                  shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                                  child: const Icon(
                                    Icons.fingerprint,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                tooltip: 'Biometric Fingerprint Quick Sign In',
                                onPressed: authState is AuthLoading ? null : _authenticateWithBiometrics,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ─── SIGN UP REDIRECT LINK ───────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "New to the arena? ",
                            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => const RegisterScreen(),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                ),
                              );
                            },
                            child: Text(
                              "Create Account",
                              style: GoogleFonts.outfit(
                                color: AppTheme.cyberCyan,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── GLASSMORPHIC ACTION HUD LOADER ──────────────────────────────
          if (authState is AuthLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.cardBorderColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.cyberCyan.withValues(alpha: 0.1),
                        blurRadius: 40,
                      )
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyberCyan),
                        strokeWidth: 3.5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
