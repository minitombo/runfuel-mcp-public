import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runfuel/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('RunFuel home and navigation render', (tester) async {
    await tester.pumpWidget(const RunFuelApp());
    await tester.pumpAndSettle();

    expect(find.text('Build consistency.'), findsOneWidget);
    expect(find.text('Training'), findsOneWidget);

    await tester.tap(find.text('Coach'));
    await tester.pumpAndSettle();
    expect(find.text('AI Coach'), findsOneWidget);
  });
}
