import { API_URL } from './api';
import { setChangedTexts } from './i18n';

/** Fetches texts staff changed for the admin panel (A25); the built-in texts are used until then. */
export async function loadChangedTexts(): Promise<void> {
  try {
    const res = await fetch(`${API_URL}/api/v1/public/texts?area=admin`);
    if (res.ok) setChangedTexts(((await res.json()) as { texts: Record<string, Record<string, string>> }).texts);
  } catch {
    /* offline: keep the built-in texts */
  }
}
