import { Check, ChevronRight, RotateCcw, Sparkles } from 'lucide-react';
import { useEffect, useState, type FormEvent } from 'react';

import { cx } from '../components/ui';
import { api, ApiError } from '../lib/api';
import { day, type Lang, type T } from '../lib/i18n';
import type { CompanyOut, ConfigOut, PlansOut, SessionOut } from '../lib/types';
import { Container } from './parts';
import { EMAIL_RE, ErrorSummary, Field, PasswordInput, Rule, SelectInput, StoreBadges, TextInput, TrialAside } from './form';
import { ROUTES } from './site';

type Errors = Partial<Record<'name' | 'email' | 'password' | 'company' | 'trade', string>>;

/** The password rules the API checks, plus "not your name or email" (checked here only). */
export function passwordRules(pw: string, min: number, name: string, email: string) {
  const lower = pw.toLowerCase();
  const parts = [...name.toLowerCase().split(/\s+/), email.toLowerCase().split('@')[0] ?? ''].filter((w) => w.length >= 3);
  return {
    length: pw.length >= min,
    mix: /[A-Za-z]/.test(pw) && /\d/.test(pw),
    personal: !parts.some((w) => lower.includes(w)),
  };
}

function Strength({ score, t }: { score: number; t: T }) {
  const strong = score >= 4;
  return (
    <div className="flex items-center gap-8">
      <div className="flex flex-1 gap-4" aria-hidden>
        {[0, 1, 2, 3].map((i) => (
          <span
            key={i}
            className={cx('h-[6px] flex-1 rounded-full', i < score ? (strong ? 'bg-status-success' : 'bg-status-danger') : 'bg-bg-subtle')}
          />
        ))}
      </div>
      <span className={cx('text-latin-caption-strong', strong ? 'text-status-success' : 'text-status-danger')}>
        {strong ? t('site.trial.strong') : t('site.trial.weak')}
      </span>
    </div>
  );
}

