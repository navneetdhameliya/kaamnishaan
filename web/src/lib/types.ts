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
