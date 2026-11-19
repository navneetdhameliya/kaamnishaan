import { ChevronLeft, ChevronRight, Search, X } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';

import { api, ApiError } from '../lib/api';
import { ago, LANGS, num, type Lang, type T } from '../lib/i18n';
import type { Role, UserList } from '../lib/types';
import { cx, FilterSelect, Initials, Link, navigate } from '../ui';
import { pages } from './Companies';

const TABS = ['', 'technician', 'manager', 'owner', 'invited'] as const;
const STATUSES = ['active', 'invited', 'removed', 'disabled'] as const;
const PAGE_SIZE = 20;

type Filters = { q: string; tab: (typeof TABS)[number]; status: string; language: string; company: string; page: number };

function readFilters(): Filters {
  const s = new URLSearchParams(window.location.search);
  const tab = (s.get('role') ?? (s.get('status') === 'invited' ? 'invited' : '')) as Filters['tab'];
  return {
    q: s.get('q') ?? '',
    tab: TABS.includes(tab) ? tab : '',
    status: s.get('status') && s.get('status') !== 'invited' ? (s.get('status') as string) : '',
    language: s.get('language') ?? '',
    company: s.get('company') ?? '',
    page: Math.max(1, Number(s.get('page')) || 1),
  };
}

function query(f: Filters): string {
  const p = new URLSearchParams();
  if (f.q.trim()) p.set('q', f.q.trim());
  if (f.tab === 'invited') p.set('status', 'invited');
  else if (f.tab) p.set('role', f.tab);
  if (f.status && f.tab !== 'invited') p.set('status', f.status);
  if (f.language) p.set('language', f.language);
  if (f.company) p.set('company', f.company);
  if (f.page > 1) p.set('page', String(f.page));
  return p.toString();
}

export function RolePill({ t, role }: { t: T; role: Role }) {
  return <span className="inline-flex rounded-full bg-bg-subtle px-[10px] py-[3px] text-[13px] font-semibold text-mocha-700">{t(`admin.co.role.${role}`)}</span>;
}

