import en from '../../../shared/i18n/en.json';
import es from '../../../shared/i18n/es.json';
import fr from '../../../shared/i18n/fr.json';
import gu from '../../../shared/i18n/gu.json';
import hi from '../../../shared/i18n/hi.json';

/** The five app languages; every admin text comes from shared/i18n (the same files as the app and website). */
export const LANGS = ['en', 'hi', 'gu', 'es', 'fr'] as const;
export type Lang = (typeof LANGS)[number];

const TEXTS: Record<Lang, Record<string, string>> = { en, hi, gu, es, fr };
const LOCALES: Record<Lang, string> = { en: 'en-IN', hi: 'hi-IN', gu: 'gu-IN', es: 'es-ES', fr: 'fr-FR' };
const KEY = 'kn.admin.lang';

export function isLang(x: unknown): x is Lang {
  return typeof x === 'string' && (LANGS as readonly string[]).includes(x);
}

/** ?lang=… first, then the last choice on this device, then the browser's language, then English. */
export function startLang(): Lang {
  const q = new URLSearchParams(window.location.search).get('lang');
  if (isLang(q)) return q;
  try {
    const saved = window.localStorage.getItem(KEY);
    if (isLang(saved)) return saved;
  } catch {
    /* storage may be blocked */
  }
  const nav = (navigator.language || 'en').slice(0, 2);
  return isLang(nav) ? nav : 'en';
}

export function rememberLang(lang: Lang): void {
  try {
    window.localStorage.setItem(KEY, lang);
  } catch {
    /* storage may be blocked */
  }
}

export type T = (key: string, params?: Record<string, string | number>) => string;

export function translator(lang: Lang): T {
  return (key, params) => {
    const raw = TEXTS[lang][key] ?? TEXTS.en[key] ?? key;
    return params ? raw.replace(/\{(\w+)\}/g, (m, k: string) => (k in params ? String(params[k]) : m)) : raw;
  };
}

/** "31 Oct 2026" */
export function day(iso: string, lang: Lang, opts: Intl.DateTimeFormatOptions = {}): string {
  return new Intl.DateTimeFormat(LOCALES[lang], { day: 'numeric', month: 'short', year: 'numeric', ...opts }).format(
    new Date(iso),
  );
}

/** "10:20 am" */
export function clock(iso: string, lang: Lang): string {
  return new Intl.DateTimeFormat(LOCALES[lang], { hour: 'numeric', minute: '2-digit' }).format(new Date(iso));
}

export function locale(lang: Lang): string {
  return LOCALES[lang];
}

/** Whole numbers with the language's separators: 3,902 */
export function num(n: number, lang: Lang, opts: Intl.NumberFormatOptions = {}): string {
  return new Intl.NumberFormat(LOCALES[lang], opts).format(n);
}

/** Money from minor units (paise, cents): ₹4,990 or $49 */
export function money(minor: number, currency: string, lang: Lang, digits = 0): string {
  return new Intl.NumberFormat(LOCALES[lang], {
    style: 'currency',
    currency,
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(minor / 100);
}

/** key_one when n is 1, else key (the five languages count the same way here). */
export function plural(t: T, key: string, n: number, params: Record<string, string | number> = {}): string {
  return n === 1 ? t(`${key}_one`, params) : t(key, { n, ...params });
}
