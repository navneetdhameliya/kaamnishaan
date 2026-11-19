import { AlertCircle, ChevronDown, Globe, Loader2, Lock } from 'lucide-react';
import { useEffect, useRef, useState, type ClipboardEvent, type KeyboardEvent, type ReactNode } from 'react';

import { LANGS, type Lang, type T } from './lib/i18n';

export function cx(...parts: (string | false | null | undefined)[]): string {
  return parts.filter(Boolean).join(' ');
}

// ---- tiny router: the admin panel is one page; paths change without reloading -----------------------
export function navigate(to: string, replace = false): void {
  if (to === window.location.pathname + window.location.search) return;
  window.history[replace ? 'replaceState' : 'pushState'](null, '', to);
  window.dispatchEvent(new PopStateEvent('popstate'));
}

export function useLocation(): { path: string; search: URLSearchParams } {
  const read = () => ({ path: window.location.pathname, search: new URLSearchParams(window.location.search) });
  const [loc, setLoc] = useState(read);
  useEffect(() => {
    const on = () => setLoc(read());
    window.addEventListener('popstate', on);
    return () => window.removeEventListener('popstate', on);
  }, []);
  return loc;
}

export function Link({ to, className, children, onClick, ...rest }: { to: string; className?: string; children: ReactNode; onClick?: () => void; 'aria-current'?: 'page' }) {
  return (
    <a
      href={to}
      className={className}
      onClick={(e) => {
        if (e.metaKey || e.ctrlKey || e.shiftKey || e.button !== 0) return;
        e.preventDefault();
        onClick?.();
        navigate(to);
      }}
      {...rest}
    >
      {children}
    </a>
  );
}

// ---- small pieces ---------------------------------------------------------------------------------
export function Spinner({ className }: { className?: string }) {
  return <Loader2 width={18} height={18} className={cx('kn-spin', className)} aria-hidden />;
}

export function Initials({ name, className }: { name: string; className?: string }) {
  const letters = name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase())
    .join('');
  return (
    <span aria-hidden className={cx('inline-flex shrink-0 items-center justify-center font-semibold', className)}>
      {letters || '·'}
    </span>
  );
}

export function ErrorBanner({ children, shake }: { children: ReactNode; shake?: number }) {
  return (
    <p key={shake} role="alert" className="kn-shake flex items-start gap-12 rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">
      <AlertCircle width={18} height={18} className="mt-[2px] shrink-0" aria-hidden />
      <span>{children}</span>
    </p>
  );
}

export const inputCls =
  'h-[56px] w-full rounded-lg border border-border-strong bg-bg-surface px-16 text-latin-body text-text-primary placeholder:text-taupe-500 hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring';

export const primaryBtn =
  'kn-btn inline-flex h-[56px] w-full items-center justify-center gap-8 rounded-lg bg-action-primary px-24 text-latin-label font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-60';

export function LangSelect({ t, lang, onChange, dark }: { t: T; lang: Lang; onChange: (l: Lang) => void; dark?: boolean }) {
  return (
    <label className={cx('relative inline-flex h-[40px] items-center gap-8 rounded-full px-12 text-latin-label-sm font-semibold', dark ? 'bg-white/10 text-cream-50' : 'border border-border-default bg-bg-surface text-text-primary')}>
      <Globe width={16} height={16} aria-hidden />
      <span className="sr-only">{t('admin.language')}</span>
      <select value={lang} onChange={(e) => onChange(e.target.value as Lang)} className="cursor-pointer appearance-none bg-transparent pr-4 focus:outline-none">
        {LANGS.map((l) => (
          <option key={l} value={l} className="text-text-primary">
            {t(`lang.${l}`)}
          </option>
        ))}
      </select>
    </label>
  );
}

/** Six boxes for the authenticator code: typing moves on, Backspace moves back, pasting fills all. */
export function OtpInput({ value, onChange, t, invalid, idPrefix = 'otp' }: { value: string; onChange: (v: string) => void; t: T; invalid?: boolean; idPrefix?: string }) {
  const refs = useRef<(HTMLInputElement | null)[]>([]);
  const digits = Array.from({ length: 6 }, (_, i) => value[i] ?? '');
  const set = (i: number, d: string) => {
    const next = digits.slice();
    next[i] = d;
    onChange(next.join('').slice(0, 6));
  };
  const onKey = (i: number, e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Backspace' && !digits[i] && i > 0) {
      set(i - 1, '');
      refs.current[i - 1]?.focus();
      e.preventDefault();
    } else if (e.key === 'ArrowLeft' && i > 0) refs.current[i - 1]?.focus();
    else if (e.key === 'ArrowRight' && i < 5) refs.current[i + 1]?.focus();
  };
  const onPaste = (e: ClipboardEvent<HTMLInputElement>) => {
    const got = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6);
    if (!got) return;
    e.preventDefault();
    onChange(got);
    refs.current[Math.min(got.length, 5)]?.focus();
  };
  return (
    <div className="flex gap-8 sm:gap-12">
      {digits.map((d, i) => (
        <input
          key={i}
          id={i === 0 ? idPrefix : undefined}
          ref={(el) => {
            refs.current[i] = el;
          }}
          value={d}
          inputMode="numeric"
          autoComplete={i === 0 ? 'one-time-code' : 'off'}
          maxLength={1}
          aria-label={t('admin.login.digit', { n: i + 1 })}
          aria-invalid={invalid || undefined}
          onPaste={onPaste}
          onKeyDown={(e) => onKey(i, e)}
          onChange={(e) => {
            const v = e.target.value.replace(/\D/g, '');
            if (v.length > 1) return onChange((digits.slice(0, i).join('') + v).slice(0, 6));
            set(i, v);
            if (v && i < 5) refs.current[i + 1]?.focus();
          }}
          className={cx(
            'h-[56px] w-full min-w-0 rounded-lg border bg-bg-surface text-center text-[22px] font-semibold text-text-primary transition-colors focus:outline-none focus:ring-2 focus:ring-focus-ring sm:h-[56px]',
            invalid ? 'border-[1.5px] border-status-danger' : d ? 'border-mocha-500' : 'border-border-strong hover:border-mocha-500',
          )}
        />
      ))}
    </div>
  );
}

