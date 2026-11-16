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

  // voice notes (M27–M29)
  static String jobVoiceNotesAPIEP(String jobId) => '/jobs/$jobId/voice-notes';
  static String jobTypedNotesAPIEP(String jobId) => '/jobs/$jobId/notes';
  static String voiceNoteAPIEP(String id) => '/voice-notes/$id';
  static String retranscribeAPIEP(String id) => '/voice-notes/$id/retranscribe';

  // reports (M31–M32)
  static String jobReportsAPIEP(String jobId) => '/jobs/$jobId/reports';
  static String reportAPIEP(String id) => '/reports/$id';
  static String reportSubmitAPIEP(String id) => '/reports/$id/submit';
  static String reportRegenerateAPIEP(String id, String section) => '/reports/$id/sections/$section/regenerate';
  static String taskAPIEP(String id) => '/tasks/$id';

  // company
  static const String companiesAPIEP = '/companies';
  static const String companyAPIEP = '/company';

  // files
  static const String uploadsAPIEP = '/uploads';

  // app settings
  static const String configAPIEP = '/config';
}
