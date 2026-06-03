// ignore_for_file: subtype_of_sealed_class, annotate_overrides

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_360_app/core/firebase/firebase_client.dart';

// ─── CUSTOM FAKE IMPLEMENTATIONS FOR OFFLINE TESTING ──────────────────

class FakeFirebaseAuth extends Fake implements FirebaseAuth {}

class FakeFirebaseFirestore extends Fake implements FirebaseFirestore {
  final Map<String, CollectionReference<Map<String, dynamic>>> collections = {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return collections.putIfAbsent(
      collectionPath,
      () => FakeCollectionReference(collectionPath),
    );
  }
}

class FakeCollectionReference extends Fake implements CollectionReference<Map<String, dynamic>> {
  final String path;
  FakeCollectionReference(this.path);

  @override
  String get id => path.split('/').last;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return FakeDocumentReference(path ?? 'auto-id');
  }
}

class FakeDocumentReference extends Fake implements DocumentReference<Map<String, dynamic>> {
  final String path;
  FakeDocumentReference(this.path);
}

// ─── MAIN UNIT TESTS ──────────────────────────────────────────────────

void main() {
  group('FirebaseClient tests', () {
    late FakeFirebaseAuth mockAuth;
    late FakeFirebaseFirestore mockFirestore;
    late FirebaseClient client;

    setUp(() {
      mockAuth = FakeFirebaseAuth();
      mockFirestore = FakeFirebaseFirestore();
      client = FirebaseClient(auth: mockAuth, firestore: mockFirestore);
    });

    test('Collection references map to correct Firestore paths', () {
      expect(client.usersCollection.id, 'users');
      expect(client.workoutsCollection.id, 'workouts');
      expect(client.routinesCollection.id, 'routines');
      expect(client.sessionsCollection.id, 'sessions');
      expect(client.aiAnalysisSessionsCollection.id, 'ai_analysis_sessions');
      expect(client.analysisResultsCollection.id, 'analysis_results');
      expect(client.alertsCollection.id, 'alerts');
      expect(client.progressCollection.id, 'progress');
      expect(client.chatsCollection.id, 'chats');
      expect(client.aiPlansCollection.id, 'ai_plans');
      expect(client.sharedRoutinesCollection.id, 'shared_routines');
    });

    test('Riverpod container successfully resolves client with overrides', () {
      final container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          firestoreProvider.overrideWithValue(mockFirestore),
        ],
      );

      final resolvedClient = container.read(firebaseClientProvider);
      expect(resolvedClient.auth, mockAuth);
      expect(resolvedClient.firestore, mockFirestore);
      container.dispose();
    });
  });
}
