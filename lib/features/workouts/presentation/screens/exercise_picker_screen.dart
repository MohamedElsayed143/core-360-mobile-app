import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/exercise.dart';
import '../providers/workout_provider.dart';
import '../widgets/exercise_gif_widget.dart';

class ExercisePickerScreen extends ConsumerStatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  ConsumerState<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends ConsumerState<ExercisePickerScreen> {
  String _searchQuery = '';

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

  void _showCreateCustomExerciseDialog() {
    final nameController = TextEditingController();
    String targetMuscle = 'arms';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.darkSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppTheme.cardBorderColor),
            ),
            title: Text(
              'CREATE CUSTOM EXERCISE',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add a custom custom-tailored exercise to your routine database.',
                    style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  
                  // Exercise Name Input
                  TextField(
                    controller: nameController,
                    style: GoogleFonts.outfit(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'EXERCISE TITLE',
                      hintText: 'E.G., INCLINE HAMMER CURLS',
                    ),
                  ),
                  const SizedBox(height: 18),
                  
                  // Target Muscle Dropdown
                  Text(
                    'TARGET MUSCLE',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white30,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: targetMuscle,
                        dropdownColor: AppTheme.darkSurface,
                        style: GoogleFonts.outfit(color: Colors.white),
                        icon: const Icon(Icons.arrow_drop_down, color: AppTheme.cyberCyan),
                        isExpanded: true,
                        items: ['chest', 'back', 'legs', 'arms', 'abs', 'shoulders']
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m.toUpperCase()),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              targetMuscle = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text(
                  'CANCEL',
                  style: GoogleFonts.outfit(color: Colors.white30, fontWeight: FontWeight.bold),
                ),
                onPressed: () => Navigator.pop(dialogContext),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cyberCyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'CREATE',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  final title = nameController.text.trim();
                  if (title.isEmpty) return;
                  
                  final customExercise = Exercise(
                    id: 'custom_${title.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}',
                    title: title,
                    description: 'Custom empty exercise registered in personal database.',
                    targetMuscle: targetMuscle,
                    thumbnailUrl: '',
                    videoUrl: '',
                    aiSupported: false,
                  );
                  
                  Navigator.pop(dialogContext); // pop dialog
                  Navigator.pop(context, customExercise); // pop picker screen returning exercise
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workoutsAsync = ref.watch(globalWorkoutsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'SELECT EXERCISE',
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
      ),
      body: workoutsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.cyberCyan),
        ),
        error: (err, stack) => Center(
          child: Text(
            'Error loading library: $err',
            style: GoogleFonts.outfit(color: Colors.redAccent),
          ),
        ),
        data: (exercises) {
          final filtered = exercises.where((ex) {
            final titleMatch = ex.title.toLowerCase().contains(_searchQuery.toLowerCase());
            final muscleMatch = ex.targetMuscle.toLowerCase().contains(_searchQuery.toLowerCase());
            return titleMatch || muscleMatch;
          }).toList();

          return Column(
            children: [
              // Search Input Box
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: GoogleFonts.outfit(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search title or target muscle (e.g. chest, abs)...',
                    prefixIcon: const Icon(Icons.search, color: Colors.white30, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.white30, size: 18),
                            onPressed: () {
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
              ),

              // + CREATE CUSTOM EXERCISE BUTTON
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
                child: GestureDetector(
                  onTap: _showCreateCustomExerciseDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.amethystPurple.withOpacity(0.4), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.amethystPurple.withOpacity(0.05),
                          blurRadius: 8,
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, color: AppTheme.amethystPurple, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "CAN'T FIND AN EXERCISE? CREATE CUSTOM",
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.amethystPurple,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Filtered list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: Text(
                            "No Exercises Found. Tap '+' to create a custom one",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: Colors.white30,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final exercise = filtered[idx];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.darkSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.cyberCyan.withOpacity(0.01),
                                  blurRadius: 10,
                                )
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              onTap: () {
                                Navigator.pop(context, exercise);
                              },
                              leading: GestureDetector(
                                onTap: exercise.videoUrl.isNotEmpty ? () => _launchVideo(exercise.videoUrl) : null,
                                child: ExerciseGifWidget(
                                  gifUrl: exercise.gifUrl,
                                  thumbnailUrl: exercise.thumbnailUrl,
                                  width: 50,
                                  height: 50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      exercise.title,
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (exercise.videoUrl.isNotEmpty) ...[
                                    IconButton(
                                      icon: const Icon(
                                        Icons.play_circle_outline,
                                        color: AppTheme.cyberCyan,
                                        size: 22,
                                      ),
                                      onPressed: () => _launchVideo(exercise.videoUrl),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (exercise.aiSupported)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.amethystPurple.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.amethystPurple.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        'AI',
                                        style: GoogleFonts.outfit(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.amethystPurple,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cyberCyan.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      exercise.targetMuscle.toUpperCase(),
                                      style: GoogleFonts.outfit(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.cyberCyan,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    exercise.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: Colors.white54,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: const Icon(
                                Icons.add_circle_outline,
                                color: AppTheme.cyberCyan,
                                size: 24,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
