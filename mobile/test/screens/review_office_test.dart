import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/review_office_section/company_reviews_section/company_reviews_controller.dart';
import 'package:kaamnishaan/UI/screens/review_office_section/review_followup_section/review_followup_controller.dart';
import 'package:kaamnishaan/UI/screens/review_office_section/review_requests_section/review_requests_controller.dart';
import 'package:kaamnishaan/UI/screens/review_office_section/review_settings_section/review_settings_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

/// Toasts and navigation need the app, which unit tests don't have.
Future<void> _ignoreApp(Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (_) {}
}

void _ignoreSync(void Function() run) {
  try {
    run();
  } on Object catch (_) {}
}

final now = DateTime(2026, 11, 5, 12);

CompanyReviewItemModel review({
  String id = 'v1',
  int rating = 2,
  bool low = true,
  bool needsReply = true,
  bool callBack = true,
  FollowupOutModel? followup = const FollowupOutModel(status: 'open'),
}) =>
    CompanyReviewItemModel(
      id: id,
      rating: rating,
      comment: 'Came 2 hours late.',
      reviewerName: 'Mr. Mehta',
      source: 'link',
      customer: 'Mehta house',
      customerId: 'c1',
      jobId: 'j1',
      jobTitle: 'AC service',
      reportNumber: 'R-1046',
      contactPhone: '+15550100321',
      createdAt: now.subtract(const Duration(minutes: 25)),
      tags: const ['late', 'not_fixed'],
      technician: const PersonRefModel(id: 'u1', name: 'Carlos Ruiz'),
      wantsCallBack: callBack,
      low: low,
      needsReply: needsReply,
      followup: followup,
    );

ReviewsPageModel page(List<CompanyReviewItemModel> data) => ReviewsPageModel(
      average: 4.66,
      count: 48,
      breakdown: const [1, 1, 2, 9, 35],
      counts: const ReviewCountsModel(all: 48, needsReply: 3, low: 1),
      data: data,
    );

