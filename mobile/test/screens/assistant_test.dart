import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/me_section/assistant_section/assistant_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:kaamnishaan/infrastructure/services/session_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

Future<void> _ignoreApp(Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (_) {}
}

final at = DateTime(2026, 11, 5, 12);

AssistantMessageOutModel msg(String id, String role, String text, {List<SourceReportModel>? reports, List<SourceJobModel>? jobs, int photos = 0}) =>
    AssistantMessageOutModel(id: id, role: role, text: text, at: at, reports: reports, jobs: jobs, photoCount: photos);

AssistantOutModel chat({int used = 0, int? limit = 200, bool paused = false, bool available = true}) => AssistantOutModel(
      data: const [],
      used: used,
      limit: limit,
      paused: paused,
      renewsAt: DateTime(2026, 12, 1),
      available: available,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TranslationService translation;
  late MockAssistantRepository assistant;
  late SessionService session;

  setUpAll(() async => initializeDateFormatting());

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    SharedPreferences.setMockInitialValues({});
    translation = TranslationService(await PreferencesService.create());
    assistant = MockAssistantRepository();
    session = SessionService(tokens: MemoryTokenStorage(), repository: MockAuthRepository());
  });

  AssistantController make() => AssistantController(assistant: assistant, translation: translation, session: session);

  test('M36 asks, then shows the answer with where it came from', () async {
    when(() => assistant.chat()).thenAnswer((_) async => ApiSuccess<AssistantOutModel>(chat()));
    final report = SourceReportModel(
      id: 'r1',
      number: 'R-0871',
      jobId: 'j1',
      customer: 'Green Valley Clinic',
      status: 'shared',
      at: DateTime(2026, 8, 12, 10),
    );
    when(() => assistant.ask(any())).thenAnswer(
      (_) async => ApiSuccess<AskOutModel>(
        AskOutModel(
          question: msg('q1', 'user', 'When did we last service Green Valley Clinic?'),
          answer: msg('a1', 'assistant', '12 August.', reports: [report], photos: 3),
          used: 1,
          limit: 200,
          paused: false,
        ),
      ),
    );
    final c = make();
    await c.load();
    expect(c.canAsk, isTrue);
    c.input.text = 'When did we last service Green Valley Clinic?';
    await c.onSend();
    verify(() => assistant.ask('When did we last service Green Valley Clinic?')).called(1);
    expect([for (final m in c.messages) m.id], ['q1', 'a1']);
    expect(c.sourcesLine(c.messages.last), 'From 1 report · 3 photos');
    expect(c.reportLine(report), '12 Aug · Approved · sent to customer');
    expect((c.used.value, c.input.text), (1, ''));
  });

  test('M36 chips: "What is missing?" asks at once, "Last visit?" waits for a name', () async {
    when(() => assistant.chat()).thenAnswer((_) async => ApiSuccess<AssistantOutModel>(chat()));
    when(() => assistant.ask(any())).thenAnswer(
      (_) async => ApiFailure<AskOutModel>(const ApiException(code: 'unknown', message: 'x')),
    );
    final c = make();
    await c.load();
    await c.onChip(c.chips.first);
    expect(c.input.text, 'When did we last visit ');
    verifyNever(() => assistant.ask(any()));
    await _ignoreApp(() => c.onChip(c.chips[1]));
    verify(() => assistant.ask("What is still missing on today's jobs?")).called(1);
    expect(c.input.text, "What is still missing on today's jobs?"); // kept to try again
    expect(c.messages, isEmpty);
    const job = SourceJobModel(id: 'j2', title: 'AC service', customer: 'Mehta house', status: 'in_progress', photos: [], missing: ['during', 'voice']);
    expect(c.missingLine(job), 'Missing: photo while working, voice note');
  });

  test('M36 the monthly limit pauses chat', () async {
    when(() => assistant.chat()).thenAnswer((_) async => ApiSuccess<AssistantOutModel>(chat(used: 199)));
    when(() => assistant.ask(any())).thenAnswer(
      (_) async => ApiFailure<AskOutModel>(
        const ApiException(code: 'ai_limit_reached', message: 'used up', details: {'used': 200, 'limit': 200}),
      ),
    );
    final c = make();
    await c.load();
    c.input.text = 'Hi';
    await c.onSend();
    expect((c.paused.value, c.pausedCard.value, c.canAsk), (true, true, false));
    expect(c.pausedBody, "Your company used this month's 200 AI questions. It starts again on 1 Dec.");
    expect((c.usedLine, c.usedFraction), ('200 of 200 questions', 1.0));
    c.onNotNow();
    expect(c.pausedCard.value, isFalse);
  });
}
