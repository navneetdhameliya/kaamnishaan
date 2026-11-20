import { useSyncExternalStore } from 'react';

import en from '../../../shared/i18n/en.json';
import es from '../../../shared/i18n/es.json';
import fr from '../../../shared/i18n/fr.json';
import gu from '../../../shared/i18n/gu.json';
import hi from '../../../shared/i18n/hi.json';

/** The five app languages; every text on the site comes from shared/i18n (the same files as the app). */
export const LANGS = ['en', 'hi', 'gu', 'es', 'fr'] as const;
export type Lang = (typeof LANGS)[number];

const TEXTS: Record<Lang, Record<string, string>> = { en, hi, gu, es, fr };
const LOCALES: Record<Lang, string> = { en: 'en-IN', hi: 'hi-IN', gu: 'gu-IN', es: 'es-ES', fr: 'fr-FR' };
const KEY = 'kn.lang';

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

/** The built-in texts (shared/i18n), before any change made in the admin panel. */
export const BUILT_IN: Readonly<Record<Lang, Readonly<Record<string, string>>>> = TEXTS;

/** Texts staff changed in the admin panel (A24 Website content, A25 Localized content), per language. */
let changed: Partial<Record<Lang, Record<string, string>>> = {};
let changedVersion = 0;
const listeners = new Set<() => void>();

export function setChangedTexts(texts: Partial<Record<string, Record<string, string>>>): void {
  changed = Object.fromEntries(Object.entries(texts).filter(([l]) => isLang(l))) as typeof changed;
  changedVersion += 1;
  listeners.forEach((f) => f());
}

/** Changes whenever new texts arrive, so screens can translate again. */
export function useTextsVersion(): number {
  return useSyncExternalStore(
    (f) => {
      listeners.add(f);
      return () => listeners.delete(f);
    },
    () => changedVersion,
  );
}

export function translator(lang: Lang): T {
  return (key, params) => {
    const raw = changed[lang]?.[key] ?? TEXTS[lang][key] ?? changed.en?.[key] ?? TEXTS.en[key] ?? key;
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
