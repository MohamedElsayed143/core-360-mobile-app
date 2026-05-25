import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/firebase/firebase_client.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_profile_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseClient _client;

  AuthRepositoryImpl(this._client);

  @override
  Stream<User?> get authStateChanges => _client.auth.authStateChanges();

  @override
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    return await _client.auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<UserCredential> signUpWithEmailAndPassword(String email, String password, String name) async {
    final credential = await _client.auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (credential.user != null) {
      await credential.user!.updateDisplayName(name);
      
      // Initialize the root user metadata document in Firestore
      await _client.usersCollection.doc(credential.user!.uid).set({
        'email': email.trim(),
        'name': name.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isTwoFactorEnabled': false,
        'settings': <String, dynamic>{},
      });
    }

    return credential;
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> saveUserProfile(String userId, UserProfile profile) async {
    final model = UserProfileModel.fromEntity(profile);
    
    // Save to the `user_profiles` sub-collection under standard `profile` document key
    await _client.usersCollection
        .doc(userId)
        .collection('user_profiles')
        .doc('profile')
        .set(model.toFirestore(), SetOptions(merge: true));

    // Also touch the parent user document's updatedAt timestamp
    await _client.usersCollection.doc(userId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<UserProfile?> getUserProfile(String userId) async {
    final docSnapshot = await _client.usersCollection
        .doc(userId)
        .collection('user_profiles')
        .doc('profile')
        .get();

    if (docSnapshot.exists) {
      return UserProfileModel.fromFirestore(docSnapshot);
    }
    return null;
  }
}

// ─── RIVERPOD REPOSITORY PROVIDER ───────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(firebaseClientProvider);
  return AuthRepositoryImpl(client);
});
