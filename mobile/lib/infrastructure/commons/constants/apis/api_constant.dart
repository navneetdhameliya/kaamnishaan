/// Endpoint paths only (the base URL comes from Env; no keys here).
abstract final class APIConstant {
  static const String apiPrefix = '/api/v1';

  // auth
  static const String otpSendAPIEP = '/auth/otp/send';
  static const String otpVerifyAPIEP = '/auth/otp/verify';
  static const String loginAPIEP = '/auth/login';
  static const String registerAPIEP = '/auth/register';
  static const String forgotPasswordAPIEP = '/auth/password/forgot';
  static const String refreshTokenAPIEP = '/auth/refresh';
  static const String logoutAPIEP = '/auth/logout';
  static const String switchCompanyAPIEP = '/auth/switch-company';

  // me
  static const String meAPIEP = '/me';
  static const String myCompaniesAPIEP = '/me/companies';
  static const String myInvitesAPIEP = '/invites/mine';
  static String acceptInviteAPIEP(String id) => '/invites/$id/accept';
  static String declineInviteAPIEP(String id) => '/invites/$id/decline';

  // home
  static const String todayAPIEP = '/me/today';
  static const String dashboardAPIEP = '/dashboard';
  static const String reportsAPIEP = '/reports';

  // company
  static const String companiesAPIEP = '/companies';
  static const String companyAPIEP = '/company';

  // files
  static const String uploadsAPIEP = '/uploads';

  // app settings
  static const String configAPIEP = '/config';
}
