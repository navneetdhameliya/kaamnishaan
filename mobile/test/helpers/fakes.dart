import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/auth_api_repository.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/config_api_repository.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/speech_service.dart';
import 'package:kaamnishaan/infrastructure/services/token_storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements IAuthApiRepository {}

class MockConfigRepository extends Mock implements IConfigApiRepository {}

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

MeOutModel me({String name = 'Ramesh Patel'}) => MeOutModel(
      id: 'u1',
      name: name,
      phone: '+919825011111',
      email: null,
      emailVerified: false,
      appLanguage: 'en',
      theme: 'system',
      role: null,
      company: null,
      permissions: const [],
    );

SessionOutModel session({List<String> needs = const [], List<MyInviteModel> invites = const []}) => SessionOutModel(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      expiresIn: 900,
      user: me(),
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
