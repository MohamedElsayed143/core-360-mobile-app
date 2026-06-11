import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _logoController;

  // ─── BIOMETRIC STATE ─────────────────────────────────────────────────
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _hasBiometricToken = false;
  bool _isBioAuthenticating = false;
  bool _canCheckBiometrics = false;
  bool _fingerprintEnabled = false;
  ProviderSubscription<AuthState>? _authSubscription;

  // ── Cached credentials so the first biometric tap is instant ─────────
  String? _cachedEmail;
  String? _cachedPassword;

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

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      next.message,
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontWeight: FontWeight.w500),
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
    _logoController.dispose();
    super.dispose();
  }

  // ─── BIOMETRIC TOKEN DETECTION ───────────────────────────────────────
  // Reads and CACHES credentials here so _authenticateWithBiometrics
  // can fire the scanner immediately on the first tap (no async reads).
  Future<void> _checkBiometricToken() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!mounted) return;
      setState(() {
        _canCheckBiometrics = canCheck && isSupported;
      });
      if (!canCheck || !isSupported) return;

      final savedEnabled = await _secureStorage.read(key: 'fingerprint_enabled');
      final email = await _secureStorage.read(key: 'saved_email');
      final password = await _secureStorage.read(key: 'saved_password');

      if (!mounted) return;

      if (savedEnabled == 'true' &&
          email != null &&
          email.trim().isNotEmpty &&
          password != null &&
          password.trim().isNotEmpty) {
        // ── Cache here so the tap handler has zero async overhead ──────
        _cachedEmail = email.trim();
        _cachedPassword = password;

        setState(() {
          _hasBiometricToken = true;
          _fingerprintEnabled = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _authenticateWithBiometrics();
        });
      } else {
        _cachedEmail = null;
        _cachedPassword = null;
        setState(() {
          _hasBiometricToken = false;
          _fingerprintEnabled = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error checking biometric token: $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<bool> _performBiometricScan() async {
    return await _localAuth.authenticate(
      localizedReason:
          'Scan fingerprint to authenticate secure access to Core-360',
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
      _cachedEmail = null;
      _cachedPassword = null;
      setState(() {
        _fingerprintEnabled = false;
        _hasBiometricToken = false;
      });
      return;
    }

    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      setState(() {
        _fingerprintEnabled = false;
      });
      return;
    }

    if (!_canCheckBiometrics) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'BIOMETRICS NOT AVAILABLE ON THIS DEVICE.',
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

    final emailEntered = _emailController.text.trim();
    if (_hasBiometricToken &&
        _cachedEmail != null &&
        _cachedEmail!.trim().toLowerCase() != emailEntered.toLowerCase()) {
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
      final success = await _authenticateBiometrics();
      if (!mounted) return;
      if (success) {
        final email = _emailController.text;
        final password = _passwordController.text;

        // ── Persist and cache simultaneously ──────────────────────────
        await _secureStorage.write(key: 'saved_email', value: email.trim());
        await _secureStorage.write(key: 'saved_password', value: password);
        await _secureStorage.write(
            key: 'fingerprint_enabled', value: 'true');
        _cachedEmail = email.trim();
        _cachedPassword = password;

        setState(() {
          _fingerprintEnabled = true;
        });

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

  // ─── FAST BIOMETRIC LOGIN ─────────────────────────────────────────────
  // Uses in-memory cached credentials — no storage reads on the hot path,
  // so the scanner sheet opens on the very first frame after the tap.
  Future<void> _authenticateWithBiometrics() async {
    if (_isBioAuthenticating) return;

    // Fast-path: use cached values if available
    final email = _cachedEmail;
    final password = _cachedPassword;

    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      // Cache miss — fall back to storage reads (first-install edge case)
      try {
        final enabled = await _secureStorage.read(key: 'fingerprint_enabled');
        final storedEmail = await _secureStorage.read(key: 'saved_email');
        final storedPassword =
            await _secureStorage.read(key: 'saved_password');

        if (!mounted) return;

        if (enabled != 'true' ||
            storedEmail == null ||
            storedEmail.trim().isEmpty ||
            storedPassword == null ||
            storedPassword.trim().isEmpty) {
          _showBiometricSnackBar(
            'BIOMETRIC CREDENTIALS NOT CONFIGURED OR EXPIRED. PLEASE SIGN IN MANUALLY.',
            const Color(0xFF22c55e),
          );
          setState(() {
            _hasBiometricToken = false;
            _fingerprintEnabled = false;
          });
          return;
        }

        _cachedEmail = storedEmail.trim();
        _cachedPassword = storedPassword;
      } catch (e) {
        debugPrint('Biometric credential read failed: $e');
        return;
      }
    }

    setState(() => _isBioAuthenticating = true);

    try {
      final authenticated = await _performBiometricScan();

      if (!mounted) return;

      if (authenticated) {
        // Re-confirm cache is still valid after the scan
        final postEmail = _cachedEmail;
        final postPassword = _cachedPassword;

        if (postEmail == null ||
            postEmail.isEmpty ||
            postPassword == null ||
            postPassword.isEmpty) {
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

        ref.read(authProvider.notifier).signInWithBiometrics(
              postEmail,
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

        bool hasAuthenticated = false;
        for (int attempt = 0; attempt < 20; attempt++) {
          final authState = ref.read(authProvider);
          if (authState is AuthenticatedWithProfile ||
              authState is AuthenticatedWithoutProfile) {
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
          return;
        }

        final finalState = ref.read(authProvider);
        if (finalState is AuthenticatedWithProfile ||
            finalState is AuthenticatedWithoutProfile) {
          if (_fingerprintEnabled) {
            await _secureStorage.write(
                key: 'saved_email', value: email.trim());
            await _secureStorage.write(key: 'saved_password', value: password);
            await _secureStorage.write(
                key: 'fingerprint_enabled', value: 'true');
            _cachedEmail = email.trim();
            _cachedPassword = password;
          } else {
            await _secureStorage.delete(key: 'saved_email');
            await _secureStorage.delete(key: 'saved_password');
            await _secureStorage.write(
                key: 'fingerprint_enabled', value: 'false');
            _cachedEmail = null;
            _cachedPassword = null;
          }
        }
      } catch (e, stack) {
        debugPrint('Error during login submission: $e');
        debugPrintStack(stackTrace: stack);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF121824), Color(0xFF1a1224)],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF252d3a).withValues(alpha: 0.87),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFF3d4d6b), width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1e3a5f)
                              .withValues(alpha: 0.25),
                          blurRadius: 60,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 40),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Logo ───────────────────────────────────────
                          _buildLogo(),
                          const SizedBox(height: 32),
                          Text(
                            'Welcome back',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ── Email ──────────────────────────────────────
                          Text(
                            'Email address',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFe2e8f0),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: GoogleFonts.outfit(
                                color: Colors.white, fontSize: 14),
                            decoration:
                                _inputDecoration('you@example.com'),
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

                          // ── Password ───────────────────────────────────
                          Text(
                            'Password',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFe2e8f0),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: GoogleFonts.outfit(
                                color: Colors.white, fontSize: 14),
                            decoration: _inputDecoration(
                              '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF94a3b8),
                                ),
                                onPressed: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
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

                          // ── Primary Sign In Button ─────────────────────
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ElevatedButton(
                              onPressed:
                                  authState is AuthLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Sign In',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),

                          // ── Biometric section (toggle + quick-login) ───
                          // Rendered together below the primary button so
                          // the fingerprint controls are spatially grouped
                          // and well away from the password field.
                          if (_canCheckBiometrics) ...[
                            const SizedBox(height: 20),

                            // OR divider
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: const Color(0xFF3d4a5e)
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'OR',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.6,
                                    color: const Color(0xFF3d4a5e),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: const Color(0xFF3d4a5e)
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // ── Fingerprint Quick-Login Button ─────────
                            // Always shown when biometrics are available;
                            // visually disabled until a token is stored.
                            AnimatedBuilder(
                              animation: _glowAnimation,
                              builder: (context, child) {
                                final g = _hasBiometricToken && _fingerprintEnabled
                                    ? _glowAnimation.value
                                    : 0.0;
                                final isActive =
                                    _hasBiometricToken && _fingerprintEnabled;
                                return GestureDetector(
                                  onTap: (authState is AuthLoading ||
                                          !isActive)
                                      ? null
                                      : _authenticateWithBiometrics,
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 300),
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? const Color(0xFF1a2533)
                                          : const Color(0xFF1e2733),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isActive
                                            ? Color.lerp(
                                                const Color(0xFF22c55e)
                                                    .withValues(alpha: 0.4),
                                                const Color(0xFF22c55e),
                                                g,
                                              )!
                                            : const Color(0xFF3d4a5e)
                                                .withValues(alpha: 0.3),
                                        width: isActive
                                            ? 1.0 + (g * 0.5)
                                            : 0.5,
                                      ),
                                      boxShadow: isActive
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF22c55e)
                                                    .withValues(
                                                        alpha: 0.10 +
                                                            g * 0.12),
                                                blurRadius: 12 + g * 8,
                                                spreadRadius: g,
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: _isBioAuthenticating
                                        ? const Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                            Color>(
                                                        Color(0xFF22c55e)),
                                                strokeWidth: 2.0,
                                              ),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.fingerprint,
                                                color: isActive
                                                    ? Color.lerp(
                                                        const Color(
                                                            0xFF22c55e),
                                                        Colors.white,
                                                        g * 0.25,
                                                      )!
                                                    : const Color(
                                                        0xFF4a5568),
                                                size: 22,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                'SIGN IN WITH FINGERPRINT',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  color: isActive
                                                      ? Color.lerp(
                                                          const Color(
                                                              0xFF22c55e),
                                                          Colors.white,
                                                          g * 0.25,
                                                        )!
                                                      : const Color(
                                                          0xFF4a5568),
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // ── Enable Fingerprint Toggle ──────────────
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF323b49),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _fingerprintEnabled
                                      ? const Color(0xFF22c55e)
                                      : const Color(0xFF3d4a5e)
                                          .withValues(alpha: 0.5),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.fingerprint,
                                    color: _fingerprintEnabled
                                        ? const Color(0xFF22c55e)
                                        : const Color(0xFF94a3b8),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Enable Fingerprint Quick Login',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          'Secure, instant bio-identity setup',
                                          style: GoogleFonts.outfit(
                                            color:
                                                const Color(0xFF94a3b8),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _fingerprintEnabled,
                                    activeThumbColor:
                                        const Color(0xFF22c55e),
                                    activeTrackColor: const Color(0xFF22c55e)
                                        .withValues(alpha: 0.3),
                                    inactiveThumbColor:
                                        const Color(0xFF94a3b8),
                                    inactiveTrackColor:
                                        const Color(0xFF1e293b),
                                    onChanged: _handleFingerprintToggle,
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // ── Sign Up Link ───────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF94a3b8),
                                  fontSize: 13,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const RegisterScreen()),
                                  ).then((_) {
                                    _checkBiometricToken();
                                  });
                                },
                                child: Text(
                                  'Sign up',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFe2e8f0),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Global loading overlay ─────────────────────────────────
            if (authState is AuthLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252d3a),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFF3d4d6b), width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF22c55e)
                              .withValues(alpha: 0.1),
                          blurRadius: 40,
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF22c55e)),
                          strokeWidth: 3.0,
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
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF323b49),
      hintText: hint,
      hintStyle:
          GoogleFonts.outfit(color: const Color(0xFF94a3b8), fontSize: 14),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
            color: const Color(0xFF3d4a5e).withValues(alpha: 0.5),
            width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
            color: const Color(0xFF3d4a5e).withValues(alpha: 0.5),
            width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: Color(0xFF22c55e), width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: Colors.redAccent, width: 1),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: FadeTransition(
        opacity: _logoController,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CORE 360',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'AI FORM GUARD™',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: const Color(0xFF22c55e),
              ),
            ),
          ],
        ),
      ),
    );
  }
}