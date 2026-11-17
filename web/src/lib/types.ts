/** The customer report page API (GET /public/reports/{token}); see shared/api/openapi.generated.json. */
export interface PublicPhoto {
  id: string;
  stage: string;
  url: string;
  thumb_url: string | null;
  taken_at: string;
}

export interface PublicReport {
  number: string;
  job_number: string;
  title: string;
  customer: string;
  address: string | null;
  technician: string | null;
  approved_by: string | null;
  approved_at: string | null;
  completed_at: string | null;
  company: { name: string; logo_url: string | null };
  language: string;
  lang: string;
  languages: string[];
  summary: string | null;
  work_done: string[];
  advice: string[];
  pairs: { subject: string | null; before: PublicPhoto; after: PublicPhoto }[];
  photos: PublicPhoto[];
  checklists: { name: string; items: { question: string; answer: string; passed: boolean | null }[] }[];
  photos_locked_at: string | null;
  acknowledged: { at: string; name: string; organisation: string | null } | null;
  link_expires_at: string;
  pdf_ready: boolean;
  fingerprint: string | null;
  review: PublicReviewState | null;
}

export interface PublicReviewState {
  can_rate: boolean;
  rated: boolean;
  rating: number | null;
  technician: string | null;
  positive_tags: string[];
  negative_tags: string[];
}

export interface ReviewIn {
  rating: number;
  technician_rating: number | null;
  tags: string[];
  comment: string | null;
  name: string | null;
  public_allowed: boolean;
  wants_call_back: boolean;
}

export interface RatedOut {
  review_id: string;
  google_review_url: string | null;
}

export interface NewLinkOut {
  sent_to: string | null;
  channel: string | null;
  company_notified: boolean;
}

// ---- website (W01, W02): GET /config and GET /plans ----------------------------------------

export interface Money {
  amount: number; // minor units (paise, cents)
  currency: 'INR' | 'USD';
}

export interface PlanOut {
  code: string;
  name: string;
  price: Money | null; // null = contact us
  annual_price: Money | null;
  technician_limit: number | null;
  report_limit_monthly: number | null; // null = fair use
  ai_questions_monthly: number | null;
  monthly_credits: number | null;
  most_popular: boolean;
  features: string[];
  support: string | null;
}

export interface PlansOut {
  currency: 'INR' | 'USD';
  plans: PlanOut[];
  credit_packs: { id: string; credits: number; price: Money }[];
  credit_rules: { sms: number; whatsapp: number; ai_call: number; email: number };
  trial_days: number;
}

export interface TradeOut {
  key: string;
  name: string;
  checklists: number;
}

export interface ConfigOut {
  trades: TradeOut[];
}
