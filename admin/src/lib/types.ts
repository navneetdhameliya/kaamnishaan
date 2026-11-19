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
