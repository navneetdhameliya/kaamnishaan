import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/auth_api_repository.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/company_api_repository.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/config_api_repository.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/files_api_repository.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/home_api_repository.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/image_picker_service.dart';
import 'package:kaamnishaan/infrastructure/services/speech_service.dart';
import 'package:kaamnishaan/infrastructure/services/token_storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements IAuthApiRepository {}

class MockConfigRepository extends Mock implements IConfigApiRepository {}

class MockCompanyRepository extends Mock implements ICompanyApiRepository {}

class MockFilesRepository extends Mock implements IFilesApiRepository {}

class MockHomeRepository extends Mock implements IHomeApiRepository {}

JobListItemModel job({
  String id = 'j1',
  String customer = 'Green Valley Clinic',
  String title = 'AC not cooling',
  String status = 'assigned',
  DateTime? at,
  ProofCountModel? proof,
}) =>
    JobListItemModel(
      id: id,
      number: 'J-1001',
      title: title,
      status: status,
      scheduledAt: at ?? DateTime(2026, 10, 31, 11, 30),
      customer: CustomerRefModel(id: 'c-$id', name: customer),
      site: SiteBriefModel(id: 's-$id', address: '4 Lake Road'),
      isQuickJob: false,
      version: 1,
      updatedAt: DateTime(2026, 10, 31),
      proof: proof,
    );

TodayModel todayData({JobListItemModel? current, List<JobListItemModel> next = const [], ContactRefModel? manager}) =>
    TodayModel(
      date: '2026-10-31',
      name: 'Ramesh Patel',
      company: 'BrightAir Services',
      stats: TodayStatsModel(jobs: 1 + next.length, done: next.where((j) => j.status == 'completed').length, photos: 12),
      currentJob: current,
      nextJobs: next,
      unread: 1,
      manager: manager,
    );

DashboardModel dashboardData({bool teamInvited = true, bool firstJob = true, int week = 38, int lastWeek = 34}) =>
    DashboardModel(
      date: '2026-10-31',
      today: const {'unassigned': 1, 'assigned': 2, 'in_progress': 3, 'done': 5},
      toReview: 2,
      week: [
        for (var i = 0; i < 7; i++)
          DayCountModel(date: '2026-10-${25 + i}', completed: i, reportsSent: const [4, 6, 5, 8, 7, 3, 5][i]),
      ],
      reportsWeek: week,
      reportsLastWeek: lastWeek,
      teamNow: const [
        TeamNowModel(id: 'u2', name: 'Ramesh Patel', role: 'technician', status: 'on_job', currentJob: 'J-1001'),
        TeamNowModel(id: 'u3', name: 'Carlos Diaz', role: 'technician', status: 'idle'),
        TeamNowModel(id: 'i1', name: 'Arjun', role: 'technician', status: 'invited'),
      ],
      onboarding: OnboardingModel(teamInvited: teamInvited, firstJobCreated: firstJob, firstReportSent: false),
    );

ReportListItemModel reviewItem({DateTime? submitted}) => ReportListItemModel(
      id: 'r1',
      number: 'R-1001',
      status: 'pending_review',
      job: const JobBriefModel(
        id: 'j1',
        number: 'J-1001',
        title: 'AC not cooling',
        status: 'in_review',
        customer: 'Green Valley Clinic',
        technician: PersonRefModel(id: 'u2', name: 'Ramesh Patel'),
        photos: 6,
      ),
      draftedBy: 'ai',
      flags: 0,
      submittedAt: submitted ?? DateTime(2026, 10, 31, 9, 20),
      updatedAt: DateTime(2026, 10, 31),
    );

/// Hands back [next] as if the person had taken or chosen it.
class FakeImagePicker implements IImagePickerService {
  PickedImage? next;
  final sources = <PickSource>[];

  @override
  Future<PickedImage?> pick(PickSource source, {double maxSide = 1024}) async {
    sources.add(source);
    return next;
  }
}

final tinyJpeg = PickedImage(bytes: Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xD9]), contentType: 'image/jpeg');

class MemoryTokenStorage implements ITokenStorage {
  MemoryTokenStorage({this.access, this.refresh});

  String? access;
  String? refresh;

  @override
  Future<String?> readAccess() async => access;

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<void> save(String a, String r) async {
    access = a;
    refresh = r;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

class FakeSpeech implements ISpeechService {
  final spoken = <String>[];

  @override
  Future<void> speak(String text, {required String languageCode}) async => spoken.add('$languageCode:$text');

  @override
  Future<void> stop() async {}
}

/// Answers HTTP calls from a list of handlers, so the API client can be tested without a server.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object? data, int status) => ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

MeOutModel me({String name = 'Ramesh Patel', String? phone = '+919825011111', String? email, String? trade}) =>
    MeOutModel(
      id: 'u1',
      name: name,
      phone: phone,
      email: email,
      trade: trade,
      emailVerified: false,
      appLanguage: 'en',
      theme: 'system',
      role: null,
      company: null,
      permissions: const [],
    );

SessionOutModel session({
  List<String> needs = const [],
  List<MyInviteModel> invites = const [],
  MeOutModel? user,
}) =>
    SessionOutModel(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      expiresIn: 900,
      user: user ?? me(),
      needs: needs,
      companies: const [],
      invites: invites,
    );

MyInviteModel invite({String status = 'pending'}) => MyInviteModel(
      id: 'inv1',
      company: const InviteCompanyModel(id: 'c1', name: 'BrightAir Services', country: 'IN', trade: 'hvac'),
      invitedBy: const InviterOutModel(name: 'Priya Mehta', phone: '+919800000000'),
      role: 'technician',
      status: status,
      sentAt: DateTime.now().subtract(const Duration(days: 2)),
      expiresAt: DateTime.now().add(const Duration(days: 5)),
    );
