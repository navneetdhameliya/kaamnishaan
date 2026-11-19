import { ChevronDown, ChevronLeft, ChevronRight, Download, Lock, ScrollText, Search, X } from 'lucide-react';
import { Fragment, useEffect, useRef, useState } from 'react';

import { api, ApiError, download } from '../lib/api';
import { day, num, type Lang, type T } from '../lib/i18n';
import type { AuditList, AuditRow } from '../lib/types';
import { cx, FilterSelect, Link, Spinner } from '../ui';
import { pages } from './Companies';

const ACTORS = ['staff', 'user', 'system'] as const;
const GROUPS = ['security', 'admin', 'company', 'team', 'jobs', 'reports'] as const;
const DAYS = [1, 7, 30, 90, 365] as const;
const PAGE_SIZE = 25;
// red: something blocked, removed or suspicious; green: something made or finished
const DANGER = new Set(['staff.login_failed', 'staff.session_reuse', 'session.reuse_detected', 'staff.user_disabled', 'job.deleted', 'job.cancelled', 'evidence.deleted', 'voice_note.deleted', 'team.removed', 'share_link.revoked', 'staff.reset']);
const GOOD = (a: string) => a.endsWith('.created') || ['report.approved', 'report.sent', 'report.acknowledged', 'team.joined', 'staff.setup_done', 'staff.user_enabled'].includes(a);

type Filters = { q: string; actor: string; group: string; company: string; days: number; page: number };

function readFilters(): Filters {
  const s = new URLSearchParams(window.location.search);
  const d = Number(s.get('days'));
  return {
    q: s.get('q') ?? '',
    actor: s.get('actor') ?? '',
    group: s.get('group') ?? '',
    company: s.get('company') ?? '',
    days: (DAYS as readonly number[]).includes(d) ? d : 7,
    page: Math.max(1, Number(s.get('page')) || 1),
  };
}

function query(f: Filters, withPage = true): string {
  const p = new URLSearchParams();
  if (f.q.trim()) p.set('q', f.q.trim());
  if (f.actor) p.set('actor', f.actor);
  if (f.group) p.set('group', f.group);
  if (f.company) p.set('company', f.company);
  if (f.days !== 7) p.set('days', String(f.days));
  if (withPage && f.page > 1) p.set('page', String(f.page));
  return p.toString();
}

/** 10.2.x or 2405:201:… in the list; the full address is in the details. */
const shortIp = (ip: string) => (ip.includes(':') ? `${ip.split(':').slice(0, 2).join(':')}:…` : `${ip.split('.').slice(0, 2).join('.')}.x`);

function label(t: T, key: string, fallback: string): string {
  const v = t(key);
  return v === key ? fallback : v;
}

function when(iso: string, lang: Lang): string {
  return day(iso, lang, { year: undefined, hour: '2-digit', minute: '2-digit' });
}

