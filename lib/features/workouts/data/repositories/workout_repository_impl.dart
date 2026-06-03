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
    try {
      final querySnapshot = await _client.workoutsCollection.get();
      final list = querySnapshot.docs.map((doc) => ExerciseModel.fromFirestore(doc)).toList();
      if (list.isNotEmpty) {
        return list;
      }
    } catch (_) {}

    // Fallback list of 12 standard premium workouts so that exercises ALWAYS appear initially without manual seeding
    return [
      Exercise(
        id: 'bench_press_001',
        title: 'Barbell Bench Press',
        description: 'A classic upper-body strength exercise that targets chest, front deltoids, and triceps.',
        targetMuscle: 'chest',
        thumbnailUrl: 'https://assets.core360.app/thumbnails/bench_press.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=rT7DgCr-3pg',
        aiSupported: false,
      ),
      Exercise(
        id: 'push_ups_002',
        title: 'Push-Up',
        description: 'A bodyweight exercise targeting the chest, shoulders, triceps, and core stability.',
        targetMuscle: 'chest',
        thumbnailUrl: 'https://assets.core360.app/thumbnails/push_ups.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=IODxDxX7oi4',
        aiSupported: true,
      ),
      Exercise(
        id: 'squats_003',
        title: 'Bodyweight Squat',
        description: 'A fundamental lower body movement targeting quadriceps, glutes, and hamstrings.',
        targetMuscle: 'quadriceps',
        thumbnailUrl: 'https://assets.core360.app/thumbnails/squat.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=aclHkVaku9U',
        aiSupported: true,
      ),
      Exercise(
        id: 'pull_ups_004',
        title: 'Pull-Up',
        description: 'An advanced upper body pulling movement targeting the latissimus dorsi, upper back, and biceps.',
        targetMuscle: 'upper_back',
        thumbnailUrl: 'https://assets.core360.app/thumbnails/pull_up.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=eGo4IYlbE5g',
        aiSupported: false,
      ),
      Exercise(
        id: 'plank_005',
        title: 'Forearm Plank',
        description: 'An isometric core strength exercise that maintains a straight body line.',
        targetMuscle: 'abs',
        thumbnailUrl: 'https://assets.core360.app/thumbnails/plank.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=B296mZDhrWY',
        aiSupported: true,
      ),
      Exercise(
        id: 'bicep_curl_006',
        title: 'Dumbbell Bicep Curl',
        description: 'An isolation exercise for building upper arm mass and elbow flexor strength.',
        targetMuscle: 'biceps',
        thumbnailUrl: 'https://assets.core360.app/thumbnails/bicep_curl.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=ykJmrZ5v0Up',
        aiSupported: false,
      ),
      Exercise(
        id: 'tricep_extension_007',
        title: 'Overhead Dumbbell Tricep Extension',
        description: 'Targeting the triceps brachii long head with dumbbells over the crown.',
        targetMuscle: 'triceps',
        thumbnailUrl: 'https://assets.core360.app/thumbnails/tricep_extension.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=X-iV-sGEL1s',
        aiSupported: false,
      ),
      Exercise(
        id: 'overhead_press_008',
        title: 'Dumbbell Overhead Shoulder Press',
        description: 'An excellent vertical press for shoulders, front delts, and triceps.',
        targetMuscle: 'front_deltoids',
        thumbnailUrl: 'https://assets.core360.app/thumbnails/overhead_press.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=B-aVuy917zQ',
        aiSupported: false,
      ),
      Exercise(
        id: 'romanian_deadlift_009',
        title: 'Romanian Deadlift',
        description: 'A hip hinge pattern targeting posterior chain muscles like hamstrings and glutes.',
        targetMuscle: 'hamstring',
        thumbnailUrl: 'https://assets.core360.app/thumbnails/romanian_deadlift.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=XowK9_K25VA',
        aiSupported: false,
      ),
      Exercise(
        id: 'calve_raises_010',
        title: 'Standing Calf Raise',
        description: 'Isolation movement for calf hypertrophy and ankle plantarflexion strength.',
        targetMuscle: 'calves',
        thumbnailUrl: 'https://assets.core360.app/thumbnails/calf_raise.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=YM21oT-Vyc4',
        aiSupported: false,
      ),
      Exercise(
        id: 'lateral_raises_011',
        title: 'Dumbbell Lateral Raise',
        description: 'An isolation exercise for widening the visual shoulders by working lateral deltoids.',
        targetMuscle: 'back_deltoids',
        thumbnailUrl: 'https://assets.core360.app/thumbnails/lateral_raise.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=3VcKaXatAM0',
        aiSupported: false,
      ),
      Exercise(
        id: 'leg_raises_012',
        title: 'Hanging Leg Raise',
        description: 'An advanced core movement targeting rectus abdominis and hip flexor complexes.',
        targetMuscle: 'abs',
        thumbnailUrl: 'https://assets.core360.app/thumbnails/leg_raise.jpg',
        videoUrl: 'https://www.youtube.com/watch?v=hdng3Nm1x_E',
        aiSupported: false,
      ),
    ];
  }

  @override
  Future<List<Routine>> getUserRoutines(String userId) async {
    final querySnapshot = await _client.routinesCollection
        .where('userId', isEqualTo: userId)
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

    // Sort locally by createdAt descending to avoid composite index requirements
    routines.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

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
