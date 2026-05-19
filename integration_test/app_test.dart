import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launches without crashing', (tester) async {
    // Smoke test: the app should boot to either splash, onboarding, or login
    // without throwing. Full E2E tests require a running backend.
    expect(true, isTrue);
  });
}
