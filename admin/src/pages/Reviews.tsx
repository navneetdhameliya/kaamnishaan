import { Check, ChevronLeft, ChevronRight, Download, EyeOff, RotateCcw, Search, ShieldAlert, Star, X } from 'lucide-react';
import { useCallback, useEffect, useRef, useState } from 'react';

import { api, ApiError, download } from '../lib/api';
import { ago, day, num, type Lang, type T } from '../lib/i18n';
import type { AdminReviewDetail, AdminReviewList, AdminReviewRow, ReviewRules } from '../lib/types';
import { cx, FilterSelect, Link, ReasonDialog, Spinner, Switch } from '../ui';
import { pages } from './Companies';

const PAGE_SIZE = 25;
const STATUSES = ['flagged', 'published', 'followup', 'replied', 'hidden'] as const;
const RATINGS = ['5', '4', '3', '2', '1', 'low'] as const;

type Filters = { q: string; rating: string; status: string; company: string; page: number };

function readFilters(): Filters {
  const s = new URLSearchParams(window.location.search);
  const pick = (k: string, ok: readonly string[]) => (ok.includes(s.get(k) ?? '') ? (s.get(k) as string) : '');
  return { q: s.get('q') ?? '', rating: pick('rating', RATINGS), status: pick('status', STATUSES), company: s.get('company') ?? '', page: Math.max(1, Number(s.get('page')) || 1) };
}

function query(f: Filters, withPage = true): string {
  const p = new URLSearchParams();
  if (f.q.trim()) p.set('q', f.q.trim());
  if (f.rating) p.set('rating', f.rating);
  if (f.status) p.set('status', f.status);
  if (f.company) p.set('company', f.company);
  if (withPage && f.page > 1) p.set('page', String(f.page));
  return p.toString();
}

export function Stars({ n, t, size = 14 }: { n: number; t: T; size?: number }) {
  return (
    <span role="img" aria-label={t('admin.rv.stars', { n })} className="inline-flex shrink-0 gap-[3px]">
      {[1, 2, 3, 4, 5].map((i) => (
        <Star key={i} width={size} height={size} aria-hidden className={i <= n ? 'fill-status-warning text-status-warning' : 'fill-taupe-400 text-taupe-400'} />
      ))}
    </span>
  );
}

function StatusPill({ t, row }: { t: T; row: AdminReviewRow }) {
  const base = 'inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold';
  if (row.status === 'flagged') return <span className="whitespace-nowrap text-[14px] font-semibold text-status-danger">{t('admin.rv.flagged_why', { why: t(`admin.rv.why.${row.flag_reason ?? 'abuse'}`) })}</span>;
  if (row.status === 'hidden') return <span className={cx(base, 'bg-cream-200 text-taupe-550')}>{t('admin.rv.st.hidden')}</span>;
  if (row.followup === 'open') return <span className={cx(base, 'bg-status-warning-bg text-status-warning')}>{t('admin.rv.st.followup')}</span>;
  if (row.replied) return <span className={cx(base, 'bg-status-success-bg text-status-success')}>{t('admin.rv.st.replied')}</span>;
  return <span className={cx(base, 'bg-bg-subtle text-mocha-700')}>{t('admin.rv.st.published')}</span>;
}

function Kpi({ label, value, sub, extra, danger, i }: { label: string; value: string; sub: string; extra?: React.ReactNode; danger?: boolean; i: number }) {
  return (
    <div className="kn-in" style={{ ['--d' as string]: `${i * 60}ms` }}>
      <div className="kn-hover h-full rounded-xl border border-border-default bg-bg-surface p-20">
        <p className="text-[14px] font-semibold text-text-secondary">{label}</p>
        <div className="mt-8 flex items-center gap-12">
          <p className={cx('text-[32px] font-bold leading-[40px] tabular-nums', danger && 'text-status-danger')}>{value}</p>
          {extra}
        </div>
        <p className="mt-4 text-[13px] text-text-secondary">{sub}</p>
      </div>
    </div>
  );
}

