// ignore_for_file: subtype_of_sealed_class, annotate_overrides

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:core_360_app/features/onboarding/domain/entities/user_profile.dart';
import 'package:core_360_app/features/onboarding/domain/repositories/auth_repository.dart';
import 'package:core_360_app/features/onboarding/presentation/providers/auth_provider.dart';
import 'package:core_360_app/features/onboarding/presentation/screens/onboarding_survey_screen.dart';
import 'package:core_360_app/features/onboarding/data/repositories/auth_repository_impl.dart';
import 'package:core_360_app/core/theme/app_theme.dart';

// ─── MOCK IMPLEMENTATIONS ───────────────────────────────────────────

class MockUser extends Fake implements fb.User {
  final String _uid;
  final String? _email;
  final String? _displayName;

  MockUser({
    required String uid,
    String? email,
    String? displayName,
  })  : _uid = uid,
        _email = email,
        _displayName = displayName;

  @override
  String get uid => _uid;

  @override
  String? get email => _email;

  @override
  String? get displayName => _displayName;
}

class MockUserCredential extends Fake implements fb.UserCredential {
  final fb.User? _user;
  MockUserCredential(this._user);

  @override
  fb.User? get user => _user;
}

class MockAuthRepository implements AuthRepository {
  final StreamController<fb.User?> _authController = StreamController<fb.User?>.broadcast();
  final Map<String, UserProfile> _profiles = {};
  fb.User? _currentUser;

  int saveProfileCalls = 0;
  int signInCalls = 0;
  int signUpCalls = 0;
  int signOutCalls = 0;

  @override
  Stream<fb.User?> get authStateChanges {
    final controller = StreamController<fb.User?>.broadcast();
    controller.add(_currentUser);
    _authController.stream.listen((event) {
      if (!controller.isClosed) {
        controller.add(event);
      }
    });
    return controller.stream;
  }

  void emitUser(fb.User? user) {
    _currentUser = user;
    _authController.add(user);
  }

  @override
  Future<fb.UserCredential> signInWithEmailAndPassword(String email, String password) async {
    signInCalls++;
    if (email == 'error@error.com') {
      throw fb.FirebaseAuthException(
        code: 'user-not-found',
        message: 'Invalid credentials provided.',
      );
    }
    final user = MockUser(uid: 'mock-uid-123', email: email, displayName: 'John Doe');
    emitUser(user);
    return MockUserCredential(user);
  }

  @override
  Future<fb.UserCredential> signUpWithEmailAndPassword(String email, String password, String name) async {
    signUpCalls++;
    if (email == 'error@error.com') {
      throw fb.FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'The email address is already in use by another account.',
      );
    }
    final user = MockUser(uid: 'mock-uid-123', email: email, displayName: name);
    emitUser(user);
    return MockUserCredential(user);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    emitUser(null);
  }

  @override
  Future<void> saveUserProfile(String userId, UserProfile profile) async {
    saveProfileCalls++;
    _profiles[userId] = profile;
  }

  @override
  Future<UserProfile?> getUserProfile(String userId) async {
    return _profiles[userId];
  }

  @override
  Future<void> reauthenticate(String password) async {}

  @override
  Future<void> changePassword(String newPassword) async {}

  @override
  Future<void> updateEmail(String newEmail) async {}

  @override
  Future<void> updateDisplayName(String newName) async {}

  @override
  Future<void> updatePhotoURL(String url) async {}

  @override
  Future<String> uploadProfilePhoto(String userId, String filePath) async => '';

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> deleteAllUserData(String userId) async {}

  @override
  Future<void> enableTwoFactorAuth(String userId, String phoneNumber) async {}

  @override
  Future<void> disableTwoFactorAuth(String userId) async {}

  @override
  Future<Map<String, dynamic>> exportUserData(String userId) async => {};

  @override
  Future<void> updateFitnessProfile(String userId, UserProfile profile) async {}

  void dispose() {
    _authController.close();
  }
}

// ─── UNIT AND WIDGET TEST SUITE ─────────────────────────────────────

