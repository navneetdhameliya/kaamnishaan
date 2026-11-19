/**
 * The staff session lives in this browser tab only (sessionStorage): closing the tab logs out, and a
 * session ends 12 hours after log in whatever happens (the API decides). Nothing else is stored.
 */
import type { StaffSession } from './types';

const KEY = 'kn.admin.session';
const ENDED = 'kn.admin.ended';
type Listener = (s: StaffSession | null) => void;
const listeners = new Set<Listener>();
let current: StaffSession | null = read();
let renewing: Promise<string | null> | null = null;

function read(): StaffSession | null {
  try {
    const raw = window.sessionStorage.getItem(KEY);
    return raw ? (JSON.parse(raw) as StaffSession) : null;
  } catch {
    return null;
  }
}

function write(s: StaffSession | null): void {
  current = s;
  try {
    if (s) window.sessionStorage.setItem(KEY, JSON.stringify(s));
    else window.sessionStorage.removeItem(KEY);
  } catch {
    /* storage may be blocked: the session still works until the page is reloaded */
  }
  listeners.forEach((l) => l(s));
}

const API = () => ((import.meta.env.VITE_API_URL as string | undefined)?.replace(/\/$/, '') || 'http://localhost:8000') + '/api/v1';

export const session = {
  get: () => current,
  set: (s: StaffSession) => write(s),
  subscribe(l: Listener): () => void {
    listeners.add(l);
    return () => listeners.delete(l);
  },
  /** New tokens from the refresh token; one renewal at a time. */
  renew(): Promise<string | null> {
    const refresh = current?.refresh_token;
    if (!refresh) return Promise.resolve(null);
    renewing ??= fetch(`${API()}/admin/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refresh }),
    })
      .then(async (r) => {
        if (!r.ok) return null;
        const s = (await r.json()) as StaffSession;
        write(s);
        return s.access_token;
      })
      .catch(() => null)
      .finally(() => {
        renewing = null;
      });
    return renewing;
  },
  /** Forget the session; `expired` shows "Your session ended" on the log-in page. */
  end(expired = false): void {
    try {
      if (expired && current) window.sessionStorage.setItem(ENDED, '1');
    } catch {
      /* ignore */
    }
    write(null);
  },
  /** True once after a session ended by itself. */
  takeEnded(): boolean {
    try {
      const v = window.sessionStorage.getItem(ENDED) === '1';
      window.sessionStorage.removeItem(ENDED);
      return v;
    } catch {
      return false;
    }
  },
};
