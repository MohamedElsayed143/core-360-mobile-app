import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../workouts/data/models/workout_session_model.dart';
import '../../../workouts/presentation/screens/analytics_dashboard_screen.dart';
import '../../../workouts/presentation/screens/pose_analysis_screen.dart';
import '../../../workouts/presentation/screens/workouts_dashboard_screen.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../providers/auth_provider.dart';
import '../../../workouts/presentation/providers/analytics_provider.dart';

ImageProvider? _profileImageProvider(String? profileUrl, String? authUrl) {
  if (profileUrl != null && profileUrl.startsWith('data:')) {
    return MemoryImage(base64Decode(profileUrl.split(',').last));
  }
  if (authUrl != null) return NetworkImage(authUrl);
  return null;
}

class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Guard to ensure we have authenticated profile data
    if (authState is! AuthenticatedWithProfile) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.cyberCyan),
        ),
      );
    }

    final user = authState.user;
    final profile = authState.profile;
    final userName = user.displayName ?? 'Athlete';

    return Scaffold(
      body: Stack(
        children: [
          // ─── AMBIENT BACKGROUND GLOWS ────────────────────────────────────
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cyberCyan.withValues(alpha: 0.06),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.cyberCyan.withValues(alpha: 0.04),
                    blurRadius: 150,
                    spreadRadius: 50,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.amethystPurple.withValues(alpha: 0.06),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.amethystPurple.withValues(alpha: 0.04),
                    blurRadius: 150,
                    spreadRadius: 50,
                  )
                ],
              ),
            ),
          ),

          // ─── MAIN CONTENT ───────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── TOP HEADER BAR ───────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WELCOME BACK,',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.cyberCyan,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userName.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      // User avatar button
                      GestureDetector(
                        onTap: () => _showUserProfile(context, ref, authState),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF323b49),
                          backgroundImage: _profileImageProvider(profile.photoURL, user.photoURL),
                          child: profile.photoURL == null && user.photoURL == null
                              ? Text(
                                  userName[0].toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ─── BIO-IDENTITY SCORECARD (GLASSMORPHIC) ─────────────────
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.cyberCyan.withValues(alpha: 0.03),
                          blurRadius: 20,
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                              child: const Icon(Icons.bolt, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'VERIFIED BIO-IDENTITY',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatItem('Age', profile.age.toString(), 'YRS'),
                            _buildStatItem('Height', profile.height.toStringAsFixed(0), 'CM'),
                            _buildStatItem('Weight', profile.weight.toStringAsFixed(1), 'KG'),
                          ],
                        ),
                        if (profile.bodyFat != null || profile.muscleMass != null) ...[
                          const SizedBox(height: 20),
                          const Divider(color: AppTheme.cardBorderColor, height: 1),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (profile.bodyFat != null)
                                _buildStatItem('Body Fat', profile.bodyFat!.toStringAsFixed(1), '%'),
                              if (profile.muscleMass != null)
                                _buildStatItem('Muscle Mass', profile.muscleMass!.toStringAsFixed(1), 'KG'),
                              if (profile.waterPercentage != null)
                                _buildStatItem('Body Water', profile.waterPercentage!.toStringAsFixed(1), '%'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ─── GOALS SECTION ────────────────────────────────────────
                  Text(
                    'ACTIVE STRATEGIC TARGETS',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppTheme.textSub,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: profile.goals.map((goal) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.glassFillColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.4), width: 1.0),
                        ),
                        child: Text(
                          goal.toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: AppTheme.cyberCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // ─── INJURIES PANEL ───────────────────────────────────────
                  if (profile.injuries != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3), width: 1.2),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BIOMECHANICAL CONTROLS SYSTEM ACTIVE',
                                  style: GoogleFonts.outfit(
                                    color: Colors.orangeAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  profile.injuries!,
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.textSub,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // ─── PERFORMANCE ANALYTICS BANNER ────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.cyberCyan.withValues(alpha: 0.12),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AnalyticsDashboardScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          child: Row(
                            children: [
                              const Icon(Icons.analytics_outlined, color: Colors.black, size: 24),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'INTELLIGENT PERFORMANCE ANALYTICS',
                                      style: GoogleFonts.outfit(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Monitor workout volume history, accuracy, and muscle maps',
                                      style: GoogleFonts.outfit(
                                        color: Colors.black,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, color: Colors.black54, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ─── FUTURISTIC NEURAL ARCHITECTURE MODULES ─────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CORE-360 ENGINE MODULES',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: AppTheme.textSub,
                        ),
                      ),
                      Text(
                        'PHASE 3-6 IN DEVELOPMENT',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.amethystPurple,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Grid of modules in premium mock state
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.15,
                    children: [
                      _buildMockModuleCard(
                        'Routine Builder',
                        Icons.fitness_center,
                        'Pillar 2',
                        AppTheme.cyberCyan,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WorkoutsDashboardScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMockModuleCard(
                        'Active Tracker',
                        Icons.timer_outlined,
                        'Pillar 3',
                        AppTheme.electricBlue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WorkoutsDashboardScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMockModuleCard(
                        'Pose Analysis',
                        Icons.camera_enhance_outlined,
                        'Pillar 4',
                        AppTheme.amethystPurple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PoseAnalysisScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMockModuleCard(
                        'AI RAG Coach',
                        Icons.chat_bubble_outline,
                        'Pillar 5',
                        AppTheme.warningAmber,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ChatScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserProfile(
      BuildContext context, WidgetRef ref, AuthenticatedWithProfile authState) {
    final user = authState.user;
    final profile = authState.profile;
    final userName = user.displayName ?? 'Athlete';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF121824), Color(0xFF1a1224)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Consumer(
              builder: (context, ref, _) {
                final analytics = ref.watch(analyticsProvider);

                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF94a3b8).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'User Profile',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'DIGITAL IDENTITY & STATISTICS',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF22c55e),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: const Color(0xFF323b49),
                        backgroundImage: _profileImageProvider(profile.photoURL, user.photoURL),
                        child: profile.photoURL == null && user.photoURL == null
                            ? Text(
                                userName[0].toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF252d3a).withValues(alpha: 0.87),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF3d4d6b), width: 0.5),
                        ),
                        child: Column(
                          children: [
                            _profileInfoRow('FULL NAME', user.displayName ?? 'Not set'),
                            const Divider(color: Color(0xFF3d4d6b), height: 24),
                            _profileInfoRow('EMAIL ADDRESS', user.email ?? 'Not set'),
                            const Divider(color: Color(0xFF3d4d6b), height: 24),
                            _profileInfoRow('PHONE NUMBER', user.phoneNumber ?? 'Not linked to 2FA'),
                            const Divider(color: Color(0xFF3d4d6b), height: 24),
                            _profileInfoRow(
                              'ACCOUNT CREATED',
                              _formatDate(user.metadata.creationTime),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: FutureBuilder<int>(
                                future: FirebaseFirestore.instance
                                    .collection('routines')
                                    .where('userId', isEqualTo: user.uid)
                                    .get()
                                    .then((snap) => snap.docs.length),
                                builder: (context, snapshot) {
                                  return _profileStatBox('WORKOUTS', '${snapshot.data ?? 0}');
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _profileStatBox('SESSIONS', '${analytics.completedSessions}'),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _profileStatBox('ANALYSES', '0'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Expanded(child: _profileStatBox('ALERTS', '0')),
                            const SizedBox(width: 10),
                            Expanded(child: _profileStatBox('PROGRESS', '0')),
                            const SizedBox(width: 10),
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Sessions',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFe2e8f0),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildRecentWorkout(ref, user.uid),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SettingsScreen(),
                                    ),
                                  );
                                },
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppTheme.darkSurface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.cardBorderColor),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.settings, color: AppTheme.cyberCyan, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Settings',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textWhite,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    ref.read(authProvider.notifier).signOut();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    'Sign Out',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _profileInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF94a3b8),
            letterSpacing: 0.5,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFe2e8f0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileStatBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF252d3a).withValues(alpha: 0.87),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3d4d6b), width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF94a3b8),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentWorkout(WidgetRef ref, String uid) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
        future: FirebaseFirestore.instance
            .collection('sessions')
            .where('userId', isEqualTo: uid)
            .get()
            .then((snap) {
          if (snap.docs.isEmpty) return null;
          snap.docs.sort((a, b) {
            final aTime = (a.data()['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();
            final bTime = (b.data()['startTime'] as Timestamp?)?.toDate() ?? DateTime.now();
            return bTime.compareTo(aTime);
          });
          return snap.docs.first;
        }),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator(color: AppTheme.cyberCyan)),
            );
          }
          final doc = snapshot.data;
          if (doc == null || !doc.exists) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: const Color(0xFF252d3a).withValues(alpha: 0.87),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF3d4d6b), width: 0.5),
              ),
              child: Column(
                children: [
                  Icon(Icons.fitness_center_outlined, color: const Color(0xFF94a3b8), size: 32),
                  const SizedBox(height: 8),
                  Text('No sessions recorded yet.',
                      style: GoogleFonts.outfit(color: const Color(0xFF94a3b8), fontSize: 13)),
                ],
              ),
            );
          }
          final model = WorkoutSessionModel.fromFirestore(doc);
          final dur = model.durationSeconds;
          final durationStr = dur >= 3600
              ? '${dur ~/ 3600}h ${(dur % 3600) ~/ 60}m'
              : dur >= 60
                  ? '${dur ~/ 60} min'
                  : '$dur sec';
          final exercises = model.exercises.length;

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF252d3a).withValues(alpha: 0.87),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF3d4d6b), width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.cyberCyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fitness_center, color: AppTheme.cyberCyan, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(model.routineName,
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatDate(model.startTime)}  •  $exercises exercises  •  $durationStr',
                        style: GoogleFonts.outfit(color: const Color(0xFF94a3b8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final amPm = date.hour < 12 ? 'AM' : 'PM';
    return '${date.month}/${date.day}/${date.year}, $hour:${date.minute.toString().padLeft(2, '0')} $amPm';
  }

  Widget _buildStatItem(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppTheme.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              unit,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.cyberCyan,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMockModuleCard(String title, IconData icon, String subtitle, Color color, {VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: color.withValues(alpha: 0.5), size: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      onTap != null ? 'ACTIVE' : 'LOCKED',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: onTap != null ? AppTheme.cyberCyan : AppTheme.textMuted,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
