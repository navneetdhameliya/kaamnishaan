import { ArrowDown, ChevronLeft, ChevronRight, Download, Plus, Search, X } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';

import { api, ApiError, download } from '../lib/api';
import { num, region, type Lang, type T } from '../lib/i18n';
import { session } from '../lib/session';
import type { CompanyList, CompanyStatus } from '../lib/types';
import { cx, FilterSelect, Initials, Link, navigate, Spinner } from '../ui';
import { StatusBadge } from './badges';

const STATUSES: CompanyStatus[] = ['active', 'trial', 'past_due', 'suspended', 'cancelled'];
const SORTS = ['reports', 'name', 'technicians', 'newest'] as const;
type Sort = (typeof SORTS)[number];
const PAGE_SIZE = 20;
const AVATARS = ['bg-mocha-500', 'bg-sage-500', 'bg-mocha-700', 'bg-mocha-300', 'bg-taupe-500', 'bg-mocha-650'];
const shade = (id: string) => AVATARS[parseInt(id.replace(/-/g, '').slice(-4), 16) % AVATARS.length];

type Filters = { q: string; status: string; plan: string; industry: string; country: string; sort: Sort; page: number };

function readFilters(): Filters {
  const s = new URLSearchParams(window.location.search);
  const sort = s.get('sort') as Sort;
  return {
    q: s.get('q') ?? '',
    status: s.get('status') ?? '',
    plan: s.get('plan') ?? '',
    industry: s.get('industry') ?? '',
    country: s.get('country') ?? '',
    sort: SORTS.includes(sort) ? sort : 'reports',
    page: Math.max(1, Number(s.get('page')) || 1),
  };
}

function query(f: Filters, lang: Lang, withPage = true): string {
  const p = new URLSearchParams();
  (['q', 'status', 'plan', 'industry', 'country'] as const).forEach((k) => f[k].trim() && p.set(k, f[k].trim()));
  if (f.sort !== 'reports') p.set('sort', f.sort);
  if (withPage && f.page > 1) p.set('page', String(f.page));
  p.set('locale', lang);
  return p.toString();
}

/** 1 … 4 5 6 … 12 */
export function pages(current: number, last: number): (number | '…')[] {
  const keep = new Set([1, last, current - 1, current, current + 1].filter((n) => n >= 1 && n <= last));
  const out: (number | '…')[] = [];
  [...keep].sort((a, b) => a - b).forEach((n, i, arr) => {
    if (i && n - arr[i - 1] > 1) out.push('…');
    out.push(n);
  });
  return out;
}