/** A08 Users: one row per person per company. Tabs by role, search, filters, pages. */
export function Users({ t, lang }: { t: T; lang: Lang }) {
  const [f, setF] = useState<Filters>(readFilters);
  const [typed, setTyped] = useState(f.q);
  const [data, setData] = useState<UserList | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const seq = useRef(0);

  useEffect(() => {
    const qs = query(f);
    window.history.replaceState(null, '', `/users${qs ? `?${qs}` : ''}`);
    const n = ++seq.current;
    setLoading(true);
    setError(false);
    api<UserList>(`/admin/users?${qs}&page_size=${PAGE_SIZE}`)
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
  const filtered = !!(f.q || f.tab || f.status || f.language || f.company);
  const clear = () => {
    setTyped('');
    setF({ q: '', tab: '', status: '', language: '', company: '', page: 1 });
  };
  const last = data ? Math.max(1, Math.ceil(data.total / data.page_size)) : 1;

  return (
    <div className="flex flex-col gap-16">
      <div role="tablist" aria-label={t('admin.us.tabs')} className="kn-in -mx-4 flex gap-8 overflow-x-auto px-4 pb-4">
        {TABS.map((tab) => {
          const n = data ? data.counts[tab || 'all'] : null;
          const on = f.tab === tab;
          return (
            <button
              key={tab || 'all'}
              role="tab"
              aria-selected={on}
              type="button"
              onClick={() => set({ tab, status: tab === 'invited' ? '' : f.status })}
              className={cx('kn-btn h-[36px] shrink-0 rounded-full border px-16 text-latin-label-sm font-semibold transition-colors', on ? 'border-espresso-950 bg-espresso-950 text-cream-50' : 'border-border-default bg-bg-surface hover:border-mocha-500')}
            >
              {tab ? t(`admin.us.tab.${tab}`) : t('admin.co.tab_all')}
              {n !== null && <span className={cx('ml-[6px] tabular-nums', on ? 'text-cream-300' : 'text-text-secondary')}>{num(n, lang)}</span>}
            </button>
          );
        })}
      </div>

      <div className="kn-in flex flex-wrap items-center gap-12" style={{ ['--d' as string]: '60ms' }}>
        <label className="relative min-w-[240px] flex-1">
          <span className="sr-only">{t('admin.us.search')}</span>
          <Search width={18} height={18} className="pointer-events-none absolute left-12 top-1/2 -translate-y-1/2 text-text-secondary" aria-hidden />
          <input
            type="search"
            value={typed}
            onChange={(e) => setTyped(e.target.value)}
            placeholder={t('admin.us.search')}
            className="h-[44px] w-full rounded-lg border border-border-strong bg-bg-surface pl-[40px] pr-12 text-latin-label-sm placeholder:text-taupe-500 hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring"
          />
        </label>
        {data?.company && (
          <span className="inline-flex h-[44px] items-center gap-8 rounded-lg border border-mocha-500 bg-bg-surface pl-12 pr-4 text-latin-label-sm font-semibold">
            {t('admin.us.company_chip', { name: data.company.label })}
            <button type="button" onClick={() => set({ company: '' })} aria-label={t('admin.us.clear_company')} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md hover:bg-bg-subtle">
              <X width={16} height={16} aria-hidden />
            </button>
          </span>
        )}
        {f.tab !== 'invited' && (
          <FilterSelect label={t('admin.us.f_status')} value={f.status} allLabel={t('admin.co.f_all')} options={STATUSES.filter((s) => s !== 'invited').map((s) => ({ value: s, label: t(`admin.us.st.${s}`) }))} onChange={(v) => set({ status: v })} />
        )}
        <FilterSelect label={t('admin.us.f_language')} value={f.language} allLabel={t('admin.co.f_all')} options={LANGS.map((l) => ({ value: l, label: t(`lang.${l}`) }))} onChange={(v) => set({ language: v })} />
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
          <span className="kn-pop inline-flex h-[88px] w-[88px] items-center justify-center rounded-full bg-bg-subtle text-mocha-700">
            <Search width={32} height={32} aria-hidden />
          </span>
          <h2 className="mt-16 text-[24px] font-bold">{filtered ? t('admin.us.empty_title') : t('admin.nav.users')}</h2>
          <p className="mt-8 max-w-[420px] text-latin-body text-text-secondary">{filtered ? t('admin.co.empty_body') : t('admin.us.none_yet')}</p>
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
                  {(['c_name', 'c_company', 'c_role', 'c_login', 'c_language', 'c_active'] as const).map((c, i) => (
                    <th key={c} scope="col" className={cx('px-16 py-12 font-semibold', i === 0 && 'pl-20')}>
                      {t(`admin.us.${c}`)}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-border-default text-[14px]">
                {data.items.map((u, i) => (
                  <tr key={u.membership_id} className={cx('kn-in group cursor-pointer transition-colors hover:bg-cream-100', u.status === 'removed' || u.status === 'disabled' ? 'text-text-secondary' : '')} style={{ ['--d' as string]: `${Math.min(i * 30, 400)}ms` }} onClick={() => navigate(`/users/${u.user_id}`)}>
                    <td className="py-12 pl-20 pr-16">
                      <div className="flex items-center gap-12">
                        <Initials name={u.name ?? '?'} className="h-[36px] w-[36px] rounded-full bg-cream-300 text-[13px] text-mocha-700" />
                        <div className="min-w-0">
                          <Link to={`/users/${u.user_id}`} className="block truncate font-semibold text-text-primary group-hover:underline">
                            {u.name || t('admin.us.no_name')}
                          </Link>
                          <p className="truncate text-[13px] text-text-secondary">{u.phone ?? u.email}</p>
                        </div>
                      </div>
                    </td>
                    <td className="max-w-[200px] truncate px-16 py-12">{u.company}</td>
                    <td className="px-16 py-12">
                      <RolePill t={t} role={u.role} />
                    </td>
                    <td className="px-16 py-12">{t(`admin.us.login.${u.login}`)}</td>
                    <td className="px-16 py-12">{u.language ? t(`lang.${u.language}`) : '—'}</td>
                    <td className="px-16 py-12">
                      <ActivityPill t={t} lang={lang} row={u} />
                    </td>
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
              <nav aria-label={t('admin.nav.users')} className="flex items-center gap-4">
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
    </div>
  );
}

function ActivityPill({ t, lang, row }: { t: T; lang: Lang; row: UserList['items'][number] }) {
  const base = 'inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold';
  if (row.status === 'disabled') return <span className={cx(base, 'bg-status-danger-bg text-status-danger')}>{t('admin.us.st.disabled')}</span>;
  if (row.status === 'removed') return <span className={cx(base, 'bg-cream-200 text-taupe-550')}>{t('admin.us.st.removed')}</span>;
  if (row.status === 'invited') return <span className={cx(base, 'bg-bg-subtle text-mocha-700')}>{t('admin.us.invited_ago', { when: row.invited_at ? ago(row.invited_at, lang) : '' })}</span>;
  if (row.on_job) return <span className={cx(base, 'bg-status-success-bg text-status-success')}>{t('admin.us.on_job')}</span>;
  return <span className={cx(base, 'bg-bg-subtle text-mocha-700')}>{row.last_seen_at ? ago(row.last_seen_at, lang) : t('admin.co.never')}</span>;
}
