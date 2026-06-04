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
}