void main() {
  late MockAuthRepository mockAuthRepository;
  late ProviderContainer container;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    mockAuthRepository.dispose();
  });

  group('AuthNotifier State Transitions', () {
    test('Initial state is AuthInitial', () {
      final state = container.read(authProvider);
      expect(state, isA<AuthInitial>());
    });

    test('Unauthenticated state is entered when auth state stream emits null', () async {
      // Initialize notifier
      container.read(authProvider);

      mockAuthRepository.emitUser(null);
      
      // Let stream asynchronous events propagate
      await Future.delayed(const Duration(milliseconds: 10));

      final state = container.read(authProvider);
      expect(state, isA<Unauthenticated>());
    });

    test('AuthenticatedWithoutProfile is entered when logged in but has no Firestore profile', () async {
      // Initialize notifier
      container.read(authProvider);

      final user = MockUser(uid: 'user-456', email: 'test@core360.com');
      mockAuthRepository.emitUser(user);

      await Future.delayed(const Duration(milliseconds: 10));

      final state = container.read(authProvider);
      expect(state, isA<AuthenticatedWithoutProfile>());
      expect((state as AuthenticatedWithoutProfile).user.uid, 'user-456');
    });

    test('AuthenticatedWithProfile is entered when logged in and profile exists', () async {
      // Initialize notifier
      container.read(authProvider);

      final user = MockUser(uid: 'user-789', email: 'verified@core360.com');
      final profile = UserProfile(
        age: 25,
        height: 180,
        weight: 80,
        goals: ['Muscle Gain'],
      );

      // Seed mock profile
      await mockAuthRepository.saveUserProfile(user.uid, profile);

      mockAuthRepository.emitUser(user);
      await Future.delayed(const Duration(milliseconds: 10));

      final state = container.read(authProvider);
      expect(state, isA<AuthenticatedWithProfile>());
      expect((state as AuthenticatedWithProfile).user.uid, 'user-789');
      expect((state).profile.age, 25);
    });

    test('Onboarding survey submission saves to Firestore and transitions to AuthenticatedWithProfile', () async {
      // Initialize notifier
      container.read(authProvider);

      final user = MockUser(uid: 'user-999', email: 'onboard@core360.com');
      mockAuthRepository.emitUser(user);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(container.read(authProvider), isA<AuthenticatedWithoutProfile>());

      final newProfile = UserProfile(
        age: 30,
        height: 175,
        weight: 70,
        goals: ['Flexibility'],
      );

      await container.read(authProvider.notifier).submitOnboarding(newProfile);

      expect(mockAuthRepository.saveProfileCalls, 1);
      expect(container.read(authProvider), isA<AuthenticatedWithProfile>());
      final finalState = container.read(authProvider) as AuthenticatedWithProfile;
      expect(finalState.profile.goals.first, 'Flexibility');
    });
    test('signUp with fingerprintEnabled = true registers, saves to secure storage, and signs out', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final notifier = container.read(authProvider.notifier);

      await notifier.signUp(
        email: 'newuser@core360.com',
        password: 'securePassword123',
        name: 'New User',
        fingerprintEnabled: true,
      );

      expect(mockAuthRepository.signUpCalls, 1);
      expect(mockAuthRepository.signOutCalls, 1);

      final state = container.read(authProvider);
      expect(state, isA<Unauthenticated>());

      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'fingerprint_enabled'), 'true');
      expect(await storage.read(key: 'saved_email'), 'newuser@core360.com');
      expect(await storage.read(key: 'saved_password'), 'securePassword123');
    });

    test('signUp with fingerprintEnabled = false registers, clears secure storage, and signs out', () async {
      FlutterSecureStorage.setMockInitialValues({
        'fingerprint_enabled': 'true',
        'saved_email': 'olduser@core360.com',
        'saved_password': 'oldpassword',
      });
      final notifier = container.read(authProvider.notifier);

      await notifier.signUp(
        email: 'anotheruser@core360.com',
        password: 'securePassword456',
        name: 'Another User',
        fingerprintEnabled: false,
      );

      expect(mockAuthRepository.signUpCalls, 1);
      expect(mockAuthRepository.signOutCalls, 1);

      final state = container.read(authProvider);
      expect(state, isA<Unauthenticated>());

      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'fingerprint_enabled'), 'false');
      expect(await storage.read(key: 'saved_email'), isNull);
      expect(await storage.read(key: 'saved_password'), isNull);
    });

    test('signUp failure sets state to AuthError and does not sign out', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final notifier = container.read(authProvider.notifier);

      await notifier.signUp(
        email: 'error@error.com',
        password: 'password123',
        name: 'Error User',
        fingerprintEnabled: false,
      );

      expect(mockAuthRepository.signUpCalls, 1);
      expect(mockAuthRepository.signOutCalls, 0);

      final state = container.read(authProvider);
      expect(state, isA<AuthError>());
      expect((state as AuthError).message, contains('already in use'));
    });
  });

  group('Onboarding Biometric Survey Validation Checks', () {
    testWidgets('Age field validator boundary checks', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: OnboardingSurveyScreen()),
          ),
        ),
      );

      // Verify page loaded
      expect(find.text('Step 1 of 3'), findsOneWidget);

      // Find Age Text Field
      final ageField = find.byType(TextFormField).at(0);
      expect(ageField, findsOneWidget);

      // Enter invalid lower bound age (< 10)
      await tester.enterText(ageField, '9');
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Age must be between 10 and 120'), findsOneWidget);

      // Enter invalid upper bound age (> 120)
      await tester.enterText(ageField, '121');
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Age must be between 10 and 120'), findsOneWidget);

      // Enter valid age
      await tester.enterText(ageField, '25');
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Age must be between 10 and 120'), findsNothing);
    });

    testWidgets('Height field validator boundary checks', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: OnboardingSurveyScreen()),
          ),
        ),
      );

      // Find Height Text Field
      final heightField = find.byType(TextFormField).at(1);
      expect(heightField, findsOneWidget);

      // Enter invalid lower bound height (< 100)
      await tester.enterText(heightField, '99');
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Height must be between 100 and 250 cm'), findsOneWidget);

      // Enter invalid upper bound height (> 250)
      await tester.enterText(heightField, '251');
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Height must be between 100 and 250 cm'), findsOneWidget);

      // Enter valid height
      await tester.enterText(heightField, '175');
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Height must be between 100 and 250 cm'), findsNothing);
    });

    testWidgets('Weight field validator boundary checks', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: OnboardingSurveyScreen()),
          ),
        ),
      );

      // Find Weight Text Field
      final weightField = find.byType(TextFormField).at(2);
      expect(weightField, findsOneWidget);

      // Enter invalid lower bound weight (< 30)
      await tester.enterText(weightField, '29');
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Weight must be between 30 and 300 kg'), findsOneWidget);

      // Enter invalid upper bound weight (> 300)
      await tester.enterText(weightField, '301');
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Weight must be between 30 and 300 kg'), findsOneWidget);

      // Enter valid weight
      await tester.enterText(weightField, '72.5');
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Weight must be between 30 and 300 kg'), findsNothing);
    });
  });
}
