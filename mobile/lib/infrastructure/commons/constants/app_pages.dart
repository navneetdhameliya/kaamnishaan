import 'package:get/get.dart';

import '../../../UI/screens/auth_section/choose_company_section/choose_company_binding.dart';
import '../../../UI/screens/auth_section/check_email_section/check_email_binding.dart';
import '../../../UI/screens/auth_section/check_email_section/check_email_screen.dart';
import '../../../UI/screens/auth_section/choose_company_section/choose_company_screen.dart';
import '../../../UI/screens/auth_section/company_setup_section/company_setup_binding.dart';
import '../../../UI/screens/auth_section/company_setup_section/company_setup_screen.dart';
import '../../../UI/screens/auth_section/email_login_section/email_login_binding.dart';
import '../../../UI/screens/auth_section/email_login_section/email_login_screen.dart';
import '../../../UI/screens/auth_section/forgot_password_section/forgot_password_binding.dart';
import '../../../UI/screens/auth_section/forgot_password_section/forgot_password_screen.dart';
import '../../../UI/screens/auth_section/join_company_section/join_company_binding.dart';
import '../../../UI/screens/auth_section/join_company_section/join_company_screen.dart';
import '../../../UI/screens/auth_section/otp_section/otp_binding.dart';
import '../../../UI/screens/auth_section/otp_section/otp_screen.dart';
import '../../../UI/screens/auth_section/owner_signup_section/owner_signup_binding.dart';
import '../../../UI/screens/auth_section/owner_signup_section/owner_signup_screen.dart';
import '../../../UI/screens/auth_section/phone_section/phone_binding.dart';
import '../../../UI/screens/auth_section/phone_section/phone_screen.dart';
import '../../../UI/screens/auth_section/profile_setup_section/profile_setup_binding.dart';
import '../../../UI/screens/auth_section/profile_setup_section/profile_setup_screen.dart';
import '../../../UI/screens/checklists_section/checklist_question_section/checklist_question_binding.dart';
import '../../../UI/screens/checklists_section/checklist_question_section/checklist_question_screen.dart';
import '../../../UI/screens/checklists_section/checklists_section/checklists_binding.dart';
import '../../../UI/screens/checklists_section/checklists_section/checklists_screen.dart';
import '../../../UI/screens/home_section/home_shell_section/home_shell_binding.dart';
import '../../../UI/screens/home_section/home_shell_section/home_shell_screen.dart';
import '../../../UI/screens/jobs_section/camera_section/camera_binding.dart';
import '../../../UI/screens/jobs_section/camera_section/camera_screen.dart';
import '../../../UI/screens/jobs_section/capture_hub_section/capture_hub_binding.dart';
import '../../../UI/screens/jobs_section/capture_hub_section/capture_hub_screen.dart';
import '../../../UI/screens/jobs_section/job_details_section/job_details_binding.dart';
import '../../../UI/screens/jobs_section/job_details_section/job_details_screen.dart';
import '../../../UI/screens/jobs_section/job_list_section/job_list_binding.dart';
import '../../../UI/screens/jobs_section/job_list_section/job_list_screen.dart';
import '../../../UI/screens/jobs_section/photo_details_section/photo_details_binding.dart';
import '../../../UI/screens/jobs_section/photo_details_section/photo_details_screen.dart';
import '../../../UI/screens/jobs_section/photo_gallery_section/photo_gallery_binding.dart';
import '../../../UI/screens/jobs_section/photo_gallery_section/photo_gallery_screen.dart';
import '../../../UI/screens/jobs_section/photo_pair_section/photo_pair_binding.dart';
import '../../../UI/screens/jobs_section/photo_pair_section/photo_pair_screen.dart';
import '../../../UI/screens/onboarding_section/intro_section/intro_binding.dart';
import '../../../UI/screens/onboarding_section/intro_section/intro_screen.dart';
import '../../../UI/screens/onboarding_section/language_section/language_binding.dart';
import '../../../UI/screens/onboarding_section/language_section/language_screen.dart';
import '../../../UI/screens/onboarding_section/splash_section/splash_binding.dart';
import '../../../UI/screens/onboarding_section/splash_section/splash_screen.dart';
import '../../../UI/screens/onboarding_section/welcome_section/welcome_binding.dart';
import '../../../UI/screens/onboarding_section/welcome_section/welcome_screen.dart';
import '../../../UI/screens/report_section/report_draft_section/report_draft_binding.dart';
import '../../../UI/screens/report_section/report_draft_section/report_draft_screen.dart';
import '../../../UI/screens/report_section/report_editor_section/report_editor_binding.dart';
import '../../../UI/screens/report_section/report_editor_section/report_editor_screen.dart';
import '../../../UI/screens/report_section/report_making_section/report_making_binding.dart';
import '../../../UI/screens/report_section/report_making_section/report_making_screen.dart';
import '../../../UI/screens/report_section/report_sent_section/report_sent_binding.dart';
import '../../../UI/screens/report_section/report_sent_section/report_sent_screen.dart';
import '../../../UI/screens/voice_section/voice_note_section/voice_note_binding.dart';
import '../../../UI/screens/voice_section/voice_note_section/voice_note_screen.dart';
import '../../../UI/screens/voice_section/voice_notes_section/voice_notes_binding.dart';
import '../../../UI/screens/voice_section/voice_notes_section/voice_notes_screen.dart';
import '../../../UI/screens/voice_section/voice_record_section/voice_record_binding.dart';
import '../../../UI/screens/voice_section/voice_record_section/voice_record_screen.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static final pages = <GetPage<dynamic>>[
    GetPage(name: RoutesConstants.splashScreen, page: () => const SplashScreen(), binding: SplashBinding()),
    GetPage(name: RoutesConstants.languageScreen, page: () => const LanguageScreen(), binding: LanguageBinding()),
    GetPage(name: RoutesConstants.introScreen, page: () => const IntroScreen(), binding: IntroBinding()),
    GetPage(name: RoutesConstants.welcomeScreen, page: () => const WelcomeScreen(), binding: WelcomeBinding()),
    GetPage(name: RoutesConstants.phoneScreen, page: () => const PhoneScreen(), binding: PhoneBinding()),
    GetPage(name: RoutesConstants.otpScreen, page: () => const OtpScreen(), binding: OtpBinding()),
    GetPage(
      name: RoutesConstants.joinCompanyScreen,
      page: () => const JoinCompanyScreen(),
      binding: JoinCompanyBinding(),
    ),
    GetPage(
      name: RoutesConstants.profileSetupScreen,
      page: () => const ProfileSetupScreen(),
      binding: ProfileSetupBinding(),
    ),
    GetPage(
      name: RoutesConstants.chooseCompanyScreen,
      page: () => const ChooseCompanyScreen(),
      binding: ChooseCompanyBinding(),
    ),
    GetPage(
      name: RoutesConstants.emailLoginScreen,
      page: () => const EmailLoginScreen(),
      binding: EmailLoginBinding(),
    ),
    GetPage(
      name: RoutesConstants.ownerSignupScreen,
      page: () => const OwnerSignupScreen(),
      binding: OwnerSignupBinding(),
    ),
    GetPage(
      name: RoutesConstants.companySetupScreen,
      page: () => const CompanySetupScreen(),
      binding: CompanySetupBinding(),
    ),
    GetPage(
      name: RoutesConstants.forgotPasswordScreen,
      page: () => const ForgotPasswordScreen(),
      binding: ForgotPasswordBinding(),
    ),
    GetPage(
      name: RoutesConstants.checkEmailScreen,
      page: () => const CheckEmailScreen(),
      binding: CheckEmailBinding(),
    ),
    GetPage(name: RoutesConstants.jobListScreen, page: () => const JobListScreen(), binding: JobListBinding()),
    GetPage(
      name: RoutesConstants.jobDetailsScreen,
      page: () => const JobDetailsScreen(),
      binding: JobDetailsBinding(),
    ),
    GetPage(
      name: RoutesConstants.captureHubScreen,
      page: () => const CaptureHubScreen(),
      binding: CaptureHubBinding(),
    ),
    GetPage(name: RoutesConstants.cameraScreen, page: () => const CameraScreen(), binding: CameraBinding()),
    GetPage(
      name: RoutesConstants.photoGalleryScreen,
      page: () => const PhotoGalleryScreen(),
      binding: PhotoGalleryBinding(),
    ),
    GetPage(
      name: RoutesConstants.photoDetailsScreen,
      page: () => const PhotoDetailsScreen(),
      binding: PhotoDetailsBinding(),
    ),
    GetPage(name: RoutesConstants.photoPairScreen, page: () => const PhotoPairScreen(), binding: PhotoPairBinding()),
    GetPage(name: RoutesConstants.checklistsScreen, page: () => const ChecklistsScreen(), binding: ChecklistsBinding()),
    GetPage(
      name: RoutesConstants.checklistQuestionScreen,
      page: () => const ChecklistQuestionScreen(),
      binding: ChecklistQuestionBinding(),
    ),
    GetPage(name: RoutesConstants.voiceRecordScreen, page: () => const VoiceRecordScreen(), binding: VoiceRecordBinding()),
    GetPage(name: RoutesConstants.voiceNotesScreen, page: () => const VoiceNotesScreen(), binding: VoiceNotesBinding()),
    GetPage(name: RoutesConstants.voiceNoteScreen, page: () => const VoiceNoteScreen(), binding: VoiceNoteBinding()),
    GetPage(name: RoutesConstants.reportMakingScreen, page: () => const ReportMakingScreen(), binding: ReportMakingBinding()),
    GetPage(name: RoutesConstants.reportDraftScreen, page: () => const ReportDraftScreen(), binding: ReportDraftBinding()),
    GetPage(name: RoutesConstants.reportEditorScreen, page: () => const ReportEditorScreen(), binding: ReportEditorBinding()),
    GetPage(name: RoutesConstants.reportSentScreen, page: () => const ReportSentScreen(), binding: ReportSentBinding()),
    GetPage(
      name: RoutesConstants.homeScreen,
      page: () => const HomeShellScreen(),
      binding: HomeShellBinding(),
    ),
  ];
}
