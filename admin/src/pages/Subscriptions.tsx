import { AlertTriangle, ChevronLeft, ChevronRight, Download, Hourglass, IndianRupee, Search, Users, X } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';

import { api, ApiError, download } from '../lib/api';
import { day, money, num, type Lang, type T } from '../lib/i18n';
import type { AdminSubList, AdminSubRow } from '../lib/types';
import { cx, FilterSelect, Link, navigate, Spinner } from '../ui';
import { pages } from './Companies';
import { StatCard } from './Dashboard';

const PAGE_SIZE = 25;
const STATUSES = ['trial', 'active', 'past_due', 'suspended', 'cancelled'] as const;
const PLANS = ['free', 'starter', 'professional', 'business', 'enterprise'] as const;

type Filters = { q: string; status: string; plan: string; page: number };

function readFilters(): Filters {
  const s = new URLSearchParams(window.location.search);
  const pick = (k: string, ok: readonly string[]) => (ok.includes(s.get(k) ?? '') ? (s.get(k) as string) : '');
  return { q: s.get('q') ?? '', status: pick('status', STATUSES), plan: pick('plan', PLANS), page: Math.max(1, Number(s.get('page')) || 1) };
}

function query(f: Filters, withPage = true): string {
  const p = new URLSearchParams();
  if (f.q.trim()) p.set('q', f.q.trim());
  if (f.status) p.set('status', f.status);
  if (f.plan) p.set('plan', f.plan);
  if (withPage && f.page > 1) p.set('page', String(f.page));
  return p.toString();
}

const pill = 'inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold';
const tone: Record<AdminSubRow['badge'], string> = {
  trial: 'bg-bg-subtle text-mocha-700',
  active: 'bg-status-success-bg text-status-success',
  past_due: 'bg-status-danger-bg text-status-danger',
  suspended: 'bg-status-danger-bg text-status-danger',
  cancelled: 'bg-cream-200 text-taupe-550',
  near_limit: 'bg-status-warning-bg text-status-warning',
};

/** The top-bar Export button: every subscription matching the filters, as a CSV. */
export function ExportSubscriptions({ t, lang }: { t: T; lang: Lang }) {
  const [busy, setBusy] = useState(false);
  return (
    <button
      type="button"
      disabled={busy}
      onClick={async () => {
        setBusy(true);
        try {
          const q = query(readFilters(), false);
          await download(`/admin/subscriptions.csv?locale=${lang}${q ? `&${q}` : ''}`, 'kaamnishaan-subscriptions.csv');
        } finally {
          setBusy(false);
        }
      }}
      className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-60"
    >
      {busy ? <Spinner /> : <Download width={16} height={16} aria-hidden />}
      {t('admin.rv.export')}
    </button>
  );
}

