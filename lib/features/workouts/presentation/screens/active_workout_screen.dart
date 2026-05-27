import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/routine.dart';
import '../providers/active_workout_provider.dart';
import '../providers/workout_provider.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  final Routine routine;

  const ActiveWorkoutScreen({super.key, required this.routine});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  YoutubePlayerController? _ytController;
  String? _currentVideoId;
  bool _isPlayerVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSession());
  }

  Future<void> _initSession() async {
    try {
      final globalWorkouts = await ref.read(globalWorkoutsProvider.future);
      final videoUrlMap = globalWorkouts
          .map((ex) => {'workoutId': ex.id, 'videoUrl': ex.videoUrl})
          .toList();
      if (mounted) {
        ref.read(activeWorkoutProvider.notifier).initSession(widget.routine, videoUrlMap);
      }
    } catch (_) {
      if (mounted) {
        ref.read(activeWorkoutProvider.notifier).initSession(widget.routine, []);
      }
    }
  }

  void _syncYoutubePlayer(String videoUrl) {
    final videoId = YoutubePlayer.convertUrlToId(videoUrl) ?? '';
    if (videoId.isEmpty || videoId == _currentVideoId) return;
    _currentVideoId = videoId;
    
    if (_ytController == null) {
      final controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          disableDragSeek: false,
          forceHD: false,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _ytController = controller;
          });
        }
      });
    } else {
      try {
        _ytController!.load(videoId);
        _ytController!.pause();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _ytController?.dispose();
    ref.read(activeWorkoutProvider.notifier).reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(activeWorkoutProvider);

    // Sync YouTube player safely on first load
    final activeEx = sessionState.activeExercise;
    if (activeEx != null && activeEx.videoUrl.isNotEmpty && _ytController == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncYoutubePlayer(activeEx.videoUrl);
        }
      });
    }

    // Handle updates safely via the Riverpod listener outside of the build phase
    ref.listen(activeWorkoutProvider, (prev, next) {
      if (next.isFinished && prev?.isFinished != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showTrophySheet(context, next);
        });
      }

      final nextEx = next.activeExercise;
      if (nextEx != null && nextEx.videoUrl.isNotEmpty) {
        final prevEx = prev?.activeExercise;
        if (prevEx == null || prevEx.videoUrl != nextEx.videoUrl) {
          _syncYoutubePlayer(nextEx.videoUrl);
        }
      }
    });

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _ytController ??
            YoutubePlayerController(initialVideoId: 'dQw4w9WgXcQ',
                flags: const YoutubePlayerFlags(autoPlay: false)),
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppTheme.cyberCyan,
        progressColors: const ProgressBarColors(
          playedColor: AppTheme.cyberCyan,
          handleColor: AppTheme.electricBlue,
        ),
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          appBar: _buildAppBar(sessionState),
          body: sessionState.exercises.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppTheme.cyberCyan))
              : _buildBody(context, sessionState, player),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(ActiveWorkoutState sessionState) {
    return AppBar(
      backgroundColor: AppTheme.darkBackground,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white54, size: 22),
        onPressed: () => _confirmExit(),
      ),
      title: Column(
        children: [
          Text(
            sessionState.routine?.name.toUpperCase() ?? 'ACTIVE SESSION',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${sessionState.exercises.length} EXERCISES',
            style: GoogleFonts.outfit(
              fontSize: 9,
              color: Colors.white38,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => _triggerEndWorkout(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
              ),
              child: Text(
                'END',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, ActiveWorkoutState sessionState, Widget player) {
    return Stack(
      children: [
        // Ambient glows
        Positioned(
          top: -80,
          right: -80,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.electricBlue.withOpacity(0.04),
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          left: -60,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.amethystPurple.withOpacity(0.04),
            ),
          ),
        ),

        Column(
          children: [
            // ── TIMER HUD ───────────────────────────────────────────
            _TimerHud(),
            const SizedBox(height: 12),

            // ── EXERCISE NAV DOTS ────────────────────────────────────
            _buildExerciseDots(sessionState),
            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── EXERCISE HEADER CARD ─────────────────────────
                    _buildExerciseHeader(sessionState),
                    const SizedBox(height: 16),

                    // ── YOUTUBE PLAYER CAPSULE ───────────────────────
                    if (_currentVideoId != null && _currentVideoId!.isNotEmpty)
                      _buildPlayerCapsule(player),

                    const SizedBox(height: 16),

                    // ── SETS LEDGER TABLE ────────────────────────────
                    _buildSetsLedger(sessionState),
                    const SizedBox(height: 16),

                    // ── ADD SET BUTTON ───────────────────────────────
                    _buildAddSetButton(sessionState),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ── PREV / NEXT EXERCISE CONTROLS ──────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildNavBar(sessionState),
        ),
      ],
    );
  }

  Widget _buildExerciseDots(ActiveWorkoutState state) {
    return SizedBox(
      height: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(state.exercises.length, (i) {
          final isActive = i == state.activeIndex;
          final isCompleted = state.exercises[i].sets.every((s) => s.isCompleted);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: isCompleted
                  ? AppTheme.cyberCyan
                  : isActive
                      ? AppTheme.electricBlue
                      : AppTheme.cardBorderColor,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildExerciseHeader(ActiveWorkoutState state) {
    final ex = state.activeExercise;
    if (ex == null) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.electricBlue.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.electricBlue.withOpacity(0.04),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.electricBlue.withOpacity(0.1),
              border: Border.all(color: AppTheme.electricBlue.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                '${state.activeIndex + 1}',
                style: GoogleFonts.outfit(
                  color: AppTheme.electricBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.cyberCyan.withOpacity(0.08),
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
                    const SizedBox(width: 8),
                    Text(
                      '${ex.sets.where((s) => s.isCompleted).length}/${ex.sets.length} SETS DONE',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: Colors.white38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (ex.videoUrl.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _isPlayerVisible = !_isPlayerVisible),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isPlayerVisible
                      ? Icons.videocam_outlined
                      : Icons.videocam_off_outlined,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerCapsule(Widget player) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isPlayerVisible
          ? Container(
              key: const ValueKey('player_visible'),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.redAccent.withOpacity(0.25), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: AppTheme.darkSurface,
                    child: Row(
                      children: [
                        const Icon(Icons.play_circle_outline,
                            color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'FORM GUIDE TUTORIAL',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white54,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  player,
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('player_hidden')),
    );
  }

  Widget _buildSetsLedger(ActiveWorkoutState state) {
    final exIndex = state.activeIndex;
    final ex = state.activeExercise;
    if (ex == null) return const SizedBox();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ledger Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                _ledgerHeaderCell('SET', flex: 1),
                _ledgerHeaderCell('KG', flex: 2),
                _ledgerHeaderCell('REPS', flex: 2),
                _ledgerHeaderCell('✓', flex: 1),
                const SizedBox(width: 36), // trash placeholder
              ],
            ),
          ),
          const Divider(color: AppTheme.cardBorderColor, height: 1),

          // Set Rows
          ...List.generate(ex.sets.length, (setIndex) {
            final set = ex.sets[setIndex];
            return _SetLedgerRow(
              key: ValueKey('set_${exIndex}_$setIndex'),
              setNumber: setIndex + 1,
              weight: set.weight,
              reps: set.reps,
              isCompleted: set.isCompleted,
              onWeightChanged: (v) =>
                  ref.read(activeWorkoutProvider.notifier).updateWeight(exIndex, setIndex, v),
              onRepsChanged: (v) =>
                  ref.read(activeWorkoutProvider.notifier).updateReps(exIndex, setIndex, v),
              onToggleComplete: () =>
                  ref.read(activeWorkoutProvider.notifier).toggleSetCompleted(exIndex, setIndex),
              onDelete: ex.sets.length > 1
                  ? () => ref.read(activeWorkoutProvider.notifier).deleteSet(exIndex, setIndex)
                  : null,
            );
          }),
        ],
      ),
    );
  }

  Widget _ledgerHeaderCell(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Colors.white30,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildAddSetButton(ActiveWorkoutState state) {
    return GestureDetector(
      onTap: () =>
          ref.read(activeWorkoutProvider.notifier).addSet(state.activeIndex),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.cyberCyan.withOpacity(0.3),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: AppTheme.cyberCyan.withOpacity(0.8), size: 18),
            const SizedBox(width: 8),
            Text(
              'ADD SET',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.cyberCyan.withOpacity(0.8),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(ActiveWorkoutState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        border: const Border(top: BorderSide(color: AppTheme.cardBorderColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Previous button
            Expanded(
              child: GestureDetector(
                onTap: state.hasPrev
                    ? () => ref.read(activeWorkoutProvider.notifier).previousExercise()
                    : null,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: state.hasPrev ? AppTheme.darkSurface : AppTheme.darkSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chevron_left,
                          color: state.hasPrev ? Colors.white70 : Colors.white24, size: 20),
                      Text(
                        'PREV',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: state.hasPrev ? Colors.white70 : Colors.white24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Next button
            Expanded(
              child: GestureDetector(
                onTap: state.hasNext
                    ? () => ref.read(activeWorkoutProvider.notifier).nextExercise()
                    : () => _triggerEndWorkout(),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: state.hasNext ? null : AppTheme.secondaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    border: state.hasNext
                        ? Border.all(color: AppTheme.electricBlue.withOpacity(0.4))
                        : null,
                    color: state.hasNext ? AppTheme.darkSurface : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        state.hasNext ? 'NEXT' : 'FINISH',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: state.hasNext ? Colors.white70 : Colors.white,
                        ),
                      ),
                      Icon(
                        state.hasNext ? Icons.chevron_right : Icons.emoji_events_outlined,
                        color: state.hasNext ? Colors.white70 : Colors.white,
                        size: 18,
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

  void _triggerEndWorkout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.cardBorderColor),
        ),
        title: Text(
          'END WORKOUT?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Save this session and view your performance trophy.',
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CONTINUE',
              style: GoogleFonts.outfit(color: Colors.white30, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(activeWorkoutProvider.notifier).saveSession();
            },
            child: Text(
              'SAVE & FINISH',
              style: GoogleFonts.outfit(
                color: AppTheme.cyberCyan,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.cardBorderColor),
        ),
        title: Text(
          'DISCARD SESSION?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Text(
          'Any progress in this session will not be saved.',
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'STAY',
              style: GoogleFonts.outfit(color: Colors.white30, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(activeWorkoutProvider.notifier).reset();
              Navigator.pop(context);
            },
            child: Text(
              'DISCARD',
              style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showTrophySheet(BuildContext context, ActiveWorkoutState state) {
    final timerState = ref.read(workoutTimerProvider);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrophySheet(
        routineName: state.routine?.name ?? 'Workout',
        durationFormatted: timerState.formatted,
        totalWeightKg: state.totalWeightKg,
        completedPercentage: state.completedPercentage,
        completedSets: state.completedSets,
        totalSets: state.totalSets,
        onDone: () {
          Navigator.pop(context); // close sheet
          ref.read(activeWorkoutProvider.notifier).reset();
          Navigator.pop(context); // back to library
        },
      ),
    );
  }
}

// ─── DECOUPLED TIMER HUD WIDGET ───────────────────────────────────────────────

class _TimerHud extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatted = ref.watch(
      workoutTimerProvider.select((s) => s.formatted),
    );
    final isRunning = ref.watch(
      workoutTimerProvider.select((s) => s.isRunning),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SESSION TIME',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white30,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatted,
                style: GoogleFonts.outfit(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.cyberCyan,
                  letterSpacing: 2,
                  height: 1.0,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              isRunning
                  ? ref.read(workoutTimerProvider.notifier).pause()
                  : ref.read(workoutTimerProvider.notifier).resume();
            },
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRunning
                    ? AppTheme.cyberCyan.withOpacity(0.1)
                    : Colors.white.withOpacity(0.06),
                border: Border.all(
                  color: isRunning
                      ? AppTheme.cyberCyan.withOpacity(0.5)
                      : AppTheme.cardBorderColor,
                  width: 1.5,
                ),
              ),
              child: Icon(
                isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: isRunning ? AppTheme.cyberCyan : Colors.white54,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SET LEDGER ROW (STATEFUL for controller isolation) ───────────────────────

class _SetLedgerRow extends StatefulWidget {
  final int setNumber;
  final double weight;
  final int reps;
  final bool isCompleted;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;
  final VoidCallback onToggleComplete;
  final VoidCallback? onDelete;

  const _SetLedgerRow({
    super.key,
    required this.setNumber,
    required this.weight,
    required this.reps,
    required this.isCompleted,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onToggleComplete,
    this.onDelete,
  });

  @override
  State<_SetLedgerRow> createState() => _SetLedgerRowState();
}

class _SetLedgerRowState extends State<_SetLedgerRow> {
  late TextEditingController _weightCtrl;
  late TextEditingController _repsCtrl;
  late FocusNode _weightFocus;
  late FocusNode _repsFocus;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
        text: widget.weight == 0.0 ? '' : widget.weight.toStringAsFixed(1));
    _repsCtrl = TextEditingController(text: widget.reps.toString());
    _weightFocus = FocusNode();
    _repsFocus = FocusNode();
  }

  @override
  void didUpdateWidget(_SetLedgerRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update controller if focus isn't active (not being edited)
    if (!_weightFocus.hasFocus) {
      final newText =
          widget.weight == 0.0 ? '' : widget.weight.toStringAsFixed(1);
      if (_weightCtrl.text != newText) _weightCtrl.text = newText;
    }
    if (!_repsFocus.hasFocus) {
      final newText = widget.reps.toString();
      if (_repsCtrl.text != newText) _repsCtrl.text = newText;
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.isCompleted
            ? AppTheme.cyberCyan.withOpacity(0.04)
            : Colors.transparent,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            // Set number badge
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  '${widget.setNumber}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: widget.isCompleted
                        ? AppTheme.cyberCyan
                        : Colors.white54,
                  ),
                ),
              ),
            ),

            // Weight field
            Expanded(
              flex: 2,
              child: _buildLedgerField(
                controller: _weightCtrl,
                focusNode: _weightFocus,
                hint: '0.0',
                suffix: 'kg',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                onSubmitted: (v) {
                  widget.onWeightChanged(double.tryParse(v) ?? 0.0);
                },
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed != null) widget.onWeightChanged(parsed);
                },
              ),
            ),

            // Reps field
            Expanded(
              flex: 2,
              child: _buildLedgerField(
                controller: _repsCtrl,
                focusNode: _repsFocus,
                hint: '10',
                suffix: '',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (v) {
                  widget.onRepsChanged(int.tryParse(v) ?? 0);
                },
                onChanged: (v) {
                  final parsed = int.tryParse(v);
                  if (parsed != null) widget.onRepsChanged(parsed);
                },
              ),
            ),

            // Complete toggle
            Expanded(
              flex: 1,
              child: Center(
                child: GestureDetector(
                  onTap: widget.onToggleComplete,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isCompleted
                          ? AppTheme.cyberCyan
                          : Colors.transparent,
                      border: Border.all(
                        color: widget.isCompleted
                            ? AppTheme.cyberCyan
                            : AppTheme.cardBorderColor,
                        width: 1.5,
                      ),
                    ),
                    child: widget.isCompleted
                        ? const Icon(Icons.check, color: Colors.black, size: 14)
                        : null,
                  ),
                ),
              ),
            ),

            // Delete action
            SizedBox(
              width: 36,
              child: widget.onDelete != null
                  ? GestureDetector(
                      onTap: widget.onDelete,
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white24,
                        size: 18,
                      ),
                    )
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required String suffix,
    required TextInputType keyboardType,
    required List<TextInputFormatter> inputFormatters,
    required ValueChanged<String> onSubmitted,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.glassFillColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cardBorderColor),
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textAlign: TextAlign.center,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(color: Colors.white24, fontSize: 12),
            suffixText: suffix.isNotEmpty ? suffix : null,
            suffixStyle:
                GoogleFonts.outfit(color: Colors.white38, fontSize: 10),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            isDense: true,
          ),
        ),
      ),
    );
  }
}

// ─── POST-WORKOUT TROPHY SHEET ─────────────────────────────────────────────────

class _TrophySheet extends StatelessWidget {
  final String routineName;
  final String durationFormatted;
  final double totalWeightKg;
  final double completedPercentage;
  final int completedSets;
  final int totalSets;
  final VoidCallback onDone;

  const _TrophySheet({
    required this.routineName,
    required this.durationFormatted,
    required this.totalWeightKg,
    required this.completedPercentage,
    required this.completedSets,
    required this.totalSets,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final pct = completedPercentage.clamp(0.0, 100.0);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: AppTheme.cardBorderColor, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.cardBorderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Trophy icon
            ShaderMask(
              shaderCallback: (b) => AppTheme.secondaryGradient.createShader(b),
              child: const Icon(Icons.emoji_events, color: Colors.white, size: 64),
            ),
            const SizedBox(height: 12),

            Text(
              'SESSION COMPLETE!',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              routineName.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: Colors.white38,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 28),

            // Metrics grid
            Row(
              children: [
                _metricTile('DURATION', durationFormatted, Icons.timer_outlined,
                    AppTheme.cyberCyan),
                const SizedBox(width: 12),
                _metricTile(
                    'WEIGHT LIFTED',
                    '${totalWeightKg.toStringAsFixed(1)} kg',
                    Icons.fitness_center,
                    AppTheme.electricBlue),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _metricTile(
                    'SETS DONE',
                    '$completedSets / $totalSets',
                    Icons.check_circle_outline,
                    AppTheme.amethystPurple),
                const SizedBox(width: 12),
                _metricTile(
                    'COMPLETION',
                    '${pct.toStringAsFixed(0)}%',
                    Icons.bar_chart,
                    AppTheme.warningAmber),
              ],
            ),
            const SizedBox(height: 20),

            // Completion progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PERFORMANCE SCORE',
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white30,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 6,
                    backgroundColor: AppTheme.cardBorderColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      pct >= 80
                          ? AppTheme.cyberCyan
                          : pct >= 50
                              ? AppTheme.warningAmber
                              : Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Done button
            ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                minimumSize: const Size.fromHeight(54),
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
                  alignment: Alignment.center,
                  height: 54,
                  child: Text(
                    'BACK TO LIBRARY',
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
        ),
      ),
    );
  }

  Widget _metricTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.white38,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
