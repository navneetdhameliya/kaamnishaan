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

  // jobs
  static const String jobsAPIEP = '/jobs';
  static String jobAPIEP(String id) => '/jobs/$id';
  static String startJobAPIEP(String id) => '/jobs/$id/start';
  static String jobProofAPIEP(String id) => '/jobs/$id/proof';
  static String jobEvidenceAPIEP(String id) => '/jobs/$id/evidence';

  // checklists
  static String jobChecklistsAPIEP(String jobId) => '/jobs/$jobId/checklists';
  static String submissionAPIEP(String id) => '/checklist-submissions/$id';
  static String answerAPIEP(String id, String questionId) => '/checklist-submissions/$id/answers/$questionId';

  // evidence
  static String evidenceAPIEP(String id) => '/evidence/$id';
  static String evidenceNotesAPIEP(String id) => '/evidence/$id/notes';
  static String photoPairsAPIEP(String jobId) => '/jobs/$jobId/photo-pairs';

  // company
  static const String companiesAPIEP = '/companies';
  static const String companyAPIEP = '/company';

  // files
  static const String uploadsAPIEP = '/uploads';

  // app settings
  static const String configAPIEP = '/config';
}