/** "Workspace ready": confirm the email (when email is switched on), get the app, invite, first job. */
function Ready({
  t,
  lang,
  email,
  company,
  plans,
  config,
  token,
}: {
  t: T;
  lang: Lang;
  email: string;
  company: CompanyOut;
  plans: PlansOut | null;
  config: ConfigOut | null;
  token: string;
}) {
  const emailOn = !!config?.features.email;
  const [wait, setWait] = useState(60);
  const [resent, setResent] = useState(false);
  useEffect(() => {
    if (!emailOn || wait <= 0) return;
    const id = window.setTimeout(() => setWait((w) => w - 1), 1000);
    return () => window.clearTimeout(id);
  }, [emailOn, wait]);
  async function resend() {
    try {
      await api('/auth/email/send-verification', { method: 'POST', token });
      setResent(true);
      setWait(60);
    } catch {
      setWait(60);
    }
  }
  const planName = plans?.plans.find((p) => p.code === company.plan)?.name ?? company.plan;
  const initials = company.name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]!.toUpperCase())
    .join('');
  const steps = [
    ...(emailOn ? [[t('site.ready.s_confirm'), t('site.ready.s_confirm_b')]] : []),
    [t('site.ready.s_app'), t('site.ready.s_app_b')],
    [t('site.ready.s_invite'), t('site.ready.s_invite_b')],
    [t('site.ready.s_job'), t('site.ready.s_job_b')],
  ];
  return (
    <div className="flex flex-col gap-24">
      <div className="flex flex-col items-start gap-12">
        <span className="inline-flex items-center gap-8 rounded-full bg-cream-200 px-12 py-[6px] text-web-eyebrow uppercase text-mocha-700">
          <Check width={14} height={14} aria-hidden />
          {t('site.ready.eyebrow')}
        </span>
        <h1 className="text-web-m-display md:text-web-display">{emailOn ? t('site.ready.title_email') : t('site.ready.title')}</h1>
        <p className="text-latin-body-lg text-text-secondary">
          {emailOn ? t('site.ready.body_email', { email }) : t('site.ready.body', { email })}
        </p>
      </div>
      <div className="flex flex-col gap-24 rounded-xl border border-border-default bg-bg-surface p-24 md:p-32">
        <div className="flex items-center gap-16 rounded-lg border border-border-default bg-bg-canvas p-16">
          <span className="inline-flex h-[48px] w-[48px] shrink-0 items-center justify-center rounded-md bg-sage-700 text-latin-label font-bold text-cream-50">
            {initials}
          </span>
          <div className="min-w-0 flex-1">
            <p className="truncate text-latin-h3">{company.name}</p>
            {company.trial_ends_at && (
              <p className="text-latin-caption text-text-secondary">
                {t('site.ready.trial_ends', { plan: planName, date: day(company.trial_ends_at, lang) })}
              </p>
            )}
          </div>
          <span className="inline-flex items-center gap-4 rounded-full bg-status-success-bg px-8 py-2 text-latin-caption-strong text-status-success">
            <Check width={12} height={12} aria-hidden />
            {t('site.ready.badge')}
          </span>
        </div>
        <div>
          <p className="mb-12 text-latin-label-sm font-semibold">{t('site.ready.next')}</p>
          <ol className="flex flex-col gap-16">
            {steps.map(([title, body], i) => (
              <li key={title} className="flex gap-12">
                <span
                  className={cx(
                    'inline-flex h-[24px] w-[24px] shrink-0 items-center justify-center rounded-full text-latin-caption-strong',
                    i === 0 ? 'bg-mocha-900 text-cream-50' : 'bg-cream-200 text-mocha-700',
                  )}
                >
                  {i + 1}
                </span>
                <span className="flex flex-col">
                  <span className="text-latin-label-sm font-semibold">{title}</span>
                  <span className="text-latin-body text-text-secondary">{body}</span>
                </span>
              </li>
            ))}
          </ol>
        </div>
        <div>
          <p className="mb-8 text-web-eyebrow uppercase text-mocha-700">{t('site.app.title')}</p>
          <StoreBadges config={config} t={t} />
        </div>
        {emailOn && (
          <div className="flex flex-col gap-8 border-t border-border-default pt-16">
            <button
              type="button"
              disabled={wait > 0}
              onClick={() => void resend()}
              className="inline-flex items-center gap-8 self-start text-latin-label font-semibold text-text-primary disabled:opacity-50"
            >
              <RotateCcw width={18} height={18} aria-hidden />
              {t('site.ready.resend')}
            </button>
            <p className="text-latin-caption text-text-secondary" aria-live="polite">
              {resent && wait > 0
                ? t('site.ready.resent', { email })
                : wait > 0
                  ? t('site.ready.resend_wait', { n: wait })
                  : t('site.ready.resend_now')}
            </p>
          </div>
        )}
      </div>
    </div>
  );
}

