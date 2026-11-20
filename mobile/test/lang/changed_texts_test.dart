import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kaamnishaan/infrastructure/lang/changed_texts.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.clearTranslations();
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('hi', 'IN');
  });

  test('A25 changed texts replace the built-in ones and use GetX placeholders', () {
    final original = 'common.save'.tr;
    ChangedTexts.apply({
      'hi': {'common.save': 'अभी सेव करें', 'msg.support_body': 'जवाब: {subject}'},
      'xx': {'common.save': 'ignored'},
    });
    expect('common.save'.tr, 'अभी सेव करें');
    expect('msg.support_body'.trParams({'subject': 'लॉगिन'}), 'जवाब: लॉगिन');

    // changed back to the original: the server stops sending it, the built-in text returns
    ChangedTexts.apply({});
    expect('common.save'.tr, original);
  });

  test('toGetx maps languages to the app locales', () {
    expect(ChangedTexts.toGetx({'gu': {'a': '{n} b'}}), {'gu_IN': {'a': '@n b'}});
  });
}
