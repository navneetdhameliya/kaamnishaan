/** The KaamNishaan API, as staff. Set VITE_API_URL on Vercel (the Render API address). */
import { session } from './session';

export const API_URL = (import.meta.env.VITE_API_URL as string | undefined)?.replace(/\/$/, '') || 'http://localhost:8000';

export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
    public details: Record<string, unknown> = {},
    public fields: Record<string, string> = {},
  ) {
    super(message);
  }
}

type Init = { method?: string; body?: unknown; auth?: boolean; file?: Blob };

async function send<T>(path: string, init: Init, token?: string): Promise<T> {
  const headers: Record<string, string> = {};
  if (init.body !== undefined) headers['Content-Type'] = 'application/json';
  if (init.file) headers['Content-Type'] = init.file.type || 'application/octet-stream';
  if (token) headers.Authorization = `Bearer ${token}`;
  let res: Response;
  try {
    res = await fetch(`${API_URL}/api/v1${path}`, {
      method: init.method ?? 'GET',
      headers,
      body: init.file ?? (init.body === undefined ? undefined : JSON.stringify(init.body)),
    });
  } catch {
    throw new ApiError(0, 'no_internet', 'No connection');
  }
  if (res.status === 204) return undefined as T;
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const e =
      (json as { error?: { code?: string; message?: string; details?: Record<string, unknown>; fields?: Record<string, string> } })
        .error ?? {};
    throw new ApiError(res.status, e.code ?? 'unknown', e.message ?? 'Something went wrong', e.details ?? {}, e.fields ?? {});
  }
  return json as T;
}

/**
 * Calls the API. Signed-in calls (the default) send the staff token, renew it once when it has run
 * out, and end the session (back to log in) when renewing fails.
 */
export async function api<T>(path: string, init: Init = {}): Promise<T> {
  if (init.auth === false) return send<T>(path, init);
  const token = session.get()?.access_token;
  if (!token) {
    session.end(true);
    throw new ApiError(401, 'not_signed_in', 'Please log in.');
  }
  try {
    return await send<T>(path, init, token);
  } catch (e) {
    if (!(e instanceof ApiError) || e.status !== 401) throw e;
    const renewed = e.code === 'token_expired' ? await session.renew() : null;
    if (!renewed) {
      session.end(true);
      throw e;
    }
    return send<T>(path, init, renewed);
  }
}

/** Downloads a file the API makes (CSV export) with the staff token, and saves it. */
export async function download(path: string, fallbackName: string): Promise<void> {
  const go = (token?: string) =>
    fetch(`${API_URL}/api/v1${path}`, { headers: token ? { Authorization: `Bearer ${token}` } : {} });
  let res: Response;
  try {
    res = await go(session.get()?.access_token);
    if (res.status === 401) {
      const t = await session.renew();
      if (!t) {
        session.end(true);
        throw new ApiError(401, 'session_ended', 'Please log in again.');
      }
      res = await go(t);
    }
  } catch (e) {
    if (e instanceof ApiError) throw e;
    throw new ApiError(0, 'no_internet', 'No connection');
  }
  if (!res.ok) throw new ApiError(res.status, 'download_failed', 'Download failed');
  const name = /filename="([^"]+)"/.exec(res.headers.get('content-disposition') ?? '')?.[1] ?? fallbackName;
  const url = URL.createObjectURL(await res.blob());
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  a.click();
  URL.revokeObjectURL(url);
}
