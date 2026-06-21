import 'package:flutter_test/flutter_test.dart';
import 'package:kkcoder_mobile/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KkCoderApp());
    expect(find.text('KKCODER'), findsOneWidget);
  });
}
