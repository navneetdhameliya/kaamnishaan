import { Briefcase, Check, Clock, FileText, Play, Plus, Lock, User } from 'lucide-react';
import { useEffect, useState, type FormEvent } from 'react';

import { cx } from '../components/ui';
import { api, ApiError } from '../lib/api';
import type { Lang, T } from '../lib/i18n';
import type { ConfigOut, DemoOut, DemoSlotsOut, PlansOut } from '../lib/types';
import { LinkButton } from './Layout';
import { Container } from './parts';
import { EMAIL_RE, ErrorSummary, Field, SelectInput, TextInput, inputClass } from './form';
import { ROUTES, money } from './site';
import { icsFile, longDay, monthDay, timeIn, zoneLabel } from './when';

type Errors = Partial<Record<'name' | 'email' | 'phone' | 'company' | 'trade' | 'time', string>>;

export function withLinks(text: string, links: Record<string, { href: string; label: string }>) {
  const keys = Object.keys(links);
  const marks = keys.map((_, i) => String.fromCharCode(i + 1));
  let s = text;
  keys.forEach((k, i) => (s = s.replace(`{${k}}`, marks[i]!)));
  return s.split(new RegExp(`(${marks.join('|')})`)).map((part, i) => {
    const at = marks.indexOf(part);
    if (at < 0) return part;
    const l = links[keys[at]!]!;
    return (
      <a key={i} href={l.href} className="underline">
        {l.label}
      </a>
    );
  });
}

function Point({ icon, title, body }: { icon: React.ReactNode; title: string; body: string }) {
  return (
    <li className="flex gap-12">
      <span className="inline-flex h-[40px] w-[40px] shrink-0 items-center justify-center rounded-full bg-sage-100 text-sage-700">{icon}</span>
      <span className="flex flex-col">
        <span className="text-latin-label-sm font-semibold">{title}</span>
        <span className="text-latin-body text-text-secondary">{body}</span>
      </span>
    </li>
  );
}

function Booked({ t, lang, booked, name, email }: { t: T; lang: Lang; booked: DemoOut; name: string; email: string }) {
  const date = booked.starts_at.slice(0, 10);
  const tile = monthDay(date, lang);
  const minutes = Math.round((new Date(booked.ends_at).getTime() - new Date(booked.starts_at).getTime()) / 60000);
  function addToCalendar() {
    const ics = icsFile(t('site.bd.cal_title'), booked.starts_at, booked.ends_at, `${booked.ticket} · ${t('site.bd.ok_team')}`);
    const url = URL.createObjectURL(new Blob([ics], { type: 'text/calendar' }));
    const a = document.createElement('a');
    a.href = url;
    a.download = 'kaamnishaan-demo.ics';
    a.click();
    URL.revokeObjectURL(url);
  }
  return (
    <div className="flex flex-col gap-24">
      <span className="inline-flex h-[48px] w-[48px] items-center justify-center rounded-full bg-status-success-bg text-status-success">
        <Check width={24} height={24} aria-hidden />
      </span>
      <div>
        <h2 className="text-latin-display">{t('site.bd.ok', { name: name.split(/\s+/)[0] ?? name })}</h2>
        <p className="mt-8 text-latin-body text-text-secondary">{t('site.bd.ok_b', { email })}</p>
      </div>
      <div className="flex gap-16 rounded-lg border border-border-default bg-bg-canvas p-16">
        <span className="flex h-[64px] w-[56px] shrink-0 flex-col items-center justify-center rounded-md bg-mocha-900 text-cream-50">
          <span className="text-web-eyebrow uppercase">{tile.month}</span>
          <span className="text-[24px] font-bold leading-[28px]">{tile.day}</span>
        </span>
        <div className="flex min-w-0 flex-col gap-4">
          <p className="text-latin-h3">{longDay(date, lang, 'long')}</p>
          <p className="inline-flex items-center gap-8 text-latin-caption text-text-secondary">
            <Clock width={14} height={14} aria-hidden />
            {t('site.bd.ok_range', {
              start: timeIn(booked.starts_at, booked.timezone, lang),
              end: timeIn(booked.ends_at, booked.timezone, lang),
              tz: zoneLabel(booked.timezone, new Date(booked.starts_at)),
              n: minutes,
            })}
          </p>
          <p className="inline-flex items-center gap-8 text-latin-caption text-text-secondary">
            <Play width={14} height={14} aria-hidden />
            {t('site.bd.ok_video')}
          </p>
          <p className="inline-flex items-center gap-8 text-latin-caption text-text-secondary">
            <User width={14} height={14} aria-hidden />
            {t('site.bd.ok_team')}
          </p>
        </div>
      </div>
      <div className="grid gap-12 sm:grid-cols-2">
        <button
          type="button"
          onClick={addToCalendar}
          className="inline-flex h-[52px] items-center justify-center gap-8 rounded-lg bg-action-primary text-latin-label font-semibold text-text-on-action hover:bg-action-primary-pressed"
        >
          <Plus width={18} height={18} aria-hidden />
          {t('site.bd.calendar')}
        </button>
        <LinkButton href={ROUTES.home} variant="secondary" size="md">
          {t('site.ct.home')}
        </LinkButton>
      </div>
      <div>
        <p className="mb-12 text-latin-label-sm font-semibold">{t('site.bd.before')}</p>
        <ul className="flex flex-col gap-12">
          {[t('site.bd.before1'), t('site.bd.before2'), t('site.bd.before3')].map((b) => (
            <li key={b} className="flex gap-12 text-latin-body">
              <Check width={18} height={18} className="mt-[3px] shrink-0 text-status-success" aria-hidden />
              {b}
            </li>
          ))}
        </ul>
      </div>
      <p className="border-t border-border-default pt-16 text-latin-caption text-text-secondary">
        {withLinks(t('site.bd.change', { ticket: '{ticket}' }), { ticket: { href: ROUTES.contact, label: booked.ticket } })}
      </p>
    </div>
  );
}

