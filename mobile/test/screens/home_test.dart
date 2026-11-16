import 'dart:convert';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/home_section/dashboard_section/dashboard_controller.dart';
import 'package:kaamnishaan/UI/screens/home_section/today_section/today_controller.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockHomeRepository home;
  late PreferencesService prefs;
  late TranslationService translation;
  late SessionService session;

  setUpAll(() async => initializeDateFormatting());

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    SharedPreferences.setMockInitialValues({});
    prefs = await PreferencesService.create();
    translation = TranslationService(prefs);
    home = MockHomeRepository();
    session = SessionService(tokens: MemoryTokenStorage(), repository: MockAuthRepository())..me.value = me();
  });

  group('M12 Today', () {
    TodayController today() => TodayController(
          repository: home,
          session: session,
          prefs: prefs,
          translation: translation,
          clock: () => DateTime(2026, 10, 31, 9, 15),
        );

    test('greets by time of day with the date, and keeps a copy for offline', () async {
      final data = todayData(current: job(status: 'in_progress', proof: const ProofCountModel(done: 2, total: 5)));
      when(() => home.today()).thenAnswer((_) async => ApiSuccess<TodayModel>(data));
      final c = today();
      await c.load();
      expect(c.greetingLine, 'Good morning · Sat 31 Oct');
      expect(c.firstName, 'Ramesh');
      expect(c.isEmpty, isFalse);
      expect(c.offline.value, isFalse);
      final saved = jsonDecode(prefs.cachedToday('u1')!) as Map<String, dynamic>;
      expect(saved['current_job']['proof'], {'done': 2, 'total': 5});
    });

    test('without internet it shows the saved day and says so', () async {
      final data = todayData(next: [job(customer: 'Mehta house')]);
      await prefs.setCachedToday('u1', jsonEncode(data.toJson()));
      when(() => home.today()).thenAnswer(
        (_) async => const ApiFailure<TodayModel>(ApiException(code: 'no_internet', message: '')),
      );
      final c = today();
      await c.load();
      expect(c.offline.value, isTrue);
      expect(c.data.value?.nextJobs.single.customer.name, 'Mehta house');
    });

    test('no jobs: empty, with the manager to call', () async {
      when(() => home.today()).thenAnswer(
        (_) async => ApiSuccess<TodayModel>(todayData(manager: const ContactRefModel(name: 'Priya', phone: '+919800000000'))),
      );
      final called = <Uri>[];
      final c = TodayController(
        repository: home,
        session: session,
        prefs: prefs,
        translation: translation,
        openUrl: (uri) async {
          called.add(uri);
          return true;
        },
      );
      await c.load();
      expect(c.isEmpty, isTrue);
      await c.onCallManagerTap();
      expect(called.single.toString(), 'tel:+919800000000');
    });

    test('Next up shows at most three rows', () async {
      when(() => home.today()).thenAnswer(
        (_) async => ApiSuccess<TodayModel>(todayData(next: [for (var i = 0; i < 5; i++) job(id: 'j$i')])),
      );
      final c = today();
      await c.load();
      expect(c.nextUp.length, 3);
    });
  });

  group('M13 Dashboard', () {
    DashboardController dashboard({void Function(int)? onOpenTab}) => DashboardController(
          repository: home,
          session: session,
          translation: translation,
          onOpenTab: onOpenTab,
          clock: () => DateTime(2026, 10, 31, 9, 30),
        );

    void answer(DashboardModel d, {List<ReportListItemModel> reviews = const []}) {
      when(() => home.dashboard()).thenAnswer((_) async => ApiSuccess<DashboardModel>(d));
      when(() => home.reviewQueue(limit: any(named: 'limit'))).thenAnswer(
        (_) async => ApiSuccess<ReportListModel>(ReportListModel(data: reviews, meta: const ListMetaModel())),
      );
    }

    test('this week compared with last week', () async {
      answer(dashboardData(week: 38, lastWeek: 34), reviews: [reviewItem()]);
      final c = dashboard();
      await c.load();
      expect(c.isNewCompany, isFalse);
      expect(c.trend, WeekTrend.more);
      expect(c.trendText, '12% more than last week');
      expect(c.todayCount('in_progress'), 3);
      expect(c.reviews.single.job.customer, 'Green Valley Clinic');
      expect(c.reviewMeta(c.reviews.single), 'Ramesh Patel · 10 min ago');
      expect(c.reviewEvidence(c.reviews.single), '6 photos · AI draft');

      answer(dashboardData(week: 30, lastWeek: 40));
      await c.load();
      expect(c.trendText, '25% less than last week');
      answer(dashboardData(week: 3, lastWeek: 0));
      await c.load();
      expect(c.trend, WeekTrend.first);
      answer(dashboardData(week: 0, lastWeek: 0));
      await c.load();
      expect(c.trend, WeekTrend.none);
    });

    test('a new company sees Get started until the team is invited and a job made', () async {
      answer(dashboardData(teamInvited: false, firstJob: false));
      final c = dashboard();
      await c.load();
      expect(c.isNewCompany, isTrue);
      expect(c.stepsDone, 1);
      answer(dashboardData(teamInvited: true, firstJob: false));
      await c.load();
      expect(c.stepsDone, 2);
      answer(dashboardData());
      await c.load();
      expect(c.isNewCompany, isFalse);
    });

    test('tapping the numbers opens Reports or Jobs', () async {
      answer(dashboardData());
      final opened = <int>[];
      final c = dashboard(onOpenTab: opened.add);
      c.onReviewTilesTap();
      c.onJobTilesTap();
      expect(opened, [2, 1]);
    });
  });
}
