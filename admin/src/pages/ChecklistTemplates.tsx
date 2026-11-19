import { Plus, Search, X } from 'lucide-react';
import { Fragment, useEffect, useRef, useState, type FormEvent } from 'react';

import { api, ApiError } from '../lib/api';
import { day, LANGS, num, plural, type Lang, type T } from '../lib/i18n';
import { session } from '../lib/session';
import type { ChecklistDetail, ChecklistList, ChecklistRow, LangState } from '../lib/types';
import { cx, ErrorBanner, FilterSelect, navigate, Spinner } from '../ui';

const TABS = ['all', 'by_trade', 'needs_translation', 'drafts'] as const;
type Tab = (typeof TABS)[number];

/** "5 of 5 languages" (green), "4 of 5 · French missing" (amber), "Hindi to check" (neutral). */
export function LangBadge({ t, langs }: { t: T; langs: Record<string, LangState> }) {
  const missing = LANGS.filter((l) => langs[l] === 'missing');
  const review = LANGS.filter((l) => langs[l] === 'review');
  const base = 'inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold';
  if (missing.length)
    return <span className={cx(base, 'bg-status-warning-bg text-status-warning')}>{t('admin.cl.langs_some', { n: 5 - missing.length, missing: missing.map((l) => t(`lang.${l}`)).join(', ') })}</span>;
  if (review.length) return <span className={cx(base, 'bg-bg-subtle text-mocha-700')}>{t('admin.cl.langs_review', { langs: review.map((l) => t(`lang.${l}`)).join(', ') })}</span>;
  return <span className={cx(base, 'bg-status-success-bg text-status-success')}>{t('admin.cl.langs_all')}</span>;
}

function CreateDialog({ t, lang, trades, onClose }: { t: T; lang: Lang; trades: { value: string; label: string }[]; onClose: () => void }) {
  const [name, setName] = useState('');
  const [trade, setTrade] = useState(trades[0]?.value ?? '');
  const [minutes, setMinutes] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const ref = useRef<HTMLInputElement>(null);
  useEffect(() => {
    ref.current?.focus();
    const esc = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', esc);
    return () => window.removeEventListener('keydown', esc);
  }, [onClose]);
  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return setError(t('admin.cl.name'));
    setBusy(true);
    setError(null);
    try {
      const d = await api<ChecklistDetail>(`/admin/checklist-templates?locale=${lang}`, { method: 'POST', body: { name: name.trim(), trade, minutes: minutes ? Number(minutes) : null } });
      navigate(`/checklist-templates/${d.id}`);
    } catch (err) {
      setError(t(err instanceof ApiError && err.status === 403 ? 'admin.cl.read_only' : 'admin.err.generic'));
      setBusy(false);
    }
  };
  const field = 'mt-8 h-[48px] w-full rounded-lg border border-border-strong bg-bg-surface px-12 text-latin-body hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring';
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center p-16 sm:items-center">
      <button type="button" aria-hidden tabIndex={-1} onClick={onClose} className="absolute inset-0 cursor-default bg-espresso-950/50" />
      <form role="dialog" aria-modal="true" aria-labelledby="new-cl" noValidate onSubmit={(e) => void submit(e)} className="kn-pop relative w-full max-w-[460px] rounded-xl bg-bg-surface p-24 shadow-lg">
        <h2 id="new-cl" className="text-[22px] font-bold">
          {t('admin.cl.create_title')}
        </h2>
        <p className="mt-4 text-latin-label-sm text-text-secondary">{t('admin.cl.create_body')}</p>
        {error && (
          <div className="mt-12">
            <ErrorBanner>{error}</ErrorBanner>
          </div>
        )}
        <label className="mt-16 block text-latin-label-sm font-semibold">
          {t('admin.cl.name')}
          <input ref={ref} value={name} onChange={(e) => setName(e.target.value)} maxLength={120} placeholder="AC service check" className={field} />
        </label>
        <label className="mt-12 block text-latin-label-sm font-semibold">
          {t('admin.cl.f_trade')}
          <select value={trade} onChange={(e) => setTrade(e.target.value)} className={field}>
            {trades.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </label>
        <label className="mt-12 block text-latin-label-sm font-semibold">
          {t('admin.cl.minutes')}
          <input type="number" min={1} max={240} inputMode="numeric" value={minutes} onChange={(e) => setMinutes(e.target.value)} className={field} />
        </label>
        <div className="mt-20 flex flex-col-reverse gap-12 sm:flex-row sm:justify-end">
          <button type="button" onClick={onClose} className="kn-btn h-[44px] rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold hover:bg-cream-300">
            {t('admin.cl.cancel')}
          </button>
          <button type="submit" disabled={busy} className="kn-btn inline-flex h-[44px] items-center justify-center gap-8 rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-60">
            {busy && <Spinner />}
            {t('admin.cl.create')}
          </button>
        </div>
      </form>
    </div>
  );
}

