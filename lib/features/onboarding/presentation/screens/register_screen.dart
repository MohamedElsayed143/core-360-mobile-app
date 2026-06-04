import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:core_360_app/core/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late AnimationController _pulseController;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _fingerprintEnabled = false;
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      setState(() {
        _canCheckBiometrics = canCheck && isSupported;
      });
    } catch (_) {}
  }

  Future<bool> _authenticateBiometrics() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan fingerprint to authenticate secure access to Core-360',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return authenticated;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'BIOMETRIC INITIALIZATION FAILED: $e',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

  Future<void> _handleFingerprintToggle(bool val) async {
    if (!val) {
      setState(() {
        _fingerprintEnabled = false;
      });
      return;
    }

    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!mounted) return;
      if (!canCheck || !isSupported) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'BIOMETRICS NOT AVAILABLE ON THIS DEVICE.',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppTheme.amethystPurple,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _fingerprintEnabled = false;
        });
        return;
      }

      // ── DUPLICATE BIOMETRIC IDENTITY PRE-CHECK ──────────────────────
      // If biometric credentials are already bound to an account on this device,
      // fail with an error and reject the enrollment.
      final existingEnabled = await _secureStorage.read(key: 'fingerprint_enabled');
      if (!mounted) return;

      if (existingEnabled == 'true') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'FINGERPRINT REGISTRATION REJECTED: Fingerprint already registered on this device.',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _fingerprintEnabled = false;
        });
        return;
      }

      final success = await _authenticateBiometrics();
      if (!mounted) return;
      if (success) {
        setState(() {
          _fingerprintEnabled = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'BIOMETRIC SCAN SUCCEEDED. FINGERPRINT ENROLLED FOR SIGN-UP.',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black),
            ),
            backgroundColor: AppTheme.cyberCyan,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _fingerprintEnabled = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'BIOMETRIC AUTHENTICATION ERROR: $e',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _fingerprintEnabled = false;
      });
    }
  }

  // Conflict dialog is deprecated as overrides are no longer permitted.

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Double check if fingerprint is enabled but already registered
    final existingEnabled = await _secureStorage.read(key: 'fingerprint_enabled');
    if (_fingerprintEnabled && existingEnabled == 'true') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'FINGERPRINT REGISTRATION REJECTED: Fingerprint already registered on this device.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _fingerprintEnabled = false;
      });
      return;
    }

    try {
      await ref.read(authProvider.notifier).signUp(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text,
        fingerprintEnabled: _fingerprintEnabled,
      );

      final authState = ref.read(authProvider);
      if (authState is AuthError) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ACCOUNT CREATED SUCCESSFULLY! PLEASE SIGN IN.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black),
          ),
          backgroundColor: AppTheme.cyberCyan,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (_) {}
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
            right: -150,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 450,
                  height: 450,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.cyberCyan.withValues(alpha: 0.08 + (_pulseController.value * 0.04)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.cyberCyan.withValues(alpha: 0.06),
                        blurRadius: 160,
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
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.amethystPurple.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.amethystPurple.withValues(alpha: 0.08),
                    blurRadius: 180,
                    spreadRadius: 80,
                  )
                ],
              ),
            ),
          ),

          // ─── SCROLLABLE REGISTER FORM ────────────────────────────────────
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
                      
                      // ─── STAGE HEADING ─────────────────────────────────────
                      Text(
                        'Join the Arena',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'CREATE YOUR CORE-360 BIO-IDENTITY',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: AppTheme.amethystPurple,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // ─── NAME INPUT ──────────────────────────────────────
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.outfit(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline, color: Colors.white70),
                          hintText: 'John Doe',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your full name';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

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
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // ─── CONFIRM PASSWORD INPUT ──────────────────────────
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: GoogleFonts.outfit(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_reset, color: Colors.white70),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.white60,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      if (_canCheckBiometrics) ...[
                        const SizedBox(height: 20),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.darkSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _fingerprintEnabled 
                                  ? AppTheme.cyberCyan.withValues(alpha: 0.8) 
                                  : AppTheme.cardBorderColor, 
                              width: 1.5,
                            ),
                            boxShadow: [
                              if (_fingerprintEnabled)
                                BoxShadow(
                                  color: AppTheme.cyberCyan.withValues(alpha: 0.15),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) => (_fingerprintEnabled 
                                            ? AppTheme.primaryGradient 
                                            : const LinearGradient(colors: [Colors.white54, Colors.white54]))
                                        .createShader(bounds),
                                    child: Icon(
                                      Icons.fingerprint,
                                      color: _fingerprintEnabled ? Colors.white : Colors.white54,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Enable Fingerprint Quick Login',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        'Secure, instant bio-identity setup',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch(
                                value: _fingerprintEnabled,
                                activeThumbColor: AppTheme.cyberCyan,
                                activeTrackColor: AppTheme.cyberCyan.withValues(alpha: 0.3),
                                inactiveThumbColor: Colors.white30,
                                inactiveTrackColor: Colors.black26,
                                onChanged: _handleFingerprintToggle,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 36),

                      // ─── REGISTER SUBMIT CTA ─────────────────────────────
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: AppTheme.secondaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.amethystPurple.withValues(alpha: 0.3),
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
                            'CREATE ACCOUNT',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── LOGIN REDIRECT LINK ─────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already registered? ",
                            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              "Sign In Instead",
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

          // ─── ACTION HUD LOADER ───────────────────────────────────────────
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
                        color: AppTheme.amethystPurple.withValues(alpha: 0.1),
                        blurRadius: 40,
                      )
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.amethystPurple),
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