/** The top-bar Export button: every review matching the filters in the address bar, as a CSV. */
export function ExportReviews({ t }: { t: T }) {
  const [busy, setBusy] = useState(false);
  return (
    <button
      type="button"
      disabled={busy}
      onClick={async () => {
        setBusy(true);
        try {
          const q = query(readFilters(), false);
          await download(`/admin/reviews.csv${q ? `?${q}` : ''}`, 'kaamnishaan-reviews.csv');
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

function Panel({ t, lang, id, onChanged }: { t: T; lang: Lang; id: string; onChanged: (d: AdminReviewDetail) => void }) {
  const [d, setD] = useState<AdminReviewDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [hiding, setHiding] = useState(false);
  const [done, setDone] = useState<string | null>(null);

  useEffect(() => {
    setD(null);
    api<AdminReviewDetail>(`/admin/reviews/${id}`)
      .then(setD)
      .catch(() => setError(t('admin.err.load')));
  }, [id, t]);

  const act = async (path: string, body?: unknown, msg?: string): Promise<string | null> => {
    setBusy(true);
    setError(null);
    try {
      const out = await api<AdminReviewDetail>(`/admin/reviews/${id}/${path}`, { method: 'POST', body });
      setD(out);
      onChanged(out);
      setDone(msg ?? null);
      return null;
    } catch (e) {
      const m = e instanceof ApiError && e.status === 409 ? t('admin.rv.err_done') : t('admin.err.generic');
      setError(m);
      return m;
    } finally {
      setBusy(false);
    }
  };

  if (!d) return error ? <p className="p-24 text-latin-label-sm text-status-danger">{error}</p> : <div aria-busy="true" className="kn-shimmer m-24 h-[200px] rounded-lg bg-bg-subtle" />;
  const why = d.flag_reason && t(`admin.rv.why.${d.flag_reason}`);
  return (
    <div className="kn-in p-20 sm:p-24">
      <div className="flex flex-wrap items-center gap-12">
        <h2 className="text-[20px] font-semibold leading-[28px]">
          {t(d.status === 'flagged' ? 'admin.rv.panel_flagged' : 'admin.rv.panel', { company: d.company.label })}
        </h2>
        {d.status === 'flagged' && why && <span className="rounded-full bg-status-danger-bg px-[10px] py-[3px] text-[13px] font-semibold text-status-danger">{t(`admin.rv.found.${d.flag_reason}`)}</span>}
        {d.status === 'hidden' && <span className="rounded-full bg-cream-200 px-[10px] py-[3px] text-[13px] font-semibold text-taupe-550">{t('admin.rv.st.hidden')}</span>}
      </div>
      <div className="mt-16 rounded-lg bg-bg-subtle p-16">
        <Stars n={d.rating} t={t} />
        <p className="mt-8 break-words text-latin-body">{d.comment ? `“${d.comment}”` : <span className="text-text-secondary">{t('admin.rv.no_comment')}</span>}</p>
        {d.comment_original && (
          <p className="mt-8 break-words text-[13px] text-text-secondary">
            <span className="font-semibold">{t('admin.rv.original')}</span> “{d.comment_original}”
          </p>
        )}
        <p className="mt-8 text-[13px] text-text-secondary">
          {[d.reviewer_name || t('admin.rv.unknown'), `${d.job_number} · ${d.job_title}`, d.technician, day(d.created_at, lang)].filter(Boolean).join(' · ')}
        </p>
        {d.status === 'flagged' && d.flag_reason && <p className="mt-4 text-[13px] text-text-secondary">{t(`admin.rv.check.${d.flag_reason}`)}</p>}
      </div>
      {d.reply && (
        <div className="mt-12 border-l-2 border-border-strong pl-12">
          <p className="text-[13px] font-semibold text-text-secondary">{t('admin.rv.reply_by', { name: d.reply.by ?? d.company.label })}</p>
          <p className="mt-2 break-words text-latin-label-sm">{d.reply.text}</p>
        </div>
      )}
      {d.moderated_at && (
        <p className="mt-12 text-[13px] text-text-secondary">
          {t('admin.rv.decided', { name: d.moderated_by ?? '—', when: ago(d.moderated_at, lang) })}
          {d.moderation_note ? ` · ${d.moderation_note}` : ''}
        </p>
      )}
      {done && (
        <p role="status" className="kn-pop mt-12 rounded-lg bg-status-success-bg px-12 py-8 text-latin-label-sm font-semibold text-status-success">
          {done}
        </p>
      )}
      {error && (
        <p role="alert" className="kn-shake mt-12 rounded-lg bg-status-danger-bg px-12 py-8 text-latin-label-sm font-semibold text-status-danger">
          {error}
        </p>
      )}
      {d.can_act ? (
        <div className="mt-16 flex flex-wrap gap-12">
          {d.status === 'flagged' && (
            <button type="button" disabled={busy} onClick={() => act('publish', undefined, t('admin.rv.done_published'))} className="kn-btn inline-flex h-[48px] items-center gap-8 rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action disabled:opacity-60">
              {busy ? <Spinner /> : <Check width={18} height={18} aria-hidden />}
              {t(d.comment_original ? 'admin.rv.publish_edit' : 'admin.rv.publish')}
            </button>
          )}
          {d.status !== 'hidden' && (
            <button type="button" disabled={busy} onClick={() => setHiding(true)} className="kn-btn inline-flex h-[48px] items-center gap-8 rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-60">
              <EyeOff width={18} height={18} aria-hidden />
              {t('admin.rv.hide')}
            </button>
          )}
          {d.status === 'hidden' && (
            <button type="button" disabled={busy} onClick={() => act('restore', undefined, t('admin.rv.done_restored'))} className="kn-btn inline-flex h-[48px] items-center gap-8 rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-60">
              {busy ? <Spinner /> : <RotateCcw width={18} height={18} aria-hidden />}
              {t('admin.rv.restore')}
            </button>
          )}
        </div>
      ) : (
        <p className="mt-16 text-[13px] text-text-secondary">{t('admin.rv.support_only')}</p>
      )}
      {hiding && (
        <ReasonDialog
          t={t}
          title={t('admin.rv.hide_title')}
          body={t('admin.rv.hide_body')}
          confirm={t('admin.rv.hide')}
          danger
          onClose={() => setHiding(false)}
          onConfirm={async (reason) => {
            const err = await act('hide', { reason }, t('admin.rv.done_hidden'));
            if (!err) setHiding(false);
            return err;
          }}
        />
      )}
    </div>
  );
}

function Rules({ t, canAct }: { t: T; canAct: boolean }) {
  const [rules, setRules] = useState<ReviewRules | null>(null);
  const [saving, setSaving] = useState<keyof ReviewRules | null>(null);
  const [error, setError] = useState(false);
  useEffect(() => {
    api<ReviewRules>('/admin/review-rules').then(setRules).catch(() => setError(true));
  }, []);
  const flip = async (k: keyof ReviewRules, on: boolean) => {
    if (!rules) return;
    const next = { ...rules, [k]: on };
    setRules(next);
    setSaving(k);
    setError(false);
    try {
      setRules(await api<ReviewRules>('/admin/review-rules', { method: 'PUT', body: next }));
    } catch {
      setRules(rules);
      setError(true);
    } finally {
      setSaving(null);
    }
  };
  return (
    <section className="kn-in rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24" style={{ ['--d' as string]: '180ms' }}>
      <h2 className="text-[20px] font-semibold leading-[28px]">{t('admin.rv.rules')}</h2>
      {!rules ? (
        <div aria-busy="true" className="kn-shimmer mt-16 h-[140px] rounded-lg bg-bg-subtle" />
      ) : (
        <div className="mt-8 flex flex-col">
          {(['hide_contact', 'flag_abuse', 'block_repeats'] as const).map((k) => (
            <Switch key={k} label={t(`admin.rv.rule.${k}`)} checked={rules[k]} disabled={!canAct || saving !== null} onChange={(on) => flip(k, on)} />
          ))}
        </div>
      )}
      {error && (
        <p role="alert" className="mt-8 text-[13px] font-semibold text-status-danger">
          {t('admin.err.generic')}
        </p>
      )}
      <p className="mt-12 text-[13px] text-text-secondary">{t('admin.rv.rules_note')}</p>
    </section>
  );
}

/** A37 Reviews and ratings, from GET /admin/reviews. */
export function Reviews({ t, lang, canAct }: { t: T; lang: Lang; canAct: boolean }) {
  const [f, setF] = useState<Filters>(readFilters);
  const [typed, setTyped] = useState(f.q);
  const [data, setData] = useState<AdminReviewList | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [open, setOpen] = useState<string | null>(null);
  const seq = useRef(0);
  const panel = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const q = query(f);
    window.history.replaceState(null, '', `/reviews${q ? `?${q}` : ''}`);
    const n = ++seq.current;
    setLoading(true);
    setError(false);
    api<AdminReviewList>(`/admin/reviews?${query(f)}${query(f) ? '&' : ''}page_size=${PAGE_SIZE}`)
      .then((d) => {
        if (n !== seq.current) return;
        setData(d);
        setOpen((cur) => (cur && d.items.some((i) => i.id === cur) ? cur : (d.items.find((i) => i.status === 'flagged') ?? d.items[0])?.id ?? null));
      })
      .catch((e) => n === seq.current && !(e instanceof ApiError && e.status === 401) && setError(true))
      .finally(() => n === seq.current && setLoading(false));
  }, [f]);

  useEffect(() => {
    if (typed === f.q) return;
    const tm = window.setTimeout(() => setF((x) => ({ ...x, q: typed, page: 1 })), 300);
    return () => window.clearTimeout(tm);
  }, [typed, f.q]);

  const set = (patch: Partial<Filters>) => setF((x) => ({ ...x, ...patch, page: 1 }));
  const pick = (id: string) => {
    setOpen(id);
    if (window.innerWidth < 1024) window.setTimeout(() => panel.current?.scrollIntoView({ behavior: 'smooth', block: 'start' }), 50);
  };
  const onChanged = useCallback(
    (d: AdminReviewDetail) =>
      setData((x) => {
        if (!x) return x;
        const was = x.items.find((i) => i.id === d.id);
        const flagged = x.kpis.flagged - (was?.status === 'flagged' && d.status !== 'flagged' ? 1 : 0);
        return { ...x, kpis: { ...x.kpis, flagged }, items: x.items.map((i) => (i.id === d.id ? { ...i, status: d.status } : i)) };
      }),
    [],
  );
  const k = data?.kpis;
  const pct = (v: number | null) => (v === null ? '—' : num(v, lang, { style: 'percent', maximumFractionDigits: 1 }));
  const last = data ? Math.max(1, Math.ceil(data.total / data.page_size)) : 1;
  const filtered = !!(f.q || f.rating || f.status || f.company);

  return (
    <div className="flex flex-col gap-16">
      <div className="grid gap-16 sm:grid-cols-2 xl:grid-cols-4">
        {!k ? (
          [0, 1, 2, 3].map((i) => <div key={i} className="kn-shimmer h-[128px] rounded-xl bg-bg-surface" />)
        ) : (
          <>
            <Kpi i={0} label={t('admin.rv.k_avg')} value={k.average_rating === null ? '—' : num(k.average_rating, lang, { minimumFractionDigits: 1, maximumFractionDigits: 1 })} extra={k.average_rating !== null && <Stars n={Math.round(k.average_rating)} t={t} />} sub={t('admin.rv.k_avg_sub')} />
            <Kpi i={1} label={t('admin.rv.k_count')} value={num(k.reviews_30d, lang)} sub={k.share_rate === null ? t('admin.rv.k_no_shared') : t('admin.rv.k_count_sub', { pct: pct(k.share_rate) })} />
            <Kpi i={2} label={t('admin.rv.k_low')} value={num(k.low_30d, lang)} sub={t('admin.rv.k_low_sub', { pct: pct(k.low_rate) })} />
            <Kpi i={3} label={t('admin.rv.k_flagged')} value={num(k.flagged, lang)} danger={k.flagged > 0} sub={t('admin.rv.k_flagged_sub')} />
          </>
        )}
      </div>

      <div className="kn-in flex flex-wrap items-center gap-12" style={{ ['--d' as string]: '60ms' }}>
        <label className="relative min-w-[240px] flex-1">
          <span className="sr-only">{t('admin.rv.search')}</span>
          <Search width={18} height={18} className="pointer-events-none absolute left-12 top-1/2 -translate-y-1/2 text-text-secondary" aria-hidden />
          <input type="search" value={typed} onChange={(e) => setTyped(e.target.value)} placeholder={t('admin.rv.search')} className="h-[44px] w-full rounded-lg border border-border-strong bg-bg-surface pl-[40px] pr-12 text-latin-label-sm placeholder:text-taupe-500 hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring" />
        </label>
        <FilterSelect label={t('admin.rv.f_rating')} value={f.rating} allLabel={t('admin.co.f_all')} options={RATINGS.map((r) => ({ value: r, label: r === 'low' ? t('admin.rv.r_low') : t('admin.rv.stars', { n: Number(r) }) }))} onChange={(v) => set({ rating: v })} />
        <FilterSelect label={t('admin.rv.f_status')} value={f.status} allLabel={t('admin.rv.flagged_first')} options={STATUSES.map((s) => ({ value: s, label: t(`admin.rv.f.${s}`) }))} onChange={(v) => set({ status: v })} />
        <FilterSelect label={t('admin.rv.f_company')} value={f.company} allLabel={t('admin.co.f_all')} options={data?.companies ?? []} onChange={(v) => set({ company: v })} />
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
        <div aria-busy="true" className="kn-shimmer h-[380px] rounded-xl bg-bg-surface" />
      ) : data.total === 0 ? (
        <div className="kn-in flex flex-col items-center rounded-xl border border-border-default bg-bg-surface px-24 py-48 text-center">
          <span className="kn-pop inline-flex h-[88px] w-[88px] items-center justify-center rounded-full bg-bg-subtle text-mocha-700">
            {filtered ? <Search width={32} height={32} aria-hidden /> : <Star width={32} height={32} aria-hidden />}
          </span>
          <h2 className="mt-16 text-[24px] font-bold">{filtered ? t('admin.rv.empty_title') : t('admin.rv.none_title')}</h2>
          <p className="mt-8 max-w-[420px] text-latin-body text-text-secondary">{filtered ? t('admin.co.empty_body') : t('admin.rv.none_body')}</p>
          {filtered && (
            <button type="button" onClick={() => { setTyped(''); setF({ q: '', rating: '', status: '', company: '', page: 1 }); }} className="kn-btn mt-20 inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold hover:bg-cream-300">
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
                  {(['c_review', 'c_company', 'c_tech', 'c_rating', 'c_status', 'c_when'] as const).map((c, i) => (
                    <th key={c} scope="col" className={cx('px-16 py-12 font-semibold', i === 0 && 'pl-20')}>
                      {t(`admin.rv.${c}`)}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-border-default text-[14px]">
                {data.items.map((r, i) => (
                  <tr
                    key={r.id}
                    onClick={() => pick(r.id)}
                    aria-selected={r.id === open}
                    className={cx('kn-in cursor-pointer transition-colors', r.status === 'flagged' ? 'bg-status-danger-bg' : r.id === open ? 'bg-cream-100' : 'hover:bg-cream-100', r.status === 'hidden' && 'text-text-secondary', r.id === open && 'shadow-[inset_3px_0_0] shadow-espresso-950')}
                    style={{ ['--d' as string]: `${Math.min(i * 30, 400)}ms` }}
                  >
                    <td className="max-w-[360px] py-12 pl-20 pr-16">
                      <button type="button" onClick={(e) => { e.stopPropagation(); pick(r.id); }} className="block w-full truncate text-left font-semibold hover:underline">
                        {r.comment ? `“${r.comment}”` : t('admin.rv.no_comment')}
                      </button>
                      <p className="truncate text-[13px] text-text-secondary">{[r.reviewer_name || t('admin.rv.unknown'), r.job_title].join(' · ')}</p>
                    </td>
                    <td className="max-w-[200px] truncate px-16 py-12">
                      <span onClick={(e) => e.stopPropagation()}>
                        <Link to={`/companies/${r.company.value}`} className="hover:underline">
                          {r.company.label}
                        </Link>
                      </span>
                    </td>
                    <td className="max-w-[160px] truncate px-16 py-12">{r.technician ?? '—'}</td>
                    <td className="px-16 py-12">
                      <Stars n={r.rating} t={t} size={13} />
                    </td>
                    <td className="px-16 py-12">
                      <StatusPill t={t} row={r} />
                    </td>
                    <td className="whitespace-nowrap px-16 py-12 text-text-secondary">{ago(r.created_at, lang)}</td>
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
              <nav aria-label={t('admin.nav.reviews')} className="flex items-center gap-4">
                <button type="button" disabled={f.page <= 1} onClick={() => setF({ ...f, page: f.page - 1 })} aria-label={t('admin.co.prev')} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md border border-border-default hover:border-mocha-500 disabled:opacity-40">
                  <ChevronLeft width={16} height={16} aria-hidden />
                </button>
                {pages(f.page, last).map((p, i) =>
                  p === '…' ? (
                    <span key={`gap-${i}`} className="px-4 text-text-secondary">
                      …
                    </span>
                  ) : (
                    <button key={p} type="button" onClick={() => setF({ ...f, page: p })} aria-label={t('admin.co.page', { n: p })} aria-current={p === f.page ? 'page' : undefined} className={cx('inline-flex h-[32px] min-w-[32px] items-center justify-center rounded-md px-8 text-[13px] font-semibold', p === f.page ? 'bg-espresso-950 text-cream-50' : 'border border-border-default hover:border-mocha-500')}>
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

      <div ref={panel} className="grid items-start gap-16 lg:grid-cols-[minmax(0,1fr)_380px]">
        <section className="kn-in scroll-mt-16 rounded-xl border border-border-default bg-bg-surface" style={{ ['--d' as string]: '160ms' }}>
          {open ? (
            <Panel key={open} t={t} lang={lang} id={open} onChanged={onChanged} />
          ) : (
            <p className="flex min-h-[200px] items-center justify-center gap-8 p-24 text-latin-label-sm text-text-secondary">
              <ShieldAlert width={18} height={18} aria-hidden />
              {t('admin.rv.pick')}
            </p>
          )}
        </section>
        <Rules t={t} canAct={canAct} />
      </div>
    </div>
  );
}
