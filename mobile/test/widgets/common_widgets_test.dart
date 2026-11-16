import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnishaan/UI/common_widgets/kn_custom_button.dart';
import 'package:kaamnishaan/UI/common_widgets/kn_number_keypad.dart';
import 'package:kaamnishaan/UI/common_widgets/kn_otp_boxes.dart';
import 'package:kaamnishaan/UI/theme/kn_app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(theme: KnTheme.light(const Locale('en')), home: Scaffold(body: child));

void main() {
  testWidgets('a disabled button still says why when tapped', (tester) async {
    var tapped = 0;
    var why = 0;
    await tester.pumpWidget(_wrap(KnCustomButton(text: 'Send code', enabled: false, onTap: () => tapped++, onDisabledTap: () => why++)));
    await tester.tap(find.text('Send code'));
    expect(tapped, 0);
    expect(why, 1);
  });

  testWidgets('a loading button shows a spinner and ignores taps', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(_wrap(KnCustomButton(text: 'Send code', loading: true, onTap: () => tapped++)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(KnCustomButton));
    expect(tapped, 0);
  });

  testWidgets('keypad sends digits and delete', (tester) async {
    final typed = <String>[];
    await tester.pumpWidget(_wrap(KnNumberKeypad(onDigit: typed.add, onBackspace: () => typed.add('<'))));
    await tester.tap(find.byKey(const ValueKey('key-4')));
    await tester.tap(find.byKey(const ValueKey('key-0')));
    await tester.tap(find.byKey(const ValueKey('key-<')));
    expect(typed, ['4', '0', '<']);
  });

  testWidgets('code boxes show the typed digits', (tester) async {
    await tester.pumpWidget(_wrap(const KnOtpBoxes(code: '472')));
    expect(find.text('4'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });
}
