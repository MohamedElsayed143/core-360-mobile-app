import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import '../../../../core/firebase/firebase_client.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_profile_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseClient _client;

  AuthRepositoryImpl(this._client);

  FirebaseAuth get _auth => _client.auth;
  FirebaseFirestore get _firestore => _client.firestore;

  // ─── EXISTING METHODS ─────────────────────────────────────────

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<UserCredential> signUpWithEmailAndPassword(String email, String password, String name) async {
    final credential = await _auth.createUserWithEmailAndPassword(
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
    await _auth.signOut();
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

  // ─── NEW SETTINGS METHODS ─────────────────────────────────────

  @override
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('No authenticated user.');
    final credential = EmailAuthProvider.credential(email: user.email!, password: password);
    await user.reauthenticateWithCredential(credential);
  }

  @override
  Future<void> changePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user.');
    await user.updatePassword(newPassword);
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user.');
    await user.verifyBeforeUpdateEmail(newEmail.trim());
    await _client.usersCollection.doc(user.uid).update({
      'email': newEmail.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateDisplayName(String newName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user.');
    await user.updateDisplayName(newName.trim());
    await _client.usersCollection.doc(user.uid).update({
      'name': newName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updatePhotoURL(String url) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user.');
    await user.updatePhotoURL(url);
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user.');
    final uid = user.uid;
    await deleteAllUserData(uid);
    await user.delete();
  }

  @override
  Future<void> deleteAllUserData(String userId) async {
    final batch = _firestore.batch();

    final userDoc = _client.usersCollection.doc(userId);
    batch.delete(userDoc);

    final sessions = await _client.sessionsCollection.where('userId', isEqualTo: userId).get();
    for (final doc in sessions.docs) { batch.delete(doc.reference); }

    final routines = await _client.routinesCollection.where('userId', isEqualTo: userId).get();
    for (final doc in routines.docs) { batch.delete(doc.reference); }

    final chats = await _client.chatsCollection.where('userId', isEqualTo: userId).get();
    for (final doc in chats.docs) { batch.delete(doc.reference); }

    final aiPlans = await _client.aiPlansCollection.where('userId', isEqualTo: userId).get();
    for (final doc in aiPlans.docs) { batch.delete(doc.reference); }

    final analysisResults = await _client.analysisResultsCollection.where('userId', isEqualTo: userId).get();
    for (final doc in analysisResults.docs) { batch.delete(doc.reference); }

    final alerts = await _client.alertsCollection.where('userId', isEqualTo: userId).get();
    for (final doc in alerts.docs) { batch.delete(doc.reference); }

    final progress = await _client.progressCollection.where('userId', isEqualTo: userId).get();
    for (final doc in progress.docs) { batch.delete(doc.reference); }

    final shared = await _client.sharedRoutinesCollection.where('userId', isEqualTo: userId).get();
    for (final doc in shared.docs) { batch.delete(doc.reference); }

    final aiAnalysis = await _client.aiAnalysisSessionsCollection.where('userId', isEqualTo: userId).get();
    for (final doc in aiAnalysis.docs) { batch.delete(doc.reference); }

    await batch.commit();
  }

  @override
  Future<void> enableTwoFactorAuth(String userId, String phoneNumber) async {
    await _client.usersCollection.doc(userId).update({
      'phoneFor2FA': phoneNumber.trim(),
      'isTwoFactorEnabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> disableTwoFactorAuth(String userId) async {
    await _client.usersCollection.doc(userId).update({
      'phoneFor2FA': FieldValue.delete(),
      'isTwoFactorEnabled': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<Map<String, dynamic>> exportUserData(String userId) async {
    final user = _auth.currentUser;
    final data = <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': null,
      'sessions': [],
      'routines': [],
      'analysisResults': [],
      'progress': [],
      'alerts': [],
    };

    if (user != null) {
      data['authProfile'] = {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'emailVerified': user.emailVerified,
        'phoneNumber': user.phoneNumber,
        'createdAt': user.metadata.creationTime?.toIso8601String(),
      };
    }

    final userDoc = await _client.usersCollection.doc(userId).get();
    if (userDoc.exists) data['profile'] = userDoc.data();

    final sessions = await _client.sessionsCollection.where('userId', isEqualTo: userId).get();
    data['sessions'] = sessions.docs.map((d) => d.data()).toList();

    final routines = await _client.routinesCollection.where('userId', isEqualTo: userId).get();
    data['routines'] = routines.docs.map((d) => d.data()).toList();

    final analysis = await _client.analysisResultsCollection.where('userId', isEqualTo: userId).get();
    data['analysisResults'] = analysis.docs.map((d) => d.data()).toList();

    final progressDocs = await _client.progressCollection.where('userId', isEqualTo: userId).get();
    data['progress'] = progressDocs.docs.map((d) => d.data()).toList();

    final alertsDocs = await _client.alertsCollection.where('userId', isEqualTo: userId).get();
    data['alerts'] = alertsDocs.docs.map((d) => d.data()).toList();

    return data;
  }

  @override
  Future<void> updateFitnessProfile(String userId, UserProfile profile) async {
    await saveUserProfile(userId, profile);
  }

  @override
  Future<String> uploadProfilePhoto(String userId, String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image.');

    final resized = img.copyResize(image, width: 256, height: 256);
    final jpeg = img.encodeJpg(resized, quality: 70);
    final b64 = base64Encode(jpeg);
    final dataUri = 'data:image/jpeg;base64,$b64';

    await _client.usersCollection.doc(userId).update({
      'photoURL': dataUri,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _client.usersCollection
        .doc(userId)
        .collection('user_profiles')
        .doc('profile')
        .set({'photoURL': dataUri}, SetOptions(merge: true));

    return dataUri;
  }
}

// ─── RIVERPOD REPOSITORY PROVIDER ───────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(firebaseClientProvider);
  return AuthRepositoryImpl(client);
});
