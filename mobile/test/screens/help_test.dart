import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/me_section/help_new_section/help_new_controller.dart';
import 'package:kaamnishaan/UI/screens/me_section/help_section/help_controller.dart';
import 'package:kaamnishaan/UI/screens/me_section/help_ticket_section/help_ticket_controller.dart';
import 'package:kaamnishaan/UI/screens/me_section/messages_section/messages_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

final now = DateTime(2026, 10, 31, 12, 10);

/// Toasts and navigation need the running app; the state changes before them.
Future<void> _ignoreApp(Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (_) {}
}

TicketOutModel ticket(String id, String status, {List<TicketMessageOutModel>? messages, DateTime? last}) =>
    TicketOutModel(
      id: id,
      number: 'T-10$id',
      subject: 'Report stuck',
      category: 'problem',
      status: status,
      createdAt: now,
      lastMessageAt: last ?? now,
      lastFrom: status == 'waiting' ? 'staff' : 'user',
      messages: messages,
    );

TicketMessageOutModel msg(String id, String body, {bool support = false}) => TicketMessageOutModel(
      id: id,
      body: body,
      fromSupport: support,
      author: support ? null : 'Ravi Kumar',
      createdAt: now,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockSupportRepository repo;
  late TranslationService translation;

  setUpAll(() async {
    await initializeDateFormatting();
    registerFallbackValue(const TicketCreateModel(category: 'problem', subject: '', body: ''));
  });

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    SharedPreferences.setMockInitialValues({});
    translation = TranslationService(await PreferencesService.create());
    repo = MockSupportRepository();
  });

  test('Help lists the requests and counts the ones support answered', () async {
    when(() => repo.list()).thenAnswer(
      (_) async => ApiSuccess<List<TicketOutModel>>([
        ticket('1', 'waiting'),
        ticket('2', 'solved', last: DateTime(2026, 10, 20, 9)),
      ]),
    );
    final c = HelpController(repository: repo, translation: translation, clock: () => now);
    await c.load();
    expect(c.items.length, 2);
    expect(c.waitingOnMe, 1);
    expect(c.when(c.items.first), startsWith('12:10'));
    expect(c.when(c.items.last), '20 Oct');
  });

  test('a new request needs a subject and a message, then sends what was typed', () async {
    when(() => repo.create(any())).thenAnswer((_) async => ApiSuccess<TicketOutModel>(ticket('1', 'open')));
    final c = HelpNewController(dictation: fakeDictation(), repository: repo, appVersion: () async => '1.0.0+1');
    c.onInit();
    expect(c.ready, isFalse);
    c.onDisabledTap();
    expect(c.error.value, 'Write a short subject (3 letters or more).');
    c.subject.text = 'Report stuck';
    c.onDisabledTap();
    expect(c.error.value, 'Tell us a little more (10 letters or more).');
    c.message.text = 'It has been loading for 10 minutes.';
    c.category.value = 'billing';
    expect(c.ready, isTrue);
    await _ignoreApp(c.onSend);
    final sent = verify(() => repo.create(captureAny())).captured.single as TicketCreateModel;
    expect((sent.category, sent.subject, sent.body, sent.appVersion),
        ('billing', 'Report stuck', 'It has been loading for 10 minutes.', '1.0.0+1'));
    expect(c.label('feature'), 'An idea');
  });

  test('a request shows the conversation; replying and "It\'s sorted" update it', () async {
    final first = ticket('1', 'waiting', messages: [msg('a', 'Report stuck'), msg('b', 'Please refresh.', support: true)]);
    when(() => repo.get('t1')).thenAnswer((_) async => ApiSuccess<TicketOutModel>(first));
    when(() => repo.reply('t1', 'Works now')).thenAnswer(
      (_) async => ApiSuccess<TicketOutModel>(ticket('1', 'open', messages: [...first.messages!, msg('c', 'Works now')])),
    );
    when(() => repo.solve('t1')).thenAnswer((_) async => ApiSuccess<TicketOutModel>(ticket('1', 'solved')));
    final c = HelpTicketController(repository: repo, translation: translation, id: 't1', clock: () => now);
    await c.load();
    expect(c.ticket.value!.messages!.length, 2);
    expect(c.statusNote, startsWith('Support replied.'));
    expect(c.canSend, isFalse);
    c.input.text = 'Works now';
    expect(c.canSend, isTrue);
    await c.onSend();
    expect(c.ticket.value!.status, 'open');
    expect(c.input.text, '');
    await _ignoreApp(c.onSolve);
    expect(c.solved, isTrue);
  });

  test('Messages shows support replies and announcements in the app language', () async {
    final notes = MockNotificationsRepository();
    when(() => notes.read(ids: any(named: 'ids'))).thenAnswer((_) async => const ApiSuccess<int>(0));
    final reply = NotificationOutModel(
      id: '1', kind: 'support_reply', params: {'subject': 'Report stuck', 'ticket_id': 't1'}, read: false, createdAt: now,
    );
    final news = NotificationOutModel(
      id: '2',
      kind: 'announcement',
      params: {'title_en': 'New: AI assistant', 'title_hi': 'नया: AI असिस्टेंट', 'body_en': 'Ask about your jobs.'},
      read: false,
      createdAt: now,
    );
    final c = MessagesController(repository: notes, translation: translation, clock: () => now);
    expect((c.title(reply), c.body(reply)), ('Support replied', 'About "Report stuck". Tap to read.'));
    expect((c.title(news), c.body(news)), ('New: AI assistant', 'Ask about your jobs.'));
    expect(c.tone(news), MessageTone.news);
    Get.locale = const Locale('hi', 'IN');
    expect((c.title(news), c.body(news)), ('नया: AI असिस्टेंट', 'Ask about your jobs.'));
  });
}