/** A31 Audit logs: who did what, to what, from where. Read only. */
export function AuditLogs({ t, lang }: { t: T; lang: Lang }) {
  const [f, setF] = useState<Filters>(readFilters);
  const [typed, setTyped] = useState(f.q);
  const [data, setData] = useState<AuditList | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [open, setOpen] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);
  const seq = useRef(0);

  useEffect(() => {
    const qs = query(f);
    window.history.replaceState(null, '', `/audit-logs${qs ? `?${qs}` : ''}`);
    const n = ++seq.current;
    setLoading(true);
    setError(false);
    api<AuditList>(`/admin/audit-logs?${qs}&page_size=${PAGE_SIZE}`)
      .then((d) => n === seq.current && setData(d))
      .catch((e) => n === seq.current && !(e instanceof ApiError && e.status === 401) && setError(true))
      .finally(() => n === seq.current && setLoading(false));
  }, [f]);

  useEffect(() => {
    if (typed === f.q) return;
    const id = window.setTimeout(() => setF((x) => ({ ...x, q: typed, page: 1 })), 300);
    return () => window.clearTimeout(id);
  }, [typed, f.q]);

  const set = (patch: Partial<Filters>) => setF((x) => ({ ...x, page: 1, ...patch }));
  const last = data ? Math.max(1, Math.ceil(data.total / data.page_size)) : 1;

  const actorCell = (r: AuditRow) => {
    if (r.actor.kind === 'system') return [t('admin.au.system'), typeof r.data.via === 'string' ? label(t, `admin.au.via.${r.data.via}`, r.data.via) : t('admin.au.system_sub')];
    if (r.actor.kind === 'unknown') return [t('admin.au.unknown'), t('admin.au.unknown_sub')];
    const role = r.actor.role ? label(t, r.actor.kind === 'staff' ? `admin.role.${r.actor.role}` : `admin.co.role.${r.actor.role}`, r.actor.role) : '';
    return [r.actor.name ?? '—', role];
  };
  const targetCell = (r: AuditRow) => {
    const base = r.target ?? (r.target_type ? label(t, `admin.au.t.${r.target_type}`, r.target_type) : '—');
    return r.change ? `${base} · ${r.change}` : base;
  };
  const targetLink = (r: AuditRow) =>
    !r.target_id ? null : r.target_type === 'company' ? `/companies/${r.target_id}` : r.target_type === 'user' ? `/users/${r.target_id}` : r.target_type === 'lead' ? `/leads/${r.target_id}` : null;

  return (
    <div className="flex flex-col gap-16">
      <div className="kn-in flex flex-wrap items-center gap-12">
        <label className="relative min-w-[240px] flex-1">
          <span className="sr-only">{t('admin.au.search')}</span>
          <Search width={18} height={18} className="pointer-events-none absolute left-12 top-1/2 -translate-y-1/2 text-text-secondary" aria-hidden />
          <input type="search" value={typed} onChange={(e) => setTyped(e.target.value)} placeholder={t('admin.au.search')} className="h-[44px] w-full rounded-lg border border-border-strong bg-bg-surface pl-[40px] pr-12 text-latin-label-sm placeholder:text-taupe-500 hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring" />
        </label>
        {data?.company && (
          <span className="inline-flex h-[44px] items-center gap-8 rounded-lg border border-mocha-500 bg-bg-surface pl-12 pr-4 text-latin-label-sm font-semibold">
            {t('admin.us.company_chip', { name: data.company.label })}
            <button type="button" onClick={() => set({ company: '' })} aria-label={t('admin.us.clear_company')} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md hover:bg-bg-subtle">
              <X width={16} height={16} aria-hidden />
            </button>
          </span>
        )}
        <FilterSelect label={t('admin.au.f_actor')} value={f.actor} allLabel={t('admin.co.f_all')} options={ACTORS.map((a) => ({ value: a, label: t(`admin.au.actor.${a}`) }))} onChange={(v) => set({ actor: v })} />
        <FilterSelect label={t('admin.au.f_action')} value={f.group} allLabel={t('admin.co.f_all')} options={GROUPS.map((g) => ({ value: g, label: t(`admin.au.g.${g}`) }))} onChange={(v) => set({ group: v })} />
        <label className="relative inline-flex h-[44px] items-center rounded-lg border border-border-default bg-bg-surface pl-12 pr-[34px] text-latin-label-sm font-semibold hover:border-mocha-500">
          <span aria-hidden>{t('admin.au.f_date')}:&nbsp;</span>
          <select value={f.days} onChange={(e) => set({ days: Number(e.target.value) })} aria-label={t('admin.au.f_date')} className="cursor-pointer appearance-none bg-transparent focus:outline-none">
            {DAYS.map((d) => (
              <option key={d} value={d}>
                {t(`admin.au.d.${d}`)}
              </option>
            ))}
          </select>
          <ChevronDown width={16} height={16} className="pointer-events-none absolute right-12" aria-hidden />
        </label>
        <button
          type="button"
          disabled={exporting || !data?.total}
          onClick={async () => {
            setExporting(true);
            try {
              await download(`/admin/audit-logs.csv?${query(f, false)}`, 'kaamnishaan-audit.csv');
            } catch {
              setError(true);
            } finally {
              setExporting(false);
            }
          }}
          className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg border border-border-default bg-bg-surface px-16 text-latin-label-sm font-semibold hover:border-mocha-500 disabled:opacity-50"
        >
          {exporting ? <Spinner /> : <Download width={16} height={16} aria-hidden />}
          {t('admin.au.export')}
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
        <div aria-busy="true" className="kn-shimmer h-[420px] rounded-xl bg-bg-surface" />
      ) : data.total === 0 ? (
        <div className="kn-in flex flex-col items-center rounded-xl border border-border-default bg-bg-surface px-24 py-48 text-center">
          <span className="kn-pop inline-flex h-[72px] w-[72px] items-center justify-center rounded-full bg-bg-subtle text-mocha-700">
            <ScrollText width={28} height={28} aria-hidden />
          </span>
          <p className="mt-16 max-w-[420px] text-latin-body text-text-secondary">{t('admin.au.empty')}</p>
        </div>
      ) : (
        <div className={cx('kn-in overflow-hidden rounded-xl border border-border-default bg-bg-surface transition-opacity', loading && 'opacity-60')} aria-busy={loading} style={{ ['--d' as string]: '80ms' }}>
          <div className="overflow-x-auto">
            <table className="w-full min-w-[980px] text-left">
              <thead className="bg-bg-subtle text-[13px] text-text-secondary">
                <tr>
                  {(['c_time', 'c_actor', 'c_action', 'c_target', 'c_company', 'c_ip'] as const).map((c, i) => (
                    <th key={c} scope="col" className={cx('px-16 py-12 font-semibold', i === 0 && 'pl-20')}>
                      {t(`admin.au.${c}`)}
                    </th>
                  ))}
                  <th scope="col" className="w-[48px] px-8 py-12">
                    <span className="sr-only">{t('admin.au.details')}</span>
                  </th>
                </tr>
              </thead>
              <tbody className="text-[14px]">
                {data.items.map((r, i) => {
                  const [who, sub] = actorCell(r);
                  const isOpen = open === r.id;
                  const link = targetLink(r);
                  const details = Object.entries(r.data);
                  return (
                    <Fragment key={r.id}>
                      <tr className={cx('kn-in cursor-pointer border-t border-border-default transition-colors hover:bg-cream-100', isOpen && 'bg-cream-100')} style={{ ['--d' as string]: `${Math.min(i * 25, 400)}ms` }} onClick={() => setOpen(isOpen ? null : r.id)}>
                        <td className="whitespace-nowrap py-12 pl-20 pr-16 font-semibold tabular-nums">{when(r.at, lang)}</td>
                        <td className="px-16 py-12">
                          <p className="font-semibold">
                            {r.actor.kind === 'user' && r.actor.id ? (
                              <Link to={`/users/${r.actor.id}`} className="kn-link">
                                {who}
                              </Link>
                            ) : (
                              who
                            )}
                          </p>
                          {sub && <p className="text-[13px] text-text-secondary">{sub}</p>}
                        </td>
                        <td className="px-16 py-12">
                          <span className={cx('inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold', DANGER.has(r.action) ? 'bg-status-danger-bg text-status-danger' : GOOD(r.action) ? 'bg-status-success-bg text-status-success' : 'bg-bg-subtle text-mocha-700')}>
                            {label(t, `admin.au.a.${r.action}`, r.action)}
                          </span>
                        </td>
                        <td className="max-w-[280px] truncate px-16 py-12">
                          {link ? (
                            <Link to={link} className="kn-link">
                              {targetCell(r)}
                            </Link>
                          ) : (
                            targetCell(r)
                          )}
                        </td>
                        <td className="max-w-[200px] truncate px-16 py-12">
                          {r.company_id ? (
                            <Link to={`/companies/${r.company_id}`} className="kn-link">
                              {r.company}
                            </Link>
                          ) : (
                            <span className="text-text-secondary">{t('admin.au.platform')}</span>
                          )}
                        </td>
                        <td className="whitespace-nowrap px-16 py-12 font-mono text-[13px] text-text-secondary">{r.ip ? shortIp(r.ip) : '—'}</td>
                        <td className="px-8 py-12">
                          <button type="button" aria-expanded={isOpen} aria-label={t('admin.au.show')} onClick={(e) => (e.stopPropagation(), setOpen(isOpen ? null : r.id))} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md hover:bg-bg-subtle">
                            <ChevronDown width={16} height={16} className={cx('transition-transform', isOpen && 'rotate-180')} aria-hidden />
                          </button>
                        </td>
                      </tr>
                      {isOpen && (
                        <tr className="bg-cream-100">
                          <td colSpan={7} className="px-20 pb-16">
                            <div className="kn-in rounded-lg border border-border-default bg-bg-surface p-16">
                              <p className="text-[13px] font-semibold text-text-secondary">
                                {t('admin.au.details')} · <span className="font-mono">{r.action}</span> · {day(r.at, lang, { hour: '2-digit', minute: '2-digit', second: '2-digit' })}
                                {r.ip && (
                                  <>
                                    {' '}
                                    · {t('admin.au.full_ip')}: <span className="font-mono">{r.ip}</span>
                                  </>
                                )}
                              </p>
                              {details.length ? (
                                <dl className="mt-8 grid gap-x-24 gap-y-4 sm:grid-cols-[max-content_1fr]">
                                  {details.map(([k, v]) => (
                                    <Fragment key={k}>
                                      <dt className="font-mono text-[13px] text-text-secondary">{k}</dt>
                                      <dd className="break-all font-mono text-[13px]">{typeof v === 'string' ? v : JSON.stringify(v)}</dd>
                                    </Fragment>
                                  ))}
                                </dl>
                              ) : (
                                <p className="mt-8 text-[13px] text-text-secondary">{t('admin.au.no_details')}</p>
                              )}
                            </div>
                          </td>
                        </tr>
                      )}
                    </Fragment>
                  );
                })}
              </tbody>
            </table>
          </div>
          <div className="flex flex-wrap items-center justify-between gap-12 border-t border-border-default px-20 py-12">
            <p className="flex items-center gap-8 text-[13px] text-text-secondary">
              <Lock width={14} height={14} aria-hidden />
              {t('admin.co.showing', { from: num((data.page - 1) * data.page_size + 1, lang), to: num(Math.min(data.page * data.page_size, data.total), lang), total: num(data.total, lang) })} · {t('admin.au.note')}
            </p>
            {last > 1 && (
              <nav aria-label={t('admin.nav.audit')} className="flex items-center gap-4">
                <button type="button" disabled={f.page <= 1} onClick={() => setF({ ...f, page: f.page - 1 })} aria-label={t('admin.co.prev')} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md border border-border-default hover:border-mocha-500 disabled:opacity-40">
                  <ChevronLeft width={16} height={16} aria-hidden />
                </button>
                {pages(f.page, last).map((p, i) =>
                  p === '…' ? (
                    <span key={`g${i}`} className="px-4 text-text-secondary">
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
    </div>
  );
}
