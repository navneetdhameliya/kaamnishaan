import { useEffect, useState } from 'react';

import { api } from '../lib/api';
import { isLang, rememberLang, startLang, translator, type Lang, type T } from '../lib/i18n';
import type { ConfigOut, Money, PlansOut } from '../lib/types';

/** The website's routes. Pages from later steps show "coming soon" until they are built. */
export const ROUTES = {
  home: '/',
  pricing: '/pricing',
  features: '/features',
  demo: '/book-demo',
  trial: '/start-trial',
  login: '/login',
  contact: '/contact',
  about: '/about',
  blog: '/blog',
  privacy: '/privacy',
  terms: '/terms',
  industry: (key: string) => `/industries/${key}`,
} as const;

/** Language for the whole site, kept on this device and on <html lang>. */
export function useLang(): { lang: Lang; t: T; setLang: (l: Lang) => void } {
  const [lang, set] = useState<Lang>(startLang);
  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);
  return {
    lang,
    t: translator(lang),
    setLang: (l) => {
      if (!isLang(l)) return;
      rememberLang(l);
      set(l);
    },
  };
}

/** India pays in rupees; everyone else in dollars. ?currency=USD|INR wins. */
export function startCurrency(): 'INR' | 'USD' {
  const q = new URLSearchParams(window.location.search).get('currency')?.toUpperCase();
  if (q === 'INR' || q === 'USD') return q;
  const zone = Intl.DateTimeFormat().resolvedOptions().timeZone ?? '';
  const langs = navigator.languages?.length ? navigator.languages : [navigator.language];
  const india = /^Asia\/(Kolkata|Calcutta)$/.test(zone) || langs.some((l) => /-IN$/i.test(l) || /^(hi|gu)\b/i.test(l));
  return india ? 'INR' : 'USD';
}

type Load<D> = { kind: 'loading' } | { kind: 'ready'; data: D } | { kind: 'error' };

function useApi<D>(path: string): [Load<D>, () => void] {
  const [state, setState] = useState<Load<D>>({ kind: 'loading' });
  const [tick, setTick] = useState(0);
  useEffect(() => {
    let live = true;
    setState((s) => (s.kind === 'ready' ? s : { kind: 'loading' }));
    api<D>(path)
      .then((data) => live && setState({ kind: 'ready', data }))
      .catch(() => live && setState({ kind: 'error' }));
    return () => {
      live = false;
    };
  }, [path, tick]);
  return [state, () => setTick((n) => n + 1)];
}

/** GET /plans: prices, limits, what each plan includes, credit packs and the trial length. */
export function usePlans(lang: Lang): [Load<PlansOut>, () => void] {
  const [currency] = useState(startCurrency);
  return useApi<PlansOut>(`/plans?currency=${currency}&locale=${lang}`);
}

/** GET /config: the trades (names in the chosen language and how many ready checklists each has). */
export function useConfig(lang: Lang) {
  return useApi<ConfigOut>(`/config?locale=${lang}`)[0];
}

const LOCALES: Record<Lang, string> = { en: 'en-IN', hi: 'hi-IN', gu: 'gu-IN', es: 'es-ES', fr: 'fr-FR' };

/** "₹499", "$9", "$1,299.50" */
export function money(m: Money, lang: Lang): string {
  const value = m.amount / 100;
  return new Intl.NumberFormat(m.currency === 'USD' && lang === 'en' ? 'en-US' : LOCALES[lang], {
    style: 'currency',
    currency: m.currency,
    maximumFractionDigits: Number.isInteger(value) ? 0 : 2,
    minimumFractionDigits: Number.isInteger(value) ? 0 : 2,
  }).format(value);
}

/** "1,500" / "1,500" in the page's language. */
export function num(n: number, lang: Lang): string {
  return new Intl.NumberFormat(LOCALES[lang]).format(n);
}
