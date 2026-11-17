import type { Lang } from '../lib/i18n';

const LOCALES: Record<Lang, string> = { en: 'en-IN', hi: 'hi-IN', gu: 'gu-IN', es: 'es-ES', fr: 'fr-FR' };

/** "IST" for Asia/Kolkata (short zone names read best in English). */
export function zoneLabel(tz: string, at = new Date()): string {
  const part = new Intl.DateTimeFormat('en-IN', { timeZone: tz, timeZoneName: 'short' }).formatToParts(at).find((p) => p.type === 'timeZoneName');
  return part?.value ?? tz;
}

/** "11:30 am" in the given zone. */
export function timeIn(iso: string | Date, tz: string, lang: Lang): string {
  return new Intl.DateTimeFormat(LOCALES[lang], { timeZone: tz, hour: 'numeric', minute: '2-digit' }).format(new Date(iso));
}

/** "Thu, 5 November 2026" for a yyyy-mm-dd day. */
export function longDay(date: string, lang: Lang, weekday: 'short' | 'long' = 'short'): string {
  return new Intl.DateTimeFormat(LOCALES[lang], { weekday, day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' }).format(
    new Date(`${date}T12:00:00Z`),
  );
}

/** "Nov" and "5" for the calendar tile. */
export function monthDay(date: string, lang: Lang): { month: string; day: string } {
  const d = new Date(`${date}T12:00:00Z`);
  return {
    month: new Intl.DateTimeFormat(LOCALES[lang], { month: 'short', timeZone: 'UTC' }).format(d),
    day: String(d.getUTCDate()),
  };
}

/** ISO weekdays [1..6] → "Mon–Sat" (or "Mon, Wed" when not a run). */
export function weekdays(days: number[], lang: Lang): string {
  // 2024-01-01 was a Monday
  const name = (n: number) => new Intl.DateTimeFormat(LOCALES[lang], { weekday: 'short', timeZone: 'UTC' }).format(new Date(Date.UTC(2024, 0, n)));
  const sorted = [...days].sort((a, b) => a - b);
  const run = sorted.every((d, i) => i === 0 || d === sorted[i - 1]! + 1);
  return run && sorted.length > 2 ? `${name(sorted[0]!)}–${name(sorted[sorted.length - 1]!)}` : sorted.map(name).join(', ');
}

/** "09:00" (a clock time in a zone) → "9 am". */
export function clockLabel(hm: string, lang: Lang): string {
  const [h, m] = hm.split(':').map(Number);
  return new Intl.DateTimeFormat(LOCALES[lang], { hour: 'numeric', minute: m ? '2-digit' : undefined, timeZone: 'UTC' }).format(
    new Date(Date.UTC(2024, 0, 1, h ?? 0, m ?? 0)),
  );
}

/** A calendar file for "Add to calendar". */
export function icsFile(title: string, start: string, end: string, details: string): string {
  const f = (iso: string) => new Date(iso).toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
  const esc = (s: string) => s.replace(/[\;,]/g, (c) => `\\${c}`).replace(/\n/g, '\\n');
  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//KaamNishaan//Website//EN',
    'BEGIN:VEVENT',
    `UID:${f(start)}-${Math.random().toString(36).slice(2)}@kaamnishaan`,
    `DTSTAMP:${f(new Date().toISOString())}`,
    `DTSTART:${f(start)}`,
    `DTEND:${f(end)}`,
    `SUMMARY:${esc(title)}`,
    `DESCRIPTION:${esc(details)}`,
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\r\n');
}
