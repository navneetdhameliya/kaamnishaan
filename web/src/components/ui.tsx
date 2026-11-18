import { Check, Globe, Star } from 'lucide-react';
import type { ButtonHTMLAttributes, ReactNode } from 'react';

import { LANGS, type Lang, type T } from '../lib/i18n';

export function cx(...parts: (string | false | null | undefined)[]): string {
  return parts.filter(Boolean).join(' ');
}

export function Card({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <section
      data-reveal="up"
      className={cx('rounded-xl border border-border-default bg-bg-surface p-20 transition-shadow duration-300 hover:shadow-md md:p-24', className)}
    >
      {children}
    </section>
  );
}

type Tone = 'success' | 'warning' | 'danger' | 'subtle';

export function Badge({ children, tone = 'subtle', icon }: { children: ReactNode; tone?: Tone; icon?: ReactNode }) {
  const tones: Record<Tone, string> = {
    success: 'bg-status-success-bg text-status-success',
    warning: 'bg-status-warning-bg text-status-warning',
    danger: 'bg-status-danger-bg text-status-danger',
    subtle: 'bg-action-secondary text-text-primary',
  };
  return (
    <span className={cx('inline-flex items-center gap-4 rounded-full px-12 py-4 text-latin-label-sm font-semibold', tones[tone])}>
      {icon}
      {children}
    </span>
  );
}

type Variant = 'primary' | 'secondary' | 'light' | 'outline-light' | 'ghost';

export function Button({
  variant = 'primary',
  icon,
  children,
  className,
  full,
  ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant; icon?: ReactNode; full?: boolean }) {
  const v: Record<Variant, string> = {
    primary: 'bg-action-primary text-text-on-action hover:bg-action-primary-pressed',
    secondary: 'bg-action-secondary text-text-primary hover:brightness-95',
    light: 'bg-bg-surface text-text-primary hover:bg-bg-canvas',
    'outline-light': 'border border-espresso-700 text-cream-50 hover:bg-espresso-850',
    ghost: 'text-text-primary underline-offset-4 hover:underline',
  };
  return (
    <button
      {...rest}
      className={cx(
        'kn-btn inline-flex min-h-[48px] items-center justify-center gap-8 rounded-lg px-20 text-web-label font-semibold disabled:cursor-not-allowed disabled:opacity-50',
        full && 'w-full',
        v[variant],
        className,
      )}
    >
      {icon}
      {children}
    </button>
  );
}

/** Five stars; with [onPick] they are buttons. */
export function Stars({
  value,
  size = 20,
  onPick,
  label,
}: {
  value: number;
  size?: number;
  onPick?: (n: number) => void;
  label?: string;
}) {
  return (
    <div className="flex items-center gap-4" role={onPick ? 'radiogroup' : 'img'} aria-label={label ?? `${value} / 5`}>
      {[1, 2, 3, 4, 5].map((n) => {
        const on = n <= value;
        const star = (
          <Star
            width={size}
            height={size}
            strokeWidth={1.5}
            className={on ? 'fill-status-warning text-status-warning' : 'fill-taupe-400 text-taupe-400'}
          />
        );
        return onPick ? (
          <button
            key={n}
            type="button"
            role="radio"
            aria-checked={value === n}
            aria-label={`${n}`}
            onClick={() => onPick(n)}
            className="rounded-sm p-2 transition-transform duration-200 ease-[cubic-bezier(.34,1.56,.64,1)] hover:scale-125 focus:outline-none focus-visible:ring-2 focus-visible:ring-focus-ring active:scale-90"
          >
            {star}
          </button>
        ) : (
          <span key={n}>{star}</span>
        );
      })}
    </div>
  );
}

export function Initials({ name, dark = true, size = 40 }: { name: string; dark?: boolean; size?: number }) {
  const letters = name
    .split(/\s+/)
    .filter((w) => w && !/^(dr|mr|mrs|ms)\.?$/i.test(w))
    .slice(0, 2)
    .map((w) => w[0]!.toUpperCase())
    .join('');
  return (
    <span
      style={{ width: size, height: size }}
      className={cx(
        'inline-flex shrink-0 items-center justify-center rounded-md text-latin-label font-bold',
        dark ? 'bg-mocha-900 text-cream-50' : 'bg-action-secondary text-text-primary',
      )}
    >
      {letters || '·'}
    </span>
  );
}

/** A tag the customer can pick ("On time"). */
export function TagChip({ label, on, onClick, danger }: { label: string; on: boolean; onClick: () => void; danger?: boolean }) {
  return (
    <button
      type="button"
      aria-pressed={on}
      onClick={onClick}
      className={cx(
        'inline-flex min-h-[40px] items-center gap-4 rounded-full border px-12 text-latin-label-sm font-semibold transition-all duration-200 hover:-translate-y-[2px] active:scale-95',
        on
          ? danger
            ? 'border-status-danger bg-status-danger-bg text-status-danger'
            : 'border-action-primary bg-action-primary text-text-on-action'
          : 'border-border-strong bg-bg-surface text-text-primary hover:bg-bg-canvas',
      )}
    >
      {on && <Check width={14} height={14} strokeWidth={2.5} />}
      {label}
    </button>
  );
}

export function LanguageSelect({ lang, langs, onChange, t, short }: { lang: Lang; langs?: string[]; onChange: (l: Lang) => void; t: T; short?: boolean }) {
  const options = LANGS.filter((l) => !langs || langs.length === 0 || langs.includes(l) || l === lang);
  return (
    <label className="relative inline-flex min-h-[40px] items-center gap-4 rounded-lg border border-border-default bg-bg-surface pl-12 pr-8 text-latin-label-sm font-semibold">
      <Globe width={16} height={16} aria-hidden />
      <span className={short ? 'md:hidden' : 'hidden'}>{lang.toUpperCase()}</span>
      <span className={short ? 'hidden md:inline' : ''}>{t(`web.lang.${lang}`)}</span>
      <select
        aria-label="Language"
        value={lang}
        onChange={(e) => onChange(e.target.value as Lang)}
        className="absolute inset-0 cursor-pointer opacity-0"
      >
        {options.map((l) => (
          <option key={l} value={l}>
            {t(`web.lang.${l}`)}
          </option>
        ))}
      </select>
    </label>
  );
}
