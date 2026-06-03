import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_client.dart';

/// Seeder utility to populate standard global workouts if they don't exist yet.
class FirestoreSeeding {
  final FirebaseClient _client;

  FirestoreSeeding(this._client);

  /// Seeds standard global workouts library if the workouts collection is empty.
  Future<void> seedGlobalWorkoutsIfEmpty() async {
    try {
      final querySnapshot = await _client.workoutsCollection.limit(1).get();
      if (querySnapshot.docs.isNotEmpty) {
        // Collection already has data, no seeding needed.
        return;
      }

      // List of standard global workouts covering primary TargetMuscles
      final List<Map<String, dynamic>> defaultWorkouts = [
        {
          'id': 'bench_press_001',
          'title': 'Barbell Bench Press',
          'description': 'A classic upper-body strength exercise that targets chest, front deltoids, and triceps.',
          'targetMuscle': 'chest',
          'thumbnailUrl': 'https://assets.core360.app/thumbnails/bench_press.jpg',
          'videoUrl': 'https://www.youtube.com/watch?v=gRVjAtPip0Y',
          'aiSupported': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'push_ups_002',
          'title': 'Push-Up',
          'description': 'A bodyweight exercise targeting the chest, shoulders, triceps, and core stability.',
          'targetMuscle': 'chest',
          'thumbnailUrl': 'https://assets.core360.app/thumbnails/push_ups.jpg',
          'videoUrl': 'https://www.youtube.com/watch?v=IODxDxX7oi4',
          'aiSupported': true, // Google ML Kit pose detection landmarking supports this
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'squats_003',
          'title': 'Bodyweight Squat',
          'description': 'A fundamental lower body movement targeting quadriceps, glutes, and hamstrings.',
          'targetMuscle': 'quadriceps',
          'thumbnailUrl': 'https://assets.core360.app/thumbnails/squat.jpg',
          'videoUrl': 'https://www.youtube.com/watch?v=UXJrBgI2RxA',
          'aiSupported': true, // Google ML Kit pose detection landmarking supports this
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'pull_ups_004',
          'title': 'Pull-Up',
          'description': 'An advanced upper body pulling movement targeting the latissimus dorsi, upper back, and biceps.',
          'targetMuscle': 'upper_back',
          'thumbnailUrl': 'https://assets.core360.app/thumbnails/pull_up.jpg',
          'videoUrl': 'https://www.youtube.com/watch?v=eGo4IYlbE5g',
          'aiSupported': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'plank_005',
          'title': 'Forearm Plank',
          'description': 'An isometric core strength exercise that maintains a straight body line.',
          'targetMuscle': 'abs',
          'thumbnailUrl': 'https://assets.core360.app/thumbnails/plank.jpg',
          'videoUrl': 'https://www.youtube.com/watch?v=pSHjTRCQxIw',
          'aiSupported': true, // Google ML Kit pose detection landmarking supports this
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'bicep_curl_006',
          'title': 'Dumbbell Bicep Curl',
          'description': 'An isolation exercise for building upper arm mass and elbow flexor strength.',
          'targetMuscle': 'biceps',
          'thumbnailUrl': 'https://assets.core360.app/thumbnails/bicep_curl.jpg',
          'videoUrl': 'https://www.youtube.com/watch?v=ykJmrZ5v0Up',
          'aiSupported': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'tricep_extension_007',
          'title': 'Overhead Dumbbell Tricep Extension',
          'description': 'Targeting the triceps brachii long head with dumbbells over the crown.',
          'targetMuscle': 'triceps',
          'thumbnailUrl': 'https://assets.core360.app/thumbnails/tricep_extension.jpg',
          'videoUrl': 'https://www.youtube.com/watch?v=-Vyt2Qg89yI',
          'aiSupported': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'overhead_press_008',
          'title': 'Dumbbell Overhead Shoulder Press',
          'description': 'An excellent vertical press for shoulders, front delts, and triceps.',
          'targetMuscle': 'front_deltoids',
          'thumbnailUrl': 'https://assets.core360.app/thumbnails/overhead_press.jpg',
          'videoUrl': 'https://www.youtube.com/watch?v=B-aVuy917zQ',
          'aiSupported': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'romanian_deadlift_009',
          'title': 'Romanian Deadlift',
          'description': 'A hip hinge pattern targeting posterior chain muscles like hamstrings and glutes.',
          'targetMuscle': 'hamstring',
          'thumbnailUrl': 'https://assets.core360.app/thumbnails/romanian_deadlift.jpg',
          'videoUrl': 'https://www.youtube.com/watch?v=JCXUYuzwEqM',
          'aiSupported': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'calve_raises_010',
          'title': 'Standing Calf Raise',
          'description': 'Isolation movement for calf hypertrophy and ankle plantarflexion strength.',
          'targetMuscle': 'calves',
          'thumbnailUrl': 'https://assets.core360.app/thumbnails/calf_raise.jpg',
          'videoUrl': 'https://www.youtube.com/watch?v=3UWi44yN-wM',
          'aiSupported': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'lateral_raises_011',
          'title': 'Dumbbell Lateral Raise',
          'description': 'An isolation exercise for widening the visual shoulders by working lateral deltoids.',
          'targetMuscle': 'back_deltoids',
          'thumbnailUrl': 'https://assets.core360.app/thumbnails/lateral_raise.jpg',
          'videoUrl': 'https://www.youtube.com/watch?v=3VcKaXatAM0',
          'aiSupported': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'leg_raises_012',
          'title': 'Hanging Leg Raise',
          'description': 'An advanced core movement targeting rectus abdominis and hip flexor complexes.',
          'targetMuscle': 'abs',
          'thumbnailUrl': 'https://assets.core360.app/thumbnails/leg_raise.jpg',
          'videoUrl': 'https://www.youtube.com/watch?v=hdng3Nm1x_E',
          'aiSupported': false,
          'createdAt': FieldValue.serverTimestamp(),
        }
      ];

      final batch = _client.firestore.batch();
      for (final workout in defaultWorkouts) {
        final docRef = _client.workoutsCollection.doc(workout['id'] as String);
        batch.set(docRef, workout);
      }
      await batch.commit();
    } catch (e) {
      // Gracefully handle/throw seeding failure
      rethrow;
    }
  }
}
