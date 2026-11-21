/** API shapes used by the admin panel (from shared/api/openapi.generated.json). */
import type { Lang } from './i18n';
export type StaffRole = 'super_admin' | 'admin' | 'support';

export interface StaffOut {
  id: string;
  name: string;
  email: string;
  role: StaffRole;
  recovery_codes_left: number;
  lang?: 'en' | 'hi' | 'gu' | 'es' | 'fr';
}

export interface StaffSession {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  session_ends_at: string;
  staff: StaffOut;
}

export interface StaffSetupInfo {
  email: string;
  name: string;
  is_reset: boolean;
  secret: string;
  otpauth_uri: string;
}

export interface StaffSetupOut extends StaffSession {
  recovery_codes: string[];
}

export interface Stat {
  value: number;
  previous: number;
}

export interface DashboardOut {
  days: number;
  since: string;
  active_companies: Stat;
  technicians: Stat;
  reports_sent: Stat;
  ai_cost_usd: Stat;
  ai_cost_per_report_usd: number | null;
  monthly_revenue: { currency: string; amount_minor: number }[];
  reports_per_day: { day: string; approved: number; ai_drafts: number }[];
  plan_mix: { code: string; name: string; prices: Record<string, number>; companies: number }[];
  top_companies: { id: string; name: string; trade: string | null; plan: string; reports: number }[];
  attention: {
    kind: 'near_limit' | 'past_due' | 'trial_ending' | 'new_leads';
    count: number;
    example: string | null;
    used: number | null;
    limit: number | null;
  }[];
  activity: {
    kind: 'company_created' | 'lead_demo' | 'lead_contact' | 'lead_newsletter' | 'staff_joined';
    title: string;
    at: string;
  }[];
}

export type CompanyStatus = 'trial' | 'active' | 'past_due' | 'suspended' | 'cancelled';
export type CompanyBadge = CompanyStatus | 'near_limit';
export interface Option {
  value: string;
  label: string;
}

export interface CompanyRow {
  id: string;
  name: string;
  owner_name: string | null;
  owner_email: string | null;
  country: string;
  industry: string | null;
  plan_code: string;
  plan: string;
  technicians: number;
  technician_limit: number | null;
  reports_30d: number;
  status: CompanyStatus;
  badge: CompanyBadge;
  trial_days_left: number | null;
  created_at: string;
}

export interface CompanyList {
  items: CompanyRow[];
  total: number;
  page: number;
  page_size: number;
  counts: Record<'all' | CompanyStatus, number>;
  plans: Option[];
  industries: Option[];
  countries: string[];
}

export interface PlanInfo {
  code: string;
  name: string;
  prices: Record<string, number>;
  technician_limit: number | null;
  report_limit_monthly: number | null;
}

export interface CompanyDetail {
  id: string;
  name: string;
  industry_slug: string | null;
  status: CompanyStatus;
  suspended_at: string | null;
  suspend_reason: string | null;
  badge: CompanyBadge;
  trial_ends_at: string | null;
  created_at: string;
  country: string;
  currency: string;
  timezone: string;
  report_language: string;
  industry: string | null;
  plan: PlanInfo;
  owner_name: string | null;
  owner_email: string | null;
  owner_phone: string | null;
  owner_user_id: string | null;
  owner_pending: boolean;
  health: 'good' | 'quiet' | 'at_risk';
  last_active_at: string | null;
  cycle_start: string;
  cycle_end: string;
  jobs_this_cycle: number;
  reports_this_cycle: number;
  technicians: number;
  members: number;
  approval_minutes_median: number | null;
  ai_cost_30d_usd: number;
  ai_cost_per_report_usd: number | null;
  team: { id: string; name: string | null; role: string; login: 'email' | 'phone'; language: string; status: string; last_seen_at: string | null }[];
  upgrade_to: PlanInfo | null;
}

export type Role = 'owner' | 'manager' | 'technician';
export interface UserRow {
  membership_id: string;
  user_id: string;
  name: string | null;
  phone: string | null;
  email: string | null;
  company_id: string;
  company: string;
  role: Role;
  login: 'email' | 'phone' | 'invited';
  language: string | null;
  status: 'active' | 'invited' | 'removed' | 'disabled';
  on_job: boolean;
  last_seen_at: string | null;
  invited_at: string | null;
}

