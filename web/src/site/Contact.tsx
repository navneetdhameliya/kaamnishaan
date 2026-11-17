import { Check, ChevronRight, FileText, Lock, Phone, Play, Search } from 'lucide-react';
import { useState, type FormEvent, type ReactNode } from 'react';

import { api, ApiError } from '../lib/api';
import type { Lang, T } from '../lib/i18n';
import type { ConfigOut, ContactOut, SupportOut } from '../lib/types';
import { withLinks } from './BookDemo';
import { LinkButton } from './Layout';
import { Container } from './parts';
import { EMAIL_RE, ErrorSummary, Field, SelectInput, TextInput, inputClass } from './form';
import { ROUTES } from './site';
import { clockLabel, weekdays, zoneLabel } from './when';

const MIN = 20;
const MAX = 1000;

function hours(s: SupportOut, lang: Lang, t: T) {
  return t('site.ct.hours', { days: weekdays(s.days, lang), open: clockLabel(s.open, lang), close: clockLabel(s.close, lang), tz: zoneLabel(s.timezone) });
}

function Way({ icon, title, lines, cta }: { icon: ReactNode; title: string; lines: string[]; cta: { href: string; label: string } }) {
  return (
    <div className="flex flex-col items-start gap-8 rounded-xl border border-border-default bg-bg-surface p-24">
      <span className="mb-8 inline-flex h-[40px] w-[40px] items-center justify-center rounded-full bg-sage-100 text-sage-700">{icon}</span>
      <h2 className="text-latin-h3 md:text-web-h3">{title}</h2>
      <p className="break-all text-latin-body text-text-primary">{lines[0]}</p>
      {lines[1] && <p className="text-latin-caption text-text-secondary">{lines[1]}</p>}
      <a href={cta.href} target={cta.href.startsWith('http') ? '_blank' : undefined} rel="noreferrer" className="mt-8 inline-flex items-center gap-4 text-latin-label-sm font-semibold text-mocha-700 hover:underline">
        {cta.label}
        <ChevronRight width={14} height={14} aria-hidden />
      </a>
    </div>
  );
}

