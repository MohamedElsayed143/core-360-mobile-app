import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/routine.dart';
import '../providers/workout_provider.dart';
import 'routine_builder_screen.dart';
import 'ai_planner_wizard_screen.dart';
import 'share_import_dialog.dart';

class WorkoutsDashboardScreen extends ConsumerStatefulWidget {
  const WorkoutsDashboardScreen({super.key});

  @override
  ConsumerState<WorkoutsDashboardScreen> createState() => _WorkoutsDashboardScreenState();
}

class _WorkoutsDashboardScreenState extends ConsumerState<WorkoutsDashboardScreen> {
  String? _expandedRoutineId;

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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
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
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18),
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
          // ─── AMBIENT GLOWS ───────────────────────────────────────────────
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cyberCyan.withOpacity(0.04),
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

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'YOUR SAVED ROUTINES',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white54,
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
                      child: Text(
                        'Error loading routines: $err',
                        style: GoogleFonts.outfit(color: Colors.redAccent),
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
                          return _buildRoutineCard(context, routine, isExpanded);
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.02),
            blurRadius: 15,
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
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
                    color: Colors.white54,
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
              'Build a custom split manually or leverage Llama AI to compile an injury-safe workout routine based on your biometrics.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Colors.white24,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineCard(BuildContext context, Routine routine, bool isExpanded) {
    final borderColor = routine.isAiGenerated ? AppTheme.amethystPurple : AppTheme.cyberCyan;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(20),
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
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(width: 8),
                if (routine.isAiGenerated)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.amethystPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.amethystPurple.withOpacity(0.3)),
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
                      color: AppTheme.cyberCyan.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.cyberCyan.withOpacity(0.2)),
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
              color: Colors.white30,
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              ex.title,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                          Text(
                            '${ex.sets.length} Sets',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.cardBorderColor),
                  const SizedBox(height: 8),

                  // Actions row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Edit
                      IconButton(
                        icon: const Icon(Icons.edit_note, color: Colors.white70, size: 20),
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
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.cardBorderColor),
        ),
        title: Text(
          'DELETE ROUTINE?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${routine.name}"?',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: Text(
              'CANCEL',
              style: GoogleFonts.outfit(color: Colors.white30, fontWeight: FontWeight.bold),
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