export interface UserList {
  items: UserRow[];
  total: number;
  page: number;
  page_size: number;
  counts: Record<'all' | Role | 'invited', number>;
  company: Option | null;
}

export interface UserDetail {
  id: string;
  name: string | null;
  phone: string | null;
  email: string | null;
  email_verified: boolean;
  login: 'email' | 'phone' | 'invited';
  status: 'active' | 'invited' | 'disabled';
  deleted_at?: string | null;
  app_language: string;
  created_at: string;
  last_seen_at: string | null;
  on_job: boolean;
  device: string | null;
  active_sessions: number;
  companies: { membership_id: string; company_id: string; company: string; role: Role; status: string; joined_at: string | null; report_language: string }[];
  jobs_30d: number;
  reports_30d: number;
  changes_asked_30d: number;
  activity: { action: string; at: string }[];
}

export type LeadKind = 'demo' | 'contact' | 'newsletter';
export type LeadStatus = 'new' | 'contacted' | 'done' | 'spam';
export interface LeadRow {
  id: string;
  number: number;
  kind: LeadKind;
  status: LeadStatus;
  name: string;
  email: string;
  company: string | null;
  topic: string | null;
  starts_at: string | null;
  preview: string | null;
  created_at: string;
}
export interface LeadList {
  items: LeadRow[];
  total: number;
  page: number;
  page_size: number;
  counts: Record<'new' | 'demo' | 'contact' | 'newsletter' | 'done', number>;
}
export interface LeadDetail extends LeadRow {
  phone: string | null;
  team_size: string | null;
  trade: string | null;
  message: string | null;
  lang: string;
  note: string | null;
  handled_by: string | null;
  handled_at: string | null;
  company_id: string | null;
  company_name: string | null;
}

export type AuditGroup = 'security' | 'admin' | 'company' | 'team' | 'jobs' | 'reports' | 'other';
export interface AuditRow {
  id: string;
  at: string;
  actor: { kind: 'staff' | 'user' | 'system' | 'unknown'; id: string | null; name: string | null; role: string | null };
  action: string;
  group: AuditGroup;
  target_type: string | null;
  target_id: string | null;
  target: string | null;
  change: string | null;
  company_id: string | null;
  company: string | null;
  ip: string | null;
  data: Record<string, unknown>;
}
export interface AuditList {
  items: AuditRow[];
  total: number;
  page: number;
  page_size: number;
  company: Option | null;
}

export type LangState = 'ready' | 'review' | 'missing';
export type TemplateStatus = 'draft' | 'published' | 'archived';
export interface ChecklistRow {
  id: string;
  name: string;
  trade: string | null;
  trade_name: string | null;
  status: TemplateStatus;
  question_count: number;
  photo_questions: number;
  languages: Record<string, LangState>;
  used_by: number;
  updated_at: string;
}
export interface ChecklistList {
  items: ChecklistRow[];
  total: number;
  counts: { all: number; needs_translation: number; drafts: number };
  trades: Option[];
}
export interface ChecklistQuestion {
  id: string;
  position: number;
  type: 'yes_no' | 'pass_fail' | 'number' | 'text' | 'choice' | 'photo' | 'signature';
  text: Record<string, string>;
  help: Record<string, string>;
  text_status: Record<string, string>;
  options: { key: string; label: Record<string, string> }[];
  unit: string | null;
  min_value: number | null;
  max_value: number | null;
  photo_rule: 'none' | 'always' | 'if_no' | 'if_fail';
  required: boolean;
  condition: { question_id: string; equals: string } | null;
}
export interface ChecklistDetail {
  id: string;
  key: string | null;
  name: Record<string, string>;
  source_language: string;
  trade: string | null;
  trade_name: string | null;
  minutes: number | null;
  status: TemplateStatus;
  version: number;
  used_by: number;
  updated_at: string;
  languages: Record<string, LangState>;
  questions: ChecklistQuestion[];
  ai_available: boolean;
  trades: Option[];
}

export interface OwnerInvite {
  company: CompanyDetail;
  invite_link: string;
  sms_text: string;
}

