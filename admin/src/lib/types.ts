/** API shapes used by the admin panel (from shared/api/openapi.generated.json). */
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
  status: CompanyStatus;
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
