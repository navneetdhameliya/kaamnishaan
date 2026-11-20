import { API_URL } from './api';
import { setChangedTexts } from './i18n';

/**
 * Fetches texts staff changed for the website (A24, A25). A ?preview=… link from the admin panel also
 * shows changes that are not published yet. Resolves when done (or failed), never throws.
 */
export const textsReady: Promise<void> = (async () => {
  const preview = new URLSearchParams(window.location.search).get('preview');
  const q = new URLSearchParams({ area: 'site' });
  if (preview) q.set('preview', preview);
  try {
    const res = await fetch(`${API_URL}/api/v1/public/texts?${q}`);
    if (res.ok) {
      const body = (await res.json()) as { texts: Record<string, Record<string, string>>; preview: boolean };
      setChangedTexts(body.texts);
      if (body.preview) document.documentElement.dataset.preview = 'true';
    }
  } catch {
    /* offline: keep the built-in texts */
  }
})();