// ---- A20 AI usage and cost ------------------------------------------------------------------------
export type AiTask = 'report_draft' | 'transcription' | 'translation' | 'assistant';
export type AiDay = { day: string } & Record<AiTask, number>;
export interface AiUsageOut {
  days: number;
  configured: boolean;
  total_cost_usd: number;
  budget_usd: number | null;
  cost_per_report_usd: number | null;
  target_per_report_usd: number | null;
  reports_drafted: number;
  draft_success: number | null;
  voice_minutes: number;
  per_day: AiDay[];
  companies: { id: string; name: string; cost_usd: number }[];
  others_cost_usd: number;
  others_count: number;
  models: { task: AiTask; model: string; calls: number; avg_cost_usd: number | null; per_minute: boolean; error_rate: number | null }[];
}

// ---- A37 Reviews and ratings ----------------------------------------------------------------------
export type ReviewState = 'published' | 'flagged' | 'hidden';
export type FlagReason = 'personal_data' | 'abuse' | 'spam';
export interface AdminReviewRow {
  id: string;
  comment: string | null;
  reviewer_name: string | null;
  job_title: string;
  company: { value: string; label: string };
  technician: string | null;
  rating: number;
  status: ReviewState;
  flag_reason: FlagReason | null;
  followup: 'open' | 'resolved' | null;
  replied: boolean;
  created_at: string;
}
export interface AdminReviewList {
  items: AdminReviewRow[];
  total: number;
  page: number;
  page_size: number;
  kpis: { average_rating: number | null; reviews_30d: number; share_rate: number | null; low_30d: number; low_rate: number | null; flagged: number };
  companies: { value: string; label: string }[];
}
export interface AdminReviewDetail extends AdminReviewRow {
  comment_original: string | null;
  technician_rating: number | null;
  tags: string[];
  source: 'link' | 'reply' | 'ai_call';
  job_number: string;
  reply: { text: string; by: string | null; at: string } | null;
  moderated_by: string | null;
  moderated_at: string | null;
  moderation_note: string | null;
  can_act: boolean;
}
export interface ReviewRules {
  hide_contact: boolean;
  flag_abuse: boolean;
  block_repeats: boolean;
}

// ---- A38 AI review calls --------------------------------------------------------------------------
export type CallOutcome = 'rated' | 'voicemail_sms' | 'call_back' | 'no_answer' | 'opted_out' | 'wrong_person' | 'skipped_dnd' | 'failed_sms' | 'no_provider_sms' | 'no_credits_sms' | 'not_sent';
export interface AiCallSettings {
  voice: 'warm' | 'bright' | 'formal';
  language: 'report' | 'en';
  hours: '10-19' | '9-20' | '11-18';
  attempts: 'call_voicemail' | 'two_calls' | 'call_only';
  record: boolean;
  skip_dnd: boolean;
  only_if_no_rating: boolean;
}
export interface AiCallsOut {
  provider: { connected: boolean; name: string | null; down_since: string | null; waiting: number };
  kpis: { calls: number; answered: number | null; rated: number | null; opted_out: number | null; cost_per_call_usd: number | null; sms_instead: number };
  settings: AiCallSettings;
  script: { version: number; opening: string; steps: { key: string; text: string }[] };
  calls: { id: string; at: string; company: { value: string; label: string }; contact_name: string | null; place: string | null; language: string | null; seconds: number; outcome: CallOutcome; rating: number | null; wants_call_back: boolean; callback_at: string | null; cost_usd: number }[];
  total: number;
  page: number;
  page_size: number;
  can_act: boolean;
}

// ---- A39 Message templates ------------------------------------------------------------------------
export type MsgChannel = 'sms' | 'whatsapp' | 'email';
export type TemplateKey = 'report_review' | 'review_reminder' | 'day5_sms' | 'report_link';
export interface TemplateText {
  channel: MsgChannel;
  language: Lang;
  text: string | null;
  subject: string | null;
  body: string | null;
  edited: boolean;
  checked: boolean;
}
export interface MessageTemplate {
  key: TemplateKey;
  channels: MsgChannel[];
  placeholders: string[];
  sample: Record<string, string>;
  email_only: string[];
  texts: TemplateText[];
}
export interface TemplatesOut {
  templates: MessageTemplate[];
  stop: Record<string, string>;
  sms_live: boolean;
  whatsapp_live: boolean;
  email_live: boolean;
  can_act: boolean;
}

