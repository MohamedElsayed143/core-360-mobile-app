import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:core_360_app/core/theme/app_theme.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:email_validator/email_validator.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _pulseController;

  // ─── BIOMETRIC STATE ─────────────────────────────────────────────────
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _hasBiometricToken = false;
  bool _isBioAuthenticating = false;
  bool _canCheckBiometrics = false;
  bool _fingerprintEnabled = false;
  ProviderSubscription<AuthState>? _authSubscription;

  /// Dedicated glow animation controller for the biometric button neon pulse
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _authSubscription = ref.listenManual<AuthState>(
      authProvider,
      (previous, next) {
        if (_isBioAuthenticating && next is! AuthLoading) {
          setState(() => _isBioAuthenticating = false);
        }

        if (next is AuthError) {
          if (!mounted) return;
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
      },
    );

    _checkBiometricToken();
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _emailController.dispose();
    _passwordController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // ─── BIOMETRIC TOKEN DETECTION ───────────────────────────────────────
  /// Reads from flutter_secure_storage to check if a valid biometric
  /// credentials token exists on this device, AND verifies the hardware
  /// actually supports biometrics.
  Future<void> _checkBiometricToken() async {
    try {
      // 1. Verify device biometric hardware capability
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!mounted) return;
      setState(() {
        _canCheckBiometrics = canCheck && isSupported;
      });
      if (!canCheck || !isSupported) return;

      // ─── SECURITY REVIEW: LOCAL PASSWORD STORAGE WARNING ────────────────
      // NOTE: Storing raw passwords in FlutterSecureStorage is a temporary solution
      // for offline/local biometric bypass. A secure token/session-based
      // biometric authentication strategy should be implemented long-term.
      // ────────────────────────────────────────────────────────────────────

      // 2. Read the cached credentials token from secure storage
      final savedEnabled = await _secureStorage.read(key: 'fingerprint_enabled');
      final email = await _secureStorage.read(key: 'saved_email');
      final password = await _secureStorage.read(key: 'saved_password');

      if (!mounted) return;

      if (savedEnabled == 'true' &&
          email != null &&
          email.trim().isNotEmpty &&
          password != null &&
          password.trim().isNotEmpty) {
        setState(() {
          _hasBiometricToken = true;
          _fingerprintEnabled = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _authenticateWithBiometrics();
        });
      } else {
        setState(() {
          _hasBiometricToken = false;
          _fingerprintEnabled = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error checking biometric token: $e');
      debugPrintStack(stackTrace: stack);
      // Silently degrade — biometric button simply won't appear
    }
  }

  Future<bool> _performBiometricScan() async {
    return await _localAuth.authenticate(
      localizedReason: 'Scan fingerprint to authenticate secure access to Core-360',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
  }

  Future<bool> _authenticateBiometrics() async {
    try {
      return await _performBiometricScan();
    } catch (e, stack) {
      debugPrint('Biometric authentication failed: $e');
      debugPrintStack(stackTrace: stack);
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
      try {
        await _secureStorage.delete(key: 'saved_email');
        await _secureStorage.delete(key: 'saved_password');
        await _secureStorage.write(key: 'fingerprint_enabled', value: 'false');
      } catch (e, stack) {
        debugPrint('Error clearing biometric credentials: $e');
        debugPrintStack(stackTrace: stack);
      }
      if (!mounted) return;
      setState(() {
        _fingerprintEnabled = false;
        _hasBiometricToken = false;
      });
      return;
    }

    // ─── VALIDATE EMAIL AND PASSWORD FIRST ──────────────────────────────
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
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

      final success = await _authenticateBiometrics();
      if (!mounted) return;
      if (success) {
        setState(() {
          _fingerprintEnabled = true;
        });

        // ─── SECURITY REVIEW: LOCAL PASSWORD STORAGE WARNING ────────────────
        // NOTE: Storing raw passwords in FlutterSecureStorage is a temporary solution
        // for offline/local biometric bypass. A secure token/session-based
        // biometric authentication strategy should be implemented long-term.
        // ────────────────────────────────────────────────────────────────────
        // Save credentials immediately
        final email = _emailController.text;
        final password = _passwordController.text;
        await _secureStorage.write(key: 'saved_email', value: email.trim());
        await _secureStorage.write(key: 'saved_password', value: password);
        await _secureStorage.write(key: 'fingerprint_enabled', value: 'true');

        // Submit the form immediately to log in and open the dashboard
        await _submit();
      } else {
        setState(() {
          _fingerprintEnabled = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Biometric toggle error: $e');
      debugPrintStack(stackTrace: stack);
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

  // ─── BIOMETRIC AUTHENTICATION HANDLER ────────────────────────────────
  /// Invokes local_auth to scan face/fingerprint. On success, authenticates
  /// via the cached secure credentials and routes to Home Dashboard.
  Future<void> _authenticateWithBiometrics() async {
    if (_isBioAuthenticating) return;

    try {
      // Re-read credentials in case storage was cleared since initState
      final enabled = await _secureStorage.read(key: 'fingerprint_enabled');
      final email = await _secureStorage.read(key: 'saved_email');
      final password = await _secureStorage.read(key: 'saved_password');

      if (!mounted) return;

      // ── Validate cached credentials are present AND non-blank ──────
      if (enabled != 'true' ||
          email == null ||
          email.trim().isEmpty ||
          password == null ||
          password.trim().isEmpty) {
        _showBiometricSnackBar(
          'BIOMETRIC CREDENTIALS NOT CONFIGURED OR EXPIRED. PLEASE SIGN IN MANUALLY.',
          AppTheme.amethystPurple,
        );
        setState(() {
          _hasBiometricToken = false;
          _fingerprintEnabled = false;
        });
        return;
      }

      setState(() => _isBioAuthenticating = true);

      final authenticated = await _performBiometricScan();

      if (!mounted) return;

      if (authenticated) {
        // ── Post-scan re-validation ──────────────────────────────────
        // Credentials could have been cleared by another screen between
        // the initial read and the biometric scan completion.
        final postEmail = await _secureStorage.read(key: 'saved_email');
        final postPassword = await _secureStorage.read(key: 'saved_password');
        if (!mounted) return;

        if (postEmail == null ||
            postEmail.trim().isEmpty ||
            postPassword == null ||
            postPassword.trim().isEmpty) {
          setState(() {
            _isBioAuthenticating = false;
            _hasBiometricToken = false;
            _fingerprintEnabled = false;
          });
          _showBiometricSnackBar(
            'BIOMETRIC CREDENTIALS WERE INVALIDATED. PLEASE SIGN IN MANUALLY.',
            Colors.redAccent,
          );
          return;
        }

        // Immediately authenticate via cached credentials
        ref.read(authProvider.notifier).signInWithBiometrics(
          postEmail.trim(),
          postPassword,
        );
      } else {
        setState(() => _isBioAuthenticating = false);
      }
    } on PlatformException catch (e, stack) {
      debugPrint('PlatformException during biometric authentication: $e');
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      setState(() => _isBioAuthenticating = false);
      _showBiometricSnackBar(
        'BIOMETRIC ERROR: ${e.message ?? e.code}',
        Colors.redAccent,
      );
    } catch (e, stack) {
      debugPrint('Exception during biometric authentication: $e');
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      setState(() => _isBioAuthenticating = false);
      _showBiometricSnackBar(
        'BIOMETRIC AUTHENTICATION FAILED: $e',
        Colors.redAccent,
      );
    }
  }

  void _showBiometricSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text;
      final password = _passwordController.text;
      try {
        await ref.read(authProvider.notifier).signIn(email, password);

        // Wait until Firebase auth actually reports an authenticated user.
        bool hasAuthenticated = false;
        for (int attempt = 0; attempt < 20; attempt++) {
          final authState = ref.read(authProvider);
          if (authState is AuthenticatedWithProfile || authState is AuthenticatedWithoutProfile) {
            hasAuthenticated = true;
            break;
          }
          await Future.delayed(const Duration(milliseconds: 200));
        }

        if (!hasAuthenticated) {
          if (mounted) {
            setState(() {
              _isBioAuthenticating = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'AUTHENTICATION TIMEOUT. PLEASE TRY AGAIN.',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
          return;
        }

        final finalState = ref.read(authProvider);
        if (finalState is AuthenticatedWithProfile || finalState is AuthenticatedWithoutProfile) {
          if (_fingerprintEnabled) {
            // ─── SECURITY REVIEW: LOCAL PASSWORD STORAGE WARNING ────────────────
            // NOTE: Storing raw passwords in FlutterSecureStorage is a temporary solution
            // for offline/local biometric bypass. A secure token/session-based
            // biometric authentication strategy should be implemented long-term.
            // ────────────────────────────────────────────────────────────────────
            await _secureStorage.write(key: 'saved_email', value: email.trim());
            await _secureStorage.write(key: 'saved_password', value: password);
            await _secureStorage.write(key: 'fingerprint_enabled', value: 'true');
          } else {
            await _secureStorage.delete(key: 'saved_email');
            await _secureStorage.delete(key: 'saved_password');
            await _secureStorage.write(key: 'fingerprint_enabled', value: 'false');
          }
        }
      } catch (e, stack) {
        debugPrint('Error during login submission: $e');
        debugPrintStack(stackTrace: stack);
      }
    }
  }

  // ─── BIOMETRIC BUTTON WIDGET ─────────────────────────────────────────
  /// Premium glowing neon biometric icon button with pulsing ring animation.
  Widget _buildBiometricButton(bool isLoading) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final glowIntensity = _glowAnimation.value;

        return GestureDetector(
          onTap: isLoading ? null : _authenticateWithBiometrics,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Color.lerp(
                  AppTheme.cyberCyan.withValues(alpha: 0.5),
                  AppTheme.cyberCyan,
                  glowIntensity,
                )!,
                width: 1.5 + (glowIntensity * 0.5),
              ),
              boxShadow: [
                // Primary neon cyan glow
                BoxShadow(
                  color: AppTheme.cyberCyan.withValues(alpha: 0.15 + (glowIntensity * 0.30)),
                  blurRadius: 14 + (glowIntensity * 10),
                  spreadRadius: glowIntensity * 3,
                ),
                // Secondary purple accent glow
                BoxShadow(
                  color: AppTheme.amethystPurple.withValues(alpha: 0.08 + (glowIntensity * 0.12)),
                  blurRadius: 10 + (glowIntensity * 6),
                  spreadRadius: -1,
                ),
              ],
            ),
            child: _isBioAuthenticating
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyberCyan),
                      strokeWidth: 2.5,
                    ),
                  )
                : ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        Color.lerp(AppTheme.cyberCyan, Colors.white, glowIntensity * 0.3)!,
                        Color.lerp(AppTheme.electricBlue, AppTheme.cyberCyan, glowIntensity)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.fingerprint,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Auth notifier state changes are handled out of build via _authSubscription in initState.

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
                          if (!EmailValidator.validate(value.trim())) {
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
                      const SizedBox(height: 24),

                      // ─── LOGIN SUBMIT CTA & BIOMETRIC BUTTON ROW ────────
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

                          // ─── GLOWING NEON BIOMETRIC BUTTON ─────────────────
                          if (_hasBiometricToken && _fingerprintEnabled) ...[
                            const SizedBox(width: 12),
                            _buildBiometricButton(authState is AuthLoading),
                          ],
                        ],
                      ),

                      // ─── BIOMETRIC HINT LABEL ──────────────────────────────
                      if (_hasBiometricToken && _fingerprintEnabled) ...[
                        const SizedBox(height: 14),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 28,
                                height: 1,
                                color: AppTheme.cardBorderColor,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'OR TAP BIOMETRIC',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.6,
                                  color: AppTheme.cyberCyan.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 28,
                                height: 1,
                                color: AppTheme.cardBorderColor,
                              ),
                            ],
                          ),
                        ),
                      ],
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
                              ).then((_) {
                                _checkBiometricToken();
                              });
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyberCyan),
                        strokeWidth: 3.5,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Signing in...',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
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
