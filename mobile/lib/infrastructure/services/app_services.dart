import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../commons/constants/app_routes.dart';
import '../data_access_layer/api_providers/auth_api_provider.dart';
import '../data_access_layer/api_providers/company_api_provider.dart';
import '../data_access_layer/api_providers/config_api_provider.dart';
import '../data_access_layer/api_providers/files_api_provider.dart';
import '../data_access_layer/api_providers/home_api_provider.dart';
import '../data_access_layer/api_providers/jobs_api_provider.dart';
import '../data_access_layer/api_repository/auth_api_repository.dart';
import '../data_access_layer/api_repository/company_api_repository.dart';
import '../data_access_layer/api_repository/config_api_repository.dart';
import '../data_access_layer/api_repository/files_api_repository.dart';
import '../data_access_layer/api_repository/home_api_repository.dart';
import '../data_access_layer/api_repository/jobs_api_repository.dart';
import '../data_access_layer/networks/api_client.dart';
import '../lang/translation_service.dart';
import 'config_service.dart';
import 'image_picker_service.dart';
import 'preferences_service.dart';
import 'session_service.dart';
import 'speech_service.dart';
import 'token_storage_service.dart';

/// Registers the app-wide services once, before runApp. Screens get them with Get.find.
abstract final class AppServices {
  static Future<void> init() async {
    await initializeDateFormatting(); // dates and times in all 5 languages
    final prefs = await PreferencesService.create();
    final tokens = SecureTokenStorage();
    final translation = TranslationService(prefs);

    final client = ApiClient(
      tokens: tokens,
      language: () => translation.currentCode,
      deviceId: prefs.deviceId,
      onSessionExpired: () async {
        if (Get.isRegistered<SessionService>()) await Get.find<SessionService>().clear();
        Get.offAllNamed(RoutesConstants.welcomeScreen);
      },
    );

    Get.put<PreferencesService>(prefs, permanent: true);
    Get.put<ITokenStorage>(tokens, permanent: true);
    Get.put<TranslationService>(translation, permanent: true);
    Get.put<ApiClient>(client, permanent: true);
    Get.put<ISpeechService>(SpeechService(), permanent: true);
    Get.put<IImagePickerService>(ImagePickerService(), permanent: true);

    final authRepository = AuthApiRepository(provider: AuthApiProvider(client), client: client);
    Get.put<IAuthApiRepository>(authRepository, permanent: true);
    Get.put<ICompanyApiRepository>(CompanyApiRepository(provider: CompanyApiProvider(client)), permanent: true);
    Get.put<IJobsApiRepository>(JobsApiRepository(provider: JobsApiProvider(client)), permanent: true);
    Get.put<IHomeApiRepository>(HomeApiRepository(provider: HomeApiProvider(client)), permanent: true);
    Get.put<IFilesApiRepository>(FilesApiRepository(provider: FilesApiProvider(client)), permanent: true);
    Get.put<IConfigApiRepository>(ConfigApiRepository(ConfigApiProvider(client)), permanent: true);
    Get.put<ConfigService>(ConfigService(Get.find<IConfigApiRepository>()), permanent: true);
    Get.put<SessionService>(SessionService(tokens: tokens, repository: authRepository), permanent: true);
  }
}
