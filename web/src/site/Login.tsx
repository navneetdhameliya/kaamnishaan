import { Check, ChevronLeft, ChevronRight, Phone } from 'lucide-react';
import { useState, type FormEvent } from 'react';

import { api, ApiError } from '../lib/api';
import { clock, type Lang, type T } from '../lib/i18n';
import type { ConfigOut, SessionOut } from '../lib/types';
import { Logo } from './Layout';
import { EMAIL_RE, ErrorSummary, Field, PasswordInput, StoreBadges, TextInput } from './form';
import { rv, Spinner } from './motion';
import { ROUTES } from './site';

function Card({ children }: { children: React.ReactNode }) {
  return (
    <div {...rv('up')} className="w-full max-w-[520px]">
      <div className="kn-drawer rounded-xl border border-border-default bg-bg-surface p-24 shadow-sm transition-shadow duration-500 hover:shadow-lg md:p-32">
        {children}
      </div>
    </div>
  );
}

/** "Forgot password?": POST /auth/password/forgot (always 202, so it never tells who has an account). */
function Forgot({ t, config, back, start }: { t: T; config: ConfigOut | null; back: () => void; start: string }) {
  const [email, setEmail] = useState(start);
  const [error, setError] = useState<string | null>(null);
  const [sent, setSent] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const emailOn = !!config?.features.email;
  async function submit(ev: FormEvent) {
    ev.preventDefault();
    if (!EMAIL_RE.test(email.trim())) return setError(t('site.login.err_email'));
    setError(null);
    setBusy(true);
    try {
      await api('/auth/password/forgot', { method: 'POST', body: { email: email.trim() } });
      setSent(email.trim());
    } catch (err) {
      setError(err instanceof ApiError && err.status === 429 ? t('site.err.wait') : t('site.err.generic'));
    } finally {
      setBusy(false);
    }
  }
  return (
    <Card>
      <button type="button" onClick={back} className="mb-16 inline-flex items-center gap-4 text-latin-label-sm font-semibold text-text-secondary hover:text-text-primary">
        <ChevronLeft width={16} height={16} aria-hidden />
        {t('site.forgot.back')}
      </button>
      <h1 className="text-latin-display">{t('site.forgot.title')}</h1>
      {!emailOn ? (
        <p className="mt-12 text-latin-body text-text-secondary">
          {t('site.forgot.no_email')}{' '}
          <a href={ROUTES.contact} className="font-semibold text-text-primary underline">
            {t('site.foot.contact')}
          </a>
        </p>
      ) : sent ? (
        <p role="status" className="mt-12 rounded-md bg-status-success-bg p-12 text-latin-body text-status-success">
          {t('site.forgot.sent', { email: sent })}
        </p>
      ) : (
        <form noValidate onSubmit={(e) => void submit(e)} className="mt-12 flex flex-col gap-20">
          <p className="text-latin-body text-text-secondary">{t('site.forgot.body')}</p>
          <Field label={t('site.trial.email')} error={error}>
            {(id, bad) => <TextInput id={id} invalid={bad} type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="name@company.com" autoComplete="email" />}
          </Field>
          <button type="submit" disabled={busy} className="h-[52px] rounded-lg kn-btn inline-flex items-center justify-center gap-8 kn-btn inline-flex items-center justify-center gap-8 bg-action-primary text-latin-label font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-60">
            {busy && <Spinner />}
                {t('site.forgot.submit')}
          </button>
        </form>
      )}
    </Card>
  );
}

/**
 * W28 Log in with work email (POST /auth/login). The workspace itself is in the mobile app for now, so a
 * right login says where to go next and the web session is closed straight away (POST /auth/logout).
 */