// ---- A40 Usage and credits ------------------------------------------------------------------------
export interface CreditRow {
  company_id: string;
  company: string;
  plan: string;
  included: number | null;
  used: number;
  topup_left: number;
  topups: number;
  status: 'unlimited' | 'ok' | 'low' | 'out';
}
export interface CreditsOut {
  kpis: { used_30d: number; included_30d: number; topup_credits_30d: number; topups_30d: number; sms_30d: number; whatsapp_30d: number; calls_30d: number; out_of_credits: number; paused_requests: number };
  rules: { sms: number; whatsapp: number; ai_call: number };
  plans: { code: string; name: string; monthly_credits: number | null; companies: number }[];
  packs: { credits: number; prices: { amount: number; currency: string }[] }[];
  items: CreditRow[];
  total: number;
  page: number;
  page_size: number;
  can_act: boolean;
}

// ---- A32 Platform settings ------------------------------------------------------------------------
export interface PlatformSettings {
  support_email: string | null;
  support_whatsapp: string | null;
  default_country: string | null;
  signups: boolean;
  ai_drafting: boolean;
  ai_assistant: boolean;
  maintenance: boolean;
  max_photo_mb: number;
}
export interface PlatformOut {
  settings: PlatformSettings;
  server: { support_email: string | null; support_whatsapp: string | null; default_country: string; ai_key: boolean; email_on: boolean };
  countries: { value: string; label: string }[];
  can_act: boolean;
}

// ---- A33 Email settings ---------------------------------------------------------------------------
export type EmailGroups = { account: boolean; reports: boolean; reminders: boolean; team: boolean };
export interface EmailSettingsOut {
  settings: { enabled: boolean; from_name: string; from_email: string | null; host: string | null; port: number; security: 'starttls' | 'ssl'; username: string | null; password_set: boolean; groups: EmailGroups };
  live: boolean;
  can_act: boolean;
}

/** A10 Roles and permissions (GET /admin/roles). */
export type RoleCell = { value: 'yes' | 'no' | 'partial'; note: string | null };
export type RoleRow = { key: string; cells: Record<string, RoleCell> };
export interface StaffRow {
  id: string;
  name: string;
  email: string;
  role: StaffRole;
  status: 'invited' | 'active' | 'disabled';
  last_login_at: string | null;
  created_at: string;
  me: boolean;
}
export interface RolesOut {
  matrix: RoleRow[];
  staff_matrix: RoleRow[];
  staff: StaffRow[];
  can_act: boolean;
}
export interface StaffLink {
  staff: StaffRow;
  setup_link: string;
}

/** A11 Jobs and A12 Job details (GET /admin/jobs, /admin/jobs/{id}). */
export type JobStatus = 'unassigned' | 'assigned' | 'in_progress' | 'in_review' | 'changes_requested' | 'completed' | 'cancelled';
export type AdminProof = { done: number; total: number };
export interface AdminJobRow {
  id: string;
  number: string;
  title: string;
  customer: string;
  company: Option;
  technician: string | null;
  status: JobStatus;
  proof: AdminProof;
  when: string;
  is_quick_job: boolean;
}
export interface AdminJobList {
  items: AdminJobRow[];
  total: number;
  page: number;
  page_size: number;
  counts: Partial<Record<JobStatus, number>>;
  companies: Option[];
}
export interface AdminTimelineItem {
  type: string;
  at: string;
  until: string | null;
  actor: string | null;
  data: { technician?: string | null; reason?: string; quick_job?: boolean; fields?: string[]; stage?: string; count?: number; reasons?: string[] };
}
export interface AdminJobDetail {
  id: string;
  number: string;
  title: string;
  description: string | null;
  status: JobStatus;
  is_quick_job: boolean;
  company: Option;
  industry: string | null;
  customer: string;
  contact: string | null;
  technician: string | null;
  scheduled_at: string | null;
  duration_min: number | null;
  created_at: string;
  completed_at: string | null;
  cancel_reason: string | null;
  place: { address: string | null; site_lat: number | null; site_lng: number | null; started_at: string | null; start_lat: number | null; start_lng: number | null; start_distance_m: number | null };
  checklists: { name: string; answered: number; total: number; done: boolean }[];
  photos: { before: number; during: number; after: number; voice_notes: number };
  proof: AdminProof;
  report: { id: string; number: string; status: string; submitted_at: string | null; approved_at: string | null; shared_at: string | null; acknowledged_at: string | null; change_requests: number; open_count: number } | null;
  timeline: AdminTimelineItem[];
}