/** A04 Companies: status tabs, search, filters, sortable table, pages and CSV export. */
export function Companies({ t, lang }: { t: T; lang: Lang }) {
  const [f, setF] = useState<Filters>(readFilters);
  const [typed, setTyped] = useState(f.q);
  const [data, setData] = useState<CompanyList | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [exporting, setExporting] = useState(false);
  const seq = useRef(0);

  // the filters live in the address, so a link or the back button gives the same list
  useEffect(() => {
    const qs = query(f, lang).replace(/(^|&)locale=[^&]*/, '').replace(/^&/, '');
    window.history.replaceState(null, '', `/companies${qs ? `?${qs}` : ''}`);
    const n = ++seq.current;
    setLoading(true);
    setError(false);
    api<CompanyList>(`/admin/companies?${query(f, lang)}&page_size=${PAGE_SIZE}`)
      .then((d) => n === seq.current && setData(d))
      .catch((e) => n === seq.current && !(e instanceof ApiError && e.status === 401) && setError(true))
      .finally(() => n === seq.current && setLoading(false));
  }, [f, lang]);

  // search as you type, after a short pause
  useEffect(() => {
    if (typed === f.q) return;
    const id = window.setTimeout(() => setF((x) => ({ ...x, q: typed, page: 1 })), 300);
    return () => window.clearTimeout(id);
  }, [typed, f.q]);

  const set = (patch: Partial<Filters>) => setF((x) => ({ ...x, page: 1, ...patch }));
  const clear = () => {
    setTyped('');
    setF({ q: '', status: '', plan: '', industry: '', country: '', sort: f.sort, page: 1 });
  };
  const filtered = !!(f.q || f.plan || f.industry || f.country || f.status);
  const last = data ? Math.max(1, Math.ceil(data.total / data.page_size)) : 1;

  const exportCsv = async () => {
    setExporting(true);
    try {
      await download(`/admin/companies.csv?${query(f, lang, false)}`, 'kaamnishaan-companies.csv');
    } catch {
      setError(true);
    } finally {
      setExporting(false);
    }
  };

  const SortHead = ({ col, label, className }: { col: Sort; label: string; className?: string }) => (
    <th scope="col" className={cx('px-16 py-12 font-semibold', className)} aria-sort={f.sort === col ? 'descending' : undefined}>
      <button type="button" onClick={() => set({ sort: col })} className={cx('group inline-flex items-center gap-4 hover:text-text-primary', f.sort === col && 'text-text-primary')} title={t('admin.co.sort_by', { col: label })}>
        {label}
        <ArrowDown width={14} height={14} className={cx('transition-opacity', f.sort === col ? 'opacity-100' : 'opacity-0 group-hover:opacity-50')} aria-hidden />
      </button>
    </th>
  );

  return (
    <div className="flex flex-col gap-16">
      {/* status tabs */}
      <div role="tablist" aria-label={t('admin.co.tabs')} className="kn-in -mx-4 flex gap-8 overflow-x-auto px-4 pb-4">
        {(['', ...STATUSES] as const).map((s) => {
          const n = data ? (s ? data.counts[s] : data.counts.all) : null;
          if (s && s !== 'active' && s !== 'trial' && n === 0 && f.status !== s) return null;
          const on = f.status === s;
          return (
            <button
              key={s || 'all'}
              role="tab"
              aria-selected={on}
              type="button"
              onClick={() => set({ status: s })}
              className={cx(
                'kn-btn h-[36px] shrink-0 rounded-full border px-16 text-latin-label-sm font-semibold transition-colors',
                on ? 'border-espresso-950 bg-espresso-950 text-cream-50' : 'border-border-default bg-bg-surface hover:border-mocha-500',
              )}
            >
              {s ? t(`admin.co.st.${s}`) : t('admin.co.tab_all')}
              {n !== null && <span className={cx('ml-[6px] tabular-nums', on ? 'text-cream-300' : 'text-text-secondary')}>{num(n, lang)}</span>}
            </button>
          );
        })}
      </div>

      {/* search and filters */}
      <div className="kn-in flex flex-wrap items-center gap-12" style={{ ['--d' as string]: '60ms' }}>
        <label className="relative min-w-[240px] flex-1">
          <span className="sr-only">{t('admin.co.search')}</span>
          <Search width={18} height={18} className="pointer-events-none absolute left-12 top-1/2 -translate-y-1/2 text-text-secondary" aria-hidden />
          <input
            type="search"
            value={typed}
            onChange={(e) => setTyped(e.target.value)}
            placeholder={t('admin.co.search')}
            className="h-[44px] w-full rounded-lg border border-border-strong bg-bg-surface pl-[40px] pr-12 text-latin-label-sm placeholder:text-taupe-500 hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring"
          />
        </label>
        <FilterSelect label={t('admin.co.f_plan')} value={f.plan} allLabel={t('admin.co.f_all')} options={data?.plans ?? []} onChange={(v) => set({ plan: v })} />
        <FilterSelect label={t('admin.co.f_industry')} value={f.industry} allLabel={t('admin.co.f_all')} options={data?.industries ?? []} onChange={(v) => set({ industry: v })} />
        <FilterSelect label={t('admin.co.f_country')} value={f.country} allLabel={t('admin.co.f_all')} options={(data?.countries ?? []).map((c) => ({ value: c, label: region(c, lang) }))} onChange={(v) => set({ country: v })} />
        {session.get()?.staff.role !== 'support' && (
          <Link to="/companies/new" className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed">
            <Plus width={18} height={18} aria-hidden />
            {t('admin.cf.create')}
          </Link>
        )}
        <button
          type="button"
          onClick={() => void exportCsv()}
          disabled={exporting || !data?.total}
          className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg border border-border-default bg-bg-surface px-16 text-latin-label-sm font-semibold hover:border-mocha-500 disabled:opacity-50"
        >
          {exporting ? <Spinner /> : <Download width={16} height={16} aria-hidden />}
          {t('admin.co.export')}
        </button>
      </div>

      {error && (
        <p role="alert" className="rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">
          {t('admin.err.load')}{' '}
          <button type="button" className="underline" onClick={() => setF({ ...f })}>
            {t('admin.retry')}
          </button>
        </p>
      )}

      {!data ? (
        <div aria-busy="true" className="kn-shimmer h-[480px] rounded-xl bg-bg-surface" />
      ) : data.total === 0 ? (
        <div className="kn-in flex flex-col items-center rounded-xl border border-border-default bg-bg-surface px-24 py-48 text-center">
          <span className="kn-pop inline-flex h-[88px] w-[88px] items-center justify-center rounded-full bg-bg-subtle text-mocha-700">
            <Search width={32} height={32} aria-hidden />
          </span>
          <h2 className="mt-16 text-[24px] font-bold">{filtered ? t('admin.co.empty_title') : t('admin.nav.companies')}</h2>
          <p className="mt-8 max-w-[420px] text-latin-body text-text-secondary">{filtered ? t('admin.co.empty_body') : t('admin.co.none_yet')}</p>
          {filtered && (
            <button type="button" onClick={clear} className="kn-btn mt-20 inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold hover:bg-cream-300">
              <X width={16} height={16} aria-hidden />
              {t('admin.co.clear')}
            </button>
          )}
        </div>
      ) : (
        <div className={cx('kn-in overflow-hidden rounded-xl border border-border-default bg-bg-surface transition-opacity', loading && 'opacity-60')} style={{ ['--d' as string]: '120ms' }} aria-busy={loading}>
          <div className="overflow-x-auto">
            <table className="w-full min-w-[920px] text-left">
              <thead className="bg-bg-subtle text-[13px] text-text-secondary">
                <tr>
                  <SortHead col="name" label={t('admin.co.c_company')} className="pl-20" />
                  <th scope="col" className="px-16 py-12 font-semibold">
                    {t('admin.co.c_industry')}
                  </th>
                  <th scope="col" className="px-16 py-12 font-semibold">
                    {t('admin.co.c_plan')}
                  </th>
                  <SortHead col="technicians" label={t('admin.co.c_techs')} />
                  <SortHead col="reports" label={t('admin.co.c_reports')} />
                  <th scope="col" className="px-16 py-12 font-semibold">
                    {t('admin.co.c_status')}
                  </th>
                  <th scope="col" className="px-16 py-12">
                    <span className="sr-only">{t('admin.co.view')}</span>
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border-default text-[14px]">
                {data.items.map((c, i) => (
                  <tr key={c.id} className="kn-in group cursor-pointer transition-colors hover:bg-cream-100" style={{ ['--d' as string]: `${Math.min(i * 30, 400)}ms` }} onClick={() => navigate(`/companies/${c.id}`)}>
                    <td className="py-12 pl-20 pr-16">
                      <div className="flex items-center gap-12">
                        <Initials name={c.name} className={cx('h-[36px] w-[36px] rounded-md text-[13px] text-cream-50', shade(c.id))} />
                        <div className="min-w-0">
                          <p className="truncate font-semibold">{c.name}</p>
                          <p className="truncate text-[13px] text-text-secondary">
                            {c.owner_name ?? t('admin.co.no_owner')} · {c.country}
                          </p>
                        </div>
                      </div>
                    </td>
                    <td className="max-w-[180px] truncate px-16 py-12">{c.industry ?? '—'}</td>
                    <td className="px-16 py-12">{c.plan}</td>
                    <td className="px-16 py-12 tabular-nums">{c.technician_limit ? `${num(c.technicians, lang)} / ${num(c.technician_limit, lang)}` : num(c.technicians, lang)}</td>
                    <td className="px-16 py-12 tabular-nums">{num(c.reports_30d, lang)}</td>
                    <td className="px-16 py-12">
                      <StatusBadge t={t} badge={c.badge} daysLeft={c.trial_days_left} />
                    </td>
                    <td className="px-16 py-12 text-right">
                      <Link to={`/companies/${c.id}`} className="inline-flex items-center gap-4 font-semibold text-mocha-700 group-hover:text-text-primary">
                        <span className="sr-only">{t('admin.co.view_name', { name: c.name })}</span>
                        <span aria-hidden>{t('admin.co.view')}</span>
                        <ChevronRight width={16} height={16} className="kn-nudge" aria-hidden />
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="flex flex-wrap items-center justify-between gap-12 border-t border-border-default px-20 py-12">
            <p className="text-[13px] text-text-secondary">
              {t('admin.co.showing', {
                from: num((data.page - 1) * data.page_size + 1, lang),
                to: num(Math.min(data.page * data.page_size, data.total), lang),
                total: num(data.total, lang),
              })}
            </p>
            {last > 1 && (
              <nav aria-label={t('admin.nav.companies')} className="flex items-center gap-4">
                <button type="button" disabled={f.page <= 1} onClick={() => setF({ ...f, page: f.page - 1 })} aria-label={t('admin.co.prev')} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md border border-border-default hover:border-mocha-500 disabled:opacity-40">
                  <ChevronLeft width={16} height={16} aria-hidden />
                </button>
                {pages(f.page, last).map((p, i) =>
                  p === '…' ? (
                    <span key={`gap-${i}`} className="px-4 text-text-secondary">
                      …
                    </span>
                  ) : (
                    <button
                      key={p}
                      type="button"
                      onClick={() => setF({ ...f, page: p })}
                      aria-label={t('admin.co.page', { n: p })}
                      aria-current={p === f.page ? 'page' : undefined}
                      className={cx('inline-flex h-[32px] min-w-[32px] items-center justify-center rounded-md px-8 text-[13px] font-semibold', p === f.page ? 'bg-espresso-950 text-cream-50' : 'border border-border-default hover:border-mocha-500')}
                    >
                      {num(p, lang)}
                    </button>
                  ),
                )}
                <button type="button" disabled={f.page >= last} onClick={() => setF({ ...f, page: f.page + 1 })} aria-label={t('admin.co.next')} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md border border-border-default hover:border-mocha-500 disabled:opacity-40">
                  <ChevronRight width={16} height={16} aria-hidden />
                </button>
              </nav>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

export { shade };