/** A23 Checklist templates: KaamNishaan's own checklists and how far their translations are. */
export function ChecklistTemplates({ t, lang }: { t: T; lang: Lang }) {
  const s = new URLSearchParams(window.location.search);
  const [tab, setTab] = useState<Tab>(TABS.includes(s.get('tab') as Tab) ? (s.get('tab') as Tab) : 'all');
  const [trade, setTrade] = useState(s.get('trade') ?? '');
  const [state, setState] = useState(s.get('language_state') ?? '');
  const [typed, setTyped] = useState(s.get('q') ?? '');
  const [q, setQ] = useState(typed);
  const [data, setData] = useState<ChecklistList | null>(null);
  const [error, setError] = useState(false);
  const [creating, setCreating] = useState(false);
  const canEdit = session.get()?.staff.role !== 'support';

  useEffect(() => {
    const p = new URLSearchParams();
    if (tab !== 'all') p.set('tab', tab);
    if (trade) p.set('trade', trade);
    if (state) p.set('language_state', state);
    if (q.trim()) p.set('q', q.trim());
    window.history.replaceState(null, '', `/checklist-templates${p.toString() ? `?${p}` : ''}`);
    p.set('locale', lang);
    setError(false);
    api<ChecklistList>(`/admin/checklist-templates?${p}`)
      .then(setData)
      .catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, [tab, trade, state, q, lang]);
  useEffect(() => {
    const id = window.setTimeout(() => setQ(typed), 300);
    return () => window.clearTimeout(id);
  }, [typed]);

  const tabCount = (x: Tab) => (!data ? null : x === 'all' ? data.counts.all : x === 'needs_translation' ? data.counts.needs_translation : x === 'drafts' ? data.counts.drafts : null);
  const row = (r: ChecklistRow, i: number) => (
    <tr key={r.id} className="kn-in cursor-pointer border-t border-border-default transition-colors hover:bg-cream-100" style={{ ['--d' as string]: `${Math.min(i * 30, 400)}ms` }} onClick={() => navigate(`/checklist-templates/${r.id}`)}>
      <td className="py-12 pl-20 pr-16">
        <a href={`/checklist-templates/${r.id}`} onClick={(e) => e.preventDefault()} className="font-semibold">
          {r.name}
        </a>
        <p className="text-[13px] text-text-secondary">
          {plural(t, 'admin.cl.n_questions', r.question_count, { n: num(r.question_count, lang) })}
          {r.photo_questions > 0 && ` · ${t('admin.cl.n_photos', { n: num(r.photo_questions, lang) })}`}
        </p>
      </td>
      <td className="px-16 py-12">{r.trade_name ?? '—'}</td>
      <td className="px-16 py-12 tabular-nums">{num(r.question_count, lang)}</td>
      <td className="px-16 py-12">
        <span className="flex flex-wrap items-center gap-8">
          <LangBadge t={t} langs={r.languages} />
          {r.status !== 'published' && <span className="rounded-full bg-cream-200 px-[10px] py-[3px] text-[13px] font-semibold text-taupe-550">{t(`admin.cl.st.${r.status}`)}</span>}
        </span>
      </td>
      <td className="px-16 py-12">{plural(t, 'admin.dash.n_companies', r.used_by, { n: num(r.used_by, lang) })}</td>
      <td className="px-16 py-12 text-text-secondary">{day(r.updated_at, lang, { year: undefined })}</td>
    </tr>
  );

  return (
    <div className="flex flex-col gap-16">
      <div className="flex flex-wrap items-center justify-between gap-12">
        <div role="tablist" aria-label={t('admin.nav.checklists')} className="kn-in -mx-4 flex gap-8 overflow-x-auto px-4 pb-4">
          {TABS.map((x) => {
            const on = tab === x;
            const n = tabCount(x);
            return (
              <button key={x} role="tab" aria-selected={on} type="button" onClick={() => setTab(x)} className={cx('kn-btn h-[36px] shrink-0 rounded-full border px-16 text-latin-label-sm font-semibold transition-colors', on ? 'border-espresso-950 bg-espresso-950 text-cream-50' : 'border-border-default bg-bg-surface hover:border-mocha-500')}>
                {t(`admin.cl.tab.${x}`)}
                {n !== null && <span className={cx('ml-[6px] tabular-nums', on ? 'text-cream-300' : 'text-text-secondary')}>{num(n, lang)}</span>}
              </button>
            );
          })}
        </div>
        {canEdit && (
          <button type="button" onClick={() => setCreating(true)} disabled={!data} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-60">
            <Plus width={18} height={18} aria-hidden />
            {t('admin.cl.new')}
          </button>
        )}
      </div>

      <div className="kn-in flex flex-wrap items-center gap-12" style={{ ['--d' as string]: '60ms' }}>
        <label className="relative min-w-[240px] flex-1">
          <span className="sr-only">{t('admin.cl.search')}</span>
          <Search width={18} height={18} className="pointer-events-none absolute left-12 top-1/2 -translate-y-1/2 text-text-secondary" aria-hidden />
          <input type="search" value={typed} onChange={(e) => setTyped(e.target.value)} placeholder={t('admin.cl.search')} className="h-[44px] w-full rounded-lg border border-border-strong bg-bg-surface pl-[40px] pr-12 text-latin-label-sm placeholder:text-taupe-500 hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring" />
        </label>
        <FilterSelect label={t('admin.cl.f_trade')} value={trade} allLabel={t('admin.co.f_all')} options={data?.trades ?? []} onChange={setTrade} />
        <FilterSelect label={t('admin.cl.f_lang')} value={state} allLabel={t('admin.co.f_all')} options={(['missing', 'review', 'ready'] as const).map((v) => ({ value: v, label: t(`admin.cl.ls.${v}`) }))} onChange={setState} />
      </div>

      {error && (
        <p role="alert" className="rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">
          {t('admin.err.load')}
        </p>
      )}

      {!data ? (
        <div aria-busy="true" className="kn-shimmer h-[360px] rounded-xl bg-bg-surface" />
      ) : data.items.length === 0 ? (
        <div className="kn-in flex flex-col items-center rounded-xl border border-border-default bg-bg-surface px-24 py-48 text-center">
          <p className="text-latin-body text-text-secondary">{t('admin.cl.empty')}</p>
          {(trade || state || q) && (
            <button type="button" onClick={() => (setTrade(''), setState(''), setTyped(''), setQ(''))} className="kn-btn mt-16 inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold">
              <X width={16} height={16} aria-hidden />
              {t('admin.co.clear')}
            </button>
          )}
        </div>
      ) : (
        <div className="kn-in overflow-hidden rounded-xl border border-border-default bg-bg-surface" style={{ ['--d' as string]: '120ms' }}>
          <div className="overflow-x-auto">
            <table className="w-full min-w-[880px] text-left text-[14px]">
              <thead className="bg-bg-subtle text-[13px] text-text-secondary">
                <tr>
                  {(['c_template', 'c_trade', 'c_questions', 'c_translations', 'c_used', 'c_updated'] as const).map((c, i) => (
                    <th key={c} scope="col" className={cx('px-16 py-12 font-semibold', i === 0 && 'pl-20')}>
                      {t(`admin.cl.${c}`)}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {tab === 'by_trade'
                  ? data.items.map((r, i) => (
                      <Fragment key={r.id}>
                        {(i === 0 || data.items[i - 1].trade !== r.trade) && (
                          <tr className="border-t border-border-default bg-cream-100">
                            <th colSpan={6} scope="colgroup" className="px-20 py-8 text-left text-[13px] font-semibold uppercase tracking-wide text-mocha-700">
                              {r.trade_name ?? '—'}
                            </th>
                          </tr>
                        )}
                        {row(r, i)}
                      </Fragment>
                    ))
                  : data.items.map(row)}
              </tbody>
            </table>
          </div>
        </div>
      )}
      {creating && data && <CreateDialog t={t} lang={lang} trades={data.trades} onClose={() => setCreating(false)} />}
    </div>
  );
}