/** W04 Start free trial: the owner's account (POST /auth/register), then the company (POST /companies). */
export default function StartTrial({ t, lang, plans, config }: { t: T; lang: Lang; plans: PlansOut | null; config: ConfigOut | null }) {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [company, setCompany] = useState('');
  const [trade, setTrade] = useState('');
  const [country, setCountry] = useState('');
  const [errors, setErrors] = useState<Errors>({});
  const [taken, setTaken] = useState(false);
  const [problem, setProblem] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [token, setToken] = useState<string | null>(null); // kept if the company step fails, so a retry doesn't sign up twice
  const [done, setDone] = useState<CompanyOut | null>(null);
  const min = config?.password_min_length ?? 8;
  const rules = passwordRules(password, min, name, email);
  const score = password ? [rules.length, rules.mix, rules.personal, password.length >= min + 4].filter(Boolean).length : 0;
  const countryCode = country || config?.default_country || 'IN';

  function check(): Errors {
    const e: Errors = {};
    if (!name.trim()) e.name = t('site.err.name');
    if (!EMAIL_RE.test(email.trim())) e.email = t('site.err.email');
    if (!token && !(rules.length && rules.mix && rules.personal)) e.password = t('site.err.password');
    if (!company.trim()) e.company = t('site.err.company');
    if (!trade) e.trade = t('site.err.trade');
    return e;
  }

  async function submit(ev: FormEvent) {
    ev.preventDefault();
    setProblem(null);
    setTaken(false);
    const e = check();
    setErrors(e);
    if (Object.keys(e).length) return;
    setBusy(true);
    try {
      let tok = token;
      if (!tok) {
        const s = await api<SessionOut>('/auth/register', {
          method: 'POST',
          body: { name: name.trim(), email: email.trim(), password, accept_terms: true },
        });
        tok = s.access_token;
        setToken(tok);
      }
      const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
      const c = await api<CompanyOut>('/companies', {
        method: 'POST',
        token: tok,
        body: { name: company.trim(), trade, country: countryCode, ...(tz ? { timezone: tz } : {}) },
      });
      setDone(c);
      window.scrollTo({ top: 0 });
    } catch (err) {
      if (err instanceof ApiError && err.code === 'email_taken') {
        setTaken(true);
        setErrors({ email: t('site.trial.taken') });
      } else if (err instanceof ApiError && err.code === 'password_weak') {
        setErrors({ password: t('site.err.password') });
      } else if (err instanceof ApiError && err.status === 422 && err.fields.email) {
        setErrors({ email: t('site.err.email') });
      } else if (err instanceof ApiError && err.status === 0) {
        setProblem(t('site.err.offline'));
      } else if (err instanceof ApiError && err.status === 429) {
        setProblem(t('site.err.wait'));
      } else {
        setProblem(t('site.err.generic'));
      }
    } finally {
      setBusy(false);
    }
  }

  const count = Object.keys(errors).length;
  return (
    <section className="bg-bg-canvas py-40 md:py-64">
      <Container className="grid grid-cols-1 items-start gap-32 lg:grid-cols-[minmax(0,576px)_minmax(0,560px)] lg:justify-between">
        {done && token ? (
          <Ready t={t} lang={lang} email={email.trim()} company={done} plans={plans} config={config} token={token} />
        ) : (
          <div className="flex flex-col gap-24">
            <div className="flex flex-col items-start gap-12">
              {plans && (
                <span className="inline-flex items-center gap-8 rounded-full bg-cream-200 px-12 py-[6px] text-web-eyebrow uppercase text-mocha-700">
                  <Sparkles width={14} height={14} aria-hidden />
                  {t('site.trial.eyebrow', { n: plans.trial_days })}
                </span>
              )}
              <h1 className="text-web-m-display md:text-web-display">{t('site.trial.title')}</h1>
              <p className="text-latin-body-lg text-text-secondary">{t('site.trial.body')}</p>
            </div>
            <form noValidate onSubmit={(e) => void submit(e)} className="flex flex-col gap-20 rounded-xl border border-border-default bg-bg-surface p-24 md:p-32">
              {count > 0 && (
                <ErrorSummary>{count === 1 ? t('site.trial.fix_one') : t('site.trial.fix_many', { n: count })}</ErrorSummary>
              )}
              {problem && <ErrorSummary>{problem}</ErrorSummary>}
              <Field label={t('site.trial.name')} error={errors.name}>
                {(id, bad) => (
                  <TextInput id={id} invalid={bad} value={name} onChange={(e) => setName(e.target.value)} placeholder={t('site.trial.name_hint')} autoComplete="name" disabled={!!token} />
                )}
              </Field>
              <Field
                label={t('site.trial.email')}
                error={errors.email}
                extra={
                  taken && (
                    <p className="text-latin-caption text-text-secondary">
                      {t('site.trial.is_you')}{' '}
                      <a href={ROUTES.login} className="inline-flex items-center gap-2 text-latin-label-sm font-semibold text-text-primary hover:underline">
                        {t('site.trial.login_instead')}
                        <ChevronRight width={14} height={14} aria-hidden />
                      </a>
                    </p>
                  )
                }
              >
                {(id, bad) => (
                  <TextInput id={id} invalid={bad} type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="name@company.com" autoComplete="email" disabled={!!token} />
                )}
              </Field>
              {!token && (
                <Field
                  label={t('site.trial.password')}
                  error={errors.password}
                  extra={
                    password && (
                      <>
                        <Strength score={score} t={t} />
                        {score < 4 && (
                          <ul className="flex flex-col gap-4">
                            <Rule ok={rules.length}>{t('site.trial.rule_len', { min, n: password.length })}</Rule>
                            <Rule ok={rules.mix}>{t('site.trial.rule_mix')}</Rule>
                            <Rule ok={rules.personal}>{t('site.trial.rule_name')}</Rule>
                          </ul>
                        )}
                      </>
                    )
                  }
                >
                  {(id, bad) => (
                    <PasswordInput id={id} invalid={bad} t={t} value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="new-password" />
                  )}
                </Field>
              )}
              <Field label={t('site.trial.company')} error={errors.company}>
                {(id, bad) => (
                  <TextInput id={id} invalid={bad} value={company} onChange={(e) => setCompany(e.target.value)} placeholder={t('site.trial.company')} autoComplete="organization" />
                )}
              </Field>
              <div className="grid gap-20 sm:grid-cols-2 sm:gap-12">
                <Field label={t('site.trial.trade')} error={errors.trade}>
                  {(id, bad) => (
                    <SelectInput
                      id={id}
                      invalid={bad}
                      value={trade}
                      onChange={setTrade}
                      placeholder={t('site.trial.trade_hint')}
                      options={(config?.trades ?? []).map((tr) => ({ value: tr.key, label: tr.name }))}
                    />
                  )}
                </Field>
                <Field label={t('site.trial.country')}>
                  {(id) => (
                    <SelectInput
                      id={id}
                      invalid={false}
                      value={countryCode}
                      onChange={setCountry}
                      lead={<span aria-hidden>{config?.countries.find((c) => c.code === countryCode)?.flag}</span>}
                      options={(config?.countries ?? []).map((c) => ({ value: c.code, label: c.name }))}
                    />
                  )}
                </Field>
              </div>
              <button
                type="submit"
                disabled={busy || !config}
                className="inline-flex h-[56px] items-center justify-center rounded-lg bg-action-primary text-latin-label font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-60"
              >
                {t('site.trial.submit')}
              </button>
              <p className="text-center text-latin-caption text-text-secondary">
                {t('site.trial.terms', { terms: '\u0000', privacy: '\u0001' })
                  .split(/(\u0000|\u0001)/)
                  .map((part, i) =>
                    part === '\u0000' ? (
                      <a key={i} href={ROUTES.terms} className="underline">
                        {t('site.trial.terms_link')}
                      </a>
                    ) : part === '\u0001' ? (
                      <a key={i} href={ROUTES.privacy} className="underline">
                        {t('site.trial.privacy_link')}
                      </a>
                    ) : (
                      part
                    ),
                  )}
              </p>
              <p className="border-t border-border-default pt-16 text-center text-latin-body text-text-secondary">
                {t('site.trial.have')}{' '}
                <a href={ROUTES.login} className="inline-flex items-center gap-2 font-semibold text-text-primary hover:underline">
                  {t('site.nav.login')}
                  <ChevronRight width={16} height={16} aria-hidden />
                </a>
              </p>
            </form>
          </div>
        )}
        <TrialAside t={t} plans={plans} config={config} />
      </Container>
    </section>
  );
}
