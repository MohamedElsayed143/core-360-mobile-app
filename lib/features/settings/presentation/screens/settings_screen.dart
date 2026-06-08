import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../onboarding/domain/entities/user_profile.dart';
import '../../../onboarding/presentation/providers/auth_provider.dart';
import '../../../onboarding/presentation/screens/onboarding_survey_screen.dart';
import 'edit_fitness_profile_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // ─── Edit Profile ──────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  // ─── Change Password ──────────────────────────────────────────
  final _currentPwController = TextEditingController();
  final _newPwController = TextEditingController();
  final _confirmPwController = TextEditingController();

  // ─── Two-Factor Auth ──────────────────────────────────────────
  final _phoneController = TextEditingController();

  // ─── Danger Zone ──────────────────────────────────────────────
  final _deletePwController = TextEditingController();

  // ─── Expandable sections ──────────────────────────────────────
  bool _passwordExpanded = false;
  bool _twoFactorExpanded = false;
  bool _exportExpanded = false;

  // ─── Biometric Authentication ──────────────────────────────────
  IconData _biometricIcon = Icons.fingerprint;
  bool _biometricHardwareAvailable = false;

  String? _statusMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricType();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      if (authState is AuthenticatedWithProfile) {
        _nameController.text = authState.user.displayName ?? '';
        _emailController.text = authState.user.email ?? '';
      } else if (authState is AuthenticatedWithoutProfile) {
        _nameController.text = authState.user.displayName ?? '';
        _emailController.text = authState.user.email ?? '';
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPwController.dispose();
    _newPwController.dispose();
    _confirmPwController.dispose();
    _phoneController.dispose();
    _deletePwController.dispose();
    super.dispose();
  }

  void _setStatus(String? msg) {
    setState(() => _statusMessage = msg);
    if (msg != null) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _statusMessage = null);
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      final err = await ref.read(authProvider.notifier).updateDisplayName(name);
      if (err != null) { _setStatus(err); setState(() => _isLoading = false); return; }
    }
    _setStatus('Profile updated.');
    setState(() => _isLoading = false);
  }

  Future<void> _changePassword() async {
    final current = _currentPwController.text;
    final newPw = _newPwController.text;
    final confirm = _confirmPwController.text;
    if (newPw != confirm) { _setStatus('Passwords do not match.'); return; }
    if (newPw.length < 6) { _setStatus('Password must be at least 6 characters.'); return; }
    setState(() => _isLoading = true);
    final err = await ref.read(authProvider.notifier).changePassword(current, newPw);
    if (err != null) { _setStatus(err); } else {
      _setStatus('Password changed successfully.');
      _currentPwController.clear();
      _newPwController.clear();
      _confirmPwController.clear();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _enableTwoFactor() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) { _setStatus('Enter a phone number.'); return; }
    setState(() => _isLoading = true);
    final err = await ref.read(authProvider.notifier).enableTwoFactorAuth('+20$phone');
    if (err != null) { _setStatus(err); } else {
      _setStatus('Two-factor auth enabled.');
      _phoneController.clear();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _exportData() async {
    setState(() => _isLoading = true);
    final result = await ref.read(authProvider.notifier).exportUserData();
    if (result != null && !result.startsWith('{')) {
      _setStatus(result);
    } else {
      _showExportDialog(result ?? 'No data.');
    }
    setState(() => _isLoading = false);
  }

  void _showExportDialog(String data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Exported Data', style: GoogleFonts.outfit(color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              data,
              style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textSub),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.outfit(color: AppTheme.cyberCyan)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final pw = _deletePwController.text;
    if (pw.isEmpty) { _setStatus('Enter your password to confirm.'); return; }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Account?', style: GoogleFonts.outfit(color: AppTheme.crimsonRed, fontWeight: FontWeight.bold)),
        content: Text('This action cannot be undone. All your data will be permanently erased.', style: GoogleFonts.outfit(color: AppTheme.textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete Everything', style: GoogleFonts.outfit(color: AppTheme.crimsonRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    final err = await ref.read(authProvider.notifier).deleteAccount(pw);
    if (err != null) { _setStatus(err); setState(() => _isLoading = false); return; }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState is AuthenticatedWithProfile
        ? authState.user
        : authState is AuthenticatedWithoutProfile
            ? authState.user
            : null;
    final profile = authState is AuthenticatedWithProfile ? authState.profile : null;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textSub, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('SETTINGS', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppTheme.textWhite, fontSize: 16)),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── EDIT PROFILE ──────────────────────────────────────
                _buildSectionHeader('Edit Profile'),
                const SizedBox(height: 16),
                _buildProfilePhoto(user?.photoURL, base64Uri: profile?.photoURL),
                const SizedBox(height: 20),
                _buildLabel('Full Name'),
                const SizedBox(height: 6),
                _buildTextField(_nameController, 'Enter your name'),
                const SizedBox(height: 16),
                _buildLabel('Email Address'),
                const SizedBox(height: 6),
                _buildTextField(_emailController, 'Enter your email'),
                const SizedBox(height: 20),
                _buildButton('SAVE CHANGES', AppTheme.cyberCyan, _saveProfile),

                const SizedBox(height: 32),
                const Divider(color: AppTheme.cardBorderColor),
                const SizedBox(height: 16),

                // ─── SECURITY ──────────────────────────────────────────
                _buildSectionHeader('Security'),
                const SizedBox(height: 16),

                // Biometric Authentication
                _buildBiometricTile(),
                const SizedBox(height: 8),

                // Change Password
                _buildExpandableTile(
                  'Change Password',
                  _passwordExpanded,
                  () => setState(() => _passwordExpanded = !_passwordExpanded),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      _buildLabel('Current Password'),
                      const SizedBox(height: 6),
                      _buildTextField(_currentPwController, 'Enter current password', obscure: true),
                      const SizedBox(height: 12),
                      _buildLabel('New Password'),
                      const SizedBox(height: 6),
                      _buildTextField(_newPwController, 'Enter new password', obscure: true),
                      const SizedBox(height: 12),
                      _buildLabel('Confirm New Password'),
                      const SizedBox(height: 6),
                      _buildTextField(_confirmPwController, 'Confirm new password', obscure: true),
                      const SizedBox(height: 16),
                      _buildButton('CHANGE PASSWORD', AppTheme.cyberCyan, _changePassword),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Two-Factor Auth
                _buildExpandableTile(
                  'Two-Factor Auth',
                  _twoFactorExpanded,
                  () => setState(() => _twoFactorExpanded = !_twoFactorExpanded),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Text('Secure your account by linking your phone number.',
                          style: GoogleFonts.outfit(color: AppTheme.textSub, fontSize: 12)),
                      const SizedBox(height: 12),
                      Text('New Phone Number', style: GoogleFonts.outfit(color: AppTheme.textSub, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.darkSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.cardBorderColor),
                            ),
                            child: Row(
                              children: [
                                Text('🇪🇬', style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 4),
                                Text('+20', style: GoogleFonts.outfit(color: AppTheme.textWhite, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTextField(_phoneController, 'Local number'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildButton('ENABLE TWO-FACTOR AUTH', AppTheme.matrixGreen, _enableTwoFactor),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Export My Data
                _buildExpandableTile(
                  'Export My Data',
                  _exportExpanded,
                  () => setState(() => _exportExpanded = !_exportExpanded),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Text('Export all your data including:', style: GoogleFonts.outfit(color: AppTheme.textWhite, fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      _buildBullet('Profile information'),
                      _buildBullet('Workout sessions and history'),
                      _buildBullet('Analysis results and corrections'),
                      _buildBullet('Progress metrics'),
                      _buildBullet('Settings and preferences'),
                      const SizedBox(height: 16),
                      _buildButton('EXPORT MY DATA', AppTheme.safetyAmber, _exportData),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                const Divider(color: AppTheme.cardBorderColor),
                const SizedBox(height: 16),

                // ─── FITNESS PROFILE ───────────────────────────────────
                _buildSectionHeader('Fitness Profile'),
                const SizedBox(height: 16),
                ..._buildFitnessProfile(profile),

                const SizedBox(height: 32),
                const Divider(color: AppTheme.cardBorderColor),
                const SizedBox(height: 16),

                // ─── DANGER ZONE ───────────────────────────────────────
                _buildSectionHeader('Danger Zone', color: AppTheme.crimsonRed),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.crimsonRed.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppTheme.crimsonRed, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Warning: This action is irreversible.',
                              style: GoogleFonts.outfit(color: AppTheme.crimsonRed, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'All your personal information, workouts, session analysis, and progress data will be permanently erased.',
                        style: GoogleFonts.outfit(color: AppTheme.textSub, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Enter Password to Confirm'),
                      const SizedBox(height: 6),
                      _buildTextField(_deletePwController, 'Your password', obscure: true),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _deletePwController.clear(),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.cardBorderColor),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: Text('CANCEL', style: GoogleFonts.outfit(color: AppTheme.textSub, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildButton('DELETE ACCOUNT', AppTheme.crimsonRed, _deleteAccount),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // ─── Status message ───────────────────────────────────────
          if (_statusMessage != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _statusMessage!.contains('Error') || _statusMessage!.contains('Failed') ? AppTheme.crimsonRed : AppTheme.matrixGreen),
                ),
                child: Text(_statusMessage!, style: GoogleFonts.outfit(color: AppTheme.textWhite, fontSize: 12)),
              ),
            ),

          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator(color: AppTheme.cyberCyan)),
            ),
        ],
      ),
    );
  }

  // ─── BUILD HELPERS ─────────────────────────────────────────────

  Widget _buildSectionHeader(String title, {Color color = AppTheme.textWhite}) {
    return Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5));
  }

  Widget _buildLabel(String text) {
    return Text(text, style: GoogleFonts.outfit(color: AppTheme.textSub, fontSize: 12, fontWeight: FontWeight.w600));
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool obscure = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorderColor),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: GoogleFonts.outfit(color: AppTheme.textWhite, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 13),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildButton(String label, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 12, letterSpacing: 0.5)),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose Photo Source', style: GoogleFonts.outfit(color: AppTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, color: AppTheme.textWhite, size: 20),
                  label: Text('Gallery', style: GoogleFonts.outfit(color: AppTheme.textWhite, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.cardBorderColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, color: AppTheme.textWhite, size: 20),
                  label: Text('Camera', style: GoogleFonts.outfit(color: AppTheme.textWhite, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.cardBorderColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512);
    if (picked == null) return;
    setState(() => _isLoading = true);
    final err = await ref.read(authProvider.notifier).uploadProfilePhoto(picked.path);
    if (!mounted) return;
    if (err != null) {
      _setStatus(err);
    } else {
      _setStatus('Photo updated.');
    }
    setState(() => _isLoading = false);
  }

  Widget _buildProfilePhoto(String? photoUrl, {String? base64Uri}) {
    final effectiveUrl = base64Uri ?? photoUrl;
    final isDataUri = effectiveUrl?.startsWith('data:') ?? false;
    return Center(
      child: GestureDetector(
        onTap: _pickAndUploadPhoto,
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.darkSurface,
                border: Border.all(color: AppTheme.cyberCyan, width: 2),
              ),
              child: Stack(
                children: [
                  if (effectiveUrl != null && effectiveUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: isDataUri
                          ? Image.memory(
                              base64Decode(effectiveUrl.split(',').last),
                              fit: BoxFit.cover, width: 80, height: 80)
                          : Image.network(effectiveUrl, fit: BoxFit.cover, width: 80, height: 80),
                    )
                  else
                    const Center(child: Icon(Icons.person, color: AppTheme.cyberCyan, size: 36)),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.cyberCyan,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.black, size: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Tap to change photo',
                style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.matrixGreen, size: 14),
          const SizedBox(width: 8),
          Text(text, style: GoogleFonts.outfit(color: AppTheme.textSub, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildExpandableTile(String title, bool expanded, VoidCallback onToggle, Widget content) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorderColor),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: GoogleFonts.outfit(color: AppTheme.textWhite, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppTheme.textMuted, size: 20),
                ],
              ),
            ),
          ),
          if (expanded) Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: content,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFitnessProfile(UserProfile? profile) {
    if (profile == null) {
      return [
        Text('Complete the onboarding survey to set up your fitness profile.',
            style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 12),
        _buildButton('COMPLETE SURVEY', AppTheme.cyberCyan, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingSurveyScreen()));
        }),
      ];
    }
    return [
      _buildStatRow('Age', '${profile.age}'),
      _buildStatRow('Height', '${profile.height} cm'),
      _buildStatRow('Weight', '${profile.weight} kg'),
      if (profile.bodyFat != null) _buildStatRow('Body Fat', '${profile.bodyFat}%'),
      if (profile.muscleMass != null) _buildStatRow('Muscle Mass', '${profile.muscleMass}%'),
      if (profile.waterPercentage != null) _buildStatRow('Water %', '${profile.waterPercentage}%'),
      if (profile.goals.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: profile.goals.map((g) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.cyberCyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.3)),
            ),
            child: Text(g, style: GoogleFonts.outfit(color: AppTheme.cyberCyan, fontSize: 10, fontWeight: FontWeight.bold)),
          )).toList(),
        ),
      ],
      if (profile.injuries != null && profile.injuries!.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Injuries: ${profile.injuries}', style: GoogleFonts.outfit(color: AppTheme.safetyAmber, fontSize: 11)),
      ],
      const SizedBox(height: 12),
      _buildButton('EDIT FITNESS PROFILE', AppTheme.cyberCyan, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => EditFitnessProfileScreen(profile: profile)));
      }),
    ];
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(color: AppTheme.textSub, fontSize: 12)),
          Text(value, style: GoogleFonts.jetBrainsMono(color: AppTheme.cyberCyan, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _checkBiometricType() async {
    try {
      final localAuth = LocalAuthentication();
      final canCheck = await localAuth.canCheckBiometrics;
      final isSupported = await localAuth.isDeviceSupported();
      if (canCheck && isSupported) {
        final available = await localAuth.getAvailableBiometrics();
        if (available.contains(BiometricType.face)) {
          _biometricIcon = Icons.face;
        } else {
          _biometricIcon = Icons.fingerprint;
        }
        _biometricHardwareAvailable = true;
      } else {
        _biometricHardwareAvailable = false;
      }
    } catch (_) {
      _biometricHardwareAvailable = false;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleBiometricToggle(bool enable) async {
    if (!enable) {
      await _revokeBiometrics();
      return;
    }

    if (!_biometricHardwareAvailable) {
      _setStatus('Biometric authentication is not supported or set up on this device.');
      return;
    }

    final password = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        bool obscure = true;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.darkSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.cardBorderColor),
              ),
              title: Text(
                'Confirm Password',
                style: GoogleFonts.outfit(
                  color: AppTheme.textWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your password to encrypt and save your credentials securely.',
                    style: GoogleFonts.outfit(
                      color: AppTheme.textSub,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorderColor),
                    ),
                    child: TextField(
                      controller: controller,
                      obscureText: obscure,
                      style: GoogleFonts.outfit(color: AppTheme.textWhite, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Your password',
                        hintStyle: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppTheme.textMuted,
                          ),
                          onPressed: () => setDialogState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.textSub)),
                ),
                TextButton(
                  onPressed: () {
                    final pw = controller.text;
                    if (pw.isNotEmpty) {
                      Navigator.pop(ctx, pw);
                    }
                  },
                  child: Text('Enable', style: GoogleFonts.outfit(color: AppTheme.cyberCyan, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (password == null || password.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);
    final err = await ref.read(authProvider.notifier).enableBiometrics(password);
    setState(() => _isLoading = false);

    if (err != null) {
      _setStatus(err);
    } else {
      _setStatus('Biometric authentication enabled.');
    }
  }

  Future<void> _revokeBiometrics() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.cardBorderColor),
        ),
        title: Text(
          'Disable Biometrics?',
          style: GoogleFonts.outfit(
            color: AppTheme.crimsonRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will clear saved login credentials from secure storage. You will need to type your password next time.',
          style: GoogleFonts.outfit(color: AppTheme.textSub, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Disable', style: GoogleFonts.outfit(color: AppTheme.crimsonRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final err = await ref.read(authProvider.notifier).disableBiometrics();
    setState(() => _isLoading = false);

    if (err != null) {
      _setStatus(err);
    } else {
      _setStatus('Biometric authentication disabled.');
    }
  }

  Widget _buildBiometricTile() {
    final isBiometricEnabled = ref.watch(biometricEnabledProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_biometricIcon, color: AppTheme.cyberCyan, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Biometric Authentication',
                      style: GoogleFonts.outfit(
                        color: AppTheme.textWhite,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Secure your biometric data for instant access',
                      style: GoogleFonts.outfit(
                        color: AppTheme.textSub,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isBiometricEnabled,
                activeThumbColor: AppTheme.cyberCyan,
                activeTrackColor: AppTheme.cyberCyan.withValues(alpha: 0.3),
                inactiveThumbColor: AppTheme.textMuted,
                inactiveTrackColor: AppTheme.darkBackground,
                onChanged: _handleBiometricToggle,
              ),
            ],
          ),
          if (isBiometricEnabled) ...[
            const SizedBox(height: 12),
            const Divider(color: AppTheme.cardBorderColor, height: 1),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _revokeBiometrics,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.delete_forever_outlined, color: AppTheme.crimsonRed, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'REVOKE & CLEAR SECURE CREDENTIALS',
                    style: GoogleFonts.outfit(
                      color: AppTheme.crimsonRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
