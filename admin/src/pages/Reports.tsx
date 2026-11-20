import { ChevronLeft, ChevronRight, Download, FileText, Search, X } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';

import { api, ApiError, download } from '../lib/api';
import { day, num, type Lang, type T } from '../lib/i18n';
import type { AdminReportList, AdminReportRow, ReportStatus } from '../lib/types';
import { cx, FilterSelect, Link, navigate, Spinner } from '../ui';
import { pages } from './Companies';
import { PAST_DATES, range } from './Jobs';

const PAGE_SIZE = 25;
export const REPORT_STATUSES: ReportStatus[] = ['generating', 'generation_failed', 'draft', 'pending_review', 'changes_requested', 'approved', 'shared', 'acknowledged'];
const LANGS = ['en', 'hi', 'gu', 'es', 'fr'] as const;

type Filters = { q: string; status: string; company: string; language: string; date: string; page: number };

function readFilters(): Filters {
  const s = new URLSearchParams(window.location.search);
  const pick = (k: string, ok: readonly string[]) => (ok.includes(s.get(k) ?? '') ? (s.get(k) as string) : '');
  return { q: s.get('q') ?? '', status: pick('status', REPORT_STATUSES), company: s.get('company') ?? '', language: pick('language', LANGS), date: pick('date', PAST_DATES), page: Math.max(1, Number(s.get('page')) || 1) };
}

function query(f: Filters, api = false, withPage = true): string {
  const p = new URLSearchParams();
  if (f.q.trim()) p.set('q', f.q.trim());
  for (const k of ['status', 'company', 'language'] as const) if (f[k]) p.set(k, f[k]);
  if (f.date && !api) p.set('date', f.date);
  const r = api ? range(f.date) : null;
  if (r) {
    p.set('from', r[0]);
    p.set('to', r[1]);
  }
  if (withPage && f.page > 1) p.set('page', String(f.page));
  return p.toString();
}

const pill = 'inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold';

export function ReportStatusPill({ t, status }: { t: T; status: ReportStatus }) {
  const tone: Record<ReportStatus, string> = {
    generating: 'bg-bg-subtle text-mocha-700',
    generation_failed: 'bg-status-danger-bg text-status-danger',
    draft: 'bg-bg-subtle text-mocha-700',
    pending_review: 'bg-status-warning-bg text-status-warning',
    changes_requested: 'bg-status-danger-bg text-status-danger',
    approved: 'bg-status-success-bg text-status-success',
    shared: 'bg-status-success-bg text-status-success',
    acknowledged: 'bg-status-success-bg text-status-success',
  };
  return <span className={cx(pill, tone[status])}>{t(`admin.jb.rs.${status}`)}</span>;
}

function CheckPill({ t, row }: { t: T; row: AdminReportRow }) {
  if (row.check === 'not_checked') return <span className="text-text-secondary">—</span>;
  if (row.check === 'passed') return <span className={cx(pill, 'bg-status-success-bg text-status-success')}>{t('admin.rp.ck.passed')}</span>;
  const bad = row.check === 'missing_evidence' || row.check === 'unsupported_claim';
  return <span className={cx(pill, bad ? 'bg-status-danger-bg text-status-danger' : 'bg-status-warning-bg text-status-warning')}>{t(`admin.rp.ck.${row.check}`, { n: row.check_count })}</span>;
}

