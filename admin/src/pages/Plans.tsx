import { Check, ExternalLink, Pencil, Star } from 'lucide-react';
import { useCallback, useEffect, useRef, useState } from 'react';

import { api, ApiError } from '../lib/api';
import { money, num, type Lang, type T } from '../lib/i18n';
import type { AdminPlan, AdminPlansOut } from '../lib/types';
import { cx, ErrorBanner, inputCls, PageActions, Spinner, Switch } from '../ui';
import { Panel } from './Dashboard';

const LANGS = ['en', 'hi', 'gu', 'es', 'fr'] as const;
const LIMITS = ['technician_limit', 'report_limit_monthly', 'monthly_credits', 'ai_questions_monthly'] as const;
const TRIAL_DAYS = [7, 14, 21, 30];

type Draft = { name: Record<string, string>; prices: Record<string, string>; limits: Record<string, string>; most_popular: boolean; is_public: boolean };

const major = (minor: number) => (minor % 100 ? (minor / 100).toFixed(2) : String(minor / 100));

function draftOf(p: AdminPlan, currencies: string[]): Draft {
  return {
    name: Object.fromEntries(LANGS.map((l) => [l, p.name[l] ?? ''])),
    prices: Object.fromEntries(currencies.map((c) => [c, p.prices[c] !== undefined ? major(p.prices[c]) : ''])),
    limits: Object.fromEntries(LIMITS.map((k) => [k, p[k] === null ? '' : String(p[k])])),
    most_popular: p.most_popular,
    is_public: p.is_public,
  };
}

function bodyOf(d: Draft) {
  const filled = Object.values(d.prices).some((v) => v.trim() !== '');
  return {
    name: Object.fromEntries(Object.entries(d.name).filter(([, v]) => v.trim())),
    prices: filled ? Object.fromEntries(Object.entries(d.prices).map(([c, v]) => [c, Math.round(Number(v || 'x') * 100)])) : {},
    ...Object.fromEntries(LIMITS.map((k) => [k, d.limits[k].trim() === '' ? null : Number(d.limits[k])])),
    most_popular: d.most_popular,
    is_public: d.is_public,
  };
}

function errorText(t: T, e: unknown): string {
  const code = e instanceof ApiError ? e.code : '';
  if (['trial_plan', 'free_mismatch', 'bad_trial_plan'].includes(code)) return t(`admin.pl.err.${code}`);
  if (e instanceof ApiError && e.status === 422) return t('admin.pl.err.invalid');
  return t('admin.err.save');
}

