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
  static const String sendVerificationAPIEP = '/auth/email/send-verification';
  static const String changeEmailAPIEP = '/auth/email';

  // me
  static const String meAPIEP = '/me';
  static const String meDeletionAPIEP = '/me/deletion';
  static const String meDeleteAPIEP = '/me/delete';
  static const String companyOwnerAPIEP = '/company/owner';
  static const String meStatsAPIEP = '/me/stats';
  static const String mePreferencesAPIEP = '/me/preferences';
  static const String notificationsAPIEP = '/notifications';
  static const String notificationsReadAPIEP = '/notifications/read';

  // M47 Help
  static const String supportTicketsAPIEP = '/support/tickets';
  static const String myCompaniesAPIEP = '/me/companies';
  static const String myInvitesAPIEP = '/invites/mine';
  static const String invitesAPIEP = '/invites';
  static const String invitePreviewAPIEP = '/invites/preview';
  static String resendInviteAPIEP(String id) => '/invites/$id/resend';
  static const String teamAPIEP = '/team';
  static const String companySettingsAPIEP = '/company/settings';
  static const String plansAPIEP = '/plans';
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
  static const String newJobTechniciansAPIEP = '/jobs/assignable-technicians';
  static String jobTechniciansAPIEP(String id) => '/jobs/$id/assignable-technicians';
  static String assignJobAPIEP(String id) => '/jobs/$id/assign';

  // reviews
  static String reviewRequestAPIEP(String jobId) => '/jobs/$jobId/review-request';
  static String cancelReviewRequestAPIEP(String id) => '/review-requests/$id';
  static const String myReviewsAPIEP = '/me/reviews';
  static String reviewAPIEP(String id) => '/reviews/$id';
  static const String companyReviewsAPIEP = '/reviews';
  static String reviewReplyAPIEP(String id) => '/reviews/$id/reply';
  static String reviewSuggestionAPIEP(String id) => '/reviews/$id/reply-suggestion';
  static String reviewFollowupAPIEP(String id) => '/reviews/$id/follow-up';
  static const String reviewRequestsAPIEP = '/review-requests';
  static const String reviewSettingsAPIEP = '/review-settings';

  // assistant
  static const String assistantAPIEP = '/assistant';
  static const String assistantAskAPIEP = '/assistant/ask';

  // billing
  static const String billingAPIEP = '/billing';
  static const String creditsAPIEP = '/credits';
  static const String planAPIEP = '/plan';

  // customers
  static const String customersAPIEP = '/customers';
  static String customerAPIEP(String id) => '/customers/$id';
  static String customerJobsAPIEP(String id) => '/customers/$id/jobs';

  // checklists
  static const String checklistTemplatesAPIEP = '/checklist-templates';
  static String checklistTemplateAPIEP(String id) => '/checklist-templates/$id';
  static String copyTemplateAPIEP(String id) => '/checklist-templates/$id/copy';
  static String templateQuestionsAPIEP(String id) => '/checklist-templates/$id/questions';
  static String templateQuestionAPIEP(String id, String questionId) => '/checklist-templates/$id/questions/$questionId';
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
  static const String dictationAPIEP = '/dictation';

  // reports (M31–M32)
  static String jobReportsAPIEP(String jobId) => '/jobs/$jobId/reports';
  static String reportAPIEP(String id) => '/reports/$id';
  static String reportSubmitAPIEP(String id) => '/reports/$id/submit';
  static String reportRegenerateAPIEP(String id, String section) => '/reports/$id/sections/$section/regenerate';
  static String taskAPIEP(String id) => '/tasks/$id';
  static String reportApproveAPIEP(String id) => '/reports/$id/approve';
  static String reportChangesAPIEP(String id) => '/reports/$id/request-changes';
  static String reportPdfAPIEP(String id) => '/reports/$id/pdf';
  static String reportShareAPIEP(String id) => '/reports/$id/share';
  static String reportShareLinksAPIEP(String id) => '/reports/$id/share-links';
  static String reportSendAPIEP(String id) => '/reports/$id/send';
  static String shareLinkAPIEP(String id) => '/share-links/$id';

  // company
  static const String companiesAPIEP = '/companies';
  static const String companyAPIEP = '/company';

  // files
  static const String uploadsAPIEP = '/uploads';

  // app settings
  static const String configAPIEP = '/config';
  static const String publicTextsAPIEP = '/public/texts';
}