/** A13 Evidence review (GET /admin/evidence). */
export type PhotoCheck = 'duplicate' | 'no_gps' | 'far' | 'early';
export type PhotoStage = 'before' | 'during' | 'after';
export interface AdminPhoto {
  id: string;
  thumb_url: string | null;
  stage: PhotoStage;
  job: { id: string; number: string; title: string; customer: string };
  company: Option;
  taken_at: string;
  gps: boolean;
  locked: boolean;
  checks: PhotoCheck[];
  staff_flag: { note: string; by: string | null; at: string } | null;
}
export interface AdminPhotoList {
  items: AdminPhoto[];
  total: number;
  page: number;
  page_size: number;
  needs_look: number;
  companies: Option[];
  can_act: boolean;
}
export interface AdminPhotoDetail extends AdminPhoto {
  image_url: string;
  taken_by: string | null;
  distance_m: number | null;
  width: number | null;
  height: number | null;
  size: number;
  fingerprint: string | null;
  job_created_at: string;
  twins: { id: string; job: AdminPhoto['job']; company: Option; taken_at: string }[];
}

/** A14 Reports and A15 Report details (GET /admin/reports, /admin/reports/{id}). */
export type ReportStatus = 'generating' | 'generation_failed' | 'draft' | 'pending_review' | 'changes_requested' | 'approved' | 'shared' | 'acknowledged';
export type AiCheck = 'passed' | 'failed_check' | 'missing_evidence' | 'unsupported_claim' | 'not_checked';
export type AdminReportJob = { id: string; number: string; title: string; customer: string };
export interface AdminReportRow {
  id: string;
  number: string;
  status: ReportStatus;
  language: string;
  job: AdminReportJob;
  company: Option;
  technician: string | null;
  check: AiCheck;
  check_count: number;
  created_at: string;
  shared_at: string | null;
}
export interface AdminReportList {
  items: AdminReportRow[];
  total: number;
  page: number;
  page_size: number;
  counts: Partial<Record<ReportStatus, number>>;
  companies: Option[];
}
export interface AdminReportDetail {
  id: string;
  number: string;
  status: ReportStatus;
  language: string;
  job: AdminReportJob;
  company: Option;
  technician: string | null;
  drafted_by: 'ai' | 'template' | null;
  edited_by: string[];
  summary: string | null;
  work_done: string | null;
  advice: string | null;
  photos: { stage: string; url: string }[];
  sentences: number;
  sentences_linked: number;
  checks_passed: number;
  checks_failed: number;
  flags: { kind: 'missing_evidence' | 'failed_check' | 'unsupported_claim'; text: string }[];
  ai_prompt_version: number | null;
  ai_tokens: number;
  ai_cost_usd: number;
  error: string | null;
  submitted_by: string | null;
  submitted_at: string | null;
  approved_by: string | null;
  approved_at: string | null;
  shared_at: string | null;
  acknowledged_at: string | null;
  acknowledged_name: string | null;
  changes: { reasons: string[]; note: string | null; by: string | null; at: string; resolved_at: string | null }[];
  links: { channel: string; recipient: string | null; created_at: string; expires_at: string; revoked: boolean; opens: number; last_opened_at: string | null }[];
  versions: { version: number; event: string; source: string; by: string | null; at: string }[];
  pdf_url: string | null;
  created_at: string;
}