/** A01 / A02 / setup frame: brand panel on the left (wide screens), the card on the right. */
export function SplitLayout({ t, lang, onLang, children }: { t: T; lang: Lang; onLang: (l: Lang) => void; children: ReactNode }) {
  return (
    <div className="flex min-h-screen bg-bg-canvas">
      <aside className="relative hidden w-[44%] max-w-[640px] shrink-0 flex-col overflow-hidden bg-mocha-900 px-64 py-64 lg:flex">
        <span aria-hidden className="pointer-events-none absolute -top-[180px] left-[360px] h-[520px] w-[520px] rounded-full border-[64px] border-mocha-800 kn-float" />
        <div className="kn-in relative">
          <div className="flex items-center gap-12">
            <img src="/brand-mark-dark.svg" alt="" width={56} height={56} className="h-[56px] w-[56px] rounded-lg" />
            <span className="text-[30px] font-bold leading-none text-cream-50">KaamNishaan</span>
          </div>
          <span className="mt-4 inline-block rounded-sm bg-white/10 px-[6px] text-[13px] font-semibold uppercase leading-[18px] tracking-wide text-mocha-300">
            {t('admin.console')}
          </span>
        </div>
        <h1 className="kn-in relative mt-64 max-w-[420px] text-[44px] font-bold leading-[54px] text-cream-50" style={{ ['--d' as string]: '120ms' }}>
          {t('admin.login.hero')}
        </h1>
        <div className="kn-in relative -mr-64 mt-auto pt-48" style={{ ['--d' as string]: '240ms' }}>
          <img src="/img/login-preview.webp" alt="" width={608} height={576} className="w-full max-w-[608px] select-none" />
        </div>
        <p className="relative mt-24 flex items-center gap-8 text-latin-label-sm text-cream-400">
          <Lock width={16} height={16} aria-hidden />
          {t('admin.login.staff_only')}
        </p>
      </aside>
      <main className="relative flex flex-1 flex-col items-center justify-center px-16 py-48 sm:px-32">
        <div className="absolute right-16 top-16 sm:right-32 sm:top-24">
          <LangSelect t={t} lang={lang} onChange={onLang} />
        </div>
        <div className="mb-24 flex items-center gap-12 lg:hidden">
          <img src="/brand-mark-dark.svg" alt="" width={40} height={40} className="h-[40px] w-[40px] rounded-md" />
          <span className="text-latin-h3 font-bold">KaamNishaan</span>
          <span className="rounded-sm bg-bg-subtle px-[6px] text-[12px] font-semibold uppercase text-mocha-700">{t('admin.console')}</span>
        </div>
        {children}
      </main>
    </div>
  );
}

export function Card({ children, className, wide }: { children: ReactNode; className?: string; wide?: boolean }) {
  return (
    <div className={cx('kn-in w-full rounded-xl border border-border-default bg-bg-surface p-24 shadow-md sm:p-32', wide ? 'max-w-[560px]' : 'max-w-[480px]', className)}>
      {children}
    </div>
  );
}

/** "Plan: All ▾" style filter (a real <select>, so it works with keyboard and screen readers). */
export function FilterSelect({ label, value, options, allLabel, onChange }: { label: string; value: string; options: { value: string; label: string }[]; allLabel: string; onChange: (v: string) => void }) {
  return (
    <label className={cx('relative inline-flex h-[44px] items-center rounded-lg border bg-bg-surface pl-12 pr-[34px] text-latin-label-sm font-semibold transition-colors hover:border-mocha-500', value ? 'border-mocha-500' : 'border-border-default')}>
      <span aria-hidden>{label}:&nbsp;</span>
      <select value={value} onChange={(e) => onChange(e.target.value)} aria-label={label} className="max-w-[160px] cursor-pointer appearance-none truncate bg-transparent focus:outline-none">
        <option value="">{allLabel}</option>
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
      <ChevronDown width={16} height={16} className="pointer-events-none absolute right-12" aria-hidden />
    </label>
  );
}
