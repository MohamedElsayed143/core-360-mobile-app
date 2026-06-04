import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  bool _ignoreAuthStateChanges = false;

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
    if (_ignoreAuthStateChanges) return;
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
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required bool fingerprintEnabled,
  }) async {
    state = const AuthLoading();
    _ignoreAuthStateChanges = true;
    bool success = false;
    try {
      final credential = await _authRepository.signUpWithEmailAndPassword(email, password, name);
      
      if (credential.user != null) {
        const storage = FlutterSecureStorage();
        if (fingerprintEnabled) {
          await storage.write(key: 'saved_email', value: email.trim());
          await storage.write(key: 'saved_password', value: password);
          await storage.write(key: 'fingerprint_enabled', value: 'true');
        } else {
          await storage.delete(key: 'saved_email');
          await storage.delete(key: 'saved_password');
          await storage.write(key: 'fingerprint_enabled', value: 'false');
        }
      }

      await _authRepository.signOut();
      success = true;
    } on fb.FirebaseAuthException catch (e) {
      if (!ref.mounted) return;
      state = AuthError(e.message ?? 'Registration attempt failed.');
    } catch (e) {
      if (!ref.mounted) return;
      state = AuthError(e.toString());
    } finally {
      _ignoreAuthStateChanges = false;
      if (success) {
        await _onAuthStateChanged(null);
      }
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

  /// Authenticates with cached biometric credentials.
  /// Catches PlatformException from local_auth channel separately
  /// to provide clear biometric-specific error messages.
  Future<void> signInWithBiometrics(String email, String password) async {
    state = const AuthLoading();
    try {
      await _authRepository.signInWithEmailAndPassword(email, password);
    } on fb.FirebaseAuthException catch (e) {
      if (!ref.mounted) return;
      state = AuthError(e.message ?? 'Biometric credentials expired. Please sign in manually.');
    } on PlatformException catch (e) {
      if (!ref.mounted) return;
      state = AuthError('Biometric platform error: ${e.message ?? e.code}');
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
      // Re-evaluate session states
      final currentUser = fb.FirebaseAuth.instance.currentUser;
      _onAuthStateChanged(currentUser);
    }
  }
}

// ─── AUTHENTICATION PROVIDER EXPOSURE ───────────────────────────────

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
