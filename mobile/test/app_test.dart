import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnishaan/app/app.dart';

void main() {
  testWidgets('placeholder shows translated app name', (tester) async {
    await tester.pumpWidget(const KaamNishaanApp());
    await tester.pumpAndSettle();
    expect(find.text('KaamNishaan'), findsOneWidget);
  });
}
