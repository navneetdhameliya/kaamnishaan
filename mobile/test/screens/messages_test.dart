import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/me_section/messages_section/messages_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

/// 31 Oct 2026, 12:10 local time.
final now = DateTime(2026, 10, 31, 12, 10);

NotificationOutModel message(
  String id,
  String kind,
  DateTime at, {
  Map<String, dynamic> params = const {},
  bool read = false,
  String? actor,
}) =>
    NotificationOutModel(
      id: id,
      kind: kind,
      params: params,
      actor: actor == null ? null : PersonRefModel(id: 'm1', name: actor),
      jobId: 'j$id',
      reportId: kind == 'job_assigned' ? null : 'r$id',
      read: read,
      createdAt: at,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockNotificationsRepository repo;
  late TranslationService translation;

  setUpAll(() async => initializeDateFormatting());

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    SharedPreferences.setMockInitialValues({});
    translation = TranslationService(await PreferencesService.create());
    repo = MockNotificationsRepository();
    when(() => repo.read(ids: any(named: 'ids'))).thenAnswer((_) async => const ApiSuccess<int>(0));
  });

  MessagesController open(List<NotificationOutModel> list) {
    when(() => repo.list(cursor: any(named: 'cursor'), limit: any(named: 'limit'))).thenAnswer(
      (_) async => ApiSuccess<NotificationListModel>(
        NotificationListModel(
          data: list,
          meta: ListMetaModel(counts: {'unread': list.where((n) => !n.read).length}),
        ),
      ),
    );
    return MessagesController(repository: repo, translation: translation, clock: () => now);
  }

  test('writes each message in the app language, grouped by day, newest first', () async {
    final c = open([
      message(
        '1',
        'changes_requested',
        now.subtract(const Duration(minutes: 10)),
        params: {'customer': 'Mehta house', 'note': 'Please add an after photo.'},
        actor: 'Priya Shah',
      ),
      message(
        '2',
        'report_shared',
        now.subtract(const Duration(hours: 1)),
        params: {'customer': 'Sharma residence'},
      ),
      message(
        '3',
        'job_assigned',
        DateTime(2026, 10, 31, 8, 5),
        params: {'customer': 'Green Valley Clinic', 'job': 'AC not cooling', 'scheduled_at': '2026-10-31T11:30:00'},
        read: true,
      ),
      message(
        '4',
        'report_submitted',
        DateTime(2026, 10, 30, 17, 0),
        params: {'customer': 'Green Valley Clinic', 'technician': 'Ramesh Patel'},
        read: true,
      ),
    ]);
    await c.load();
    expect(c.subtitle, '2 new');
    expect(c.groups.map((g) => (g.$1, g.$2.length)), [('Today', 3), ('Yesterday', 1)]);
    final [changes, shared, job, submitted] = c.items.toList();
    expect((c.title(changes), c.body(changes), c.when(changes)),
        ('Changes asked', 'Priya: Mehta house — Please add an after photo.', '10 min'));
    expect((c.title(shared), c.body(shared), c.when(shared)),
        ('Report approved', 'Sharma residence report was sent to the customer.', '1 h'));
    expect(c.title(job), 'New job for today');
    expect(c.body(job), startsWith('Green Valley Clinic · 11:30'));
    expect(c.body(job), endsWith('· AC not cooling'));
    expect(c.when(job), startsWith('8:05'));
    expect(c.body(submitted), 'Ramesh sent the Green Valley Clinic report.');
    expect(c.tone(changes), MessageTone.problem);
    expect(c.tone(job), MessageTone.job);
  });

  test('a technician\'s "Not sure?" question reads plainly and opens the job', () async {
    final c = open([
      message('5', 'tech_question', now, params: {
        'customer': 'Green Valley Clinic',
        'technician': 'Ramesh Patel',
        'question': 'Is the air filter clean?',
        'note': 'It looks new already',
      }),
      message('6', 'tech_question', now, params: {
        'customer': 'Mehta house',
        'technician': 'Ramesh Patel',
        'question': 'Gas pressure?',
      }),
    ]);
    await c.load();
    final [withNote, plain] = c.items.toList();
    expect(c.title(withNote), 'Question from the job');
    expect(c.body(withNote), 'Ramesh at Green Valley Clinic isn’t sure: “Is the air filter clean?” — It looks new already');
    expect(c.body(plain), 'Ramesh at Mehta house isn’t sure: “Gas pressure?”');
    expect(c.tone(plain), MessageTone.review);
  });

  test('plan limit messages tell the owner how many reports are left and when more come', () async {
    final about = {'used': '48', 'limit': '60', 'plan': 'starter', 'renews_at': '2026-12-01T06:30:00Z'};
    final c = open([
      message('7', 'plan_limit', now, params: {...about, 'stage': 'near'}),
      message('8', 'plan_limit', now, params: {...about, 'used': '60', 'stage': 'reached'}),
      message('9', 'plan_limit', now, params: {
        ...about,
        'used': '60',
        'stage': 'blocked',
        'technician': 'Ramesh Patel',
        'customer': 'Green Valley Clinic',
      }),
    ]);
    await c.load();
    final [near, reached, blocked] = c.items.toList();
    expect((c.title(near), c.body(near)),
        ('Reports running out', '48 of 60 reports used this month. More come on 1 Dec, or upgrade your plan.'));
    expect((c.title(reached), c.body(reached)),
        ('This month’s reports are used up', 'All 60 reports are used. New reports wait until 1 Dec, or upgrade your plan.'));
    expect(c.title(blocked), 'A report couldn’t be made');
    expect(c.body(blocked), startsWith('Ramesh tried to make the Green Valley Clinic report, but all 60 reports are used.'));
    expect((c.tone(near), c.tone(reached), c.tone(blocked)), (MessageTone.news, MessageTone.problem, MessageTone.problem));
  });

  test('opening the list marks everything read, but this visit still shows which were new', () async {
    final c = open([
      message('1', 'report_approved', now, params: {'customer': 'Mehta house'}),
      message('2', 'report_approved', now, params: {'customer': 'Sharma residence'}, read: true),
    ]);
    await c.load();
    verify(() => repo.read()).called(1);
    expect(c.fresh, {'1'});
  });

  test('nothing new: nothing is marked', () async {
    final c = open([message('1', 'report_approved', now, read: true)]);
    await c.load();
    verifyNever(() => repo.read(ids: any(named: 'ids')));
    expect(c.subtitle, 'All read');
  });
}
