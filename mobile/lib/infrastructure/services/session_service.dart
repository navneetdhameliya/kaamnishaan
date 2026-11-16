import 'package:get/get.dart';

import '../commons/constants/app_routes.dart';
import '../data_access_layer/api_repository/auth_api_repository.dart';
import '../models/api_models.g.dart';
import 'token_storage_service.dart';

/// Who is signed in, and which screen comes next after login (M10 join, M11 profile,
/// choose company, or home). The rules follow the backend's `needs` list.
class SessionService extends GetxService {
  SessionService({required this.tokens, required this.repository});

  final ITokenStorage tokens;
  final IAuthApiRepository repository;

  final Rxn<MeOutModel> me = Rxn<MeOutModel>();
  final RxList<CompanyChoiceModel> companies = <CompanyChoiceModel>[].obs;
  final RxList<MyInviteModel> invites = <MyInviteModel>[].obs;
  final RxList<String> needs = <String>[].obs;

  bool get isLoggedIn => me.value != null;

  Future<void> apply(SessionOutModel session) async {
    await tokens.save(session.accessToken, session.refreshToken);
    me.value = session.user;
    companies.assignAll(session.companies);
    invites.assignAll(session.invites);
    needs.assignAll(session.needs);
  }

  /// On app start: if a login is saved, renew it and return the next screen; else null.
  Future<String?> restore() async {
    if (await tokens.readRefresh() == null) return null;
    final result = await repository.refreshSession();
    final session = result.dataOrNull;
    if (session == null) {
      if (result.errorOrNull?.isNetwork ?? false) return RoutesConstants.homeScreen; // offline: keep going
      await tokens.clear();
      return null;
    }
    await apply(session);
    return nextRoute();
  }

  String nextRoute() {
    if (needs.contains('create_or_join_company')) return RoutesConstants.joinCompanyScreen;
    if (needs.contains('profile')) return RoutesConstants.profileSetupScreen;
    if (needs.contains('choose_company')) return RoutesConstants.chooseCompanyScreen;
    return RoutesConstants.homeScreen;
  }

  /// After joining a company or saving the profile: renew the session so the token carries the company.
  Future<String> refreshAndRoute() async {
    final session = (await repository.refreshSession()).dataOrNull;
    if (session != null) await apply(session);
    return nextRoute();
  }

  Future<void> logout() async {
    await repository.logout();
    await clear();
  }

  Future<void> clear() async {
    await tokens.clear();
    me.value = null;
    companies.clear();
    invites.clear();
    needs.clear();
  }
}
