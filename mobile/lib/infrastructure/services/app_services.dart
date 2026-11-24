import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../commons/constants/app_routes.dart';
import '../data_access_layer/api_providers/assistant_api_provider.dart';
import '../data_access_layer/api_providers/auth_api_provider.dart';
import '../data_access_layer/api_providers/billing_api_provider.dart';
import '../data_access_layer/api_providers/checklists_api_provider.dart';
import '../data_access_layer/api_providers/company_api_provider.dart';
import '../data_access_layer/api_providers/config_api_provider.dart';
import '../data_access_layer/api_providers/customers_api_provider.dart';
import '../data_access_layer/api_providers/files_api_provider.dart';
import '../data_access_layer/api_providers/home_api_provider.dart';
import '../data_access_layer/api_providers/jobs_api_provider.dart';
import '../data_access_layer/api_providers/me_api_provider.dart';
import '../data_access_layer/api_providers/notifications_api_provider.dart';
import '../data_access_layer/api_providers/reports_api_provider.dart';
import '../data_access_layer/api_providers/reviews_api_provider.dart';
import '../data_access_layer/api_providers/support_api_provider.dart';
import '../data_access_layer/api_providers/voice_api_provider.dart';
import '../data_access_layer/api_repository/assistant_api_repository.dart';
import '../data_access_layer/api_repository/auth_api_repository.dart';
import '../data_access_layer/api_repository/billing_api_repository.dart';
import '../data_access_layer/api_repository/checklists_api_repository.dart';
import '../data_access_layer/api_repository/company_api_repository.dart';
import '../data_access_layer/api_repository/config_api_repository.dart';
import '../data_access_layer/api_repository/customers_api_repository.dart';
import '../data_access_layer/api_repository/files_api_repository.dart';
import '../data_access_layer/api_repository/home_api_repository.dart';
import '../data_access_layer/api_repository/jobs_api_repository.dart';
import '../data_access_layer/api_repository/me_api_repository.dart';
import '../data_access_layer/api_repository/notifications_api_repository.dart';
import '../data_access_layer/api_repository/reports_api_repository.dart';
import '../data_access_layer/api_repository/reviews_api_repository.dart';
import '../data_access_layer/api_repository/support_api_repository.dart';
import '../data_access_layer/api_repository/voice_api_repository.dart';
import '../data_access_layer/networks/api_client.dart';
import '../lang/translation_service.dart';
import 'audio_service.dart';
import 'camera_service.dart';
import 'config_service.dart';
import 'image_picker_service.dart';
import 'share_service.dart';
import 'location_service.dart';
import 'photo_queue_service.dart';
import 'preferences_service.dart';
import 'session_service.dart';
import 'speech_service.dart';
import 'token_storage_service.dart';

/// Registers the app-wide services once, before runApp. Screens get them with Get.find.
abstract final class AppServices {
  /// True once every service is registered (so "Try again" after a failure doesn't register twice).
  static bool ready = false;

  static Future<void> init() async {
    Get.reset(); // a retry after a failed start begins clean
    await initializeDateFormatting(); // dates and times in all 5 languages
    final prefs = await PreferencesService.create();
    final tokens = SecureTokenStorage();
    final translation = TranslationService(prefs);

    final client = ApiClient(
      tokens: tokens,
      language: () => translation.currentCode,
      deviceId: prefs.deviceId,
      appVersion: _appVersion,
      onSessionExpired: () async {
        if (Get.isRegistered<SessionService>()) await Get.find<SessionService>().clear();
        Get.offAllNamed(RoutesConstants.welcomeScreen);
      },
      onCompanySuspended: () {
        if (Get.currentRoute == RoutesConstants.companyPausedScreen) return;
        Get.offAllNamed<void>(RoutesConstants.companyPausedScreen);
      },
    );

    Get.put<PreferencesService>(prefs, permanent: true);
    Get.put<ITokenStorage>(tokens, permanent: true);
    Get.put<TranslationService>(translation, permanent: true);
    Get.put<ApiClient>(client, permanent: true);
    Get.put<ISpeechService>(SpeechService(), permanent: true);
    Get.put<IImagePickerService>(ImagePickerService(), permanent: true);
    Get.put<IShareService>(ShareService(), permanent: true);
    Get.put<ICameraService>(CameraService(), permanent: true);
    Get.put<ILocationService>(LocationService(), permanent: true);
    Get.put<IVoiceRecorder>(VoiceRecorder(), permanent: true);
    Get.put<IVoicePlayer>(VoicePlayer(), permanent: true);

    final authRepository = AuthApiRepository(provider: AuthApiProvider(client), client: client);
    Get.put<IAuthApiRepository>(authRepository, permanent: true);
    Get.put<ICompanyApiRepository>(CompanyApiRepository(provider: CompanyApiProvider(client)), permanent: true);
    Get.put<IChecklistsApiRepository>(
      ChecklistsApiRepository(provider: ChecklistsApiProvider(client)),
      permanent: true,
    );
    Get.put<IJobsApiRepository>(JobsApiRepository(provider: JobsApiProvider(client)), permanent: true);
    Get.put<IReviewsApiRepository>(ReviewsApiRepository(provider: ReviewsApiProvider(client)), permanent: true);
    Get.put<IAssistantApiRepository>(AssistantApiRepository(provider: AssistantApiProvider(client)), permanent: true);
    Get.put<IBillingApiRepository>(BillingApiRepository(provider: BillingApiProvider(client)), permanent: true);
    Get.put<ICustomersApiRepository>(CustomersApiRepository(provider: CustomersApiProvider(client)), permanent: true);
    Get.put<IVoiceApiRepository>(VoiceApiRepository(provider: VoiceApiProvider(client)), permanent: true);
    Get.put<IReportsApiRepository>(ReportsApiRepository(provider: ReportsApiProvider(client)), permanent: true);
    Get.put<IMeApiRepository>(MeApiRepository(provider: MeApiProvider(client)), permanent: true);
    Get.put<INotificationsApiRepository>(
      NotificationsApiRepository(provider: NotificationsApiProvider(client)),
      permanent: true,
    );
    Get.put<IHomeApiRepository>(HomeApiRepository(provider: HomeApiProvider(client)), permanent: true);
    Get.put<ISupportApiRepository>(SupportApiRepository(provider: SupportApiProvider(client)), permanent: true);
    Get.put<IFilesApiRepository>(FilesApiRepository(provider: FilesApiProvider(client)), permanent: true);
    Get.put<IConfigApiRepository>(ConfigApiRepository(ConfigApiProvider(client)), permanent: true);
    Get.put<ConfigService>(ConfigService(Get.find<IConfigApiRepository>(), prefs: prefs), permanent: true);
    Get.put<SessionService>(SessionService(tokens: tokens, repository: authRepository), permanent: true);

    final photos = PhotoQueueService(
      files: Get.find(),
      jobs: Get.find(),
      checklists: Get.find<IChecklistsApiRepository>(),
      voice: Get.find<IVoiceApiRepository>(),
      folder: () async => Directory('${(await getApplicationDocumentsDirectory()).path}/pending_photos'),
      online: Connectivity().onConnectivityChanged.map((r) => r.any((c) => c != ConnectivityResult.none)),
      startDelay: const Duration(seconds: 3),
    );
    Get.put<PhotoQueueService>(await photos.init(), permanent: true);
    ready = true;
  }
}

Future<String?>? _version;

/// The app's version, read once (Signed-in devices shows it, D-146).
Future<String?> _appVersion() =>
    _version ??= PackageInfo.fromPlatform().then<String?>((p) => p.version).catchError((Object _) => null);