/** A16 Subscriptions, A17 Plans and pricing, A18 Payments. */
export type Money = { currency: string; amount_minor: number };
export type CompanyBadgeKey = 'trial' | 'active' | 'past_due' | 'suspended' | 'cancelled' | 'near_limit';
export interface AdminSubRow {
  id: string;
  name: string;
  plan_code: string;
  plan: string;
  price: Money | null;
  status: Exclude<CompanyBadgeKey, 'near_limit'>;
  badge: CompanyBadgeKey;
  trial_days_left: number | null;
  renews_at: string | null;
  seats: number;
  seat_limit: number | null;
}
export interface AdminSubList {
  kpis: { mrr: Money[]; paying: number; on_free: number; trials: number; trials_ending_7d: number; past_due: number; cancelled_30d: number };
  items: AdminSubRow[];
  total: number;
  page: number;
  page_size: number;
}
export interface AdminPlan {
  code: string;
  name: Record<string, string>;
  prices: Record<string, number>;
  technician_limit: number | null;
  report_limit_monthly: number | null;
  monthly_credits: number | null;
  ai_questions_monthly: number | null;
  most_popular: boolean;
  is_public: boolean;
  features: string[];
  support: string | null;
  companies: number;
  trials: number;
}
export interface AdminPlansOut {
  plans: AdminPlan[];
  packs: { id: string; credits: number; prices: Record<string, number>; active: boolean }[];
  trial: { plan_code: string; days: number };
  currencies: string[];
  can_act: boolean;
  pricing_url: string;
}
export interface AdminPaymentsOut {
  connected: boolean;
  provider: string | null;
  items: unknown[];
}

/** A19 AI configuration, A21 Prompts, A22 Industries. */
export interface AiConfig {
  text_model: string;
  transcribe_model: string;
  fallback: 'template' | 'error';
  monthly_budget_usd: number;
  max_tokens_report: number;
  mask_contacts: boolean;
}
export interface AdminAiConfigOut {
  config: AiConfig;
  text_models: string[];
  transcribe_models: string[];
  key_set: boolean;
  month_spend_usd: number;
  can_act: boolean;
}
export type PromptTask = 'report_draft' | 'assistant' | 'translation';
export interface AdminPromptVersion {
  version: number;
  status: 'draft' | 'live' | 'retired';
  system_prompt: string;
  note: string | null;
  edited_by: string | null;
  published_by: string | null;
  published_at: string | null;
  created_at: string;
  updated_at: string;
  reports: number | null;
  flagged: number | null;
}
export interface AdminPrompt {
  task: PromptTask;
  live: number | null;
  draft: number | null;
  variables: string[];
  versions: AdminPromptVersion[];
  stats: { runs: number; failed: number; avg_tokens: number; avg_cost_usd: number };
}
export interface AdminPromptsOut {
  prompts: AdminPrompt[];
  can_act: boolean;
}
export interface AdminIndustry {
  slug: string;
  name: Record<string, string>;
  status: 'live' | 'draft';
  sort: number;
  companies: number;
  checklists: number;
  default_checklist: string | null;
  default_questions: number | null;
}
export interface AdminIndustriesOut {
  items: AdminIndustry[];
  can_act: boolean;
}

/** A28 Support tickets, A29 Notifications. */
export type TicketStatus = 'open' | 'waiting' | 'solved';
export interface AdminTicketRow {
  id: string;
  number: string;
  subject: string;
  category: 'problem' | 'question' | 'billing' | 'feature';
  status: TicketStatus;
  priority: 'normal' | 'high';
  company: string | null;
  company_id: string | null;
  person: string | null;
  created_at: string;
  last_message_at: string;
  last_from: 'user' | 'staff';
}
export interface AdminTicketList {
  items: AdminTicketRow[];
  total: number;
  page: number;
  page_size: number;
  counts: { open: number; waiting: number; solved: number; high: number };
}
export interface AdminTicketDetail extends AdminTicketRow {
  plan: string | null;
  company_status: string | null;
  person_role: string | null;
  person_phone: string | null;
  lang: string;
  app_version: string | null;
  job_id: string | null;
  job_number: string | null;
  messages: { id: string; from_support: boolean; internal: boolean; author: string | null; body: string; created_at: string }[];
}
export type Audience = 'everyone' | 'owners_managers' | 'owners' | 'company';
export interface AdminAnnouncement {
  id: string;
  audience: Audience;
  company: string | null;
  title: Record<string, string>;
  body: Record<string, string>;
  send_at: string;
  sent_at: string | null;
  cancelled_at: string | null;
  recipients: number;
  by: string | null;
}
export interface AdminNotificationsOut {
  rules: { kind: string; on: boolean; to: string; channel: 'in_app' | 'email'; available: boolean }[];
  announcements: AdminAnnouncement[];
  audience_sizes: Record<string, number>;
  can_act: boolean;
}

