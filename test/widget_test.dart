import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_app_frontend/features/auth/presentation/auth_state.dart';
import 'package:travel_app_frontend/main.dart';

void main() {
  testWidgets('TravelApp smoke test renders login view', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(() => FakeAuthNotifier()),
        ],
        child: const TravelApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trailmark'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
  });
}

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState.unauthenticated();
}
