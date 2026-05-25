import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/firebase/firebase_client.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/routine.dart';
import '../../domain/repositories/workout_repository.dart';
import '../models/exercise_model.dart';
import '../models/routine_exercise_model.dart';
import '../models/routine_model.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  final FirebaseClient _client;

  WorkoutRepositoryImpl(this._client);

  @override
  Future<List<Exercise>> getGlobalWorkouts() async {
    final querySnapshot = await _client.workoutsCollection.get();
    return querySnapshot.docs.map((doc) => ExerciseModel.fromFirestore(doc)).toList();
  }

  @override
  Future<List<Routine>> getUserRoutines(String userId) async {
    final querySnapshot = await _client.routinesCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    final List<Routine> routines = [];

    for (final doc in querySnapshot.docs) {
      // Fetch sub-collection of exercises for this routine
      final exercisesSnapshot = await doc.reference
          .collection('exercises')
          .orderBy('order', descending: false)
          .get();

      final exercises = exercisesSnapshot.docs
          .map((eDoc) => RoutineExerciseModel.fromFirestore(eDoc))
          .toList();

      routines.add(RoutineModel.fromFirestore(doc, exercises));
    }

    return routines;
  }

  @override
  Future<void> saveRoutine(Routine routine) async {
    final routineId = routine.id.isEmpty
        ? _client.routinesCollection.doc().id
        : routine.id;

    final routineRef = _client.routinesCollection.doc(routineId);
    final exercisesCollectionRef = routineRef.collection('exercises');

    // 1. Delete existing exercises in subcollection to avoid orphans during updates
    final existingExercises = await exercisesCollectionRef.get();
    
    final batch = _client.firestore.batch();

    for (final doc in existingExercises.docs) {
      batch.delete(doc.reference);
    }

    // 2. Set routine parent doc
    final model = RoutineModel(
      id: routineId,
      userId: routine.userId,
      name: routine.name,
      exercises: routine.exercises,
      isAiGenerated: routine.isAiGenerated,
      shareCode: routine.shareCode,
      createdAt: routine.createdAt ?? DateTime.now(),
    );
    batch.set(routineRef, model.toFirestore(), SetOptions(merge: true));

    // 3. Add new exercises in subcollection
    for (int i = 0; i < routine.exercises.length; i++) {
      final exercise = routine.exercises[i];
      final exModel = RoutineExerciseModel(
        workoutId: exercise.workoutId,
        title: exercise.title,
        targetMuscle: exercise.targetMuscle,
        sets: exercise.sets,
        order: i,
      );
      // Create document under exercises subcollection
      final exRef = exercisesCollectionRef.doc('${exercise.workoutId}_$i');
      batch.set(exRef, exModel.toMap());
    }

    await batch.commit();
  }

  @override
  Future<void> deleteRoutine(String routineId) async {
    final routineRef = _client.routinesCollection.doc(routineId);
    final exercisesCollectionRef = routineRef.collection('exercises');

    final existingExercises = await exercisesCollectionRef.get();
    final batch = _client.firestore.batch();

    for (final doc in existingExercises.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(routineRef);

    await batch.commit();
  }

  @override
  Future<String> createSharedRoutine(Routine routine, {DateTime? expiresAt}) async {
    // Generate an 8-char uppercase alphanumeric code, e.g. CORE7X9A
    final code = _generateShareCode();

    final sharedRef = _client.sharedRoutinesCollection.doc(code);
    final exerciseMaps = routine.exercises
        .map((e) => RoutineExerciseModel.fromEntity(e).toMap())
        .toList();

    await sharedRef.set({
      'code': code,
      'name': routine.name,
      'exercises': exerciseMaps,
      'creatorId': routine.userId,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
    });

    // Update local routine to store shareCode
    if (routine.id.isNotEmpty) {
      await _client.routinesCollection.doc(routine.id).update({
        'shareCode': code,
      });
    }

    return code;
  }

  @override
  Future<Routine?> getSharedRoutineByCode(String code) async {
    final docSnapshot = await _client.sharedRoutinesCollection.doc(code.toUpperCase().trim()).get();
    if (!docSnapshot.exists) return null;

    final data = docSnapshot.data() ?? {};
    final expiresAtTimestamp = data['expiresAt'] as Timestamp?;
    if (expiresAtTimestamp != null && expiresAtTimestamp.toDate().isBefore(DateTime.now())) {
      // Shared routine expired
      return null;
    }

    final rawExercises = data['exercises'] as List? ?? [];
    final exercises = rawExercises
        .map((e) => RoutineExerciseModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return Routine(
      id: '', // Will be assigned on import
      userId: '', // Will be assigned to current user on import
      name: data['name'] as String? ?? 'Shared Routine',
      exercises: exercises,
      isAiGenerated: false,
      shareCode: code,
      createdAt: DateTime.now(),
    );
  }

  String _generateShareCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    
    // We can start with "CORE" and append 4 random alphanumeric chars
    final buffer = StringBuffer('CORE');
    for (int i = 0; i < 4; i++) {
      buffer.write(chars[rand.nextInt(chars.length)]);
    }
    return buffer.toString();
  }
}

// ─── RIVERPOD PROVIDERS ─────────────────────────────────────────────

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  final client = ref.watch(firebaseClientProvider);
  return WorkoutRepositoryImpl(client);
});
