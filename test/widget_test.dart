import 'package:flutter_test/flutter_test.dart';
import 'package:erp_canada/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const ERPCanadaApp());
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