function EditPlan({ t, lang, plan, currencies, onClose, onSaved }: { t: T; lang: Lang; plan: AdminPlan; currencies: string[]; onClose: () => void; onSaved: (d: AdminPlansOut) => void }) {
  const [d, setD] = useState<Draft>(() => draftOf(plan, currencies));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const first = useRef<HTMLInputElement>(null);
  useEffect(() => first.current?.focus(), []);
  useEffect(() => {
    const esc = (e: globalThis.KeyboardEvent) => e.key === 'Escape' && !busy && onClose();
    window.addEventListener('keydown', esc);
    return () => window.removeEventListener('keydown', esc);
  }, [busy, onClose]);

  const save = async () => {
    const filled = Object.values(d.prices).filter((v) => v.trim() !== '');
    if (!d.name.en.trim()) return setError(t('admin.pl.err.name'));
    if (filled.length && filled.length !== currencies.length) return setError(t('admin.pl.err.prices'));
    if (filled.some((v) => !(Number(v) >= 0))) return setError(t('admin.pl.err.invalid'));
    if (LIMITS.some((k) => d.limits[k].trim() !== '' && !(Number.isInteger(Number(d.limits[k])) && Number(d.limits[k]) >= 0))) return setError(t('admin.pl.err.invalid'));
    setBusy(true);
    setError(null);
    try {
      onSaved(await api<AdminPlansOut>(`/admin/plans/${plan.code}`, { method: 'PUT', body: bodyOf(d) }));
    } catch (e) {
      setError(errorText(t, e));
      setBusy(false);
    }
  };
  const label = 'block text-latin-label-sm font-semibold';
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center p-16 sm:items-center">
      <button type="button" aria-hidden tabIndex={-1} onClick={() => !busy && onClose()} className="absolute inset-0 cursor-default bg-espresso-950/50" />
      <div role="dialog" aria-modal="true" aria-labelledby="plan-title" className="kn-pop relative flex max-h-[90vh] w-full max-w-[640px] flex-col overflow-hidden rounded-xl bg-bg-surface shadow-lg">
        <div className="overflow-y-auto p-24">
          <h2 id="plan-title" className="text-[22px] font-bold leading-[30px]">{t('admin.pl.edit_title', { plan: plan.name[lang] || plan.name.en })}</h2>
          <p className="mt-8 text-latin-body text-text-secondary">{t('admin.pl.edit_body')}</p>

          <fieldset className="mt-20">
            <legend className={label}>{t('admin.pl.f_name')}</legend>
            <div className="mt-8 grid gap-8 sm:grid-cols-2">
              {LANGS.map((l, i) => (
                <label key={l} className="block">
                  <span className="text-[13px] text-text-secondary">{t(`lang.${l}`)}</span>
                  <input ref={i === 0 ? first : undefined} value={d.name[l]} maxLength={40} onChange={(e) => setD({ ...d, name: { ...d.name, [l]: e.target.value } })} className={cx(inputCls, 'mt-4')} />
                </label>
              ))}
            </div>
          </fieldset>

          <fieldset className="mt-20">
            <legend className={label}>{t('admin.pl.f_price')}</legend>
            <p className="text-[13px] text-text-secondary">{t('admin.pl.f_price_hint')}</p>
            <div className="mt-8 grid gap-8 sm:grid-cols-2">
              {currencies.map((c) => (
                <label key={c} className="block">
                  <span className="text-[13px] text-text-secondary">{c}</span>
                  <input inputMode="decimal" value={d.prices[c]} onChange={(e) => setD({ ...d, prices: { ...d.prices, [c]: e.target.value.replace(/[^\d.]/g, '') } })} className={cx(inputCls, 'mt-4 tabular-nums')} />
                </label>
              ))}
            </div>
          </fieldset>

          <fieldset className="mt-20">
            <legend className={label}>{t('admin.pl.f_limits')}</legend>
            <p className="text-[13px] text-text-secondary">{t('admin.pl.f_limits_hint')}</p>
            <div className="mt-8 grid gap-8 sm:grid-cols-2">
              {LIMITS.map((k) => (
                <label key={k} className="block">
                  <span className="text-[13px] text-text-secondary">{t(`admin.pl.lim.${k}`)}</span>
                  <input inputMode="numeric" value={d.limits[k]} placeholder={t('admin.pl.no_limit')} onChange={(e) => setD({ ...d, limits: { ...d.limits, [k]: e.target.value.replace(/\D/g, '') } })} className={cx(inputCls, 'mt-4 tabular-nums')} />
                </label>
              ))}
            </div>
          </fieldset>

          <div className="mt-20 flex flex-col gap-8">
            <Switch label={t('admin.pl.f_popular')} hint={t('admin.pl.f_popular_hint')} checked={d.most_popular} onChange={(v) => setD({ ...d, most_popular: v })} />
            <Switch label={t('admin.pl.f_public')} hint={t('admin.pl.f_public_hint')} checked={d.is_public} onChange={(v) => setD({ ...d, is_public: v })} />
          </div>
          {error && <div className="mt-12"><ErrorBanner>{error}</ErrorBanner></div>}
        </div>
        <div className="flex flex-col-reverse gap-12 border-t border-border-default p-16 sm:flex-row sm:justify-end">
          <button type="button" onClick={onClose} disabled={busy} className="kn-btn inline-flex h-[44px] items-center justify-center rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold hover:bg-cream-300">{t('admin.us.cancel')}</button>
          <button type="button" onClick={() => void save()} disabled={busy} className="kn-btn inline-flex h-[44px] items-center justify-center gap-8 rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-60">
            {busy ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
            {t('admin.pl.save')}
          </button>
        </div>
      </div>
    </div>
  );
}

