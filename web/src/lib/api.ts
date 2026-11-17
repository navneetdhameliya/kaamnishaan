/** The KaamNishaan API (public customer pages need no login). Set VITE_API_URL on Vercel. */
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

export async function api<T>(path: string, init: { method?: string; body?: unknown; token?: string } = {}): Promise<T> {
  let res: Response;
  const headers: Record<string, string> = {};
  if (init.body !== undefined) headers['Content-Type'] = 'application/json';
  if (init.token) headers.Authorization = `Bearer ${init.token}`;
  try {
    res = await fetch(`${API_URL}/api/v1${path}`, {
      method: init.method ?? 'GET',
      headers,
      body: init.body === undefined ? undefined : JSON.stringify(init.body),
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

export const apiUrl = (path: string) => `${API_URL}/api/v1${path}`;
