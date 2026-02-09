import 'package:flutter_test/flutter_test.dart';
import 'package:foryou/main.dart';

void main() {
  testWidgets('Foryou AI app loads with dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const ForyouApp());
    await tester.pumpAndSettle();
    expect(find.text('QUICK SCAN'), findsOneWidget);
  });
}