/** The top-bar Export button: every report matching the filters in the address bar, as a CSV. */
export function ExportReports({ t }: { t: T }) {
  const [busy, setBusy] = useState(false);
  return (
    <button
      type="button"
      disabled={busy}
      onClick={async () => {
        setBusy(true);
        try {
          const q = query(readFilters(), true, false);
          await download(`/admin/reports.csv${q ? `?${q}` : ''}`, 'kaamnishaan-reports.csv');
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

/** A14 Reports: every company's reports, newest first, with what the AI checks found. */
export function Reports({ t, lang }: { t: T; lang: Lang }) {
  const [f, setF] = useState<Filters>(readFilters);
  const [typed, setTyped] = useState(f.q);
  const [data, setData] = useState<AdminReportList | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const seq = useRef(0);

  useEffect(() => {
    const q = query(f);
    window.history.replaceState(null, '', `/reports${q ? `?${q}` : ''}`);
    const n = ++seq.current;
    setLoading(true);
    setError(false);
    const aq = query(f, true);
    api<AdminReportList>(`/admin/reports?${aq}${aq ? '&' : ''}page_size=${PAGE_SIZE}`)
      .then((d) => n === seq.current && setData(d))
      .catch((e) => n === seq.current && !(e instanceof ApiError && e.status === 401) && setError(true))
      .finally(() => n === seq.current && setLoading(false));
  }, [f]);
  useEffect(() => {
    if (typed === f.q) return;
    const tm = window.setTimeout(() => setF((x) => ({ ...x, q: typed, page: 1 })), 300);
    return () => window.clearTimeout(tm);
  }, [typed, f.q]);

  const set = (patch: Partial<Filters>) => setF((x) => ({ ...x, ...patch, page: 1 }));
  const last = data ? Math.max(1, Math.ceil(data.total / data.page_size)) : 1;
  const filtered = !!(f.q || f.status || f.company || f.language || f.date);

  return (
    <div className="flex flex-col gap-16">
      <div className="kn-in flex flex-wrap items-center gap-12">
        <label className="relative min-w-[240px] flex-1">
          <span className="sr-only">{t('admin.rp.search')}</span>
          <Search width={18} height={18} className="pointer-events-none absolute left-12 top-1/2 -translate-y-1/2 text-text-secondary" aria-hidden />
          <input type="search" value={typed} onChange={(e) => setTyped(e.target.value)} placeholder={t('admin.rp.search')} className="h-[44px] w-full rounded-lg border border-border-strong bg-bg-surface pl-[40px] pr-12 text-latin-label-sm placeholder:text-taupe-500 hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring" />
        </label>
        <FilterSelect label={t('admin.rv.f_status')} value={f.status} allLabel={t('admin.co.f_all')} options={REPORT_STATUSES.map((s) => ({ value: s, label: `${t(`admin.jb.rs.${s}`)} (${num(data?.counts[s] ?? 0, lang)})` }))} onChange={(v) => set({ status: v })} />
        <FilterSelect label={t('admin.rp.f_language')} value={f.language} allLabel={t('admin.co.f_all')} options={LANGS.map((l) => ({ value: l, label: t(`lang.${l}`) }))} onChange={(v) => set({ language: v })} />
        <FilterSelect label={t('admin.rv.f_company')} value={f.company} allLabel={t('admin.co.f_all')} options={data?.companies ?? []} onChange={(v) => set({ company: v })} />
        <FilterSelect label={t('admin.jb.f_date')} value={f.date} allLabel={t('admin.jb.d.any')} options={PAST_DATES.map((d) => ({ value: d, label: t(`admin.jb.d.${d}`) }))} onChange={(v) => set({ date: v })} />
      </div>

      {error && (
        <p role="alert" className="rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">
          {t('admin.err.load')}{' '}
          <button type="button" className="underline" onClick={() => setF({ ...f })}>{t('admin.retry')}</button>
        </p>
      )}

      {!data ? (
        <div aria-busy="true" className="kn-shimmer h-[380px] rounded-xl bg-bg-surface" />
      ) : data.total === 0 ? (
        <div className="kn-in flex flex-col items-center rounded-xl border border-border-default bg-bg-surface px-24 py-48 text-center">
          <span className="kn-pop inline-flex h-[88px] w-[88px] items-center justify-center rounded-full bg-bg-subtle text-mocha-700">
            {filtered ? <Search width={32} height={32} aria-hidden /> : <FileText width={32} height={32} aria-hidden />}
          </span>
          <h2 className="mt-16 text-[24px] font-bold">{filtered ? t('admin.rp.empty_title') : t('admin.rp.none_title')}</h2>
          <p className="mt-8 max-w-[420px] text-latin-body text-text-secondary">{filtered ? t('admin.co.empty_body') : t('admin.rp.none_body')}</p>
          {filtered && (
            <button type="button" onClick={() => { setTyped(''); setF({ q: '', status: '', company: '', language: '', date: '', page: 1 }); }} className="kn-btn mt-20 inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold hover:bg-cream-300">
              <X width={16} height={16} aria-hidden />
              {t('admin.co.clear')}
            </button>
          )}
        </div>
      ) : (
        <div className={cx('kn-in overflow-hidden rounded-xl border border-border-default bg-bg-surface transition-opacity', loading && 'opacity-60')} style={{ ['--d' as string]: '120ms' }} aria-busy={loading}>
          <div className="overflow-x-auto">
            <table className="w-full min-w-[980px] text-left">
              <thead className="bg-bg-subtle text-[13px] text-text-secondary">
                <tr>
                  {(['c_report', 'c_company', 'c_language', 'c_check', 'c_status', 'c_sent'] as const).map((c, i) => (
                    <th key={c} scope="col" className={cx('px-16 py-12 font-semibold', i === 0 && 'pl-20')}>{t(`admin.rp.${c}`)}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-border-default text-[14px]">
                {data.items.map((r, i) => (
                  <tr key={r.id} onClick={() => navigate(`/reports/${r.id}`)} className="kn-in group cursor-pointer transition-colors hover:bg-cream-100" style={{ ['--d' as string]: `${Math.min(i * 30, 400)}ms` }}>
                    <td className="max-w-[320px] py-12 pl-20 pr-16">
                      <Link to={`/reports/${r.id}`} className="block truncate font-semibold text-text-primary group-hover:underline">#{r.number} {r.job.customer}</Link>
                      <p className="truncate text-[13px] text-text-secondary">{r.technician ?? '—'}</p>
                    </td>
                    <td className="max-w-[200px] truncate px-16 py-12">
                      <span onClick={(e) => e.stopPropagation()}>
                        <Link to={`/companies/${r.company.value}`} className="hover:underline">{r.company.label}</Link>
                      </span>
                    </td>
                    <td className="px-16 py-12">{t(`lang.${r.language}`)}</td>
                    <td className="px-16 py-12"><CheckPill t={t} row={r} /></td>
                    <td className="px-16 py-12"><ReportStatusPill t={t} status={r.status} /></td>
                    <td className="whitespace-nowrap px-16 py-12">{r.shared_at ? day(r.shared_at, lang, { year: undefined }) : <span className="text-text-secondary">—</span>}</td>
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
              <nav aria-label={t('admin.nav.reports')} className="flex items-center gap-4">
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
    </div>
  );
}
