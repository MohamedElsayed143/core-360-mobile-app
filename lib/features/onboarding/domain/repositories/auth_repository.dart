import 'package:firebase_auth/firebase_auth.dart';
import '../entities/user_profile.dart';

abstract class AuthRepository {
  /// Stream tracking the current authenticated state of the user
  Stream<User?> get authStateChanges;

  /// Logs in a user with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password);

  /// Registers a user with email, password, and sets a display name
  Future<UserCredential> signUpWithEmailAndPassword(String email, String password, String name);

  /// Closes the current session
  Future<void> signOut();

  /// Saves or updates the UserProfile inside a sub-collection for a specific user ID
  Future<void> saveUserProfile(String userId, UserProfile profile);

  /// Loads the UserProfile from the Firestore user document sub-collection
  Future<UserProfile?> getUserProfile(String userId);

  /// Re-authenticates the current user with their password
  Future<void> reauthenticate(String password);

  /// Changes the user's password (requires prior reauthentication)
  Future<void> changePassword(String newPassword);

  /// Updates the user's email address, signs them out after
  Future<void> updateEmail(String newEmail);

  /// Updates the user's display name
  Future<void> updateDisplayName(String newName);

  /// Updates the user's photo URL
  Future<void> updatePhotoURL(String url);

  /// Uploads a profile photo and returns the download URL
  Future<String> uploadProfilePhoto(String userId, String filePath);

  /// Deletes the user account and all associated data
  Future<void> deleteAccount();

  /// Deletes all user data from Firestore collections
  Future<void> deleteAllUserData(String userId);

  /// Enables two-factor auth by saving phone number and flag
  Future<void> enableTwoFactorAuth(String userId, String phoneNumber);

  /// Disables two-factor auth
  Future<void> disableTwoFactorAuth(String userId);

  /// Exports all user data as a JSON map
  Future<Map<String, dynamic>> exportUserData(String userId);

  /// Updates the fitness profile (UserProfile)
  Future<void> updateFitnessProfile(String userId, UserProfile profile);
}
