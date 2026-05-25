import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/routine.dart';
import '../../domain/entities/routine_exercise.dart';
import '../../domain/entities/set_config.dart';
import '../providers/workout_provider.dart';
import 'exercise_picker_screen.dart';

class RoutineBuilderScreen extends ConsumerStatefulWidget {
  final Routine? existingRoutine;
  const RoutineBuilderScreen({super.key, this.existingRoutine});

  @override
  ConsumerState<RoutineBuilderScreen> createState() => _RoutineBuilderScreenState();
}

class _RoutineBuilderScreenState extends ConsumerState<RoutineBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  List<RoutineExercise> _exercises = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingRoutine?.name ?? '',
    );
    if (widget.existingRoutine != null) {
      // Deep copy existing exercises
      _exercises = widget.existingRoutine!.exercises.map((e) {
        return RoutineExercise(
          workoutId: e.workoutId,
          title: e.title,
          targetMuscle: e.targetMuscle,
          sets: e.sets.map((s) => SetConfig(reps: s.reps, weight: s.weight)).toList(),
          order: e.order,
        );
      }).toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickExercise() async {
    final Exercise? selected = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(
        builder: (context) => const ExercisePickerScreen(),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _exercises.add(
          RoutineExercise(
            workoutId: selected.id,
            title: selected.title,
            targetMuscle: selected.targetMuscle,
            sets: [
              SetConfig(reps: 10, weight: 0.0), // Default 1st set
            ],
            order: _exercises.length,
          ),
        );
      });
    }
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
      // Re-map order indices
      for (int i = 0; i < _exercises.length; i++) {
        _exercises[i] = _exercises[i].copyWith(order: i);
      }
    });
  }

  void _moveExerciseUp(int index) {
    if (index == 0) return;
    setState(() {
      final temp = _exercises[index];
      _exercises[index] = _exercises[index - 1].copyWith(order: index);
      _exercises[index - 1] = temp.copyWith(order: index - 1);
      // Sort to verify array aligns with order
      _exercises.sort((a, b) => a.order.compareTo(b.order));
    });
  }

  void _moveExerciseDown(int index) {
    if (index == _exercises.length - 1) return;
    setState(() {
      final temp = _exercises[index];
      _exercises[index] = _exercises[index + 1].copyWith(order: index);
      _exercises[index + 1] = temp.copyWith(order: index + 1);
      _exercises.sort((a, b) => a.order.compareTo(b.order));
    });
  }

  void _addSet(int exerciseIndex) {
    setState(() {
      final exercise = _exercises[exerciseIndex];
      final lastSet = exercise.sets.isNotEmpty
          ? exercise.sets.last
          : SetConfig(reps: 10, weight: 0.0);
      
      final updatedSets = List<SetConfig>.from(exercise.sets)
        ..add(SetConfig(reps: lastSet.reps, weight: lastSet.weight));
      
      _exercises[exerciseIndex] = exercise.copyWith(sets: updatedSets);
    });
  }

  void _removeSet(int exerciseIndex, int setIndex) {
    setState(() {
      final exercise = _exercises[exerciseIndex];
      if (exercise.sets.length <= 1) {
        // Remove exercise completely if it has 0 sets
        _removeExercise(exerciseIndex);
        return;
      }
      final updatedSets = List<SetConfig>.from(exercise.sets)..removeAt(setIndex);
      _exercises[exerciseIndex] = exercise.copyWith(sets: updatedSets);
    });
  }

  void _updateSetReps(int exerciseIndex, int setIndex, int delta) {
    setState(() {
      final exercise = _exercises[exerciseIndex];
      final sets = List<SetConfig>.from(exercise.sets);
      final newReps = (sets[setIndex].reps + delta).clamp(1, 999);
      sets[setIndex] = sets[setIndex].copyWith(reps: newReps);
      _exercises[exerciseIndex] = exercise.copyWith(sets: sets);
    });
  }

  void _updateSetWeight(int exerciseIndex, int setIndex, double delta) {
    setState(() {
      final exercise = _exercises[exerciseIndex];
      final sets = List<SetConfig>.from(exercise.sets);
      final newWeight = (sets[setIndex].weight + delta).clamp(0.0, 999.0);
      sets[setIndex] = sets[setIndex].copyWith(weight: newWeight);
      _exercises[exerciseIndex] = exercise.copyWith(sets: sets);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PLEASE ADD AT LEAST ONE EXERCISE.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final routine = Routine(
        id: widget.existingRoutine?.id ?? '',
        userId: widget.existingRoutine?.userId ?? '',
        name: _nameController.text.trim().toUpperCase(),
        exercises: _exercises,
        isAiGenerated: widget.existingRoutine?.isAiGenerated ?? false,
        shareCode: widget.existingRoutine?.shareCode,
        createdAt: widget.existingRoutine?.createdAt,
      );

      await ref.read(userRoutinesProvider.notifier).saveRoutine(routine);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ROUTINE SAVED SUCCESSFULLY.',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppTheme.cyberCyan,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.existingRoutine != null ? 'EDIT ROUTINE' : 'NEW ROUTINE',
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
          if (!_isSaving)
            IconButton(
              icon: const Icon(Icons.check, color: AppTheme.cyberCyan, size: 24),
              onPressed: _save,
            ),
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Routine Name Input Field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: TextFormField(
                    controller: _nameController,
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                    textCapitalization: TextCapitalization.characters,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Routine name is required';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'ROUTINE NAME',
                      hintText: 'E.G., SCULPT & BURN SPLIT',
                    ),
                  ),
                ),

                // Selected Exercises Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EXERCISES IN ROUTINE',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: Colors.white54,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickExercise,
                        icon: const Icon(Icons.add, size: 16, color: AppTheme.cyberCyan),
                        label: Text(
                          'ADD EXERCISE',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.cyberCyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Exercises List
                Expanded(
                  child: _exercises.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.fitness_center_outlined, color: Colors.white24, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                'NO EXERCISES ADDED YET.',
                                style: GoogleFonts.outfit(color: Colors.white30, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _pickExercise,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.darkSurface,
                                  foregroundColor: AppTheme.cyberCyan,
                                  side: const BorderSide(color: AppTheme.cardBorderColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'BROWSE LIBRARY',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          itemCount: _exercises.length,
                          itemBuilder: (context, exIdx) {
                            final exercise = _exercises[exIdx];
                            return _buildExerciseCard(exIdx, exercise);
                          },
                        ),
                ),
              ],
            ),
          ),
          
          if (_isSaving)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.cyberCyan),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(int exIdx, RoutineExercise exercise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header of Exercise Block
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                // Ordering Badge
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.glassFillColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${exIdx + 1}',
                    style: GoogleFonts.outfit(
                      color: AppTheme.cyberCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.title,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        exercise.targetMuscle.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cyberCyan,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Reorder up
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white38, size: 20),
                  onPressed: exIdx > 0 ? () => _moveExerciseUp(exIdx) : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                // Reorder down
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white38, size: 20),
                  onPressed: exIdx < _exercises.length - 1 ? () => _moveExerciseDown(exIdx) : null,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                ),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => _removeExercise(exIdx),
                ),
              ],
            ),
          ),
          
          const Divider(color: AppTheme.cardBorderColor, height: 1),

          // Sets list inside the exercise
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: exercise.sets.length,
            itemBuilder: (context, setIdx) {
              final setConf = exercise.sets[setIdx];
              return _buildSetRow(exIdx, setIdx, setConf);
            },
          ),

          // Add set button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: OutlinedButton.icon(
              onPressed: () => _addSet(exIdx),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: AppTheme.cardBorderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add, size: 14),
              label: Text(
                'ADD SET',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetRow(int exIdx, int setIdx, SetConfig setConf) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Set number label
          SizedBox(
            width: 48,
            child: Text(
              'SET ${setIdx + 1}',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white38,
              ),
            ),
          ),
          
          // Reps adjusters
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.white30, size: 18),
                  onPressed: () => _updateSetReps(exIdx, setIdx, -1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${setConf.reps}',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppTheme.cyberCyan, size: 18),
                  onPressed: () => _updateSetReps(exIdx, setIdx, 1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                Text(
                  'REPS',
                  style: GoogleFonts.outfit(fontSize: 9, color: Colors.white30, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          // Weight adjusters
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.white30, size: 18),
                  onPressed: () => _updateSetWeight(exIdx, setIdx, -2.5),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    setConf.weight.toStringAsFixed(1),
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppTheme.cyberCyan, size: 18),
                  onPressed: () => _updateSetWeight(exIdx, setIdx, 2.5),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                Text(
                  'KG',
                  style: GoogleFonts.outfit(fontSize: 9, color: Colors.white30, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Delete set
          IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent, size: 16),
            onPressed: () => _removeSet(exIdx, setIdx),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