function PlanCard({ t, lang, p, can, i, onEdit, onToggle }: { t: T; lang: Lang; p: AdminPlan; can: boolean; i: number; onEdit: () => void; onToggle: (on: boolean) => void }) {
  const inr = p.prices.INR;
  const price = inr === undefined ? t('admin.pl.custom') : t('admin.pl.month', { price: money(inr, 'INR', lang) });
  const usd = p.prices.USD !== undefined ? money(p.prices.USD, 'USD', lang) : null;
  const lim = (n: number | null, key: string, none: string) => (n === null ? t(none) : t(key, { n: num(n, lang) }));
  const lines = [
    lim(p.technician_limit, 'admin.pl.l.techs', 'admin.pl.l.techs_any'),
    lim(p.report_limit_monthly, 'admin.pl.l.reports', 'admin.pl.l.fair'),
    lim(p.ai_questions_monthly, 'admin.pl.l.ai', 'admin.pl.l.ai_any'),
  ];
  return (
    <div className="kn-in" style={{ ['--d' as string]: `${i * 60}ms` }}>
      <div className={cx('kn-hover flex h-full flex-col rounded-xl bg-bg-surface p-20', p.most_popular ? 'border-2 border-espresso-950' : 'border border-border-default', !p.is_public && 'opacity-80')}>
        <h3 className="text-[20px] font-semibold">{p.name[lang] || p.name.en}</h3>
        {p.most_popular && <span className="mt-4 w-fit rounded-full bg-bg-subtle px-[10px] py-[3px] text-[12px] font-semibold text-mocha-700">{t('admin.pl.popular')}</span>}
        <p className="mt-8 whitespace-nowrap text-[22px] font-bold leading-[30px]">{price}</p>
        {usd && <p className="text-[13px] text-text-secondary">{t('admin.pl.month', { price: usd })}</p>}
        <ul className="mt-12 flex flex-1 flex-col gap-4 text-[14px]">
          {lines.map((l) => <li key={l} className="flex items-start gap-8"><Check width={14} height={14} aria-hidden className="mt-[3px] shrink-0 text-status-success" />{l}</li>)}
          <li className="flex items-start gap-8"><Star width={14} height={14} aria-hidden className="mt-[3px] shrink-0 text-status-warning" />{lim(p.monthly_credits, 'admin.pl.l.credits', 'admin.pl.l.credits_any')}</li>
        </ul>
        <p className="mt-12 text-[13px] text-text-secondary">{t('admin.pl.companies', { n: num(p.companies, lang), trials: num(p.trials, lang) })}</p>
        <div className="mt-8 border-t border-border-default pt-8">
          <Switch label={t('admin.pl.on_site')} checked={p.is_public} disabled={!can} onChange={onToggle} />
        </div>
        {can && (
          <button type="button" onClick={onEdit} className="kn-btn mt-8 inline-flex h-[44px] items-center justify-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300">
            <Pencil width={16} height={16} aria-hidden />
            {t('admin.pl.edit')}
          </button>
        )}
      </div>
    </div>
  );
}

