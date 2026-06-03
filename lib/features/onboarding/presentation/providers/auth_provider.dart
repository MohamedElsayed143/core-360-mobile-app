import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';

// ─── AUTHENTICATION STATES ──────────────────────────────────────────

abstract class AuthState {
  const AuthState();
}

/// App loading initial configs
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Progressive action loading indicators
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Anonymous visitor
class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// Signed up/in, but requires 3-Step biometrics survey
class AuthenticatedWithoutProfile extends AuthState {
  final fb.User user;
  const AuthenticatedWithoutProfile(this.user);
}

/// Completed survey and fully onboarded to home dashboard
class AuthenticatedWithProfile extends AuthState {
  final fb.User user;
  final UserProfile profile;
  const AuthenticatedWithProfile(this.user, this.profile);
}

/// Operation failure
class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

// ─── AUTHENTICATION STATE NOTIFIER ──────────────────────────────────

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _authRepository;
  StreamSubscription<fb.User?>? _authSubscription;

  @override
  AuthState build() {
    _authRepository = ref.watch(authRepositoryProvider);
    
    // Subscribe to auth state updates on initialization
    _authSubscription?.cancel();
    _authSubscription = _authRepository.authStateChanges.listen((user) {
      _onAuthStateChanged(user);
    });

    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    return const AuthInitial();
  }

  Future<void> _onAuthStateChanged(fb.User? user) async {
    if (user == null) {
      if (!ref.mounted) return;
      state = const Unauthenticated();
    } else {
      if (!ref.mounted) return;
      state = const AuthLoading();
      try {
        final profile = await _authRepository.getUserProfile(user.uid);
        if (!ref.mounted) return;
        if (profile == null) {
          state = AuthenticatedWithoutProfile(user);
        } else {
          state = AuthenticatedWithProfile(user, profile);
        }
      } catch (e) {
        if (!ref.mounted) return;
        state = AuthError(e.toString());
      }
    }
  }

  /// Submits credentials for active authentication check-in
  Future<void> signIn(String email, String password) async {
    state = const AuthLoading();
    try {
      await _authRepository.signInWithEmailAndPassword(email, password);
    } on fb.FirebaseAuthException catch (e) {
      if (!ref.mounted) return;
      state = AuthError(e.message ?? 'Authentication credentials rejected.');
    } catch (e) {
      if (!ref.mounted) return;
      state = AuthError(e.toString());
    }
  }

  /// Signs up with email, password, name and logs entry document
  Future<void> signUp(String email, String password, String name) async {
    state = const AuthLoading();
    try {
      await _authRepository.signUpWithEmailAndPassword(email, password, name);
    } on fb.FirebaseAuthException catch (e) {
      if (!ref.mounted) return;
      state = AuthError(e.message ?? 'Registration attempt failed.');
    } catch (e) {
      if (!ref.mounted) return;
      state = AuthError(e.toString());
    }
  }

  /// Logs out and resets active sessions
  Future<void> signOut() async {
    state = const AuthLoading();
    try {
      await _authRepository.signOut();
    } catch (e) {
      if (!ref.mounted) return;
      state = AuthError(e.toString());
    }
  }

  /// Submits the 3-step biometric survey to Firestore, transitions state to active
  Future<void> submitOnboarding(UserProfile profile) async {
    final currentState = state;
    if (currentState is! AuthenticatedWithoutProfile) return;

    state = const AuthLoading();
    try {
      await _authRepository.saveUserProfile(currentState.user.uid, profile);
      if (!ref.mounted) return;
      state = AuthenticatedWithProfile(currentState.user, profile);
    } catch (e) {
      if (!ref.mounted) return;
      state = AuthError(e.toString());
    }
  }

  /// Clears any auth errors and returns user to standard layout checks
  void clearError() {
    if (state is AuthError) {
      final currentUser = fb.FirebaseAuth.instance.currentUser;
      _onAuthStateChanged(currentUser);
    }
  }

  // ─── SETTINGS ACTIONS ────────────────────────────────────────────

  /// Updates display name in Firebase Auth + Firestore
  Future<String?> updateDisplayName(String newName) async {
    try {
      await _authRepository.updateDisplayName(newName);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Updates email — reauthenticates first, then forces sign-out
  Future<String?> updateEmail(String newEmail, String password) async {
    try {
      await _authRepository.reauthenticate(password);
      await _authRepository.updateEmail(newEmail);
      return null;
    } on fb.FirebaseAuthException catch (e) {
      return e.message ?? 'Failed to update email.';
    } catch (e) {
      return e.toString();
    }
  }

  /// Changes password — reauthenticates first
  Future<String?> changePassword(String currentPassword, String newPassword) async {
    try {
      await _authRepository.reauthenticate(currentPassword);
      await _authRepository.changePassword(newPassword);
      return null;
    } on fb.FirebaseAuthException catch (e) {
      return e.message ?? 'Failed to change password.';
    } catch (e) {
      return e.toString();
    }
  }

  /// Enables two-factor auth with phone number
  Future<String?> enableTwoFactorAuth(String phoneNumber) async {
    final currentState = state;
    if (currentState is! AuthenticatedWithProfile && currentState is! AuthenticatedWithoutProfile) {
      return 'Not authenticated.';
    }
    final uid = currentState is AuthenticatedWithProfile
        ? currentState.user.uid
        : (currentState as AuthenticatedWithoutProfile).user.uid;
    try {
      await _authRepository.enableTwoFactorAuth(uid, phoneNumber);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Exports all user data as a JSON string
  Future<String?> exportUserData() async {
    final currentState = state;
    if (currentState is! AuthenticatedWithProfile && currentState is! AuthenticatedWithoutProfile) {
      return 'Not authenticated.';
    }
    final uid = currentState is AuthenticatedWithProfile
        ? currentState.user.uid
        : (currentState as AuthenticatedWithoutProfile).user.uid;
    try {
      final data = await _authRepository.exportUserData(uid);
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (e) {
      return e.toString();
    }
  }

  /// Deletes account — reauthenticates then removes everything
  Future<String?> deleteAccount(String password) async {
    try {
      await _authRepository.reauthenticate(password);
      await _authRepository.deleteAccount();
      return null;
    } on fb.FirebaseAuthException catch (e) {
      return e.message ?? 'Failed to delete account.';
    } catch (e) {
      return e.toString();
    }
  }

  /// Uploads a profile photo from a local file path (saved as base64 data URI)
  Future<String?> uploadProfilePhoto(String filePath) async {
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) return 'Not authenticated.';
      final photoURL = await _authRepository.uploadProfilePhoto(user.uid, filePath);
      if (!ref.mounted) return null;
      final currentState = state;
      if (currentState is AuthenticatedWithProfile) {
        final updated = UserProfile(
          age: currentState.profile.age,
          height: currentState.profile.height,
          weight: currentState.profile.weight,
          bodyFat: currentState.profile.bodyFat,
          waterPercentage: currentState.profile.waterPercentage,
          muscleMass: currentState.profile.muscleMass,
          goals: currentState.profile.goals,
          injuries: currentState.profile.injuries,
          photoURL: photoURL,
        );
        state = AuthenticatedWithProfile(currentState.user, updated);
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Updates the fitness profile
  Future<String?> updateFitnessProfile(UserProfile profile) async {
    final currentState = state;
    if (currentState is! AuthenticatedWithProfile) return 'Profile not loaded.';
    try {
      await _authRepository.updateFitnessProfile(currentState.user.uid, profile);
      if (!ref.mounted) return null;
      state = AuthenticatedWithProfile(currentState.user, profile);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

// ─── AUTHENTICATION PROVIDER EXPOSURE ───────────────────────────────

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
