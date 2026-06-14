import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/main.dart';

void main() {
  testWidgets('Home screen is rendered', (WidgetTester tester) async {
    await tester.pumpWidget(const VolleyScoutApp());

    expect(find.text('Volley Scout'), findsOneWidget);
    expect(find.text('Setup squadre'), findsOneWidget);
  });
}
