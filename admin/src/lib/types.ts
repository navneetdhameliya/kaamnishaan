/** API shapes used by the admin panel (from shared/api/openapi.generated.json). */
import type { Lang } from './i18n';
export type StaffRole = 'super_admin' | 'admin' | 'support';

export interface StaffOut {
  id: string;
  name: string;
  email: string;
  role: StaffRole;
  recovery_codes_left: number;
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