/** W05 Contact: ways to reach us (GET /config support; hidden while not set), a message form (POST /public/contact). */
export default function Contact({ t, lang, config }: { t: T; lang: Lang; config: ConfigOut | null }) {
  const s = config?.support ?? null;
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [topic, setTopic] = useState('');
  const [message, setMessage] = useState('');
  const [errors, setErrors] = useState<Partial<Record<'name' | 'email' | 'topic' | 'message', string>>>({});
  const [problem, setProblem] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState<ContactOut | null>(null);

  async function submit(ev: FormEvent) {
    ev.preventDefault();
    setProblem(null);
    const e: typeof errors = {};
    if (!name.trim()) e.name = t('site.err.name');
    if (!EMAIL_RE.test(email.trim())) e.email = t('site.err.email');
    if (!topic) e.topic = t('site.ct.err_topic');
    if (message.trim().length < MIN) e.message = t('site.ct.err_message', { n: MIN });
    setErrors(e);
    if (Object.keys(e).length) return;
    setBusy(true);
    try {
      setSent(await api<ContactOut>('/public/contact', { method: 'POST', body: { name: name.trim(), email: email.trim(), topic, message: message.trim(), lang } }));
    } catch (err) {
      if (err instanceof ApiError && err.status === 429) setProblem(t('site.err.wait'));
      else if (err instanceof ApiError && err.status === 0) setProblem(t('site.err.offline'));
      else if (err instanceof ApiError && err.status === 422 && err.fields.email) setErrors({ email: t('site.err.email') });
      else setProblem(t('site.err.generic'));
    } finally {
      setBusy(false);
    }
  }

  const ways = s
    ? [
        s.email && { icon: <FileText width={20} height={20} aria-hidden />, title: t('site.ct.email'), lines: [s.email, t('site.ct.email_b')], cta: { href: `mailto:${s.email}`, label: t('site.ct.email_cta') } },
        s.whatsapp && { icon: <Phone width={20} height={20} aria-hidden />, title: t('site.ct.wa'), lines: [hours(s, lang, t), t('site.ct.wa_b')], cta: { href: `https://wa.me/${s.whatsapp}`, label: t('site.ct.wa_cta') } },
        s.help_url && { icon: <Search width={20} height={20} aria-hidden />, title: t('site.ct.help'), lines: [t('site.ct.help_b'), t('site.ct.help_b2')], cta: { href: s.help_url, label: t('site.ct.help_cta') } },
      ].filter((w): w is Exclude<typeof w, null | '' | undefined> => !!w)
    : [];
  const countries = new Map((config?.countries ?? []).map((c) => [c.code, c]));
  const langName = new Map((config?.languages ?? []).map((l) => [l.code, l.native_name]));

  return (
    <>
      <section className="relative overflow-hidden bg-espresso-950 py-48 md:py-64">
        <div aria-hidden className="pointer-events-none absolute -right-[160px] -top-[200px] hidden h-[560px] w-[560px] rounded-full border-[56px] border-mocha-950 md:block" />
        <Container className="relative flex flex-col items-center gap-16 text-center">
          <span className="inline-flex items-center gap-8 rounded-full border border-cream-100/[0.14] bg-cream-100/[0.06] px-12 py-[6px] text-web-eyebrow uppercase text-cream-200">
            <Phone width={14} height={14} aria-hidden />
            {t('site.ct.eyebrow')}
          </span>
          <h1 className="text-web-m-display text-cream-50 md:text-web-display">{t('site.ct.title')}</h1>
          <p className="max-w-[640px] text-latin-body-lg text-cream-400 md:text-web-body-lg">{t('site.ct.body')}</p>
        </Container>
      </section>
      <section className="bg-bg-canvas py-40 md:py-64">
        <Container>
          {ways.length > 0 && (
            <div className={`mb-24 grid gap-16 md:mb-32 md:gap-24 ${ways.length === 3 ? 'md:grid-cols-3' : ways.length === 2 ? 'md:grid-cols-2' : ''}`}>
              {ways.map((w) => (
                <Way key={w.title} {...w} />
              ))}
            </div>
          )}
          <div className="grid grid-cols-1 items-start gap-24 lg:grid-cols-[minmax(0,1fr)_438px]">
            <div className="rounded-xl border border-border-default bg-bg-surface p-24 shadow-lg md:p-32">
              {sent ? (
                <div className="flex flex-col gap-24">
                  <span className="inline-flex h-[48px] w-[48px] items-center justify-center rounded-full bg-status-success-bg text-status-success">
                    <Check width={24} height={24} aria-hidden />
                  </span>
                  <div>
                    <h2 className="text-latin-display">{t('site.ct.sent')}</h2>
                    <p className="mt-8 text-latin-body text-text-secondary">{t('site.ct.sent_b', { name: name.trim().split(/\s+/)[0] ?? '', email: email.trim() })}</p>
                  </div>
                  <div className="rounded-lg border border-border-default bg-bg-canvas p-16">
                    <div className="flex items-center justify-between gap-8">
                      <p className="text-latin-label-sm font-semibold">{t('site.ct.ticket', { ticket: sent.ticket })}</p>
                      <span className="rounded-full bg-cream-200 px-8 py-2 text-latin-caption-strong text-mocha-700">{t(`site.ct.topic.${sent.topic}`)}</span>
                    </div>
                    <p className="mt-8 whitespace-pre-line text-latin-body text-text-secondary">“{message.trim()}”</p>
                  </div>
                  <div>
                    <p className="mb-12 text-latin-label-sm font-semibold">{t('site.ct.next')}</p>
                    <ul className="flex flex-col gap-12">
                      {[t('site.ct.next1'), t('site.ct.next2'), ...(s?.whatsapp ? [t('site.ct.next3')] : [])].map((x) => (
                        <li key={x} className="flex gap-12 text-latin-body">
                          <Check width={18} height={18} className="mt-[3px] shrink-0 text-status-success" aria-hidden />
                          {x}
                        </li>
                      ))}
                    </ul>
                  </div>
                  <div className="grid gap-12 sm:grid-cols-2">
                    <LinkButton href={ROUTES.home} variant="primary" size="md">
                      {t('site.ct.home')}
                    </LinkButton>
                    {s?.help_url && (
                      <LinkButton href={s.help_url} variant="secondary" size="md">
                        {t('site.ct.help_cta')}
                      </LinkButton>
                    )}
                  </div>
                </div>
              ) : (
                <form noValidate onSubmit={(e) => void submit(e)} className="flex flex-col gap-20">
                  <div>
                    <h2 className="text-latin-h2 font-semibold">{t('site.ct.form')}</h2>
                    <p className="mt-4 text-latin-body text-text-secondary">{t('site.ct.form_b')}</p>
                  </div>
                  {Object.keys(errors).length > 0 && (
                    <ErrorSummary>
                      {Object.keys(errors).length === 1 ? t('site.ct.fix_one') : t('site.ct.fix_many', { n: Object.keys(errors).length })}
                    </ErrorSummary>
                  )}
                  {problem && <ErrorSummary>{problem}</ErrorSummary>}
                  <div className="grid gap-20 sm:grid-cols-2 sm:gap-12">
                    <Field label={t('site.ct.name')} error={errors.name}>
                      {(id, bad) => <TextInput id={id} invalid={bad} value={name} onChange={(e) => setName(e.target.value)} placeholder={t('site.bd.name_hint')} autoComplete="name" />}
                    </Field>
                    <Field label={t('site.ct.email_f')} error={errors.email}>
                      {(id, bad) => <TextInput id={id} invalid={bad} type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="name@company.com" autoComplete="email" />}
                    </Field>
                  </div>
                  <Field label={t('site.ct.topic')} error={errors.topic}>
                    {(id, bad) => (
                      <SelectInput
                        id={id}
                        invalid={bad}
                        value={topic}
                        onChange={setTopic}
                        placeholder={t('site.ct.topic_hint')}
                        options={(s?.topics ?? []).map((x) => ({ value: x, label: t(`site.ct.topic.${x}`) }))}
                      />
                    )}
                  </Field>
                  <Field
                    label={t('site.ct.message')}
                    error={errors.message}
                    extra={<p className="text-right text-latin-caption text-text-secondary">{`${message.length} / ${MAX}`}</p>}
                  >
                    {(id, bad) => (
                      <textarea
                        id={id}
                        value={message}
                        maxLength={MAX}
                        rows={5}
                        onChange={(e) => setMessage(e.target.value)}
                        placeholder={t('site.ct.message_hint')}
                        aria-invalid={bad || undefined}
                        aria-describedby={bad ? `${id}-error` : undefined}
                        className={`${inputClass(bad)} h-auto py-12`}
                      />
                    )}
                  </Field>
                  <div className="flex flex-col gap-12 sm:flex-row sm:items-center">
                    <button
                      type="submit"
                      disabled={busy}
                      className="inline-flex h-[52px] items-center justify-center rounded-lg bg-action-primary px-24 text-latin-label font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-60"
                    >
                      {t('site.ct.submit')}
                    </button>
                    <p className="inline-flex items-center gap-8 text-latin-caption text-text-secondary">
                      <Lock width={14} height={14} className="shrink-0" aria-hidden />
                      <span>{withLinks(t('site.ct.privacy'), { privacy: { href: ROUTES.privacy, label: t('site.trial.privacy_link') } })}</span>
                    </p>
                  </div>
                </form>
              )}
            </div>
            {s && (
              <aside className="overflow-hidden rounded-xl border border-border-default bg-bg-surface">
                <img src="/img/office-map.webp" alt={t('site.ct.map_alt')} width={438} height={180} loading="lazy" className="h-[180px] w-full object-cover" />
                <div className="flex flex-col gap-20 p-24">
                  <div>
                    <p className="text-web-eyebrow uppercase text-mocha-700">{t('site.ct.office')}</p>
                    <p className="mt-4 text-latin-h3 md:text-web-h3">{s.office}</p>
                    <p className="text-latin-body text-text-secondary">{t('site.ct.support_hours', { hours: hours(s, lang, t) })}</p>
                  </div>
                  <div className="border-t border-border-default pt-16">
                    <p className="mb-12 text-web-eyebrow uppercase text-mocha-700">{t('site.ct.regions')}</p>
                    <ul className="flex flex-col gap-8">
                      {s.regions.map((r) => {
                        const c = countries.get(r.country);
                        return (
                          <li key={r.country} className="flex items-center justify-between gap-12 text-latin-label-sm">
                            <span className="inline-flex items-center gap-8 font-semibold">
                              <span aria-hidden>{c?.flag}</span>
                              {c?.name ?? r.country}
                            </span>
                            <span className="text-latin-caption text-text-secondary">{r.languages.map((l) => langName.get(l) ?? l).join(', ')}</span>
                          </li>
                        );
                      })}
                    </ul>
                  </div>
                  <a href={ROUTES.demo} className="flex items-center gap-12 rounded-lg bg-cream-200 p-16 hover:brightness-95">
                    <Play width={20} height={20} className="shrink-0" aria-hidden />
                    <span className="flex flex-1 flex-col">
                      <span className="text-latin-label-sm font-semibold">{t('site.ct.sales')}</span>
                      <span className="text-latin-caption text-text-secondary">{t('site.ct.sales_b', { n: s.demo_minutes })}</span>
                    </span>
                    <ChevronRight width={18} height={18} aria-hidden />
                  </a>
                </div>
              </aside>
            )}
          </div>
        </Container>
      </section>
    </>
  );
}
