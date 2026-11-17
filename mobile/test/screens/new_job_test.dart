import 'package:flutter/material.dart' show Locale, TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/assign_technician_section/assign_technician_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/new_job_section/new_job_controller.dart';
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

void _ignoreSync(void Function() run) {
  try {
    run();
  } on Object catch (_) {}
}

/// Sat 31 Oct 2026, 9:30.
final now = DateTime(2026, 10, 31, 9, 30);

const clinic = CustomerListItemModel(
  id: 'c1',
  name: 'Green Valley Clinic',
  jobCount: 4,
  site: SiteBriefModel(id: 's1', address: '4 Lake Road, Springfield'),
);

const ramesh = AssignableTechnicianModel(
  id: 'u1', name: 'Ramesh Patel', status: 'active', jobsToday: 3, capacity: 5, available: true, distanceKm: 1.14,
);
const carlos = AssignableTechnicianModel(
  id: 'u2', name: 'Carlos Ruiz', status: 'active', jobsToday: 2, capacity: 5, available: true,
);
const arjun = AssignableTechnicianModel(
  id: 'u3', name: 'Arjun Desai', status: 'invited', jobsToday: 0, capacity: 5, available: false,
  disabledReason: 'invite_pending',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockJobsRepository jobs;
  late TranslationService translation;

  setUpAll(() async {
    registerFallbackValue(DateTime(2026));
    await initializeDateFormatting();
  });

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    SharedPreferences.setMockInitialValues({});
    translation = TranslationService(await PreferencesService.create());
    jobs = MockJobsRepository();
  });

  group('M16 New job', () {
    late MockCustomersRepository customers;

    NewJobController open() {
      customers = MockCustomersRepository();
      final checklists = MockChecklistsRepository();
      when(() => customers.search(any())).thenAnswer(
        (_) async => const ApiSuccess<CustomerListModel>(CustomerListModel(data: [clinic], meta: ListMetaModel())),
      );
      when(() => checklists.templates()).thenAnswer(
        (_) async => const ApiSuccess<TemplateListModel>(
          TemplateListModel(
            data: [
              TemplateListItemModel(
                id: 't1', name: 'HVAC service check', questionCount: 12, status: 'published',
                needsTranslation: 0, scope: 'company', usageCount: 3, version: 1,
              ),
              TemplateListItemModel(
                id: 't2', name: 'Old draft', questionCount: 2, status: 'draft',
                needsTranslation: 0, scope: 'company', usageCount: 0, version: 1,
              ),
            ],
            meta: ListMetaModel(),
          ),
        ),
      );
      when(
        () => jobs.create(
          title: any(named: 'title'),
          scheduledAt: any(named: 'scheduledAt'),
          clientUuid: any(named: 'clientUuid'),
          customerId: any(named: 'customerId'),
          newCustomer: any(named: 'newCustomer'),
          address: any(named: 'address'),
          technicianId: any(named: 'technicianId'),
          checklistIds: any(named: 'checklistIds'),
        ),
      ).thenAnswer((_) async => ApiSuccess<JobOutModel>(jobOut()));
      return NewJobController(
        jobs: jobs,
        customers: customers,
        checklists: checklists,
        session: SessionService(tokens: MemoryTokenStorage(), repository: MockAuthRepository()),
        translation: translation,
        clock: () => now,
        searchDelay: Duration.zero,
      )..onInit();
    }

    test('nothing filled: says how many things are missing and sends nothing', () async {
      final c = open();
      await Future<void>.delayed(Duration.zero);
      expect(c.templates.map((t) => t.id), ['t1']); // drafts are not offered
      expect(c.dayLabel, 'Sat, 31 Oct');
      await c.onCreateTap();
      expect((c.customerMissing, c.timeMissing, c.workMissing), (true, true, true));
      expect(c.missingBanner, '3 things are missing. Please fill them in.');
      c.work.text = 'AC not cooling in room 2';
      c.onWorkChanged(c.work.text);
      expect(c.missingBanner, '2 things are missing. Please fill them in.');
      verifyNever(
        () => jobs.create(
          title: any(named: 'title'),
          scheduledAt: any(named: 'scheduledAt'),
          clientUuid: any(named: 'clientUuid'),
        ),
      );
    });

    test('a known customer brings its address; the job goes out with the checklist and technician', () async {
      final c = open();
      c.prepareSearch();
      await Future<void>.delayed(Duration.zero);
      expect(c.found.single.name, 'Green Valley Clinic');
      _ignoreSync(() => c.onCustomerPicked(clinic));
      expect((c.customerName, c.address.text), ('Green Valley Clinic', '4 Lake Road, Springfield'));
      c.onDatePicked(DateTime(2026, 11, 2));
      c.onTimePicked(const TimeOfDay(hour: 11, minute: 30));
      expect(c.timeLabel, startsWith('11:30'));
      c.work.text = 'AC not cooling in room 2';
      c.onWorkChanged(c.work.text);
      await Future<void>.delayed(Duration.zero);
      _ignoreSync(() => c.onChecklistPicked(c.templates.single));
      c.technician.value = ramesh;
      expect(c.technicianLine, '3 of 5 jobs');
      await _ignoreApp(c.onCreateTap);
      verify(
        () => jobs.create(
          title: 'AC not cooling in room 2',
          scheduledAt: DateTime(2026, 11, 2, 11, 30),
          clientUuid: c.clientUuid,
          customerId: 'c1',
          address: '4 Lake Road, Springfield',
          technicianId: 'u1',
          checklistIds: ['t1'],
        ),
      ).called(1);
    });

    test('a new name becomes a new customer', () async {
      final c = open();
      c.prepareSearch();
      c.search.text = 'Mehta house';
      c.onSearchChanged('Mehta house');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(c.canAddNew, isTrue);
      _ignoreSync(c.onNewCustomerPicked);
      expect(c.customerName, 'Mehta house');
      c.onTimePicked(const TimeOfDay(hour: 15, minute: 0));
      c.work.text = 'Gas refill';
      c.onWorkChanged(c.work.text);
      await _ignoreApp(c.onCreateTap);
      verify(
        () => jobs.create(
          title: 'Gas refill',
          scheduledAt: DateTime(2026, 10, 31, 15),
          clientUuid: c.clientUuid,
          newCustomer: 'Mehta house',
          address: '',
        ),
      ).called(1);
    });
  });

  group('M17 Assign technician', () {
    AssignTechnicianController open({String? jobId, DateTime? at}) {
      when(() => jobs.technicians(jobId: any(named: 'jobId'), at: any(named: 'at'))).thenAnswer(
        (_) async => const ApiSuccess<AssignableListModel>(
          AssignableListModel(data: [carlos, ramesh, arjun], meta: ListMetaModel()),
        ),
      );
      return AssignTechnicianController(
        jobs: jobs,
        translation: translation,
        clock: () => now,
        args: AssignArguments(
          customer: 'Green Valley Clinic',
          title: 'AC not cooling',
          jobId: jobId,
          at: at ?? DateTime(2026, 10, 31, 11, 30),
        ),
      );
    }

    test('shows each person’s day, and people who have not joined cannot be picked', () async {
      final c = open();
      await c.load();
      expect(c.summary, startsWith('AC not cooling · Sat 31 Oct, 11:30'));
      expect(c.heading, 'Available today');
      expect(c.line(ramesh), '3 jobs today · 1.1 km away');
      expect((c.loadText(ramesh), c.tone(ramesh)), ('3 of 5 jobs', LoadTone.busy));
      expect((c.loadText(carlos), c.tone(carlos)), ('2 of 5 jobs', LoadTone.light));
      expect(c.line(arjun), 'Technician · invite sent');
      _ignoreSync(() => c.onPersonTap(arjun));
      expect(c.picked.value, isNull);
      expect(c.buttonText, 'Pick a technician');
      c.onPersonTap(ramesh);
      expect(c.buttonText, 'Assign Ramesh');
      await _ignoreApp(c.onAssignTap);
      verifyNever(() => jobs.assign(any(), any()));
    });

    test('another day says so; a saved job is given at once', () async {
      when(() => jobs.assign(any(), any())).thenAnswer((_) async => ApiSuccess<JobOutModel>(jobOut()));
      final c = open(jobId: 'j1', at: DateTime(2026, 11, 2, 10));
      await c.load();
      expect(c.heading, 'Available on Mon 2 Nov');
      expect(c.line(carlos), '2 jobs that day');
      expect(c.canSaveWithout, isFalse);
      c.onPersonTap(carlos);
      await _ignoreApp(c.onAssignTap);
      verify(() => jobs.assign('j1', 'u2')).called(1);
    });
  });
}
