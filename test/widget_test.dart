import 'package:flutter_test/flutter_test.dart';
import 'package:uno_no_mercy/main.dart';

void main() {
  testWidgets('UnoNoMercyApp lobby smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const UnoNoMercyApp());
    expect(find.text('UNO'), findsOneWidget);
    expect(find.text('SHOW \'EM NO MERCY'), findsOneWidget);
    expect(find.text('റൂം ക്രിയേറ്റ് ചെയ്യുക (Create Room)'), findsOneWidget);
  });
}
