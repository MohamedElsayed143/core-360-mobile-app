import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/routine.dart';
import '../../data/repositories/workout_repository_impl.dart';
import 'workout_provider.dart';

class ShareState {
  final bool isLoading;
  final String? shareCode;
  final Routine? importedRoutine;
  final String? errorMessage;

  ShareState({
    this.isLoading = false,
    this.shareCode,
    this.importedRoutine,
    this.errorMessage,
  });

  ShareState copyWith({
    bool? isLoading,
    String? shareCode,
    Routine? importedRoutine,
    String? errorMessage,
  }) {
    return ShareState(
      isLoading: isLoading ?? this.isLoading,
      shareCode: shareCode ?? this.shareCode,
      importedRoutine: importedRoutine ?? this.importedRoutine,
      errorMessage: errorMessage,
    );
  }
}

class ShareNotifier extends Notifier<ShareState> {
  @override
  ShareState build() {
    return ShareState();
  }

  Future<String?> generateShareCode(Routine routine) async {
    state = state.copyWith(isLoading: true, errorMessage: null, shareCode: null);
    try {
      final repo = ref.read(workoutRepositoryProvider);
      // Expiration date: 7 days from now
      final expiresAt = DateTime.now().add(const Duration(days: 7));
      final code = await repo.createSharedRoutine(routine, expiresAt: expiresAt);
      state = state.copyWith(isLoading: false, shareCode: code);
      
      // Refresh local routines list to reflect updated shareCode
      ref.read(userRoutinesProvider.notifier).refresh();
      return code;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to generate share code: $e');
      return null;
    }
  }

  Future<Routine?> lookupShareCode(String code) async {
    state = state.copyWith(isLoading: true, errorMessage: null, importedRoutine: null);
    try {
      final repo = ref.read(workoutRepositoryProvider);
      final routine = await repo.getSharedRoutineByCode(code);
      if (routine == null) {
        state = state.copyWith(isLoading: false, errorMessage: 'Invalid or expired share code.');
        return null;
      }
      state = state.copyWith(isLoading: false, importedRoutine: routine);
      return routine;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Error looking up share code: $e');
      return null;
    }
  }

  Future<void> importRoutine(Routine sharedRoutine, String customName) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final imported = Routine(
        id: '', // Will be generated
        userId: '', // Will be set by saveRoutine notifier to current user ID
        name: customName.trim().isEmpty ? sharedRoutine.name : customName.trim(),
        exercises: sharedRoutine.exercises,
        isAiGenerated: false,
        shareCode: sharedRoutine.shareCode,
        createdAt: DateTime.now(),
      );
      await ref.read(userRoutinesProvider.notifier).saveRoutine(imported);
      state = state.copyWith(isLoading: false, importedRoutine: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to import routine: $e');
      rethrow;
    }
  }

  void clearState() {
    state = ShareState();
  }
}

final shareProvider = NotifierProvider<ShareNotifier, ShareState>(() {
  return ShareNotifier();
});