/** W03 Book a demo: free times from GET /public/demo-slots, booking with POST /public/demo-requests. */
export default function BookDemo({ t, lang, plans, config }: { t: T; lang: Lang; plans: PlansOut | null; config: ConfigOut | null }) {
  const [slots, setSlots] = useState<DemoSlotsOut | null>(null);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [dial, setDial] = useState('');
  const [phone, setPhone] = useState('');
  const [company, setCompany] = useState('');
  const [team, setTeam] = useState('');
  const [trade, setTrade] = useState('');
  const [day, setDay] = useState('');
  const [time, setTime] = useState('');
  const [errors, setErrors] = useState<Errors>({});
  const [problem, setProblem] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [booked, setBooked] = useState<DemoOut | null>(null);

  async function loadSlots() {
    try {
      const s = await api<DemoSlotsOut>('/public/demo-slots');
      setSlots(s);
      setDay((d) => (d && s.days.some((x) => x.date === d) ? d : (s.days[0]?.date ?? '')));
      setTeam((v) => v || (s.team_sizes[0] ?? ''));
    } catch {
      setProblem(t('site.err.offline'));
    }
  }
  useEffect(() => {
    void loadSlots();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const country = config?.countries.find((c) => c.code === config.default_country);
  const dialCode = dial || country?.dial_code || '+91';
  const today = slots?.days.find((d) => d.date === day);
  const minutes = slots?.minutes ?? 30;
  const pro = plans?.plans.find((p) => p.most_popular);
  const cheapest = plans?.plans.find((p) => p.price != null);
  const tz = slots?.timezone ?? config?.support?.timezone ?? 'Asia/Kolkata';
  const tradeNames = (config?.trades ?? []).map((tr) => tr.name);

  async function submit(ev: FormEvent) {
    ev.preventDefault();
    setProblem(null);
    const e: Errors = {};
    if (!name.trim()) e.name = t('site.err.name');
    if (!EMAIL_RE.test(email.trim())) e.email = t('site.err.email');
    if (phone.replace(/\D/g, '').length < 10) e.phone = t('site.bd.err_phone');
    if (!company.trim()) e.company = t('site.err.company');
    if (!trade) e.trade = t('site.err.trade');
    if (!time) e.time = t('site.bd.err_time');
    setErrors(e);
    if (Object.keys(e).length) return;
    setBusy(true);
    try {
      const out = await api<DemoOut>('/public/demo-requests', {
        method: 'POST',
        body: { name: name.trim(), email: email.trim(), phone: `${dialCode} ${phone.trim()}`, company: company.trim(), team_size: team, trade, starts_at: time, lang },
      });
      setBooked(out);
    } catch (err) {
      if (err instanceof ApiError && (err.code === 'slot_taken' || err.code === 'slot_unavailable')) {
        setErrors({ time: t('site.bd.err_taken') });
        setTime('');
        void loadSlots();
      } else if (err instanceof ApiError && err.status === 422 && err.fields.email) {
        setErrors({ email: t('site.err.email') });
      } else if (err instanceof ApiError && err.status === 429) {
        setProblem(t('site.err.wait'));
      } else if (err instanceof ApiError && err.status === 0) {
        setProblem(t('site.err.offline'));
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
      <Container className="grid grid-cols-1 items-start gap-32 lg:grid-cols-[minmax(0,560px)_minmax(0,560px)] lg:justify-between">
        <div className="flex flex-col gap-24">
          <span className="inline-flex items-center gap-8 self-start rounded-full bg-cream-200 px-12 py-[6px] text-web-eyebrow uppercase text-mocha-700">
            <Play width={14} height={14} aria-hidden />
            {t('site.nav.demo')}
          </span>
          <h1 className="text-web-m-display md:text-web-display">{t('site.bd.title')}</h1>
          <p className="text-latin-body-lg text-text-secondary">{t('site.bd.body', { n: minutes })}</p>
          <ul className="flex flex-col gap-16">
            <Point icon={<Play width={18} height={18} aria-hidden />} title={t('site.bd.b1')} body={t('site.bd.b1_b')} />
            <Point icon={<Briefcase width={18} height={18} aria-hidden />} title={t('site.bd.b2')} body={t('site.bd.b2_b')} />
            {cheapest?.price && (
              <Point icon={<FileText width={18} height={18} aria-hidden />} title={t('site.bd.b3')} body={t('site.bd.b3_b', { price: money(cheapest.price, lang) })} />
            )}
          </ul>
          <div className="relative overflow-hidden rounded-xl">
            <img src="/img/industry-hvac.webp" alt={t('site.bd.photo_alt')} loading="lazy" className="aspect-[560/320] w-full object-cover" />
            <span className="absolute bottom-16 left-16 flex items-center gap-12 rounded-full bg-cream-50 py-8 pl-8 pr-16 shadow-md">
              <span className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-full bg-status-success-bg text-status-success">
                <Check width={16} height={16} aria-hidden />
              </span>
              <span className="flex flex-col">
                <span className="text-latin-label-sm font-semibold">{t('site.hero.chip_approved')}</span>
                <span className="text-[12px] leading-[16px] text-text-secondary">{t('site.hero.chip_approved_sub')}</span>
              </span>
            </span>
          </div>
          <div className="rounded-xl border border-border-default bg-bg-surface p-24">
            <h2 className="text-latin-h2 font-semibold">{t('site.bd.expect')}</h2>
            <ol className="mt-16 flex flex-col gap-16">
              {[
                [t('site.bd.e1', { n: minutes }), t('site.bd.e1_b')],
                [t('site.bd.e2'), tradeNames.length ? t('site.bd.e2_b', { trades: tradeNames.join(', ') }) : ''],
                [t('site.bd.e3'), pro && plans ? t('site.bd.e3_b', { n: plans.trial_days, plan: pro.name }) : ''],
              ].map(([title, body], i) => (
                <li key={title} className="flex gap-12">
                  <span className="inline-flex h-[24px] w-[24px] shrink-0 items-center justify-center rounded-full bg-mocha-900 text-latin-caption-strong text-cream-50">
                    {i + 1}
                  </span>
                  <span className="flex flex-col">
                    <span className="text-latin-label-sm font-semibold">{title}</span>
                    {body && <span className="text-latin-body text-text-secondary">{body}</span>}
                  </span>
                </li>
              ))}
            </ol>
          </div>
        </div>
        <div className="rounded-xl border border-border-default bg-bg-surface p-24 shadow-lg md:p-32 lg:sticky lg:top-24">
          {booked ? (
            <Booked t={t} lang={lang} booked={booked} name={name.trim()} email={email.trim()} />
          ) : (
            <form noValidate onSubmit={(e) => void submit(e)} className="flex flex-col gap-20">
              <div>
                <h2 className="text-latin-h2 font-semibold">{t('site.bd.form')}</h2>
                <p className="mt-4 text-latin-body text-text-secondary">{t('site.bd.form_b')}</p>
              </div>
              {count > 0 && <ErrorSummary>{count === 1 ? t('site.bd.fix_one') : t('site.bd.fix_many', { n: count })}</ErrorSummary>}
              {problem && <ErrorSummary>{problem}</ErrorSummary>}
              <Field label={t('site.bd.name')} error={errors.name}>
                {(id, bad) => <TextInput id={id} invalid={bad} value={name} onChange={(e) => setName(e.target.value)} placeholder={t('site.bd.name_hint')} autoComplete="name" />}
              </Field>
              <Field label={t('site.trial.email')} error={errors.email}>
                {(id, bad) => <TextInput id={id} invalid={bad} type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="name@company.com" autoComplete="email" />}
              </Field>
              <Field label={t('site.bd.phone')} error={errors.phone}>
                {(id, bad) => (
                  <div className={cx(inputClass(bad), 'flex items-center gap-8 px-0 focus-within:ring-2 focus-within:ring-focus-ring')}>
                    <select
                      aria-label={t('site.trial.country')}
                      value={dialCode}
                      onChange={(e) => setDial(e.target.value)}
                      className="h-full rounded-l-lg border-r border-border-default bg-transparent pl-12 pr-8 text-latin-body focus:outline-none"
                    >
                      {[...new Map((config?.countries ?? []).map((c) => [c.dial_code, c])).values()].map((c) => (
                        <option key={c.dial_code} value={c.dial_code}>
                          {c.flag} {c.dial_code}
                        </option>
                      ))}
                    </select>
                    <input
                      id={id}
                      type="tel"
                      inputMode="tel"
                      value={phone}
                      onChange={(e) => setPhone(e.target.value)}
                      placeholder="98765 43210"
                      autoComplete="tel-national"
                      aria-invalid={bad || undefined}
                      aria-describedby={bad ? `${id}-error` : undefined}
                      className="h-full min-w-0 flex-1 bg-transparent pr-12 text-latin-body focus:outline-none"
                    />
                  </div>
                )}
              </Field>
              <Field label={t('site.trial.company')} error={errors.company}>
                {(id, bad) => <TextInput id={id} invalid={bad} value={company} onChange={(e) => setCompany(e.target.value)} placeholder={t('site.trial.company')} autoComplete="organization" />}
              </Field>
              <div className="grid gap-20 sm:grid-cols-2 sm:gap-12">
                <Field label={t('site.bd.team')}>
                  {(id) => (
                    <SelectInput
                      id={id}
                      invalid={false}
                      value={team}
                      onChange={setTeam}
                      options={(slots?.team_sizes ?? []).map((v, i) => ({ value: v, label: t(`site.bd.team_${i + 1}`) }))}
                    />
                  )}
                </Field>
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
              </div>
              <Field label={t('site.bd.day')}>
                {(id) => (
                  <SelectInput
                    id={id}
                    invalid={false}
                    value={day}
                    onChange={(d) => {
                      setDay(d);
                      setTime('');
                    }}
                    options={(slots?.days ?? []).map((d) => ({ value: d.date, label: longDay(d.date, lang) }))}
                  />
                )}
              </Field>
              <fieldset className="flex flex-col gap-8">
                <legend className="mb-8 text-latin-label-sm font-semibold">{t('site.bd.time', { tz: zoneLabel(tz) })}</legend>
                <div role="radiogroup" className="flex flex-wrap gap-8">
                  {today?.slots.map((s) => {
                    const on = time === s;
                    return (
                      <button
                        key={s}
                        type="button"
                        role="radio"
                        aria-checked={on}
                        onClick={() => setTime(s)}
                        className={cx(
                          'inline-flex h-[40px] items-center gap-4 rounded-full border px-16 text-latin-label-sm font-semibold transition',
                          on ? 'border-mocha-900 bg-mocha-900 text-cream-50' : 'border-border-strong bg-bg-surface text-text-primary hover:bg-bg-canvas',
                        )}
                      >
                        {on && <Check width={14} height={14} aria-hidden />}
                        {timeIn(s, tz, lang)}
                      </button>
                    );
                  })}
                  {slots && !today?.slots.length && <p className="text-latin-caption text-text-secondary">{t('site.bd.no_slots')}</p>}
                </div>
                {errors.time && <p className="text-latin-caption text-status-danger">{errors.time}</p>}
              </fieldset>
              <button
                type="submit"
                disabled={busy || !slots}
                className="inline-flex h-[56px] items-center justify-center rounded-lg bg-action-primary text-latin-label font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-60"
              >
                {t('site.bd.submit')}
              </button>
              <p className="inline-flex items-center gap-8 text-latin-caption text-text-secondary">
                <Lock width={14} height={14} className="shrink-0" aria-hidden />
                <span>{withLinks(t('site.bd.privacy'), { privacy: { href: ROUTES.privacy, label: t('site.trial.privacy_link') } })}</span>
              </p>
            </form>
          )}
        </div>
      </Container>
    </section>
  );
}
