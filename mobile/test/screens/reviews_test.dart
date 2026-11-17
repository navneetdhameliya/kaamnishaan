import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/me_section/my_reviews_section/my_reviews_controller.dart';
import 'package:kaamnishaan/UI/screens/me_section/review_details_section/review_details_controller.dart';
import 'package:kaamnishaan/UI/screens/report_section/report_sent_section/report_sent_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:kaamnishaan/infrastructure/shared/job_arguments.dart';
import 'package:kaamnishaan/infrastructure/shared/review_words.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

/// Toasts need the app, which unit tests don't have.
Future<void> _ignoreApp(Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (_) {}
}

final now = DateTime(2026, 11, 5, 12);

const notAsked = JobReviewModel(
  status: 'not_requested',
  canRequest: true,
  contactName: 'Dr. Anita Rao',
  contactPhone: '+1 555 010 0444',
  aiCallEnabled: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TranslationService translation;
  late MockReviewsRepository reviews;

  setUpAll(() async => initializeDateFormatting());

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    SharedPreferences.setMockInitialValues({});
    translation = TranslationService(await PreferencesService.create());
    reviews = MockReviewsRepository();
  });

  test('the review card says where the review stands', () {
    final w = ReviewWords('en');
    expect(w.chip(notAsked), 'Not asked yet');
    expect(
      w.notAskedBody(notAsked),
      'Send Dr. Anita Rao a link to rate this job. Reminders and one AI call follow if needed.',
    );
    const noContact = JobReviewModel(status: 'not_requested', canRequest: false, blockedReason: 'no_contact');
    expect(w.notAskedBody(noContact), "Add the customer's phone or email to ask for a review.");
    final sent = JobReviewModel(
      status: 'link_sent',
      canRequest: false,
      sentAt: DateTime(2026, 10, 31, 12),
      channels: const ['sms', 'email'],
      reminderAt: DateTime(2026, 11, 2, 11),
      aiCallAt: DateTime(2026, 11, 5, 11),
      requestedByMe: true,
    );
    expect(w.chip(sent), 'Waiting for rating');
    expect(w.sentLine(sent), '31 Oct · SMS + email');
    expect(w.reminderLine(sent), startsWith('Mon, 2 Nov · 11:00'));
    expect(w.aiCallLine(sent), 'Thu, 5 Nov · if still no rating');
    expect(w.requestedBy(sent), 'Requested by you · no need to ask again.');
    final rated = ReviewBriefModel(
      id: 'r1',
      rating: 5,
      technicianRating: 4,
      source: 'ai_call',
      createdAt: DateTime(2026, 11, 5, 10),
    );
    expect(w.ratedLine(rated), '4 · via AI call · 5 Nov');
    expect(ReviewWords.tag('explained_clearly'), 'Explained clearly');
  });

  test('M31 offers to ask for a review, and asking it hides the offer', () async {
    final reports = MockReportsRepository();
    final jobs = MockJobsRepository();
    when(() => reports.report(any())).thenAnswer((_) async => ApiSuccess<ReportOutModel>(reportOut(status: 'pending_review')));
    when(() => jobs.job(any())).thenAnswer((_) async => ApiSuccess<JobOutModel>(jobOut(review: notAsked)));
    when(() => reviews.request(any())).thenAnswer(
      (_) async => const ApiSuccess<JobReviewModel>(
        JobReviewModel(status: 'queued', canRequest: false, canCancel: true, contactName: 'Dr. Anita Rao'),
      ),
    );
    final c = ReportSentController(
      reports: reports,
      translation: translation,
      jobs: jobs,
      reviews: reviews,
      args: const ReportArguments(jobId: 'j1', customer: 'Green Valley Clinic', reportId: 'r1'),
    );
    await c.load();
    expect(c.canAsk, isTrue);
    expect(c.askTitle, 'Ask Dr. Anita Rao for a review?');
    expect(c.askLine, 'Green Valley Clinic · +1 555 010 0444');
    await _ignoreApp(c.onAskTap);
    verify(() => reviews.request('j1')).called(1);
    expect((c.review.value?.status, c.canAsk), ('queued', false));
  });

  test('M31 "Not now" leaves the usual sent screen', () async {
    final reports = MockReportsRepository();
    final jobs = MockJobsRepository();
    when(() => reports.report(any())).thenAnswer((_) async => ApiSuccess<ReportOutModel>(reportOut(status: 'pending_review')));
    when(() => jobs.job(any())).thenAnswer((_) async => ApiSuccess<JobOutModel>(jobOut(review: notAsked)));
    final c = ReportSentController(
      reports: reports,
      translation: translation,
      jobs: jobs,
      reviews: reviews,
      args: const ReportArguments(jobId: 'j1', customer: 'Green Valley Clinic', reportId: 'r1'),
    );
    await c.load();
    c.onNotNowTap();
    expect(c.canAsk, isFalse);
    verifyNever(() => reviews.request(any()));
  });

  test('M44 my reviews: average, share of 4+ stars, good tags and each review', () async {
    when(() => reviews.mine()).thenAnswer(
      (_) async => ApiSuccess<MyReviewsModel>(
        MyReviewsModel(
          average: 4.8,
          count: 36,
          share4Plus: 94,
          tags: const [
            TagCountModel(key: 'on_time', count: 31),
            TagCountModel(key: 'clean_work', count: 28),
            TagCountModel(key: 'explained_clearly', count: 22),
            TagCountModel(key: 'polite', count: 9),
          ],
          data: [
            ReviewListItemModel(
              id: 'v1',
              rating: 4,
              technicianRating: 5,
              comment: 'Quick and tidy.',
              reviewerName: 'Dr. Anita Rao',
              source: 'link',
              customer: 'Green Valley Clinic',
              jobTitle: 'AC not cooling',
              createdAt: now.subtract(const Duration(hours: 2)),
              reply: ReplyOutModel(
                author: const PersonRefModel(id: 'm1', name: 'Priya Mehta'),
                text: 'Thank you, Dr. Rao!',
                createdAt: now,
              ),
            ),
          ],
        ),
      ),
    );
    final c = MyReviewsController(reviews: reviews, clock: () => now);
    await c.load();
    expect((c.average, c.stars, c.summary), ('4.8', 5, '36 reviews · 94% gave 4★ or more'));
    expect(c.tags, ['On time · 31', 'Clean work · 28', 'Explained clearly · 22']);
    final r = c.items.single;
    expect((c.who(r), c.meta(r), c.ago(r), c.rating(r)), ('Dr. Anita Rao', 'Green Valley Clinic · AC not cooling', '2 h ago', 5));
    expect(c.replied(r), 'Priya replied');
  });

  test('M44 no reviews yet', () async {
    when(() => reviews.mine()).thenAnswer(
      (_) async => const ApiSuccess<MyReviewsModel>(MyReviewsModel(count: 0, share4Plus: 0, tags: [], data: [])),
    );
    final c = MyReviewsController(reviews: reviews, clock: () => now);
    await c.load();
    expect(c.empty, isTrue);
  });

  test('M44 review details', () async {
    when(() => reviews.review(any())).thenAnswer(
      (_) async => ApiSuccess<ReviewOutModel>(
        ReviewOutModel(
          id: 'v1',
          rating: 4,
          technicianRating: 5,
          comment: 'Quick and tidy.',
          reviewerName: 'Dr. Anita Rao',
          source: 'link',
          customer: 'Green Valley Clinic',
          jobTitle: 'AC not cooling',
          createdAt: DateTime(2026, 10, 31, 15),
          tags: const ['on_time', 'clean_work'],
          jobId: 'j1',
          reportNumber: 'R-1042',
          technician: const PersonRefModel(id: 'u1', name: 'Ramesh Patel'),
          publicAllowed: false,
          wantsCallBack: false,
          reply: ReplyOutModel(
            author: const PersonRefModel(id: 'm1', name: 'Priya Mehta'),
            text: 'Thank you!',
            createdAt: now.subtract(const Duration(hours: 1)),
          ),
        ),
      ),
    );
    final c = ReviewDetailsController(reviews: reviews, translation: translation, reviewId: 'v1', clock: () => now);
    await c.load();
    expect((c.subtitle, c.name, c.meta), ('Report #R-1042', 'Dr. Anita Rao', 'Green Valley Clinic · 31 Oct'));
    expect((c.youLabel, c.quote), ('You (Ramesh)', '“Quick and tidy.”'));
    expect(c.tags, ['On time', 'Clean work']);
    expect(c.replyBy, 'Priya Mehta replied · 1 h ago');
  });
}