const settings = ReviewSettingsOutModel(
  askOnShare: true,
  reminderEnabled: true,
  reminderDay: 2,
  reminderChannels: ['sms', 'email'],
  aiCallEnabled: true,
  aiCallDay: 5,
  callWindow: '10:00-19:00',
  lowRatingAlert: true,
  lowRatingThreshold: 2,
  techsCanRequest: true,
  techsSeeReviews: true,
  showPublicReviews: false,
  canEdit: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TranslationService translation;
  late MockReviewsRepository reviews;

  setUpAll(() async {
    await initializeDateFormatting();
    registerFallbackValue(const FollowupInModel());
    registerFallbackValue(const ReviewSettingsInModel());
  });

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    SharedPreferences.setMockInitialValues({});
    translation = TranslationService(await PreferencesService.create());
    reviews = MockReviewsRepository();
  });

  test('M45 shows the average, the chips and which cards need a follow-up', () async {
    final good = review(id: 'v2', rating: 4, low: false, callBack: false, followup: null);
    when(() => reviews.company(any())).thenAnswer((_) async => ApiSuccess<ReviewsPageModel>(page([review(), good])));
    final c = CompanyReviewsController(dictation: fakeDictation(), reviews: reviews, filter: 'all', clock: () => now);
    await c.load();
    expect((c.average, c.countLine), ('4.7', '48 reviews'));
    expect([for (final f in CompanyReviewsController.filters) c.chip(f)], ['All 48', 'Needs reply 3', 'Low 1']);
    expect((c.open(c.items.first), c.open(c.items.last)), (true, false));
    expect(c.ago(c.items.first), '25 min ago');
    expect(c.replyNote(good), "Your reply shows on the customer's report page and to Carlos.");
    await c.onFilter('low');
    verify(() => reviews.company('low')).called(1);
  });

  test('M45 reply: suggest, then send', () async {
    final r = review(rating: 5, low: false);
    when(() => reviews.company(any())).thenAnswer((_) async => ApiSuccess<ReviewsPageModel>(page([r])));
    when(() => reviews.suggestion(any())).thenAnswer((_) async => const ApiSuccess<String>('Thank you, Mr. Mehta!'));
    when(() => reviews.reply(any(), any())).thenAnswer(
      (_) async => ApiSuccess<ReplyOutModel>(ReplyOutModel(text: 'Thank you, Mr. Mehta!', createdAt: now)),
    );
    final c = CompanyReviewsController(dictation: fakeDictation(), reviews: reviews, filter: 'all', clock: () => now);
    c.onInit();
    c.startReply(r);
    expect(c.draft.value, '');
    await c.onSuggest(r);
    expect(c.replyText.text, 'Thank you, Mr. Mehta!');
    await _ignoreApp(() async {
      await c.onSendReply(r);
    });
    verify(() => reviews.reply('v1', 'Thank you, Mr. Mehta!')).called(1);
  });

  test('M45 low rating: what it says, call now and mark as resolved', () async {
    final opened = <Uri>[];
    when(() => reviews.followUp(any(), any())).thenAnswer(
      (_) async => ApiSuccess<FollowupOutModel>(FollowupOutModel(status: 'resolved', resolvedAt: now)),
    );
    final c = ReviewFollowupController(
      reviews: reviews,
      review: review(),
      clock: () => now,
      openUrl: (u) async {
        opened.add(u);
        return true;
      },
    );
    c.onInit();
    expect((c.title, c.subtitle), ('2-star review', 'Needs follow-up · 25 min ago'));
    expect(c.who, 'Mr. Mehta · Mehta house');
    expect(c.tags, ['Late', 'Not fixed']);
    expect(c.byLine, 'Carlos Ruiz · Report #R-1046');
    expect(c.callLine, '+15550100321 · within 1 working day');
    await c.onCallTap();
    expect(opened.single.toString(), 'tel:+15550100321');
    c.note.text = 'Called, revisit Friday.';
    expect(c.noteChanged, isTrue);
    await _ignoreApp(c.onResolveTap);
    final sent = verify(() => reviews.followUp('v1', captureAny())).captured.single as FollowupInModel;
    expect((sent.status, sent.privateNote), ('resolved', 'Called, revisit Friday.'));
    expect(c.resolved, isTrue);
    expect(c.subtitle, 'Resolved · just now');
  });

  test('M45 review requests: the chip and what happens next', () async {
    final items = [
      RequestItemModel(
        id: 'q1',
        jobId: 'j1',
        customer: 'Sharma residence',
        status: 'link_sent',
        nextStep: 'reminder',
        nextAt: DateTime(2026, 11, 2, 11),
      ),
      RequestItemModel(
        id: 'q2',
        jobId: 'j2',
        customer: 'Lake View',
        status: 'reminded',
        nextStep: 'ai_call',
        nextAt: DateTime(2026, 11, 5, 11),
      ),
      const RequestItemModel(id: 'q3', jobId: 'j3', customer: 'Green Valley', status: 'rated', rating: 4, source: 'ai_call'),
      const RequestItemModel(id: 'q4', jobId: 'j4', customer: 'Riverside', status: 'opted_out'),
    ];
    when(() => reviews.requests(any())).thenAnswer(
      (_) async => ApiSuccess<RequestsPageModel>(
        RequestsPageModel(counts: const RequestCountsModel(waiting: 5, rated: 41, optedOut: 2), data: items),
      ),
    );
    final c = ReviewRequestsController(reviews: reviews, translation: translation);
    await c.load();
    expect([for (final t in ReviewRequestsController.tabs) c.label(t)], ['Waiting 5', 'Rated 41', 'Opted out 2']);
    expect([for (final r in c.items) c.chip(r)], ['Link sent', 'Reminder sent', 'Rated 4★ via AI call', 'Opted out']);
    expect(
      [for (final r in c.items) c.line(r)],
      ['Reminder on Mon, 2 Nov', 'AI call on Thu, 5 Nov', 'Follow-ups stopped', 'No more contact'],
    );
    expect(c.tone(c.items[2]), RequestTone.good);
    await c.onTab('rated');
    verify(() => reviews.requests('rated')).called(1);
  });

  test('M46 settings: Save sends only what changed; a reminder needs one way to send', () async {
    when(() => reviews.settings()).thenAnswer((_) async => const ApiSuccess<ReviewSettingsOutModel>(settings));
    when(() => reviews.saveSettings(any())).thenAnswer((_) async => const ApiSuccess<ReviewSettingsOutModel>(settings));
    final c = ReviewSettingsController(reviews: reviews, translation: translation);
    c.onInit();
    await c.load();
    expect(c.dirty, isFalse);
    expect(c.reminderSub, 'If no review after 2 days, by SMS + email');
    expect(c.lowSub, '2 stars or less · in the app');
    expect(c.aiSub, startsWith('One call + voicemail, 10:00'));
    c.toggle(c.showPublicReviews, true);
    c.onChannelTap('whatsapp');
    c.onChannelTap('sms');
    _ignoreSync(() => c.onChannelTap('email'));
    _ignoreSync(() => c.onChannelTap('whatsapp')); // the last one stays
    expect(c.reminderChannels, ['whatsapp']);
    c.onChannelTap('email');
    c.googleUrl.text = 'g.page/r/brightair';
    expect(c.dirty, isTrue);
    await _ignoreApp(c.onSave);
    final sent = verify(() => reviews.saveSettings(captureAny())).captured.single as ReviewSettingsInModel;
    expect(sent.toJson()..removeWhere((_, v) => v == null), {
      'google_review_url': 'g.page/r/brightair',
      'reminder_channels': ['whatsapp', 'email'],
      'show_public_reviews': true,
    });
  });
}
