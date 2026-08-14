import 'package:dokploy_mobile/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('demo command center renders', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: DokployMobileApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Demo Infrastructure'), findsOneWidget);
    expect(find.text('RECENT DEPLOYMENTS'), findsOneWidget);
    expect(find.text('Servers'), findsWidgets);
  });
}
