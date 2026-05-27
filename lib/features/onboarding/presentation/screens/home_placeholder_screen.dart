import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:core_360_app/core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../../../workouts/presentation/screens/workouts_dashboard_screen.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../workouts/presentation/screens/pose_analysis_screen.dart';
import '../../../workouts/presentation/screens/analytics_dashboard_screen.dart';

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
                color: AppTheme.cyberCyan.withOpacity(0.06),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.cyberCyan.withOpacity(0.04),
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
                color: AppTheme.amethystPurple.withOpacity(0.06),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.amethystPurple.withOpacity(0.04),
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
                      // Sign Out Button with a premium glassmorphic border
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
                          color: AppTheme.glassFillColor,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
                          onPressed: () {
                            ref.read(authProvider.notifier).signOut();
                          },
                          tooltip: 'Sign Out',
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
                          color: AppTheme.cyberCyan.withOpacity(0.03),
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
                            _buildStatItem('Age', '${profile.age}', 'YRS'),
                            _buildStatItem('Height', '${profile.height.toStringAsFixed(0)}', 'CM'),
                            _buildStatItem('Weight', '${profile.weight.toStringAsFixed(1)}', 'KG'),
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
                                _buildStatItem('Body Fat', '${profile.bodyFat!.toStringAsFixed(1)}', '%'),
                              if (profile.muscleMass != null)
                                _buildStatItem('Muscle Mass', '${profile.muscleMass!.toStringAsFixed(1)}', 'KG'),
                              if (profile.waterPercentage != null)
                                _buildStatItem('Body Water', '${profile.waterPercentage!.toStringAsFixed(1)}', '%'),
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
                      color: Colors.white54,
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
                          border: Border.all(color: AppTheme.cyberCyan.withOpacity(0.4), width: 1.0),
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
                        color: Colors.orangeAccent.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3), width: 1.2),
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
                                    color: Colors.white70,
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
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.cyberCyan.withOpacity(0.12),
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
                        borderRadius: BorderRadius.circular(20),
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
                                        color: Colors.black87,
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
                          color: Colors.white54,
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

  Widget _buildStatItem(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white38,
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: color.withOpacity(0.5), size: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.06),
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
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      onTap != null ? 'ACTIVE' : 'LOCKED',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: onTap != null ? AppTheme.cyberCyan : Colors.white30,
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
