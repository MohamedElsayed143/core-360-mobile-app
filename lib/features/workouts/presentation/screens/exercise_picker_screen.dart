import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/workout_provider.dart';

class ExercisePickerScreen extends ConsumerStatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  ConsumerState<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends ConsumerState<ExercisePickerScreen> {
  String _searchQuery = '';

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

              // Filtered list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No exercises found.',
                          style: GoogleFonts.outfit(color: Colors.white30),
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
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: AppTheme.glassFillColor,
                                  border: Border.all(color: AppTheme.cardBorderColor),
                                ),
                                child: exercise.thumbnailUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(9),
                                        child: Image.network(
                                          exercise.thumbnailUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => const Icon(
                                            Icons.fitness_center,
                                            color: AppTheme.cyberCyan,
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.fitness_center, color: AppTheme.cyberCyan),
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
