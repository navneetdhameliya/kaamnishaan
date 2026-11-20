import { AlertCircle, Check, ChevronLeft, Copy, ExternalLink, MessageCircle, PauseCircle, Power } from 'lucide-react';
import { useEffect, useState, type FormEvent, type ReactNode } from 'react';

import { api, ApiError } from '../lib/api';
import { day, LANGS, money, type Lang, type T } from '../lib/i18n';
import { session } from '../lib/session';
import type { CompanyDetail, OwnerInvite } from '../lib/types';
import { cx, ErrorBanner, Link, navigate, ReasonDialog, Spinner } from '../ui';

type Config = { countries: { code: string; name: string; dial_code: string }[]; trades: { key: string; name: string }[] };
type Plans = { trial_days: number; currency: string; plans: { code: string; name: string; price: { amount: number; currency: string } | null }[] };
type Form = { name: string; trade: string; country: string; report_language: Lang; owner_name: string; owner_phone: string; owner_email: string; plan: string; trial_ends_at: string };
type Errors = Partial<Record<keyof Form, string>>;

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const field = 'mt-8 h-[48px] w-full rounded-lg border bg-bg-surface px-12 text-latin-body hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring';

function Section({ title, sub, children, i }: { title: string; sub: string; children: ReactNode; i: number }) {
  return (
    <section className="kn-in grid gap-16 rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24 lg:grid-cols-[280px_1fr]" style={{ ['--d' as string]: `${i * 60}ms` }}>
      <div>
        <h2 className="text-[20px] font-semibold">{title}</h2>
        <p className="mt-4 text-[13px] text-text-secondary">{sub}</p>
      </div>
      <div className="grid gap-16 sm:grid-cols-2">{children}</div>
    </section>
  );
}

function Field({ id, label, error, children }: { id: string; label: string; error?: string; children: ReactNode }) {
  return (
    <div>
      <label htmlFor={id} className="text-latin-label-sm font-semibold">
        {label}
      </label>
      {children}
      {error && (
        <p id={`${id}-err`} className="mt-4 flex items-center gap-4 text-[13px] text-status-danger">
          <AlertCircle width={14} height={14} aria-hidden />
          {error}
        </p>
      )}
    </div>
  );
}

function useCopied(): [string | null, (k: string, text: string) => void] {
  const [done, setDone] = useState<string | null>(null);
  return [done, (k, text) => void navigator.clipboard?.writeText(text).then(() => (setDone(k), window.setTimeout(() => setDone(null), 1800)))];
}

/** After creating a company, or making a new link: how the owner gets in. Shown once. */
export function InvitePanel({ t, invite, onOpen }: { t: T; invite: OwnerInvite; onOpen?: () => void }) {
  const [copied, copy] = useCopied();
  const c = invite.company;
  return (
    <section className="kn-pop rounded-xl border border-status-success bg-bg-surface p-20 sm:p-24">
      <p className="flex items-center gap-8 text-[18px] font-semibold text-status-success">
        <Check width={20} height={20} aria-hidden />
        {onOpen ? t('admin.cf.created_title') : t('admin.cf.new_link_done')}
      </p>
      <p className="mt-8 text-latin-body">{t('admin.cf.created_body', { name: c.owner_name ?? '', phone: c.owner_phone ?? '' })}</p>
      <p className="mt-12 rounded-lg bg-bg-subtle p-12 font-mono text-[13px] break-all">{invite.sms_text}</p>
      <p className="mt-8 text-[13px] text-text-secondary">{t('admin.cf.sms_note')}</p>
      <div className="mt-16 flex flex-wrap gap-12">
        <button type="button" onClick={() => copy('link', invite.invite_link)} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg border border-border-strong bg-bg-surface px-16 text-latin-label-sm font-semibold hover:border-mocha-500">
          {copied === 'link' ? <Check width={16} height={16} className="kn-pop" aria-hidden /> : <Copy width={16} height={16} aria-hidden />}
          <span aria-live="polite">{copied === 'link' ? t('admin.setup.copied') : t('admin.cf.copy_link')}</span>
        </button>
        <button type="button" onClick={() => copy('sms', invite.sms_text)} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg border border-border-strong bg-bg-surface px-16 text-latin-label-sm font-semibold hover:border-mocha-500">
          {copied === 'sms' ? <Check width={16} height={16} className="kn-pop" aria-hidden /> : <Copy width={16} height={16} aria-hidden />}
          <span aria-live="polite">{copied === 'sms' ? t('admin.setup.copied') : t('admin.cf.copy_sms')}</span>
        </button>
        {c.owner_phone && (
          <a href={`https://wa.me/${c.owner_phone.replace(/\D/g, '')}?text=${encodeURIComponent(invite.sms_text)}`} target="_blank" rel="noopener noreferrer" className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg border border-border-strong bg-bg-surface px-16 text-latin-label-sm font-semibold hover:border-mocha-500">
            <MessageCircle width={16} height={16} aria-hidden />
            {t('admin.cf.whatsapp')}
          </a>
        )}
        {onOpen && (
          <button type="button" onClick={onOpen} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed">
            {t('admin.cf.open')}
          </button>
        )}
      </div>
    </section>
  );
}

