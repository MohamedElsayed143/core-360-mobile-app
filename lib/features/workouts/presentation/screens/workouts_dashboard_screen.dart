import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/routine.dart';
import '../providers/workout_provider.dart';
import 'active_workout_screen.dart';
import 'routine_builder_screen.dart';
import 'ai_planner_wizard_screen.dart';
import 'share_import_dialog.dart';

class WorkoutsDashboardScreen extends ConsumerStatefulWidget {
  const WorkoutsDashboardScreen({super.key});

  @override
  ConsumerState<WorkoutsDashboardScreen> createState() =>
      _WorkoutsDashboardScreenState();
}

class _WorkoutsDashboardScreenState
    extends ConsumerState<WorkoutsDashboardScreen> {
  String? _expandedRoutineId;
  bool _isCreateDropdownOpen = false;

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
      backgroundColor: const Color(0xFF060b13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF060b13),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Workouts',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textSub, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [],
      ),
      body: Stack(
        children: [
          CustomPaint(
            painter: const GridPainter(),
            size: Size.infinite,
          ),
          SafeArea(
            child: routinesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF00b4d8)),
              ),
              error: (err, stack) => Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                        width: 1.2),
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
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 40),
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
                        style: GoogleFonts.outfit(
                            color: AppTheme.textSub,
                            fontSize: 11,
                            height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.read(userRoutinesProvider.notifier).refresh();
                        },
                        icon: const Icon(Icons.refresh,
                            size: 16, color: Color(0xFF00b4d8)),
                        label: Text('RETRY',
                            style:
                                GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF060b13),
                          foregroundColor: const Color(0xFF00b4d8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                                color: AppTheme.cardBorderColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              data: (routines) {
                if (routines.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildRoutineList(routines);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF0b1329),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: const Color(0xFF1e293b).withValues(alpha: 0.5),
                    width: 0.5),
              ),
              child: Transform.rotate(
                angle: 0.785,
                child: const Icon(Icons.fitness_center,
                    color: Color(0xFF00b4d8), size: 36),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Routines Yet',
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Build your first custom routine manually or use AI to generate a personalized plan.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: const Color(0xFF64748b),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: 'Manual Builder',
                    icon: Icons.checklist,
                    bgColor: const Color(0xFF09141f),
                    borderColor: const Color(0xFF00b4d8),
                    textColor: const Color(0xFF00b4d8),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RoutineBuilderScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    label: 'AI Enhanced',
                    icon: Icons.auto_awesome,
                    bgColor: const Color(0xFF061a12),
                    borderColor: const Color(0xFF22c55e),
                    textColor: const Color(0xFF22c55e),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AiPlannerWizardScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 200,
              child: _buildActionButton(
                label: 'Add from Code',
                icon: Icons.link,
                bgColor: const Color(0xFF07162c),
                borderColor: const Color(0xFF00b4d8),
                textColor: const Color(0xFF00b4d8),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const ShareImportDialog(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: borderColor.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: textColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoutineList(List<Routine> routines) {
    return Stack(
      children: [
        if (_isCreateDropdownOpen)
          GestureDetector(
            onTap: () {
              setState(() {
                _isCreateDropdownOpen = false;
              });
            },
            child: Container(color: Colors.transparent),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1e2530),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'My Routines ${routines.length}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isCreateDropdownOpen = !_isCreateDropdownOpen;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF091520),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF00b4d8)
                                .withValues(alpha: 0.5),
                            width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add,
                              size: 16, color: Color(0xFF00b4d8)),
                          const SizedBox(width: 6),
                          Text(
                            'Create Routine',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF00b4d8),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            _isCreateDropdownOpen
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 18,
                            color: const Color(0xFF00b4d8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: routines.length,
                itemBuilder: (context, index) {
                  final routine = routines[index];
                  final isExpanded = _expandedRoutineId == routine.id;
                  return _buildRoutineCard(context, routine, isExpanded);
                },
              ),
            ),
          ],
        ),
        if (_isCreateDropdownOpen)
          Positioned(
            top: 60,
            left: 24,
            right: 24,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1e2530),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDropdownItem(
                      icon: Icons.checklist,
                      iconBg: const Color(0xFF0b1a2e),
                      iconColor: const Color(0xFF00b4d8),
                      title: 'Manual',
                      subtitle: 'Build from scratch',
                      onTap: () {
                        setState(() {
                          _isCreateDropdownOpen = false;
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RoutineBuilderScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(
                        color: Color(0xFF2a3342), height: 1, thickness: 1),
                    _buildDropdownItem(
                      icon: Icons.auto_awesome,
                      iconBg: const Color(0xFF0c2418),
                      iconColor: const Color(0xFF22c55e),
                      title: 'AI Enhanced',
                      subtitle: 'Smart AI-powered generation',
                      onTap: () {
                        setState(() {
                          _isCreateDropdownOpen = false;
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AiPlannerWizardScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(
                        color: Color(0xFF2a3342), height: 1, thickness: 1),
                    _buildDropdownItem(
                      icon: Icons.link,
                      iconBg: const Color(0xFF0c1a2e),
                      iconColor: const Color(0xFF00b4d8),
                      title: 'Add from Code',
                      subtitle: 'Import a shared routine',
                      onTap: () {
                        setState(() {
                          _isCreateDropdownOpen = false;
                        });
                        showDialog(
                          context: context,
                          builder: (context) => const ShareImportDialog(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdownItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: const Color(0xFF64748b),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineCard(
      BuildContext context, Routine routine, bool isExpanded) {
    final borderColor =
        routine.isAiGenerated ? AppTheme.amethystPurple : AppTheme.cyberCyan;

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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.amethystPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppTheme.amethystPurple.withValues(alpha: 0.3)),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.cyberCyan.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppTheme.cyberCyan.withValues(alpha: 0.2)),
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
              isExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: AppTheme.textMuted,
            ),
          ),
          if (isExpanded) ...[
            const Divider(color: AppTheme.cardBorderColor, height: 1),
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
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                          Text(
                            '${ex.sets.length} Sets',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppTheme.textSub,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ActiveWorkoutScreen(routine: routine),
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
                          const Icon(Icons.play_arrow_rounded,
                              color: Colors.black, size: 20),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_note,
                            color: AppTheme.textSub, size: 20),
                        tooltip: 'Edit Routine',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RoutineBuilderScreen(
                                  existingRoutine: routine),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined,
                            color: AppTheme.cyberCyan, size: 18),
                        tooltip: 'Share Routine',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) =>
                                ShareImportDialog(routineToShare: routine),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever_outlined,
                            color: Colors.redAccent, size: 18),
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
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${routine.name}"?',
          style: GoogleFonts.outfit(color: AppTheme.textSub),
        ),
        actions: [
          TextButton(
            child: Text(
              'CANCEL',
              style: GoogleFonts.outfit(
                  color: AppTheme.textMuted, fontWeight: FontWeight.bold),
            ),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          TextButton(
            child: Text(
              'DELETE',
              style: GoogleFonts.outfit(
                  color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref
                    .read(userRoutinesProvider.notifier)
                    .deleteRoutine(routine.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'ROUTINE DELETED.',
                        style:
                            GoogleFonts.outfit(fontWeight: FontWeight.bold),
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
                        style:
                            GoogleFonts.outfit(fontWeight: FontWeight.bold),
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
