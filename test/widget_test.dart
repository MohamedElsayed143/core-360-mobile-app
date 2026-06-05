import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_360_app/main.dart';

void main() {
  testWidgets('MyApp renders FirebaseErrorScreen when not initialized', (WidgetTester tester) async {
    // Build our app with isFirebaseInitialized set to false
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(isFirebaseInitialized: false),
      ),
    );

    // Verify that the FirebaseErrorScreen contents are visible
    expect(find.text('FIREBASE NOT CALIBRATED'), findsOneWidget);
    expect(find.text('DEVELOPER QUICK RUN CHECK:'), findsOneWidget);
  });
}