/** A06 Create company and A07 Edit company (with Suspend / Turn back on). */
export function CompanyForm({ t, lang, id, onName }: { t: T; lang: Lang; id: string | null; onName: (n: string) => void }) {
  const editing = !!id;
  const [config, setConfig] = useState<Config | null>(null);
  const [plans, setPlans] = useState<Plans | null>(null);
  const [company, setCompany] = useState<CompanyDetail | null>(null);
  const [f, setF] = useState<Form>({ name: '', trade: '', country: 'IN', report_language: 'en', owner_name: '', owner_phone: '', owner_email: '', plan: 'professional', trial_ends_at: '' });
  const [errors, setErrors] = useState<Errors>({});
  const [banner, setBanner] = useState<string | null>(null);
  const [tries, setTries] = useState(0);
  const [busy, setBusy] = useState(false);
  const [created, setCreated] = useState<OwnerInvite | null>(null);
  const [dialog, setDialog] = useState<'suspend' | 'reactivate' | null>(null);
  const [done, setDone] = useState<string | null>(null);
  const canChange = session.get()?.staff.role !== 'support';
  // same rule as the server: India pays in rupees, everyone else in dollars (D-97)
  const currency = f.country === 'IN' ? 'INR' : 'USD';

  useEffect(() => {
    api<Config>(`/config?locale=${lang}`, { auth: false }).then((c) => {
      setConfig(c);
      setF((x) => (x.trade ? x : { ...x, trade: c.trades[0]?.key ?? '' }));
    });
  }, [lang]);
  useEffect(() => {
    api<Plans>(`/plans?currency=${currency}&locale=${lang}`, { auth: false }).then(setPlans).catch(() => setPlans(null));
  }, [currency, lang]);
  useEffect(() => {
    if (!id) return onName(t('admin.cf.create_title'));
    api<CompanyDetail>(`/admin/companies/${id}?locale=${lang}`).then((c) => {
      setCompany(c);
      onName(t('admin.cf.edit_title'));
      setF((x) => ({ ...x, name: c.name, trade: c.industry_slug ?? '', country: c.country, report_language: c.report_language as Lang, plan: c.plan.code, trial_ends_at: c.trial_ends_at ? c.trial_ends_at.slice(0, 10) : '' }));
    });
  }, [id, lang, onName, t]);

  const set = (patch: Partial<Form>) => {
    setF((x) => ({ ...x, ...patch }));
    setErrors((e) => {
      const n = { ...e };
      (Object.keys(patch) as (keyof Form)[]).forEach((k) => delete n[k]);
      return n;
    });
  };
  const check = (): Errors => {
    const e: Errors = {};
    if (!f.name.trim()) e.name = t('admin.cf.e.name');
    if (!f.trade) e.trade = t('admin.cf.e.trade');
    if (!editing) {
      if (!f.owner_name.trim()) e.owner_name = t('admin.cf.e.owner_name');
      if (f.owner_phone.replace(/\D/g, '').length < 8) e.owner_phone = t('admin.cf.e.owner_phone');
      if (f.owner_email.trim() && !EMAIL.test(f.owner_email.trim())) e.owner_email = t('admin.cf.e.owner_email');
    }
    return e;
  };
  const showErrors = (e: Errors) => {
    setErrors(e);
    const n = Object.keys(e).length;
    setBanner(n === 1 ? t('admin.cf.fix_one') : t('admin.cf.fix', { n }));
    setTries((x) => x + 1);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };
  const fromServer = (err: unknown) => {
    if (!(err instanceof ApiError)) return setBanner(t('admin.err.generic'));
    if (err.status === 403) return setBanner(t('admin.cf.not_allowed'));
    if (err.status === 0) return setBanner(t('admin.err.offline'));
    const map: Record<string, [keyof Form, string]> = {
      'owner_phone:invalid': ['owner_phone', 'admin.cf.e.owner_phone'],
      'owner_phone:disabled': ['owner_phone', 'admin.cf.e.phone_disabled'],
      'owner_email:taken': ['owner_email', 'admin.cf.e.email_taken'],
      'plan:unknown': ['plan', 'admin.cf.e.plan'],
      'trade:unknown': ['trade', 'admin.cf.e.trade'],
      'trial_ends_at:not_in_trial': ['trial_ends_at', 'admin.cf.e.trial'],
    };
    const e: Errors = {};
    Object.entries(err.fields).forEach(([k, v]) => {
      const hit = map[`${k}:${v}`];
      if (hit) e[hit[0]] = t(hit[1]);
    });
    if (Object.keys(e).length) showErrors(e);
    else setBanner(err.message);
  };

  const submit = async (ev: FormEvent) => {
    ev.preventDefault();
    const e = check();
    if (Object.keys(e).length) return showErrors(e);
    setBusy(true);
    setBanner(null);
    try {
      if (editing && company) {
        const body: Record<string, unknown> = { name: f.name.trim(), trade: f.trade, country: f.country, report_language: f.report_language, plan: f.plan };
        if (company.status === 'trial' && f.trial_ends_at && f.trial_ends_at !== company.trial_ends_at?.slice(0, 10)) body.trial_ends_at = `${f.trial_ends_at}T23:59:00Z`;
        setCompany(await api<CompanyDetail>(`/admin/companies/${id}?locale=${lang}`, { method: 'PATCH', body }));
        setDone(t('admin.cf.done_saved'));
      } else {
        const out = await api<OwnerInvite>(`/admin/companies?locale=${lang}`, {
          method: 'POST',
          body: { name: f.name.trim(), trade: f.trade, country: f.country, report_language: f.report_language, owner_name: f.owner_name.trim(), owner_phone: f.owner_phone.trim(), owner_email: f.owner_email.trim() || null, plan: f.plan },
        });
        setCreated(out);
        onName(out.company.name);
        window.scrollTo({ top: 0, behavior: 'smooth' });
      }
    } catch (err) {
      fromServer(err);
    } finally {
      setBusy(false);
    }
  };

  const act = async (kind: 'suspend' | 'reactivate', reason: string): Promise<string | null> => {
    try {
      setCompany(await api<CompanyDetail>(`/admin/companies/${id}/${kind}?locale=${lang}`, { method: 'POST', body: { reason } }));
      setDialog(null);
      setDone(t(kind === 'suspend' ? 'admin.cf.done_suspend' : 'admin.cf.done_reactivate'));
      return null;
    } catch (err) {
      return err instanceof ApiError && err.status === 403 ? t('admin.cf.not_allowed') : t('admin.err.generic');
    }
  };

  const back = (
    <Link to={id ? `/companies/${id}` : '/companies'} className="group inline-flex w-fit items-center gap-4 text-latin-label-sm font-semibold text-text-secondary hover:text-text-primary">
      <ChevronLeft width={16} height={16} className="transition-transform group-hover:-translate-x-[3px]" aria-hidden />
      {id && company ? company.name : t('admin.co.back')}
    </Link>
  );
  if (created)
    return (
      <div className="flex flex-col gap-16">
        {back}
        <InvitePanel t={t} invite={created} onOpen={() => navigate(`/companies/${created.company.id}`)} />
      </div>
    );
  if (!config || (editing && !company)) return <div aria-busy="true" className="kn-shimmer h-[520px] rounded-xl bg-bg-surface" />;

  const cls = (k: keyof Form) => cx(field, errors[k] ? 'border-[1.5px] border-status-danger' : 'border-border-strong');
  const aria = (k: keyof Form) => ({ 'aria-invalid': !!errors[k] || undefined, 'aria-describedby': errors[k] ? `${k}-err` : undefined });
  const planLabel = (p: Plans['plans'][number]) =>
    !editing && plans ? t('admin.cf.plan_trial', { plan: p.name, n: plans.trial_days }) : p.price ? `${p.name} · ${t('admin.co.per_month', { price: money(p.price.amount, p.price.currency, lang) })}` : t('admin.cf.plan_contact', { plan: p.name });

  return (
    <form noValidate onSubmit={(e) => void submit(e)} className="flex flex-col gap-16">
      <div className="flex flex-wrap items-center justify-between gap-12">
        {back}
        {canChange && (
          <div className="flex gap-12">
            <Link to={id ? `/companies/${id}` : '/companies'} className="kn-btn inline-flex h-[44px] items-center rounded-lg px-16 text-latin-label-sm font-semibold text-text-secondary hover:bg-bg-subtle">
              {t('admin.us.cancel')}
            </Link>
            <button type="submit" disabled={busy} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-60">
              {busy ? <Spinner /> : <Check width={18} height={18} aria-hidden />}
              {editing ? t('admin.cf.save') : t('admin.cf.create')}
            </button>
          </div>
        )}
      </div>
      {banner && <ErrorBanner shake={tries}>{banner}</ErrorBanner>}
      {done && (
        <p role="status" className="kn-pop rounded-lg bg-status-success-bg px-16 py-12 text-latin-label-sm font-semibold text-status-success">
          {done}
        </p>
      )}

      <Section i={0} title={t('admin.cf.company')} sub={t('admin.cf.company_sub')}>
        <Field id="name" label={t('admin.cf.name')} error={errors.name}>
          <input id="name" value={f.name} onChange={(e) => set({ name: e.target.value })} maxLength={120} className={cls('name')} {...aria('name')} />
        </Field>
        <Field id="trade" label={t('admin.cf.industry')} error={errors.trade}>
          <select id="trade" value={f.trade} onChange={(e) => set({ trade: e.target.value })} className={cls('trade')} {...aria('trade')}>
            {config.trades.map((x) => (
              <option key={x.key} value={x.key}>
                {x.name}
              </option>
            ))}
          </select>
        </Field>
        <Field id="country" label={t('admin.cf.country')}>
          <select id="country" value={f.country} onChange={(e) => set({ country: e.target.value })} className={cls('country')}>
            {config.countries.map((x) => (
              <option key={x.code} value={x.code}>
                {x.name}
              </option>
            ))}
          </select>
        </Field>
        <Field id="lang" label={t('admin.cf.language')}>
          <select id="lang" value={f.report_language} onChange={(e) => set({ report_language: e.target.value as Lang })} className={cls('report_language')}>
            {LANGS.map((l) => (
              <option key={l} value={l}>
                {t(`lang.${l}`)}
              </option>
            ))}
          </select>
        </Field>
      </Section>

      <Section i={1} title={t('admin.cf.owner')} sub={t(editing ? 'admin.cf.owner_sub_edit' : 'admin.cf.owner_sub_create')}>
        {editing && company ? (
          <div className="sm:col-span-2">
            <p className="text-latin-body font-semibold">{company.owner_name ?? '—'}</p>
            <p className="text-[14px] text-text-secondary">{[company.owner_phone, company.owner_email].filter(Boolean).join(' · ')}</p>
            {company.owner_user_id && (
              <Link to={`/users/${company.owner_user_id}`} className="kn-link mt-8 inline-flex items-center gap-4 text-latin-label-sm font-semibold text-mocha-700">
                {t('admin.cf.open_user')}
                <ExternalLink width={14} height={14} aria-hidden />
              </Link>
            )}
          </div>
        ) : (
          <>
            <Field id="owner_name" label={t('admin.cf.owner_name')} error={errors.owner_name}>
              <input id="owner_name" value={f.owner_name} onChange={(e) => set({ owner_name: e.target.value })} maxLength={120} autoComplete="off" className={cls('owner_name')} {...aria('owner_name')} />
            </Field>
            <Field id="owner_phone" label={t('admin.cf.owner_phone')} error={errors.owner_phone}>
              <input id="owner_phone" type="tel" inputMode="tel" value={f.owner_phone} onChange={(e) => set({ owner_phone: e.target.value })} maxLength={24} placeholder={`${config.countries.find((x) => x.code === f.country)?.dial_code ?? '+91'} 98765 43210`} className={cls('owner_phone')} {...aria('owner_phone')} />
            </Field>
            <Field id="owner_email" label={t('admin.cf.owner_email')} error={errors.owner_email}>
              <input id="owner_email" type="email" value={f.owner_email} onChange={(e) => set({ owner_email: e.target.value })} maxLength={254} placeholder="name@company.com" autoComplete="off" className={cls('owner_email')} {...aria('owner_email')} />
            </Field>
          </>
        )}
      </Section>

      <Section i={2} title={t('admin.cf.plan')} sub={editing ? t('admin.cf.plan_sub_edit') : t('admin.cf.plan_sub_create', { n: plans?.trial_days ?? 14 })}>
        <Field id="plan" label={t('admin.cf.plan')} error={errors.plan}>
          <select id="plan" value={f.plan} onChange={(e) => set({ plan: e.target.value })} className={cls('plan')} {...aria('plan')}>
            {(plans?.plans ?? []).map((p) => (
              <option key={p.code} value={p.code}>
                {planLabel(p)}
              </option>
            ))}
          </select>
        </Field>
        {editing && company?.status === 'trial' && (
          <Field id="trial" label={t('admin.cf.trial_ends')} error={errors.trial_ends_at}>
            <input id="trial" type="date" value={f.trial_ends_at} min={new Date().toISOString().slice(0, 10)} onChange={(e) => set({ trial_ends_at: e.target.value })} className={cls('trial_ends_at')} {...aria('trial_ends_at')} />
          </Field>
        )}
      </Section>

      {editing && company && canChange && (
        company.status === 'suspended' ? (
          <section className="kn-in flex flex-col gap-12 rounded-xl border border-status-success bg-bg-surface p-20 sm:flex-row sm:items-center sm:justify-between sm:p-24">
            <div>
              <h2 className="text-[20px] font-semibold text-status-success">{t('admin.cf.reactivate_title')}</h2>
              <p className="mt-4 text-[13px] text-text-secondary">{t('admin.cf.suspended', { date: company.suspended_at ? day(company.suspended_at, lang) : '', reason: company.suspend_reason ?? '' })}</p>
            </div>
            <button type="button" onClick={() => setDialog('reactivate')} className="kn-btn inline-flex h-[44px] shrink-0 items-center gap-8 rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed">
              <Power width={16} height={16} aria-hidden />
              {t('admin.cf.reactivate')}
            </button>
          </section>
        ) : (
          <section className="kn-in flex flex-col gap-12 rounded-xl border border-status-danger bg-bg-surface p-20 sm:flex-row sm:items-center sm:justify-between sm:p-24" style={{ ['--d' as string]: '180ms' }}>
            <div>
              <h2 className="text-[20px] font-semibold text-status-danger">{t('admin.cf.suspend_title')}</h2>
              <p className="mt-4 max-w-[640px] text-[13px] text-text-secondary">{t('admin.cf.suspend_body')}</p>
            </div>
            <button type="button" onClick={() => setDialog('suspend')} className="kn-btn inline-flex h-[44px] shrink-0 items-center gap-8 rounded-lg bg-status-danger px-20 text-latin-label-sm font-semibold text-cream-50 hover:brightness-95">
              <PauseCircle width={16} height={16} aria-hidden />
              {t('admin.cf.suspend')}
            </button>
          </section>
        )
      )}
      {dialog && company && (
        <ReasonDialog
          t={t}
          title={t(dialog === 'suspend' ? 'admin.cf.confirm_suspend' : 'admin.cf.confirm_reactivate', { name: company.name })}
          body={t(dialog === 'suspend' ? 'admin.cf.suspend_body' : 'admin.cf.confirm_reactivate_body')}
          confirm={t(dialog === 'suspend' ? 'admin.cf.suspend' : 'admin.cf.reactivate')}
          danger={dialog === 'suspend'}
          onClose={() => setDialog(null)}
          onConfirm={(r) => act(dialog, r)}
        />
      )}
    </form>
  );
}
