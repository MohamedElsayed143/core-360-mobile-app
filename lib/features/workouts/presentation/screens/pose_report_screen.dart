import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/pose_analysis_provider.dart';

class PoseReportScreen extends ConsumerWidget {
  const PoseReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poseState = ref.watch(poseAnalysisProvider);
    final avgScore = poseState.averageAccuracy;

    // Determine color codes
    Color mainColor = AppTheme.cyberCyan;
    String riskText = 'LOW';
    Color riskColor = AppTheme.cyberCyan;
    String riskDescription = 'Your form is safe. Good range of motion and joint load balance.';

    if (avgScore < 55.0) {
      mainColor = Colors.redAccent;
      riskText = 'HIGH';
      riskColor = Colors.redAccent;
      riskDescription = 'High risk of acute strain. Adjust load or consult the AI Coach before reloading.';
    } else if (avgScore < 75.0) {
      mainColor = AppTheme.warningAmber;
      riskText = 'MEDIUM';
      riskColor = AppTheme.warningAmber;
      riskDescription = 'Moderate stress points detected. Monitor fatigue levels and maintain posture controls.';
    }

    // Format duration
    final durationMin = (poseState.elapsedSeconds ~/ 60).toString();
    final durationSec = (poseState.elapsedSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Stack(
        children: [
          // ─── AMBIENT GLOWS ───────────────────────────────────────────────
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: mainColor.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.amethystPurple.withValues(alpha: 0.03),
              ),
            ),
          ),

          // ─── REPORT BODY CONTENT ──────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── HEADER TITLE ─────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI REPORT COMPLETED',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: mainColor,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'BIOMECHANICAL AUDIT',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.cardBorderColor),
                        ),
                        child: Icon(Icons.bolt, color: mainColor, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ─── ACCURACY CIRCULAR GAUGE ──────────────────────────────
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Glow Ring
                        Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                            border: Border.all(
                              color: mainColor.withValues(alpha: 0.05),
                              width: 12,
                            ),
                          ),
                        ),
                        // Circular indicator
                        SizedBox(
                          width: 156,
                          height: 156,
                          child: CircularProgressIndicator(
                            value: avgScore / 100.0,
                            strokeWidth: 8,
                            color: mainColor,
                            backgroundColor: AppTheme.cardBorderColor,
                          ),
                        ),
                        // Text metrics inside circular gauge
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${avgScore.toStringAsFixed(1)}%',
                              style: GoogleFonts.outfit(
                                fontSize: 38,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -1.0,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'AVG ACCURACY',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textMuted,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ─── PERFORMANCE DETAILS OVERVIEW CARDS ───────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _buildSessionStatCard(
                          'EXERCISE',
                          poseState.exerciseName.toUpperCase(),
                          Icons.fitness_center_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSessionStatCard(
                          'DURATION',
                          '$durationMin:$durationSec',
                          Icons.timer_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─── RISK LEVEL NEON BOX ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'BIOMECHANICAL RISK ASSESSMENT',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textMuted,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: riskColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: riskColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                riskText,
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: riskColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          riskDescription,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppTheme.textSub,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── JOINT ANALYSIS SUMMARY TABLE ─────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          child: Text(
                            'JOINT LOADING & STRESS ANALYSIS',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMuted,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const Divider(color: AppTheme.cardBorderColor, height: 1),
                        if (poseState.jointStress.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'No joint metrics logged. Stand fully in frame.',
                              style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 11),
                            ),
                          )
                        else
                          ...poseState.jointStress.entries.map((entry) {
                            return _buildJointTableRow(entry.key, entry.value);
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── CORRECTIVE TIPS PANEL ──────────────────────────────
                  _buildCorrectiveTipsPanel(poseState, mainColor),
                  const SizedBox(height: 32),

                  // ─── RETURN BUTTON CTA ────────────────────────────────────
                  ElevatedButton(
                    onPressed: () {
                      ref.read(poseAnalysisProvider.notifier).reset();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        child: Text(
                          'RETURN TO LIBRARY',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionStatCard(String label, String val, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 8,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  val,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJointTableRow(String name, String status) {
    Color badgeColor = AppTheme.cyberCyan;
    if (status == 'CRITICAL') {
      badgeColor = Colors.redAccent;
    } else if (status == 'WARNING') {
      badgeColor = AppTheme.warningAmber;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSub,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              status,
              style: GoogleFonts.outfit(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrectiveTipsPanel(PoseAnalysisState state, Color color) {
    // Generate corrections or show AI report feedback
    final tips = <String>[];
    if (state.exerciseName.toLowerCase().contains('plank')) {
      if (state.averageAccuracy < 80) {
        tips.add('Hip Sagging: Tighten glutes and core to lift hips inline.');
        tips.add('Shoulder Stress: Align elbows directly under shoulders.');
      } else {
        tips.add('Perfect Form: Core alignment is within structural limit bounds.');
      }
    } else {
      if (state.averageAccuracy < 85) {
        tips.add('Shallow Depth: Try squats on a low bench to build hip flexion.');
        tips.add('Torso Lean: Lift chest up and focus eyes forward during descent.');
      } else {
        tips.add('Excellent Mechanics: Knees are tracing toes correctly.');
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                'AI CORRECTIVE ACTIONS',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tips.map((tip) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: GoogleFonts.outfit(color: color, fontSize: 14)),
                  Expanded(
                    child: Text(
                      tip,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textSub,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