/** A24 Website content, A25 Localized content. */
export interface FieldValue {
  live: string | null;
  draft: string | null;
  has_draft: boolean;
}
export interface AdminPageField {
  key: string;
  label: string;
  n: number | null;
  max: number;
  multiline: boolean;
  values: Record<string, FieldValue>;
}
export interface AdminPageOut {
  page: string;
  path: string;
  trade: string | null;
  sections: { key: string; fields: AdminPageField[] }[];
  drafts: number;
  edited_at: string | null;
  edited_by: string | null;
}
export interface AdminPagesOut {
  pages: { page: string; path: string; trade: string | null; drafts: number; changed: number; edited_at: string | null }[];
  can_act: boolean;
  web_url: string;
}
export interface AdminTextRow {
  key: string;
  lang: string;
  value: string | null;
  draft: string | null;
  has_draft: boolean;
  reviewed_at: string | null;
  reviewed_by: string | null;
  updated_at: string;
}
export interface AdminTextsOut {
  rows: AdminTextRow[];
  can_act: boolean;
}
export interface AdminTextChange {
  key: string;
  lang: string;
  set_value?: boolean;
  value?: string | null;
  reviewed?: boolean;
}

/** A26 Blog management, A27 Testimonials. */
export type BlogState = 'draft' | 'scheduled' | 'published';
export interface AdminBlogRow {
  id: string;
  slug: string;
  title: string;
  category: string;
  cover_url: string;
  author: string;
  languages: string[];
  state: BlogState;
  publish_at: string | null;
  read_minutes: number;
  featured: boolean;
  updated_at: string;
}
export interface AdminBlogList {
  items: AdminBlogRow[];
  counts: Record<'all' | BlogState, number>;
  categories: string[];
  can_act: boolean;
}
export interface BlogBlock {
  type: 'p' | 'h2' | 'quote' | 'list' | 'image';
  text?: string | null;
  by?: string | null;
  title?: string | null;
  items?: string[];
  src?: string | null;
  caption?: string | null;
}
export interface BlogContent {
  title: string;
  summary: string;
  author: string;
  blocks: BlogBlock[];
}
export interface AdminBlogDetail {
  id: string;
  slug: string;
  category: string;
  featured: boolean;
  state: BlogState;
  publish_at: string | null;
  cover: string;
  cover_url: string;
  content: Record<string, BlogContent>;
  web_url: string;
  site_url: string;
  updated_at: string;
  updated_by: string | null;
  can_act: boolean;
}
export interface MediaOut {
  key: string;
  url: string;
}
export interface AdminTestimonial {
  id: string;
  quote: Record<string, string>;
  person_name: string;
  role: string;
  company_name: string;
  city: string | null;
  photo: string | null;
  photo_url: string | null;
  approved_in_writing: boolean;
  approval_note: string | null;
  on_website: boolean;
  updated_at: string;
}
export interface AdminTestimonials {
  items: AdminTestimonial[];
  can_act: boolean;
}

/** A30 Analytics, A34 Storage, A35 Localization, A36 My profile. */
export interface Metric {
  value: number | null;
  previous: number | null;
}
export interface Share {
  key: string;
  label: string | null;
  count: number;
}
export interface AdminAnalyticsOut {
  days: number;
  reports_sent: Metric;
  review_minutes: Metric;
  first_time: Metric;
  active_technicians: Metric;
  step: 'day' | 'week';
  sent_by_period: { start: string; count: number }[];
  voice_languages: Share[];
  voice_total: number;
  reports_by_industry: Share[];
}
export interface AdminStorageOut {
  provider: 'local' | 'r2';
  bucket: string;
  kinds: { kind: 'photos' | 'voice' | 'pdfs'; files: number; bytes: number }[];
  total_bytes: number;
  top_companies: { id: string; name: string; bytes: number }[];
  link_minutes: number;
  max_photo_mb: number;
  locked_evidence: number;
}
export interface AdminLocalizationOut {
  languages: { code: string; native_name: string; app_checked: number; site_checked: number; reports: boolean; voice: boolean }[];
  report_language: string;
  can_act: boolean;
}
export interface StaffDevice {
  id: string;
  device: string;
  ip: string | null;
  started_at: string;
  last_used_at: string | null;
  ends_at: string;
  current: boolean;
}
