import { Check, ChevronDown, CircleAlert, Eye, EyeOff, Smartphone, X } from 'lucide-react';
import { useId, useState, type InputHTMLAttributes, type ReactNode } from 'react';

import { cx } from '../components/ui';
import type { T } from '../lib/i18n';
import type { ConfigOut, PlansOut } from '../lib/types';
import { rv } from './motion';

export const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

/** Label, box and the red line under it (W04, W28). */
export function Field({
  label,
  error,
  extra,
  aside,
  children,
}: {
  label: string;
  error?: string | null;
  extra?: ReactNode;
  aside?: ReactNode;
  children: (id: string, invalid: boolean) => ReactNode;
}) {
  const id = useId();
  return (
    <div className="flex flex-col gap-8">
      <div className="flex items-baseline justify-between gap-8">
        <label htmlFor={id} className="text-latin-label-sm font-semibold text-text-primary">
          {label}
        </label>
        {aside}
      </div>
      {children(id, !!error)}
      {error && (
        <p id={`${id}-error`} className="kn-drawer inline-flex items-start gap-4 text-latin-caption text-status-danger">
          <CircleAlert width={14} height={14} className="mt-[2px] shrink-0" aria-hidden />
          {error}
        </p>
      )}
      {extra}
    </div>
  );
}

export function inputClass(invalid: boolean) {
  return cx(
    'h-[52px] w-full rounded-lg border bg-bg-surface px-12 text-latin-body text-text-primary placeholder:text-taupe-500 focus:outline-none focus:ring-2 focus:ring-focus-ring',
    'transition-[border-color,box-shadow,background-color] duration-200',
    invalid ? 'border-[1.5px] border-status-danger' : 'border-border-strong hover:border-mocha-500',
  );
}

export function TextInput({ id, invalid, ...rest }: InputHTMLAttributes<HTMLInputElement> & { id: string; invalid: boolean }) {
  return (
    <input
      id={id}
      aria-invalid={invalid || undefined}
      aria-describedby={invalid ? `${id}-error` : undefined}
      className={inputClass(invalid)}
      {...rest}
    />
  );
}

export function PasswordInput({
  id,
  invalid,
  t,
  icon,
  ...rest
}: InputHTMLAttributes<HTMLInputElement> & { id: string; invalid: boolean; t: T; icon?: boolean }) {
  const [show, setShow] = useState(false);
  return (
    <div className="relative">
      <input
        id={id}
        type={show ? 'text' : 'password'}
        aria-invalid={invalid || undefined}
        aria-describedby={invalid ? `${id}-error` : undefined}
        className={cx(inputClass(invalid), 'pr-[64px]')}
        {...rest}
      />
      <button
        type="button"
        onClick={() => setShow((s) => !s)}
        aria-label={show ? t('site.trial.hide') : t('site.trial.show')}
        className="absolute right-8 top-1/2 inline-flex h-[40px] min-w-[40px] -translate-y-1/2 items-center justify-center rounded-md px-8 text-latin-label-sm font-semibold text-text-secondary hover:text-text-primary"
      >
        {icon ? show ? <EyeOff width={20} height={20} /> : <Eye width={20} height={20} /> : show ? t('site.trial.hide') : t('site.trial.show')}
      </button>
    </div>
  );
}

export function SelectInput({
  id,
  invalid,
  value,
  onChange,
  placeholder,
  options,
  lead,
}: {
  id: string;
  invalid: boolean;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  options: { value: string; label: string }[];
  lead?: ReactNode;
}) {
  return (
    <div className="relative">
      {lead && <span className="pointer-events-none absolute left-12 top-1/2 -translate-y-1/2">{lead}</span>}
      <select
        id={id}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        aria-invalid={invalid || undefined}
        aria-describedby={invalid ? `${id}-error` : undefined}
        className={cx(inputClass(invalid), 'appearance-none pr-40', lead ? 'pl-40' : null, !value && 'text-taupe-500')}
      >
        {placeholder && (
          <option value="" disabled>
            {placeholder}
          </option>
        )}
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
      <ChevronDown width={20} height={20} className="pointer-events-none absolute right-12 top-1/2 -translate-y-1/2 text-text-primary" aria-hidden />
    </div>
  );
}

