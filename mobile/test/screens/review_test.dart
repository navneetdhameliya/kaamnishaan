import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/review_section/report_pdf_section/report_pdf_controller.dart';
import 'package:kaamnishaan/UI/screens/review_section/report_review_section/report_review_controller.dart';
import 'package:kaamnishaan/UI/screens/review_section/review_queue_section/review_queue_controller.dart';
import 'package:kaamnishaan/UI/screens/review_section/share_report_section/share_report_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:kaamnishaan/infrastructure/services/session_service.dart';
import 'package:kaamnishaan/infrastructure/shared/job_arguments.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

/// Toasts and navigation need the app, which unit tests don't have.
Future<void> _ignoreApp(Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (_) {}
}

final now = DateTime(2026, 10, 31, 12, 0);

ReportListItemModel queued(String id, int waiting, {String drafted = 'ai'}) => ReportListItemModel(
      id: id,
      number: 'R-$id',
      status: 'pending_review',
      draftedBy: drafted,
      flags: 0,
      waitingMinutes: waiting,
      submittedAt: now.subtract(Duration(minutes: waiting)),
      updatedAt: now,
      thumbs: const ['https://x/1.jpg'],
      job: const JobBriefModel(
        id: 'j1',
        number: 'J-1',
        title: 'Duct cleaning',
        customer: 'Lake View Apartments',
        status: 'in_review',
        photos: 9,
        technician: PersonRefModel(id: 'u2', name: 'Carlos Diaz'),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockReportsRepository reports;
  late TranslationService translation;
  const args = ReportArguments(jobId: 'j1', customer: 'Green Valley Clinic', reportId: 'r1');

  setUpAll(() async => initializeDateFormatting());

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    SharedPreferences.setMockInitialValues({});
    translation = TranslationService(await PreferencesService.create());
    reports = MockReportsRepository();
  });

  test('M30 queue: oldest first, how long each waits, and the approved count', () async {
    when(() => reports.list(statuses: any(named: 'statuses'), period: any(named: 'period'), q: any(named: 'q'), cursor: any(named: 'cursor')))
        .thenAnswer((i) async {
      final statuses = i.namedArguments[#statuses] as List<String>?;
      if (statuses?.first == 'approved') {
        return const ApiSuccess<ReportListModel>(ReportListModel(data: [], meta: ListMetaModel()));
      }
      return ApiSuccess<ReportListModel>(
        ReportListModel(
          data: [queued('1041', 65), queued('1042', 10)],
          meta: const ListMetaModel(counts: {'pending_review': 2}),
        ),
      );
    });
    final c = ReviewQueueController(reports: reports, clock: () => now);
    await c.load();
    expect(c.subtitle, '2 waiting for your review');
    expect(c.tabLabel(QueueTab.review), 'To review 2');
    final [first, second] = c.items.toList();
    expect(c.waitChip(first), 'Oldest · 1 h');
    expect(c.isOldest(first), isTrue);
    expect(c.waitChip(second), 'Waiting 10 min');
    expect(c.byLine(first), 'Carlos · sent 1 h ago');
    expect(c.meta(first), 'Duct cleaning · #R-1041');
    c.onTabTap(QueueTab.changes);
    await Future<void>.delayed(Duration.zero);
    verify(() => reports.list(statuses: ['changes_requested'])).called(1);
    c.onClose();
  });

  group('M33 review', () {
    late MockJobsRepository jobs;

    ReportReviewController review(ReportOutModel r) {
      jobs = MockJobsRepository();
      when(() => reports.report(any())).thenAnswer((_) async => ApiSuccess<ReportOutModel>(r));
      when(() => jobs.evidence(any())).thenAnswer(
        (_) async => const ApiSuccess<EvidenceListModel>(EvidenceListModel(data: [], meta: ListMetaModel(), pairs: [])),
      );
      return ReportReviewController(dictation: fakeDictation(), reports: reports, jobs: jobs, translation: translation, args: args, clock: () => now);
    }

    ReportOutModel waiting() => reportOut(
          status: 'pending_review',
          actions: const ['approve', 'request_changes'],
          flags: const [ReportFlagModel(kind: 'missing_evidence', text: 'drain pipe leak')],
        );

    test('shows what to look at and approves', () async {
      final c = review(waiting());
      await c.load();
      expect(c.subtitle, 'Green Valley Clinic · #R-1042');
      expect(c.flagsTitle, 'AI check · 1 thing to look at');
      expect(c.flagText(c.flags.single), 'Drain pipe leak · no photo');
      expect((c.checksPassed, c.checksTotal, c.notes), (11, 12, 2));
      expect(c.waiting, isTrue);
      when(() => reports.approve(any())).thenAnswer(
        (_) async => ApiSuccess<ReportOutModel>(reportOut(status: 'approved', actions: const [])),
      );
      await _ignoreApp(c.onApproveTap);
      verify(() => reports.approve('r1')).called(1);
      expect(c.approved, isTrue);
    });

    test('ask for changes: the missing photo and failed check are ticked, and their words reach the technician', () async {
      final c = review(waiting());
      await c.load();
      c.prepareChanges();
      expect(c.options.map((o) => (o.label, o.checked.value)), [
        ('Add a photo of drain pipe leak', true),
        ('Explain the failed checks (1)', true),
        ('Fix the work done text', false),
        ('Fix the job details', false),
        ('Something else', false),
      ]);
      when(() => reports.requestChanges(any(), reasons: any(named: 'reasons'), note: any(named: 'note')))
          .thenAnswer((_) async => ApiSuccess<ReportOutModel>(reportOut(status: 'changes_requested')));
      c.note.text = 'Please photograph the leak.';
      var sent = false;
      await _ignoreApp(() async => sent = await c.onSendChangesTap());
      verify(
        () => reports.requestChanges(
          'r1',
          reasons: ['missing_photos', 'failed_check_not_explained'],
          note: 'Add a photo of drain pipe leak. Explain the failed checks (1). Please photograph the leak.',
        ),
      ).called(1);
      expect(sent || c.report.value?.status == 'changes_requested', isTrue);
    });

    test('"Something else" needs a note; nothing ticked says so', () async {
      final c = review(waiting());
      await c.load();
      c.prepareChanges();
      for (final o in c.options) {
        o.checked.value = false;
      }
      expect(await c.onSendChangesTap(), isFalse);
      expect(c.changesError.value, 'Choose what needs fixing.');
      c.onOptionTap(c.options.last);
      expect(await c.onSendChangesTap(), isFalse);
      expect(c.changesError.value, 'Say what needs changing.');
      verifyNever(() => reports.requestChanges(any(), reasons: any(named: 'reasons'), note: any(named: 'note')));
    });
  });

  test('M34 waits while the PDF builds, then it is ready', () async {
    final jobs = MockJobsRepository();
    when(() => reports.report(any())).thenAnswer((_) async => ApiSuccess<ReportOutModel>(reportOut(status: 'approved')));
    when(() => jobs.evidence(any())).thenAnswer(
      (_) async => const ApiSuccess<EvidenceListModel>(EvidenceListModel(data: [], meta: ListMetaModel(), pairs: [])),
    );
    var calls = 0;
    when(() => reports.pdf(any())).thenAnswer(
      (_) async => ApiSuccess<PdfOutModel>(
        ++calls == 1
            ? const PdfOutModel(status: 'building', filename: 'R-1042.pdf')
            : const PdfOutModel(status: 'ready', filename: 'R-1042.pdf', pages: 3, url: 'https://x/r.pdf', size: 2400000),
      ),
    );
    Uri? opened;
    final c = ReportPdfController(
      reports: reports,
      jobs: jobs,
      session: SessionService(tokens: MemoryTokenStorage(), repository: MockAuthRepository()),
      translation: translation,
      args: args,
      pollEvery: const Duration(hours: 1),
      open: (u) async {
        opened = u;
        return true;
      },
    );
    await c.load();
    expect(c.building, isTrue);
    await c.check();
    expect((c.ready, c.pages), (true, 3));
    await c.onDownloadTap();
    expect(opened.toString(), 'https://x/r.pdf');
    c.onClose();
  });

  group('M35 share', () {
    ShareInfoModel info({RecipientModel? to, bool sms = true}) => ShareInfoModel(
          reportId: 'r1',
          reportStatus: 'approved',
          canShare: true,
          recipient: to,
          channels: [
            ChannelOutModel(key: 'sms', available: sms),
            const ChannelOutModel(key: 'whatsapp', available: false, reason: 'Not set up yet'),
            ChannelOutModel(key: 'email', available: to?.email != null),
          ],
          sent: const [],
        );

    ShareReportController share(ShareInfoModel i) {
      when(() => reports.share(any())).thenAnswer((_) async => ApiSuccess<ShareInfoModel>(i));
      when(() => reports.pdf(any())).thenAnswer(
        (_) async => const ApiSuccess<PdfOutModel>(PdfOutModel(status: 'ready', filename: 'r.pdf', pages: 3, size: 2400000)),
      );
      when(() => reports.report(any())).thenAnswer((_) async => ApiSuccess<ReportOutModel>(reportOut(status: 'approved')));
      return ShareReportController(reports: reports, args: args)..onInit();
    }

    test('SMS is picked when the customer has a phone, and the send goes out', () async {
      final c = share(info(to: const RecipientModel(name: 'Dr. Anita Rao', phone: '+15550100444')));
      await c.load();
      expect(c.picked, {'sms'});
      expect((c.name, c.contactLine, c.size, c.pages), ('Dr. Anita Rao', '+15550100444', '2.3 MB', 3));
      expect(c.available('whatsapp'), isFalse);
      expect((c.initials, c.pdfMeta), ('AR', 'PDF · 2.3 MB'));
      when(() => reports.send(any(), channels: any(named: 'channels'), name: any(named: 'name'), phone: any(named: 'phone'), email: any(named: 'email')))
          .thenAnswer((_) async => ApiSuccess<ShareInfoModel>(info()));
      await _ignoreApp(c.onSendTap);
      verify(() => reports.send('r1', channels: ['sms'])).called(1);
      c.onClose();
    });

    test('no phone or email: a typed email is used for this send', () async {
      final c = share(info(sms: false));
      await c.load();
      expect(c.editing.value, isTrue);
      expect(c.picked, isEmpty);
      c.contact.text = 'office@greenvalley.in';
      c.onContactChanged('');
      expect(c.available('email'), isTrue);
      expect(c.picked, {'email'});
      when(() => reports.send(any(), channels: any(named: 'channels'), name: any(named: 'name'), phone: any(named: 'phone'), email: any(named: 'email')))
          .thenAnswer((_) async => ApiSuccess<ShareInfoModel>(info()));
      await _ignoreApp(c.onSendTap);
      verify(() => reports.send('r1', channels: ['email'], email: 'office@greenvalley.in')).called(1);
      c.onClose();
    });

    test('while email is off, the email button says so and stays off', () async {
      final c = share(
        const ShareInfoModel(
          reportId: 'r1',
          reportStatus: 'approved',
          canShare: true,
          recipient: RecipientModel(name: 'Dr. Anita Rao', email: 'office@greenvalley.in'),
          channels: [
            ChannelOutModel(key: 'sms', available: false, reason: 'no_phone'),
            ChannelOutModel(key: 'whatsapp', available: false, reason: 'no_phone'),
            ChannelOutModel(key: 'email', available: false, to: 'office@greenvalley.in', reason: 'email_off'),
          ],
          sent: [],
        ),
      );
      await c.load();
      expect((c.available('email'), c.picked.isEmpty), (false, true));
      expect(c.reason('email'), "Email isn't switched on yet. Send by SMS or WhatsApp, or copy the link.");
      expect(c.reason('sms'), 'No phone number saved for this customer.');
      c.onClose();
    });
  });
}