/** A16 Subscriptions: every company's plan, price, status and renewal. No payments are taken yet. */
export function Subscriptions({ t, lang }: { t: T; lang: Lang }) {
  const [f, setF] = useState<Filters>(readFilters);
  const [typed, setTyped] = useState(f.q);
  const [data, setData] = useState<AdminSubList | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const seq = useRef(0);

  useEffect(() => {
    const q = query(f);
    window.history.replaceState(null, '', `/subscriptions${q ? `?${q}` : ''}`);
    const n = ++seq.current;
    setLoading(true);
    setError(false);
    api<AdminSubList>(`/admin/subscriptions?locale=${lang}&page_size=${PAGE_SIZE}${q ? `&${q}` : ''}`)
      .then((d) => n === seq.current && setData(d))
      .catch((e) => n === seq.current && !(e instanceof ApiError && e.status === 401) && setError(true))
      .finally(() => n === seq.current && setLoading(false));
  }, [f, lang]);
  useEffect(() => {
    if (typed === f.q) return;
    const tm = window.setTimeout(() => setF((x) => ({ ...x, q: typed, page: 1 })), 300);
    return () => window.clearTimeout(tm);
  }, [typed, f.q]);

  const set = (patch: Partial<Filters>) => setF((x) => ({ ...x, ...patch, page: 1 }));
  const last = data ? Math.max(1, Math.ceil(data.total / data.page_size)) : 1;
  const k = data?.kpis;
  const mrr = k ? (k.mrr.length ? k.mrr.map((m) => money(m.amount_minor, m.currency, lang)).join(' + ') : money(0, 'INR', lang)) : '';

  return (
    <div className="flex flex-col gap-16">
      {!k ? (
        <div aria-busy="true" className="grid gap-16 sm:grid-cols-2 xl:grid-cols-4">
          {[0, 1, 2, 3].map((i) => <div key={i} className="kn-shimmer h-[150px] rounded-xl bg-bg-surface" />)}
        </div>
      ) : (
        <div className="grid gap-16 sm:grid-cols-2 xl:grid-cols-4">
          <StatCard i={0} icon={IndianRupee} label={t('admin.sb.mrr')} value={mrr} trend={{ text: t('admin.sb.mrr_note'), tone: 'flat' }} />
          <StatCard i={1} icon={Users} label={t('admin.sb.paying')} value={num(k.paying, lang)} trend={{ text: t('admin.sb.on_free', { n: num(k.on_free, lang) }), tone: 'flat' }} />
          <StatCard i={2} icon={Hourglass} label={t('admin.sb.trials')} value={num(k.trials, lang)} trend={{ text: t('admin.sb.trials_end', { n: num(k.trials_ending_7d, lang) }), tone: k.trials_ending_7d ? 'bad' : 'flat' }} />
          <StatCard i={3} icon={AlertTriangle} label={t('admin.sb.churn')} value={num(k.cancelled_30d, lang)} trend={{ text: t('admin.sb.past_due', { n: num(k.past_due, lang) }), tone: k.past_due ? 'bad' : 'flat' }} />
        </div>
      )}

      <div className="kn-in flex flex-wrap items-center gap-12">
        <label className="relative min-w-[240px] flex-1">
          <span className="sr-only">{t('admin.sb.search')}</span>
          <Search width={18} height={18} className="pointer-events-none absolute left-12 top-1/2 -translate-y-1/2 text-text-secondary" aria-hidden />
          <input type="search" value={typed} onChange={(e) => setTyped(e.target.value)} placeholder={t('admin.sb.search')} className="h-[44px] w-full rounded-lg border border-border-strong bg-bg-surface pl-[40px] pr-12 text-latin-label-sm placeholder:text-taupe-500 hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring" />
        </label>
        <FilterSelect label={t('admin.rv.f_status')} value={f.status} allLabel={t('admin.co.f_all')} options={STATUSES.map((s) => ({ value: s, label: t(`admin.co.st.${s}`) }))} onChange={(v) => set({ status: v })} />
        <FilterSelect label={t('admin.sb.f_plan')} value={f.plan} allLabel={t('admin.co.f_all')} options={PLANS.map((p) => ({ value: p, label: t(`admin.sb.plan.${p}`) }))} onChange={(v) => set({ plan: v })} />
      </div>

      {error && (
        <p role="alert" className="rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">
          {t('admin.err.load')}{' '}
          <button type="button" className="underline" onClick={() => setF({ ...f })}>{t('admin.retry')}</button>
        </p>
      )}

      {!data ? (
        <div aria-busy="true" className="kn-shimmer h-[320px] rounded-xl bg-bg-surface" />
      ) : data.total === 0 ? (
        <div className="kn-in flex flex-col items-center rounded-xl border border-border-default bg-bg-surface px-24 py-48 text-center">
          <span className="kn-pop inline-flex h-[88px] w-[88px] items-center justify-center rounded-full bg-bg-subtle text-mocha-700"><Search width={32} height={32} aria-hidden /></span>
          <h2 className="mt-16 text-[24px] font-bold">{t('admin.sb.empty_title')}</h2>
          <button type="button" onClick={() => { setTyped(''); setF({ q: '', status: '', plan: '', page: 1 }); }} className="kn-btn mt-20 inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold hover:bg-cream-300">
            <X width={16} height={16} aria-hidden />
            {t('admin.co.clear')}
          </button>
        </div>
      ) : (
        <div className={cx('kn-in overflow-hidden rounded-xl border border-border-default bg-bg-surface transition-opacity', loading && 'opacity-60')} style={{ ['--d' as string]: '200ms' }} aria-busy={loading}>
          <div className="overflow-x-auto">
            <table className="w-full min-w-[880px] text-left">
              <thead className="bg-bg-subtle text-[13px] text-text-secondary">
                <tr>
                  {(['c_company', 'c_plan', 'c_price', 'c_status', 'c_renews', 'c_seats'] as const).map((c, i) => (
                    <th key={c} scope="col" className={cx('px-16 py-12 font-semibold', i === 0 && 'pl-20')}>{t(`admin.sb.${c}`)}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-border-default text-[14px]">
                {data.items.map((r, i) => (
                  <tr key={r.id} onClick={() => navigate(`/companies/${r.id}`)} className="kn-in group cursor-pointer transition-colors hover:bg-cream-100" style={{ ['--d' as string]: `${200 + Math.min(i * 30, 400)}ms` }}>
                    <td className="max-w-[260px] truncate py-12 pl-20 pr-16">
                      <Link to={`/companies/${r.id}`} className="font-semibold text-text-primary group-hover:underline">{r.name}</Link>
                    </td>
                    <td className="px-16 py-12">{r.status === 'trial' ? t('admin.sb.plan_trial', { plan: r.plan }) : r.plan}</td>
                    <td className="whitespace-nowrap px-16 py-12 tabular-nums">{r.status === 'trial' ? money(0, r.price?.currency ?? 'INR', lang) : r.price ? t('admin.sb.per_month', { price: money(r.price.amount_minor, r.price.currency, lang) }) : t('admin.pl.custom')}</td>
                    <td className="px-16 py-12">
                      <span className={cx(pill, tone[r.badge])}>{r.badge === 'trial' && r.trial_days_left !== null ? t('admin.sb.trial_days', { n: num(r.trial_days_left, lang) }) : t(`admin.co.st.${r.badge}`)}</span>
                    </td>
                    <td className="whitespace-nowrap px-16 py-12">{r.renews_at ? day(r.renews_at, lang, { year: undefined }) : <span className="text-text-secondary">—</span>}</td>
                    <td className="whitespace-nowrap px-16 py-12 tabular-nums">{r.seat_limit === null ? num(r.seats, lang) : `${num(r.seats, lang)} / ${num(r.seat_limit, lang)}`}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="flex flex-wrap items-center justify-between gap-12 border-t border-border-default px-20 py-12">
            <p className="text-[13px] text-text-secondary">
              {t('admin.co.showing', { from: num((data.page - 1) * data.page_size + 1, lang), to: num(Math.min(data.page * data.page_size, data.total), lang), total: num(data.total, lang) })}
            </p>
            {last > 1 && (
              <nav aria-label={t('admin.nav.subscriptions')} className="flex items-center gap-4">
                <button type="button" disabled={f.page <= 1} onClick={() => setF({ ...f, page: f.page - 1 })} aria-label={t('admin.co.prev')} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md border border-border-default hover:border-mocha-500 disabled:opacity-40"><ChevronLeft width={16} height={16} aria-hidden /></button>
                {pages(f.page, last).map((p, i) =>
                  p === '…' ? <span key={`gap-${i}`} className="px-4 text-text-secondary">…</span> : (
                    <button key={p} type="button" onClick={() => setF({ ...f, page: p })} aria-label={t('admin.co.page', { n: p })} aria-current={p === f.page ? 'page' : undefined} className={cx('inline-flex h-[32px] min-w-[32px] items-center justify-center rounded-md px-8 text-[13px] font-semibold', p === f.page ? 'bg-espresso-950 text-cream-50' : 'border border-border-default hover:border-mocha-500')}>{num(p, lang)}</button>
                  ),
                )}
                <button type="button" disabled={f.page >= last} onClick={() => setF({ ...f, page: f.page + 1 })} aria-label={t('admin.co.next')} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md border border-border-default hover:border-mocha-500 disabled:opacity-40"><ChevronRight width={16} height={16} aria-hidden /></button>
              </nav>
            )}
          </div>
        </div>
      )}
      <p className="text-[13px] text-text-secondary">{t('admin.sb.note')}</p>
    </div>
  );
}