export function ErrorSummary({ children }: { children: ReactNode }) {
  return (
    <div role="alert" className="kn-shake flex items-start gap-8 rounded-md bg-status-danger-bg px-12 py-12 text-latin-label-sm font-semibold text-status-danger">
      <CircleAlert width={16} height={16} className="mt-[2px] shrink-0" aria-hidden />
      <span>{children}</span>
    </div>
  );
}

export function Rule({ ok, children }: { ok: boolean; children: ReactNode }) {
  return (
    <li className={cx('flex items-center gap-[6px] text-latin-caption transition-colors duration-300', ok ? 'text-text-secondary' : 'text-status-danger')}>
      {ok ? <Check width={14} height={14} className="text-status-success" aria-hidden /> : <X width={14} height={14} aria-hidden />}
      {children}
    </li>
  );
}

function Badge({ href, small, big }: { href: string; small: string; big: string }) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noreferrer"
      className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-md bg-black px-12 text-white hover:bg-espresso-900"
    >
      <Smartphone width={20} height={20} aria-hidden />
      <span className="flex flex-col leading-none">
        <span className="text-[9px] font-semibold uppercase">{small}</span>
        <span className="text-[15px] font-semibold">{big}</span>
      </span>
    </a>
  );
}

/** Google Play / App Store buttons, only for the stores the app is published in (GET /config app_links). */
export function StoreBadges({ config, t, label }: { config: ConfigOut | null; t: T; label?: boolean }) {
  const links = config?.app_links;
  if (!links) return null;
  if (!links.android && !links.ios) return <p className="text-latin-caption text-text-secondary">{t('site.app.soon')}</p>;
  return (
    <div className="flex flex-wrap items-center gap-12">
      {label && <span className="text-latin-label-sm font-semibold text-text-secondary">{t('site.app.title')}</span>}
      {links.android && <Badge href={links.android} small={t('site.app.play_small')} big="Google Play" />}
      {links.ios && <Badge href={links.ios} small={t('site.app.store_small')} big="App Store" />}
    </div>
  );
}

/** The dark panel next to W04: what the trial includes (from GET /plans) and the report languages (GET /config). */
export function TrialAside({ t, plans, config }: { t: T; plans: PlansOut | null; config: ConfigOut | null }) {
  const pro = plans?.plans.find((p) => p.most_popular);
  const points = [
    pro && pro.technician_limit != null && pro.report_limit_monthly != null
      ? t('site.aside.limits', { techs: pro.technician_limit, reports: pro.report_limit_monthly })
      : null,
    t('site.aside.approvals'),
    t('site.aside.offline'),
    t('site.aside.no_card'),
  ].filter((x): x is string => !!x);
  return (
    <aside {...rv('right', 1)} className="relative overflow-hidden rounded-xl bg-espresso-950 px-24 pt-40 md:px-48 md:pt-48">
      <div
        aria-hidden
        className="pointer-events-none absolute -bottom-[120px] -right-[160px] h-[420px] w-[420px] rounded-full border-[48px] border-mocha-950"
      />
      <div className="relative">
        {pro && plans && (
          <h2 className="text-web-m-h2 text-cream-50 md:text-web-h2">{t('site.aside.title', { plan: pro.name, n: plans.trial_days })}</h2>
        )}
        <ul className="mt-24 flex flex-col gap-12">
          {points.map((p) => (
            <li key={p} className="flex items-center gap-12 text-latin-body text-cream-200">
              <span className="inline-flex h-[24px] w-[24px] shrink-0 items-center justify-center rounded-full bg-cream-100/[0.12]">
                <Check width={14} height={14} aria-hidden />
              </span>
              {p}
            </li>
          ))}
        </ul>
        {config && (
          <>
            <p className="mt-24 text-web-eyebrow uppercase text-cream-400">{t('site.aside.langs')}</p>
            <div className="mt-12 flex flex-wrap gap-8">
              {config.languages.map((l) => (
                <span key={l.code} className="rounded-full border border-cream-100/[0.14] px-12 py-[6px] text-latin-label-sm font-semibold text-cream-100">
                  {l.native_name}
                </span>
              ))}
            </div>
          </>
        )}
        <img
          src="/img/hero-phone-report.webp"
          alt=""
          width={243}
          height={516}
          className="kn-float mx-auto mb-40 mt-32 w-[200px] drop-shadow-[0_16px_32px_rgba(0,0,0,0.35)] md:w-[243px]"
        />
      </div>
    </aside>
  );
}