export default function Login({ t, lang, config }: { t: T; lang: Lang; config: ConfigOut | null }) {
  const [view, setView] = useState<'login' | 'forgot'>(() => (new URLSearchParams(window.location.search).has('forgot') ? 'forgot' : 'login'));
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [errors, setErrors] = useState<{ email?: string; password?: string }>({});
  const [problem, setProblem] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [phoneNote, setPhoneNote] = useState(false);
  const [done, setDone] = useState<{ name: string; company: string | null } | null>(null);

  async function submit(ev: FormEvent) {
    ev.preventDefault();
    const e: typeof errors = {};
    if (!EMAIL_RE.test(email.trim())) e.email = t('site.login.err_email');
    if (!password) e.password = t('site.login.err_password');
    setErrors(e);
    setProblem(null);
    if (Object.keys(e).length) return;
    setBusy(true);
    try {
      const s = await api<SessionOut>('/auth/login', { method: 'POST', body: { email: email.trim(), password } });
      setDone({ name: s.user.name.split(/\s+/)[0] ?? s.user.name, company: s.companies.find((c) => c.active)?.name ?? s.companies[0]?.name ?? null });
      setPassword('');
      void api('/auth/logout', { method: 'POST', token: s.access_token }).catch(() => undefined);
    } catch (err) {
      if (err instanceof ApiError && err.code === 'login_invalid') {
        const left = Number(err.details.attempts_left);
        setProblem(Number.isFinite(left) && left > 0 && left <= 3 ? t('site.login.wrong_left', { n: left }) : t('site.login.wrong'));
      } else if (err instanceof ApiError && err.code === 'account_locked') {
        const until = typeof err.details.locked_until === 'string' ? clock(err.details.locked_until, lang) : '';
        setProblem(t('site.login.locked', { time: until }));
      } else if (err instanceof ApiError && err.code === 'account_disabled') {
        setProblem(t('site.login.disabled'));
      } else if (err instanceof ApiError && err.status === 0) {
        setProblem(t('site.err.offline'));
      } else {
        setProblem(t('site.err.generic'));
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="grid bg-bg-canvas lg:min-h-[908px] lg:grid-cols-[640px_1fr]">
      <div className="relative hidden overflow-hidden bg-espresso-950 px-[80px] pt-[80px] lg:block">
        <div
          aria-hidden
          className="pointer-events-none absolute left-[380px] top-[-140px] h-[480px] w-[480px] animate-[spin_70s_linear_infinite] rounded-full border-[56px] border-mocha-950 border-l-transparent"
        />
        <div className="relative">
          <div {...rv('down')}>
            <Logo />
          </div>
          <h2 {...rv('up', 1)} className="mt-32 text-web-display text-cream-50">
            {t('site.login.welcome')}
          </h2>
          <p {...rv('up', 2)} className="mt-8 text-web-body-lg text-cream-400">
            {t('site.login.tagline')}
          </p>
          <div {...rv('up', 3)} className="relative mt-48 h-[560px] w-[480px]">
            <img
              src="/img/login-phone.webp"
              alt=""
              width={243}
              height={516}
              className="kn-float absolute left-[150px] top-[20px] w-[243px] drop-shadow-[0_12px_32px_rgba(59,41,33,0.3)]"
            />
            <div
              style={{ '--f': '-3s' } as React.CSSProperties}
              className="kn-float absolute left-0 top-[400px] flex items-center gap-12 rounded-full bg-cream-50 py-[10px] pl-12 pr-20 shadow-md"
            >
              <span className="inline-flex h-[36px] w-[36px] items-center justify-center rounded-full bg-status-success-bg text-status-success">
                <Check width={18} height={18} aria-hidden />
              </span>
              <span className="flex flex-col whitespace-nowrap">
                <span className="text-latin-label-sm font-semibold">{t('site.hero.chip_approved')}</span>
                <span className="text-latin-caption text-text-secondary">{t('site.hero.chip_approved_sub')}</span>
              </span>
            </div>
          </div>
        </div>
      </div>
      <div className="flex items-start justify-center px-16 py-40 md:px-32 md:py-[80px]">
        {view === 'forgot' ? (
          <Forgot t={t} config={config} back={() => setView('login')} start={email} />
        ) : done ? (
          <Card>
            <span className="kn-pop inline-flex h-[48px] w-[48px] items-center justify-center rounded-full bg-status-success-bg text-status-success">
              <Check width={24} height={24} aria-hidden />
            </span>
            <h1 className="mt-16 text-latin-display">{t('site.login.ok_title', { name: done.name })}</h1>
            <p className="mt-12 text-latin-body text-text-secondary">{t('site.login.ok_body', { company: done.company ? ` (${done.company})` : '' })}</p>
            <div className="mt-24">
              <StoreBadges config={config} t={t} label />
            </div>
            <button
              type="button"
              onClick={() => setDone(null)}
              className="mt-24 inline-flex items-center gap-4 text-latin-label-sm font-semibold text-text-primary hover:underline"
            >
              {t('site.login.ok_again')}
              <ChevronRight width={16} height={16} aria-hidden />
            </button>
          </Card>
        ) : (
          <Card>
            <h1 className="text-[32px] font-bold leading-[40px] md:text-latin-display">{t('site.login.title')}</h1>
            <p className="mt-8 text-latin-body text-text-secondary">{t('site.login.body')}</p>
            <form noValidate onSubmit={(e) => void submit(e)} className="mt-24 flex flex-col gap-20">
              {problem && <ErrorSummary>{problem}</ErrorSummary>}
              <Field label={t('site.trial.email')} error={errors.email}>
                {(id, bad) => <TextInput id={id} invalid={bad} type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="name@company.com" autoComplete="email" />}
              </Field>
              <Field
                label={t('site.trial.password')}
                error={errors.password}
                aside={
                  <button type="button" onClick={() => setView('forgot')} className="text-latin-label-sm font-semibold text-mocha-700 hover:underline">
                    {t('site.login.forgot')}
                  </button>
                }
              >
                {(id, bad) => <PasswordInput id={id} invalid={bad} t={t} icon value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" />}
              </Field>
              <button type="submit" disabled={busy} className="h-[52px] rounded-lg kn-btn inline-flex items-center justify-center gap-8 kn-btn inline-flex items-center justify-center gap-8 bg-action-primary text-latin-label font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-60">
                {busy && <Spinner />}
                {t('site.login.submit')}
              </button>
            </form>
            <div className="my-20 flex items-center gap-12 text-latin-caption text-text-secondary" aria-hidden>
              <span className="h-px flex-1 bg-border-default" />
              {t('site.login.or')}
              <span className="h-px flex-1 bg-border-default" />
            </div>
            <button
              type="button"
              aria-expanded={phoneNote}
              onClick={() => setPhoneNote((v) => !v)}
              className="kn-btn inline-flex h-[52px] w-full items-center justify-center gap-8 rounded-lg bg-action-secondary text-latin-label font-semibold text-text-primary hover:brightness-95"
            >
              <Phone width={18} height={18} aria-hidden />
              {t('site.login.phone')}
            </button>
            {phoneNote && (
              <div className="kn-drawer mt-12 flex flex-col gap-12 rounded-md bg-bg-canvas p-12">
                <p className="text-latin-body text-text-secondary">{t('site.login.phone_note')}</p>
                <StoreBadges config={config} t={t} />
              </div>
            )}
            <p className="mt-20 text-latin-body text-text-secondary">
              {t('site.login.new')}{' '}
              <a href={ROUTES.trial} className="inline-flex items-center gap-2 font-semibold text-text-primary hover:underline">
                {t('site.nav.trial')}
                <ChevronRight width={16} height={16} aria-hidden />
              </a>
            </p>
            {!phoneNote && (
              <div className="mt-20 border-t border-border-default pt-20">
                <StoreBadges config={config} t={t} label />
              </div>
            )}
          </Card>
        )}
      </div>
    </section>
  );
}
