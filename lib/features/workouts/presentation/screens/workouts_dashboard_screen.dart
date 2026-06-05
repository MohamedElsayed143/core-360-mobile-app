import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/routine.dart';
import '../providers/workout_provider.dart';
import 'active_workout_screen.dart';
import 'routine_builder_screen.dart';
import 'ai_planner_wizard_screen.dart';
import 'share_import_dialog.dart';
import 'pose_analysis_screen.dart';
import '../../domain/entities/exercise.dart';
import '../widgets/exercise_gif_widget.dart';

class WorkoutsDashboardScreen extends ConsumerStatefulWidget {
  const WorkoutsDashboardScreen({super.key});

  @override
  ConsumerState<WorkoutsDashboardScreen> createState() => _WorkoutsDashboardScreenState();
}

class _WorkoutsDashboardScreenState extends ConsumerState<WorkoutsDashboardScreen> {
  String? _expandedRoutineId;

  Future<void> _launchVideo(String urlString) async {
    if (urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open video URL: $urlString'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _toggleExpand(String id) {
    setState(() {
      if (_expandedRoutineId == id) {
        _expandedRoutineId = null;
      } else {
        _expandedRoutineId = id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(userRoutinesProvider);
    final workoutsAsync = ref.watch(globalWorkoutsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF060b13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF060b13),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'WORKOUT LIBRARY',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textSub, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_for_offline_outlined, color: AppTheme.cyberCyan, size: 24),
            tooltip: 'Import Share Code',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const ShareImportDialog(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Cyber Grid Background
          const CustomPaint(
            painter: GridPainter(),
            size: Size.infinite,
          ),

          // Ambient glow
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cyberCyan.withValues(alpha: 0.04),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top control buttons (Create/Generate)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      // Create Custom
                      Expanded(
                        child: _buildDashboardHeaderButton(
                          title: 'CREATE CUSTOM',
                          subtitle: 'Manual Sandbox Builder',
                          icon: Icons.add,
                          color: AppTheme.cyberCyan,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RoutineBuilderScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      // AI planner
                      Expanded(
                        child: _buildDashboardHeaderButton(
                          title: 'GENERATE PLAN',
                          subtitle: 'AI Biometric Split',
                          icon: Icons.auto_awesome,
                          color: AppTheme.amethystPurple,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AiPlannerWizardScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Neural Pose Analysis Camera Banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.secondaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.electricBlue.withValues(alpha: 0.12),
                          blurRadius: 10,
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
                              builder: (context) => const PoseAnalysisScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.camera_enhance_outlined, color: Colors.white, size: 22),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'NEURAL POSE ANALYSIS CAMERA',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Scan active posture and check joint flexion in real-time',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white70,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.white70, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'YOUR SAVED ROUTINES',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Routines List
                Expanded(
                  child: routinesAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppTheme.cyberCyan),
                    ),
                    error: (err, stack) => Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withValues(alpha: 0.05),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                            const SizedBox(height: 16),
                            Text(
                              'ERROR LOADING ROUTINES',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              err.toString().contains('composite index') 
                                  ? 'Firestore requires a composite index. We have optimized collections locally to prevent this error.'
                                  : err.toString(),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(color: AppTheme.textSub, fontSize: 11, height: 1.4),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () {
                                ref.read(userRoutinesProvider.notifier).refresh();
                              },
                              icon: const Icon(Icons.refresh, size: 16, color: AppTheme.cyberCyan),
                              label: Text('RETRY', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.darkBackground,
                                foregroundColor: AppTheme.cyberCyan,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: AppTheme.cardBorderColor),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (routines) {
                      if (routines.isEmpty) {
                        return _buildEmptyState(context);
                      }
                      
                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: routines.length,
                        itemBuilder: (context, index) {
                          final routine = routines[index];
                          final isExpanded = _expandedRoutineId == routine.id;
                          return _buildRoutineCard(context, routine, isExpanded, workoutsAsync.value);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHeaderButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.02),
            blurRadius: 15,
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    color: AppTheme.textSub,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fitness_center_outlined, color: Colors.white10, size: 64),
          const SizedBox(height: 16),
          Text(
            'YOUR WORKOUT LIBRARY IS EMPTY',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white30,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Build a custom split manually or leverage AI to compile an injury-safe workout routine based on your biometrics.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppTheme.textMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineCard(BuildContext context, Routine routine, bool isExpanded, List<Exercise>? globalExercises) {
    final borderColor = routine.isAiGenerated ? AppTheme.amethystPurple : AppTheme.cyberCyan;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? borderColor : AppTheme.cardBorderColor,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            onTap: () => _toggleExpand(routine.id),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            title: Text(
              routine.name,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
            subtitle: Row(
              children: [
                Text(
                  '${routine.exercises.length} EXERCISES',
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                if (routine.isAiGenerated)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.amethystPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.amethystPurple.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'AI GENERATED',
                      style: GoogleFonts.outfit(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.amethystPurple,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.cyberCyan.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      'CUSTOM',
                      style: GoogleFonts.outfit(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cyberCyan,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: AppTheme.textMuted,
            ),
          ),

          if (isExpanded) ...[
            const Divider(color: AppTheme.cardBorderColor, height: 1),
            
            // Exercises list preview
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...routine.exercises.map((ex) {
                    final matchingExercise = globalExercises?.firstWhere(
                      (e) => e.id == ex.workoutId || e.title.toLowerCase().trim() == ex.title.toLowerCase().trim(),
                      orElse: () => Exercise(
                        id: '',
                        title: ex.title,
                        description: '',
                        targetMuscle: ex.targetMuscle,
                        thumbnailUrl: '',
                        videoUrl: '',
                        gifUrl: '',
                        aiSupported: false,
                      ),
                    );
                    final gifUrl = matchingExercise?.gifUrl ?? '';
                    final thumbnailUrl = matchingExercise?.thumbnailUrl ?? '';
                    final videoUrl = matchingExercise?.videoUrl ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: InkWell(
                        onTap: videoUrl.isNotEmpty ? () => _launchVideo(videoUrl) : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            ExerciseGifWidget(
                              gifUrl: gifUrl,
                              thumbnailUrl: thumbnailUrl,
                              width: 40,
                              height: 40,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          ex.title,
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white.withValues(alpha: 0.9),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (videoUrl.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.play_circle_outline,
                                          color: AppTheme.cyberCyan,
                                          size: 14,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    ex.targetMuscle.toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      color: AppTheme.cyberCyan.withValues(alpha: 0.8),
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.glassFillColor,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.cardBorderColor),
                              ),
                              child: Text(
                                '${ex.sets.length} SETS',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSub,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // ── START TRACKING SESSION BUTTON ─────────────────
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActiveWorkoutScreen(routine: routine),
                        ),
                      );
                    },
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.cyberCyan.withValues(alpha: 0.2),
                            blurRadius: 16,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'START TRACKING SESSION',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.cardBorderColor),
                  const SizedBox(height: 4),

                  // Actions row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Edit
                      IconButton(
                        icon: const Icon(Icons.edit_note, color: AppTheme.textSub, size: 20),
                        tooltip: 'Edit Routine',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RoutineBuilderScreen(existingRoutine: routine),
                            ),
                          );
                        },
                      ),
                      // Share
                      IconButton(
                        icon: const Icon(Icons.share_outlined, color: AppTheme.cyberCyan, size: 18),
                        tooltip: 'Share Routine',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => ShareImportDialog(routineToShare: routine),
                          );
                        },
                      ),
                      // Delete
                      IconButton(
                        icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent, size: 18),
                        tooltip: 'Delete Routine',
                        onPressed: () => _confirmDelete(routine),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(Routine routine) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.cardBorderColor),
        ),
        title: Text(
          'DELETE ROUTINE?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${routine.name}"?',
          style: GoogleFonts.outfit(color: AppTheme.textSub),
        ),
        actions: [
          TextButton(
            child: Text(
              'CANCEL',
              style: GoogleFonts.outfit(color: AppTheme.textMuted, fontWeight: FontWeight.bold),
            ),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          TextButton(
            child: Text(
              'DELETE',
              style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(userRoutinesProvider.notifier).deleteRoutine(routine.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'ROUTINE DELETED.',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'DELETE FAILED: $e',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  const GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1e293b).withValues(alpha: 0.12)
      ..strokeWidth = 0.5;

    const gridSize = 40.0;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