/** A17 Plans and pricing: the plans, top-up packs and free trial. Changes are live at once (no payments yet). */
export function Plans({ t, lang }: { t: T; lang: Lang }) {
  const [data, setData] = useState<AdminPlansOut | null>(null);
  const [error, setError] = useState(false);
  const [editing, setEditing] = useState<AdminPlan | null>(null);
  const [notice, setNotice] = useState<{ ok: boolean; text: string } | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  const load = useCallback(() => {
    setError(false);
    api<AdminPlansOut>('/admin/plans').then(setData).catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, []);
  useEffect(load, [load]);
  useEffect(() => {
    if (!notice) return;
    const tm = window.setTimeout(() => setNotice(null), 4000);
    return () => window.clearTimeout(tm);
  }, [notice]);

  const run = async (key: string, fn: () => Promise<AdminPlansOut>) => {
    setBusy(key);
    try {
      setData(await fn());
      setNotice({ ok: true, text: t('admin.pl.saved') });
    } catch (e) {
      setNotice({ ok: false, text: errorText(t, e) });
    } finally {
      setBusy(null);
    }
  };

  if (error && !data)
    return (
      <div className="kn-in mx-auto mt-48 max-w-[480px] rounded-xl border border-border-default bg-bg-surface p-24 text-center">
        <p className="text-latin-body text-text-secondary">{t('admin.err.load')}</p>
        <button type="button" onClick={load} className="kn-btn mt-16 inline-flex h-[44px] items-center rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action">{t('admin.retry')}</button>
      </div>
    );
  if (!data)
    return (
      <div aria-busy="true" className="grid gap-16 sm:grid-cols-2 xl:grid-cols-5">
        {[0, 1, 2, 3, 4].map((i) => <div key={i} className="kn-shimmer h-[380px] rounded-xl bg-bg-surface" />)}
      </div>
    );

  const can = data.can_act;
  const paid = data.plans.filter((p) => p.is_public && Object.values(p.prices).some((v) => v > 0));
  const toggle = (p: AdminPlan, on: boolean) =>
    run(p.code, () => api<AdminPlansOut>(`/admin/plans/${p.code}`, { method: 'PUT', body: bodyOf({ ...draftOf(p, data.currencies), is_public: on }) }));

  return (
    <div className="flex flex-col gap-16">
      <PageActions>
        <a href={data.pricing_url} target="_blank" rel="noreferrer" className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300">
          <ExternalLink width={16} height={16} aria-hidden />
          {t('admin.pl.preview')}
        </a>
      </PageActions>
      <p className="kn-in rounded-xl bg-bg-subtle px-16 py-12 text-[14px] font-semibold text-mocha-700">{t(can ? 'admin.pl.banner' : 'admin.pl.banner_view')}</p>
      {notice && (
        <p role="status" className={cx('kn-pop rounded-lg px-16 py-12 text-latin-label-sm font-semibold', notice.ok ? 'bg-status-success-bg text-status-success' : 'bg-status-danger-bg text-status-danger')}>{notice.text}</p>
      )}
      <div className="grid gap-16 sm:grid-cols-2 xl:grid-cols-5">
        {data.plans.map((p, i) => <PlanCard key={p.code} t={t} lang={lang} p={p} can={can && busy !== p.code} i={i} onEdit={() => setEditing(p)} onToggle={(on) => void toggle(p, on)} />)}
      </div>

      <Panel i={2} title={t('admin.pl.trial')} sub={t('admin.pl.trial_sub')}>
        <div className="mt-16 grid gap-12 sm:grid-cols-3">
          <label className="block">
            <span className="block text-latin-label-sm font-semibold">{t('admin.pl.trial_plan')}</span>
            <select disabled={!can || !!busy} value={data.trial.plan_code} onChange={(e) => void run('trial', () => api<AdminPlansOut>('/admin/trial', { method: 'PUT', body: { ...data.trial, plan_code: e.target.value } }))} className={cx(inputCls, 'mt-8')}>
              {paid.map((p) => <option key={p.code} value={p.code}>{p.name[lang] || p.name.en}</option>)}
            </select>
          </label>
          <label className="block">
            <span className="block text-latin-label-sm font-semibold">{t('admin.pl.trial_days')}</span>
            <select disabled={!can || !!busy} value={data.trial.days} onChange={(e) => void run('trial', () => api<AdminPlansOut>('/admin/trial', { method: 'PUT', body: { ...data.trial, days: Number(e.target.value) } }))} className={cx(inputCls, 'mt-8')}>
              {[...new Set([...TRIAL_DAYS, data.trial.days])].sort((a, b) => a - b).map((n) => <option key={n} value={n}>{t('admin.pl.days', { n })}</option>)}
            </select>
          </label>
          <label className="block">
            <span className="block text-latin-label-sm font-semibold">{t('admin.pl.card')}</span>
            <select disabled value="no" className={cx(inputCls, 'mt-8')}>
              <option value="no">{t('admin.pl.card_no')}</option>
            </select>
            <span className="mt-4 block text-[13px] text-text-secondary">{t('admin.pl.card_hint')}</span>
          </label>
        </div>
      </Panel>

      <Panel i={3} title={t('admin.pl.packs')} sub={t('admin.pl.packs_sub')}>
        <ul className="mt-12 divide-y divide-border-default">
          {data.packs.map((k) => (
            <PackRow key={k.id} t={t} lang={lang} pack={k} can={can && !busy} onSave={(prices, active) => run(k.id, () => api<AdminPlansOut>(`/admin/credit-packs/${k.id}`, { method: 'PUT', body: { prices, active } }))} />
          ))}
        </ul>
      </Panel>

      {editing && <EditPlan t={t} lang={lang} plan={editing} currencies={data.currencies} onClose={() => setEditing(null)} onSaved={(d) => { setData(d); setEditing(null); setNotice({ ok: true, text: t('admin.pl.saved') }); }} />}
    </div>
  );
}

function PackRow({ t, lang, pack, can, onSave }: { t: T; lang: Lang; pack: AdminPlansOut['packs'][number]; can: boolean; onSave: (prices: Record<string, number>, active: boolean) => Promise<void> }) {
  const [p, setP] = useState(() => Object.fromEntries(Object.entries(pack.prices).map(([c, v]) => [c, major(v)])));
  useEffect(() => setP(Object.fromEntries(Object.entries(pack.prices).map(([c, v]) => [c, major(v)]))), [pack.prices]);
  const changed = Object.entries(p).some(([c, v]) => Math.round(Number(v) * 100) !== pack.prices[c]);
  const valid = Object.values(p).every((v) => Number(v) > 0);
  const minor = () => Object.fromEntries(Object.entries(p).map(([c, v]) => [c, Math.round(Number(v) * 100)]));
  return (
    <li className="flex flex-wrap items-center gap-12 py-12">
      <p className="min-w-[140px] flex-1 text-[15px] font-semibold">{t('admin.pl.pack', { n: num(pack.credits, lang) })}</p>
      {Object.keys(p).map((c) => (
        <label key={c} className="flex items-center gap-8 text-[13px] text-text-secondary">
          {c}
          <input disabled={!can} inputMode="decimal" value={p[c]} onChange={(e) => setP({ ...p, [c]: e.target.value.replace(/[^\d.]/g, '') })} className={cx(inputCls, 'h-[40px] w-[110px] tabular-nums')} aria-label={t('admin.pl.pack_price', { n: pack.credits, c })} />
        </label>
      ))}
      {can && changed && (
        <button type="button" disabled={!valid} onClick={() => void onSave(minor(), pack.active)} className="kn-btn inline-flex h-[40px] items-center rounded-lg bg-action-primary px-16 text-[13px] font-semibold text-text-on-action disabled:opacity-50">{t('admin.pl.save')}</button>
      )}
      <div className="w-[200px]">
        <Switch label={t('admin.pl.pack_on')} checked={pack.active} disabled={!can} onChange={(on) => void onSave(minor(), on)} />
      </div>
    </li>
  );
}
