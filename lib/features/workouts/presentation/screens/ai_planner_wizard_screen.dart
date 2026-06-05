import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../onboarding/presentation/providers/auth_provider.dart';
import '../providers/ai_planner_provider.dart';

class AiPlannerWizardScreen extends ConsumerWidget {
  const AiPlannerWizardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plannerState = ref.watch(aiPlannerProvider);
    final plannerNotifier = ref.read(aiPlannerProvider.notifier);
    
    final authState = ref.watch(authProvider);
    final userProfile = authState is AuthenticatedWithProfile ? authState.profile : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'AI ROUTINE BUILDER',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textSub, size: 18),
          onPressed: () {
            if (plannerState.step > 0 && !plannerState.isGenerating && plannerState.generatedRoutine == null) {
              plannerNotifier.setStep(plannerState.step - 1);
            } else {
              plannerNotifier.reset();
              Navigator.pop(context);
            }
          },
        ),
      ),
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
                color: AppTheme.amethystPurple.withValues(alpha: 0.04),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Step Indicator Progress bar
                if (plannerState.generatedRoutine == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'STEP ${plannerState.step + 1} OF 4',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.cyberCyan,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Text(
                              _getStepTitle(plannerState.step),
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSub,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppTheme.cardBorderColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: MediaQuery.of(context).size.width *
                                  ((plannerState.step + 1) / 4) - 48,
                              height: 4,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Main surveys or preview
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: plannerState.generatedRoutine != null
                        ? _buildRoutinePreview(context, plannerState, plannerNotifier)
                        : _buildWizardStep(context, plannerState, plannerNotifier, userProfile?.injuries),
                  ),
                ),
              ],
            ),
          ),

          // Loading overlay
          if (plannerState.isGenerating)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        color: AppTheme.amethystPurple,
                        strokeWidth: 4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'COMPILING NEURAL PROMPT...',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.amethystPurple,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Filtering injuries & matching global assets...',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textSub,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'EXPERIENCE LEVEL';
      case 1:
        return 'WEEKLY FREQUENCY';
      case 2:
        return 'SPLIT FOCUS';
      case 3:
        return 'REVIEW & GENERATE';
      default:
        return '';
    }
  }

  Widget _buildWizardStep(
    BuildContext context,
    AiPlannerState state,
    AiPlannerNotifier notifier,
    String? injuries,
  ) {
    switch (state.step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'WHAT IS YOUR TRAINING EXPERIENCE?',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            _buildSelectionCard(
              title: 'BEGINNER',
              description: 'New to formal training, learning proper form mechanics and movements.',
              isSelected: state.experienceLevel == 'beginner',
              onTap: () {
                notifier.setExperienceLevel('beginner');
                notifier.setStep(1);
              },
            ),
            _buildSelectionCard(
              title: 'INTERMEDIATE',
              description: '1-3 years of consistent tracking, looking to build volume and splits.',
              isSelected: state.experienceLevel == 'intermediate',
              onTap: () {
                notifier.setExperienceLevel('intermediate');
                notifier.setStep(1);
              },
            ),
            _buildSelectionCard(
              title: 'ADVANCED',
              description: '3+ years experience, requiring optimized scheduling and progressive overload.',
              isSelected: state.experienceLevel == 'advanced',
              onTap: () {
                notifier.setExperienceLevel('advanced');
                notifier.setStep(1);
              },
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'HOW MANY DAYS A WEEK WILL YOU TRAIN?',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [2, 3, 4, 5, 6].map((freq) {
                final isSel = state.trainingFrequency == freq;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      notifier.setTrainingFrequency(freq);
                    },
                    child: Container(
                      height: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSel ? Colors.transparent : AppTheme.darkSurface,
                        gradient: isSel ? AppTheme.primaryGradient : null,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSel ? AppTheme.cyberCyan : AppTheme.cardBorderColor,
                          width: 1.2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$freq',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'DAYS PER WEEK',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => notifier.setStep(2),
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
                  height: 56,
                  alignment: Alignment.center,
                  child: Text(
                    'NEXT STEP',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'SELECT YOUR WORKOUT SPLIT FOCUS',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            _buildSelectionCard(
              title: 'FULL BODY',
              description: 'Complete systemic stimulation targeting legs, chest, back, and core.',
              isSelected: state.splitFocus == 'full_body',
              onTap: () {
                notifier.setSplitFocus('full_body');
                notifier.setStep(3);
              },
            ),
            _buildSelectionCard(
              title: 'UPPER BODY',
              description: 'Focuses on chest, back, shoulders, and arms.',
              isSelected: state.splitFocus == 'upper',
              onTap: () {
                notifier.setSplitFocus('upper');
                notifier.setStep(3);
              },
            ),
            _buildSelectionCard(
              title: 'LOWER BODY',
              description: 'Focuses on quadriceps, hamstrings, glutes, and calves.',
              isSelected: state.splitFocus == 'lower',
              onTap: () {
                notifier.setSplitFocus('lower');
                notifier.setStep(3);
              },
            ),
            _buildSelectionCard(
              title: 'PUSH SPLIT',
              description: 'Targets pushing muscles: chest, front delts, and triceps.',
              isSelected: state.splitFocus == 'push',
              onTap: () {
                notifier.setSplitFocus('push');
                notifier.setStep(3);
              },
            ),
            _buildSelectionCard(
              title: 'PULL SPLIT',
              description: 'Targets pulling muscles: upper back, biceps, and rear delts.',
              isSelected: state.splitFocus == 'pull',
              onTap: () {
                notifier.setSplitFocus('pull');
                notifier.setStep(3);
              },
            ),
            _buildSelectionCard(
              title: 'CORE & CARDIO',
              description: 'Targeting rectus abdominis, obliques, and cardiovascular conditioning.',
              isSelected: state.splitFocus == 'core',
              onTap: () {
                notifier.setSplitFocus('core');
                notifier.setStep(3);
              },
            ),
          ],
        );
      case 3:
        final hasInjuries = injuries != null && injuries.trim().isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'READY TO CALIBRATE DYNAMIC PLAN',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Our AI engine will merge your active biometrics and goals with these survey split configurations.',
              style: GoogleFonts.outfit(color: AppTheme.textSub, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),

            // Summary box
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorderColor),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('EXPERIENCE', state.experienceLevel.toUpperCase()),
                  const Divider(color: AppTheme.cardBorderColor, height: 20),
                  _buildSummaryRow('FREQUENCY', '${state.trainingFrequency} DAYS/WEEK'),
                  const Divider(color: AppTheme.cardBorderColor, height: 20),
                  _buildSummaryRow('SPLIT FOCUS', state.splitFocus.toUpperCase().replaceAll('_', ' ')),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Injury warning
            if (hasInjuries)
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
                    const Icon(Icons.security, color: Colors.orangeAccent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SAFEGUARDING ALIGNMENT',
                            style: GoogleFonts.outfit(
                              color: Colors.orangeAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'The AI is instructed to bypass exercises straining: "$injuries".',
                            style: GoogleFonts.outfit(color: AppTheme.textSub, fontSize: 12, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 40),

            // Generate Button
            ElevatedButton(
              onPressed: () async {
                final routine = await notifier.generateAiRoutine();
                if (routine == null && context.mounted && state.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        state.errorMessage!,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
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
                  gradient: AppTheme.secondaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'GENERATE AI ROUTINE',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildSelectionCard({
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppTheme.cyberCyan : AppTheme.cardBorderColor,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.cyberCyan : Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: AppTheme.cyberCyan, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppTheme.textSub,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildRoutinePreview(
    BuildContext context,
    AiPlannerState state,
    AiPlannerNotifier notifier,
  ) {
    final routine = state.generatedRoutine!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => AppTheme.secondaryGradient.createShader(bounds),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'AI PLAN CALIBRATED!',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'A specialized AI split has been configured. View exercises below before saving.',
          style: GoogleFonts.outfit(color: AppTheme.textSub, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),

        // Routine Name Title
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.3)),
          ),
          child: Text(
            routine.name.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.cyberCyan,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Exercises list
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: routine.exercises.length,
          itemBuilder: (context, idx) {
            final ex = routine.exercises[idx];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppTheme.glassFillColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${idx + 1}',
                        style: GoogleFonts.outfit(
                          color: AppTheme.cyberCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ex.title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${ex.sets.length} Sets • ${ex.sets.map((s) => "${s.reps}x${s.weight.toStringAsFixed(1)}kg").join(', ')}',
                          style: GoogleFonts.outfit(
                            color: AppTheme.textSub,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.cyberCyan.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ex.targetMuscle.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cyberCyan,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 32),

        // Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  notifier.reset();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.cardBorderColor),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'RE-GENERATE',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSub,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await notifier.saveGeneratedRoutine();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'AI ROUTINE ADDED TO LIBRARY.',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: AppTheme.cyberCyan,
                        ),
                      );
                      notifier.reset();
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'SAVE FAILED: $e',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
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
                      'SAVE ROUTINE',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
