import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:email_validator/email_validator.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _fingerprintEnabled = false;
  bool _canCheckBiometrics = false;
  bool _existingFingerprintEnabled = false;
  String? _savedEmailOnDevice;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      final existingEnabled = await _secureStorage.read(key: 'fingerprint_enabled');
      final savedEmail = await _secureStorage.read(key: 'saved_email');
      setState(() {
        _canCheckBiometrics = canCheck && isSupported;
        _existingFingerprintEnabled = (existingEnabled == 'true');
        _savedEmailOnDevice = savedEmail;
      });
    } catch (_) {}
  }

  Future<bool> _authenticateBiometrics() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verify fingerprint to enable quick login for Core-360',
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

  // عند تغيير حالة الـ Switch، نطلب المصادقة فوراً إذا كان المستخدم يريد التفعيل
  Future<void> _handleFingerprintToggle(bool newValue) async {
    if (!newValue) {
      // إيقاف البصمة - مباشر بدون مصادقة
      setState(() {
        _fingerprintEnabled = false;
      });
      return;
    }

    // محاولة تفعيل البصمة
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
    if (_existingFingerprintEnabled &&
        _savedEmailOnDevice != null &&
        _savedEmailOnDevice!.trim().toLowerCase() != emailEntered.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'FINGERPRINT ALREADY REGISTERED FOR ANOTHER ACCOUNT ON THIS DEVICE.',
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

    // عرض مصادقة البصمة فوراً
    final success = await _authenticateBiometrics();
    if (!mounted) return;
    if (success) {
      setState(() {
        _fingerprintEnabled = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'FINGERPRINT ENABLED SUCCESSFULLY.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black),
          ),
          backgroundColor: const Color(0xFF22c55e),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _fingerprintEnabled = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'FINGERPRINT AUTHENTICATION FAILED. PLEASE TRY AGAIN.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final emailEntered = _emailController.text.trim();
    if (_fingerprintEnabled &&
        _existingFingerprintEnabled &&
        _savedEmailOnDevice != null &&
        _savedEmailOnDevice!.trim().toLowerCase() != emailEntered.toLowerCase()) {
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
          backgroundColor: const Color(0xFF22c55e),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

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
                    style: GoogleFonts.outfit(
                        color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'DISMISS',
              textColor: Colors.white,
              onPressed: () => ref.read(authProvider.notifier).clearError(),
            ),
          ),
        );
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF121824), Color(0xFF1a1224)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                decoration: BoxDecoration(
                  color: const Color(0xFF252d3a).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: const Color(0xFF3d4d6b), width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1e3a5f).withValues(alpha: 0.25),
                      blurRadius: 60,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 36),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 28),
                      Text(
                        'Create an account',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Join us and get started today',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: const Color(0xFF94a3b8),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Name field
                      Text(
                        'Full Name',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFe2e8f0),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.outfit(
                            color: Colors.white, fontSize: 14),
                        decoration: _inputDecoration('John Doe'),
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
                      const SizedBox(height: 18),
                      // Email field
                      Text(
                        'Email address',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFe2e8f0),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.outfit(
                            color: Colors.white, fontSize: 14),
                        decoration: _inputDecoration('you@example.com'),
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
                      const SizedBox(height: 18),
                      // Password field
                      Text(
                        'Password',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFe2e8f0),
                        ),
                      ),
                      const SizedBox(height: 6),
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
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
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
                      const SizedBox(height: 18),
                      // Confirm Password field
                      Text(
                        'Confirm Password',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFe2e8f0),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: GoogleFonts.outfit(
                            color: Colors.white, fontSize: 14),
                        decoration: _inputDecoration(
                          '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF94a3b8),
                            ),
                            onPressed: () => setState(
                                () => _obscureConfirmPassword = !_obscureConfirmPassword),
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
                      const SizedBox(height: 20),
                      // Fingerprint toggle section (redesigned for better spacing and single-tap)
                      if (_canCheckBiometrics) ...[
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF323b49),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _fingerprintEnabled 
                                  ? const Color(0xFF22c55e).withValues(alpha: 0.6)
                                  : const Color(0xFF3d4a5e).withValues(alpha: 0.5), 
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.fingerprint,
                                color: _fingerprintEnabled ? const Color(0xFF22c55e) : const Color(0xFF94a3b8),
                                size: 28,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Fingerprint Quick Login',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Enable biometric authentication for faster sign-in',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF94a3b8),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _fingerprintEnabled,
                                activeColor: const Color(0xFF22c55e),
                                activeTrackColor: const Color(0xFF22c55e).withValues(alpha: 0.3),
                                inactiveThumbColor: const Color(0xFF94a3b8),
                                inactiveTrackColor: const Color(0xFF1e293b),
                                onChanged: _handleFingerprintToggle,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Submit button
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: authState is AuthLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Sign Up',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF94a3b8),
                              fontSize: 13,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              'Sign in',
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
        borderRadius: BorderRadius.circular(10),
        borderSide:
            BorderSide(color: const Color(0xFF3d4a5e).withValues(alpha: 0.5), width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            BorderSide(color: const Color(0xFF3d4a5e).withValues(alpha: 0.5), width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF22c55e), width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'CORE 360',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 20,
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
    );
  }
}