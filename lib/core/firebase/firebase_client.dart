import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Central client manager mapping Cloud Firestore root collections.
class FirebaseClient {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  FirebaseClient({
    required this.auth,
    required this.firestore,
  });

  // ─── ROOT COLLECTIONS ───────────────────────────────────────────────

  /// Users Root Collection
  CollectionReference<Map<String, dynamic>> get usersCollection =>
      firestore.collection('users');

  /// Workouts Global Library Root Collection
  CollectionReference<Map<String, dynamic>> get workoutsCollection =>
      firestore.collection('workouts');

  /// Routines Root Collection
  CollectionReference<Map<String, dynamic>> get routinesCollection =>
      firestore.collection('routines');

  /// Active/Completed Sessions Root Collection
  CollectionReference<Map<String, dynamic>> get sessionsCollection =>
      firestore.collection('sessions');

  /// AI Analysis Session History logs Root Collection
  CollectionReference<Map<String, dynamic>> get aiAnalysisSessionsCollection =>
      firestore.collection('ai_analysis_sessions');

  /// Detailed skeletal/stress pose analytics Root Collection
  CollectionReference<Map<String, dynamic>> get analysisResultsCollection =>
      firestore.collection('analysis_results');

  /// Active or resolved safety/injury alerts Root Collection
  CollectionReference<Map<String, dynamic>> get alertsCollection =>
      firestore.collection('alerts');

  /// KPI Tracking Data points Root Collection
  CollectionReference<Map<String, dynamic>> get progressCollection =>
      firestore.collection('progress');

  /// AI Coach Chat Threads Root Collection
  CollectionReference<Map<String, dynamic>> get chatsCollection =>
      firestore.collection('chats');

  /// Daily Scheduled AI Workout Plans Root Collection
  CollectionReference<Map<String, dynamic>> get aiPlansCollection =>
      firestore.collection('ai_plans');

  /// Global Shared Routines Lookup Collection
  CollectionReference<Map<String, dynamic>> get sharedRoutinesCollection =>
      firestore.collection('shared_routines');
}

// ─── RIVERPOD PROVIDERS ─────────────────────────────────────────────

/// Provider for raw FirebaseAuth instance
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// Provider for raw FirebaseFirestore instance
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Injectable FirebaseClient singleton mapping collections and auth handles
final firebaseClientProvider = Provider<FirebaseClient>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);
  return FirebaseClient(auth: auth, firestore: firestore);
});

/// Notifier to bypass Firebase calibration checks for offline simulated test runs.
/// Uses Riverpod 3.x [Notifier] pattern (StateProvider was removed in v3).
class FirebaseBypassNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
  void toggle() => state = !state;
}

final firebaseBypassProvider =
    NotifierProvider<FirebaseBypassNotifier, bool>(FirebaseBypassNotifier.new);
