import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('App smoke test initializes SeliscoApp', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SeliscoApp(),
      ),
    );

    // Verify app renders with title
    expect(find.byType(SeliscoApp), findsOneWidget);
  });
}
