import 'package:ayyam/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts the Ayyam application', (tester) async {
    await tester.pumpWidget(const MainApp());

    expect(find.text('Make each\nday count.'), findsOneWidget);
    expect(find.text('Begin'), findsOneWidget);
  });
}
