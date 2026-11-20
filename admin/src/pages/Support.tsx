import { Check, ChevronLeft, ChevronRight, Download, Inbox, Lock, Search, Send } from 'lucide-react';
import { useCallback, useEffect, useRef, useState } from 'react';

import { api, ApiError, download } from '../lib/api';
import { ago, clock, day, num, type Lang, type T } from '../lib/i18n';
import type { AdminTicketDetail, AdminTicketList, AdminTicketRow, TicketStatus } from '../lib/types';
import { cx, ErrorBanner, Initials, Link, navigate, Spinner } from '../ui';

const PAGE_SIZE = 25;
const TABS = ['open', 'waiting', 'solved', 'all'] as const;
type Tab = (typeof TABS)[number];
const pill = 'inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold';
const at = (iso: string, lang: Lang) => `${day(iso, lang, { year: undefined })}, ${clock(iso, lang)}`;

function StatusPill({ t, lang, r }: { t: T; lang: Lang; r: AdminTicketRow }) {
  if (r.status === 'solved') return <span className={cx(pill, 'bg-status-success-bg text-status-success')}>{t('admin.su.st.solved')}</span>;
  if (r.status === 'waiting') return <span className={cx(pill, 'bg-status-warning-bg text-status-warning')}>{t('admin.su.st.waiting')}</span>;
  return <span className={cx(pill, 'bg-status-danger-bg text-status-danger')}>{t('admin.su.st.open_for', { ago: ago(r.last_message_at, lang) })}</span>;
}

/** The status, as plain text of the next action, for staff. */
function Detail({ t, lang, id, onChanged }: { t: T; lang: Lang; id: string; onChanged: (d: AdminTicketDetail) => void }) {
  const [d, setD] = useState<AdminTicketDetail | null>(null);
  const [error, setError] = useState(false);
  const [text, setText] = useState('');
  const [internal, setInternal] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const [problem, setProblem] = useState<string | null>(null);
  const end = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setD(null);
    setError(false);
    api<AdminTicketDetail>(`/admin/support/${id}?locale=${lang}`).then(setD).catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, [id, lang]);
  useEffect(() => {
    end.current?.scrollIntoView({ block: 'nearest' });
  }, [d?.messages.length]);

  const take = (x: AdminTicketDetail) => {
    setD(x);
    onChanged(x);
  };
  const send = async (solve: boolean) => {
    setBusy(solve ? 'solve' : 'send');
    setProblem(null);
    try {
      take(await api<AdminTicketDetail>(`/admin/support/${id}/messages?locale=${lang}`, { method: 'POST', body: { body: text.trim(), internal, solve: solve && !internal } }));
      setText('');
    } catch {
      setProblem(t('admin.err.generic'));
    } finally {
      setBusy(null);
    }
  };
  const patch = async (body: { status?: TicketStatus; priority?: 'normal' | 'high' }, key: string) => {
    setBusy(key);
    setProblem(null);
    try {
      take(await api<AdminTicketDetail>(`/admin/support/${id}?locale=${lang}`, { method: 'PATCH', body }));
    } catch {
      setProblem(t('admin.err.generic'));
    } finally {
      setBusy(null);
    }
  };

  if (error) return <p className="p-24 text-latin-label-sm text-status-danger">{t('admin.err.load')}</p>;
  if (!d) return <div aria-busy="true" className="kn-shimmer m-20 h-[360px] rounded-lg bg-bg-subtle" />;

  return (
    <div className="kn-in flex flex-col gap-16 p-20 sm:p-24">
      <div>
        <h2 className="break-words text-[22px] font-bold leading-[30px]">#{d.number} · {d.subject}</h2>
        <div className="mt-8 flex flex-wrap items-center gap-8 text-[13px]">
          <StatusPill t={t} lang={lang} r={d} />
          {d.priority === 'high' && <span className={cx(pill, 'bg-status-danger-bg text-status-danger')}>{t('admin.su.high')}</span>}
          <span className={cx(pill, 'bg-bg-subtle text-mocha-700')}>{t(`admin.su.cat.${d.category}`)}</span>
          {d.company && (
            <Link to={`/companies/${d.company_id}`} className={cx(pill, 'bg-bg-subtle text-mocha-700 hover:underline')}>
              {[d.company, d.plan].filter(Boolean).join(' · ')}
            </Link>
          )}
          {d.job_id && <Link to={`/jobs/${d.job_id}`} className={cx(pill, 'bg-bg-subtle text-mocha-700 hover:underline')}>{t('admin.su.job', { n: d.job_number ?? '' })}</Link>}
          {d.company_status === 'suspended' && <span className={cx(pill, 'bg-status-danger-bg text-status-danger')}>{t('admin.co.st.suspended')}</span>}
        </div>
        <p className="mt-8 text-[13px] text-text-secondary">
          {[d.person, d.person_role && t(`admin.ro.col.${d.person_role}`), d.person_phone, t(`lang.${d.lang}`), d.app_version && t('admin.su.app', { v: d.app_version })].filter(Boolean).join(' · ')}
        </p>
      </div>

      <ol className="flex flex-col gap-12">
        {d.messages.map((m) => (
          <li key={m.id} className="flex items-start gap-12">
            <Initials name={m.author ?? 'KaamNishaan'} className={cx('h-[36px] w-[36px] shrink-0 rounded-full text-[13px]', m.from_support ? 'bg-espresso-950 text-cream-50' : 'bg-cream-300 text-mocha-700')} />
            <div className={cx('min-w-0 flex-1 rounded-xl px-16 py-12', m.internal ? 'border border-dashed border-status-warning bg-status-warning-bg' : m.from_support ? 'bg-bg-subtle' : 'bg-cream-200')}>
              <p className="flex flex-wrap items-center gap-4 text-[13px] text-text-secondary">
                {m.internal && <Lock width={12} height={12} aria-hidden />}
                {m.from_support ? t(m.internal ? 'admin.su.note_by' : 'admin.su.reply_by', { who: m.author ?? '—' }) : m.author ?? t('admin.su.someone')} · {at(m.created_at, lang)}
              </p>
              <p className="mt-4 whitespace-pre-line break-words text-latin-body">{m.body}</p>
            </div>
          </li>
        ))}
      </ol>
      <div ref={end} />

      <div className="border-t border-border-default pt-16">
        <div role="tablist" aria-label={t('admin.su.reply')} className="flex gap-8">
          {([false, true] as const).map((x) => (
            <button key={String(x)} role="tab" aria-selected={internal === x} type="button" onClick={() => setInternal(x)} className={cx('kn-btn h-[32px] rounded-full border px-12 text-[13px] font-semibold', internal === x ? 'border-espresso-950 bg-espresso-950 text-cream-50' : 'border-border-default hover:border-mocha-500')}>
              {t(x ? 'admin.su.tab_note' : 'admin.su.tab_reply')}
            </button>
          ))}
        </div>
        <label htmlFor="ticket-reply" className="sr-only">{t('admin.su.reply')}</label>
        <textarea id="ticket-reply" value={text} maxLength={4000} rows={4} onChange={(e) => setText(e.target.value)} placeholder={t(internal ? 'admin.su.note_hint' : 'admin.su.reply_hint')} className={cx('mt-12 w-full rounded-lg border px-16 py-12 text-latin-body placeholder:text-taupe-500 hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring', internal ? 'border-status-warning bg-status-warning-bg' : 'border-border-strong bg-bg-surface')} />
        <p className="mt-4 text-[13px] text-text-secondary">{t(internal ? 'admin.su.note_info' : 'admin.su.reply_info')}</p>
        {problem && <div className="mt-8"><ErrorBanner>{problem}</ErrorBanner></div>}
        <div className="mt-12 flex flex-wrap gap-12">
          <button type="button" disabled={!text.trim() || !!busy} onClick={() => void send(false)} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-50">
            {busy === 'send' ? <Spinner /> : internal ? <Lock width={16} height={16} aria-hidden /> : <Send width={16} height={16} aria-hidden />}
            {t(internal ? 'admin.su.add_note' : 'admin.su.send')}
          </button>
          {!internal && (
            <button type="button" disabled={!text.trim() || !!busy} onClick={() => void send(true)} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-50">
              {busy === 'solve' ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
              {t('admin.su.send_solve')}
            </button>
          )}
          {d.status !== 'solved' ? (
            <button type="button" disabled={!!busy} onClick={() => void patch({ status: 'solved' }, 'solved')} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg border border-border-default px-16 text-latin-label-sm font-semibold hover:border-mocha-500 disabled:opacity-50">
              {busy === 'solved' ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
              {t('admin.su.mark_solved')}
            </button>
          ) : (
            <button type="button" disabled={!!busy} onClick={() => void patch({ status: 'open' }, 'open')} className="kn-btn inline-flex h-[44px] items-center rounded-lg border border-border-default px-16 text-latin-label-sm font-semibold hover:border-mocha-500 disabled:opacity-50">
              {t('admin.su.reopen')}
            </button>
          )}
          <button type="button" disabled={!!busy} onClick={() => void patch({ priority: d.priority === 'high' ? 'normal' : 'high' }, 'prio')} className="kn-btn inline-flex h-[44px] items-center rounded-lg px-16 text-latin-label-sm font-semibold text-text-secondary hover:bg-bg-subtle disabled:opacity-50">
            {t(d.priority === 'high' ? 'admin.su.normal' : 'admin.su.make_high')}
          </button>
        </div>
      </div>
    </div>
  );
}

/** The top-bar Export button: every ticket on the current tab and search, as a CSV. */
export function ExportSupport({ t }: { t: T }) {
  const [busy, setBusy] = useState(false);
  return (
    <button
      type="button"
      disabled={busy}
      onClick={async () => {
        setBusy(true);
        try {
          const s = new URLSearchParams(window.location.search);
          const p = new URLSearchParams({ tab: s.get('tab') ?? 'open' });
          if (s.get('q')) p.set('q', s.get('q')!);
          await download(`/admin/support.csv?${p}`, 'kaamnishaan-support.csv');
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

/** A28 Support tickets: help requests from the app (list on the left, the ticket on the right). */
export function Support({ t, lang, id }: { t: T; lang: Lang; id: string | null }) {
  const read = () => {
    const s = new URLSearchParams(window.location.search);
    const tab = s.get('tab') as Tab;
    return { tab: TABS.includes(tab) ? tab : ('open' as Tab), q: s.get('q') ?? '', page: Math.max(1, Number(s.get('page')) || 1) };
  };
  const [f, setF] = useState(read);
  const [typed, setTyped] = useState(f.q);
  const [data, setData] = useState<AdminTicketList | null>(null);
  const [error, setError] = useState(false);
  const seq = useRef(0);

  const qs = useCallback((x: typeof f) => {
    const p = new URLSearchParams();
    if (x.tab !== 'open') p.set('tab', x.tab);
    if (x.q.trim()) p.set('q', x.q.trim());
    if (x.page > 1) p.set('page', String(x.page));
    return p.toString();
  }, []);

  const load = useCallback(() => {
    const n = ++seq.current;
    setError(false);
    api<AdminTicketList>(`/admin/support?tab=${f.tab}${f.q.trim() ? `&q=${encodeURIComponent(f.q.trim())}` : ''}&page=${f.page}&page_size=${PAGE_SIZE}`)
      .then((d) => n === seq.current && setData(d))
      .catch((e) => n === seq.current && !(e instanceof ApiError && e.status === 401) && setError(true));
  }, [f]);
  useEffect(() => {
    const q = qs(f);
    window.history.replaceState(null, '', `/support${id ? `/${id}` : ''}${q ? `?${q}` : ''}`);
  }, [f, id, qs]);
  useEffect(load, [load]);
  useEffect(() => {
    if (typed === f.q) return;
    const tm = window.setTimeout(() => setF((x) => ({ ...x, q: typed, page: 1 })), 300);
    return () => window.clearTimeout(tm);
  }, [typed, f.q]);

  const open = (ticketId: string) => {
    const q = qs(f);
    navigate(`/support/${ticketId}${q ? `?${q}` : ''}`);
  };
  const last = data ? Math.max(1, Math.ceil(data.total / data.page_size)) : 1;
  const count = (tab: Tab) => (data ? (tab === 'all' ? data.counts.open + data.counts.waiting + data.counts.solved : data.counts[tab]) : 0);

  return (
    <div className="flex flex-col gap-16">
      <div role="tablist" aria-label={t('admin.su.tabs')} className="kn-in -mx-4 flex gap-8 overflow-x-auto px-4 pb-4">
        {TABS.map((tab) => {
          const on = f.tab === tab;
          return (
            <button key={tab} role="tab" aria-selected={on} type="button" onClick={() => setF({ tab, q: f.q, page: 1 })} className={cx('kn-btn h-[36px] shrink-0 rounded-full border px-16 text-latin-label-sm font-semibold transition-colors', on ? 'border-espresso-950 bg-espresso-950 text-cream-50' : 'border-border-default bg-bg-surface hover:border-mocha-500')}>
              {t(`admin.su.tab.${tab}`)}
              {data && <span className={cx('ml-[6px] tabular-nums', on ? 'text-cream-300' : 'text-text-secondary')}>{num(count(tab), lang)}</span>}
            </button>
          );
        })}
        {data && data.counts.high > 0 && <span className={cx(pill, 'self-center bg-status-danger-bg text-status-danger')}>{t('admin.su.high_n', { n: num(data.counts.high, lang) })}</span>}
      </div>

      {error && (
        <p role="alert" className="rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">
          {t('admin.err.load')}{' '}
          <button type="button" className="underline" onClick={load}>{t('admin.retry')}</button>
        </p>
      )}

      <div className="grid items-start gap-16 lg:grid-cols-[400px_1fr]">
        <section className={cx('kn-in overflow-hidden rounded-xl border border-border-default bg-bg-surface', id && 'hidden lg:block')}>
          <label className="relative block border-b border-border-default p-12">
            <span className="sr-only">{t('admin.su.search')}</span>
            <Search width={18} height={18} className="pointer-events-none absolute left-[24px] top-1/2 -translate-y-1/2 text-text-secondary" aria-hidden />
            <input type="search" value={typed} onChange={(e) => setTyped(e.target.value)} placeholder={t('admin.su.search')} className="h-[40px] w-full rounded-lg border border-border-strong bg-bg-surface pl-[38px] pr-12 text-[14px] placeholder:text-taupe-500 hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring" />
          </label>
          {!data ? (
            <div aria-busy="true" className="kn-shimmer m-12 h-[320px] rounded-lg bg-bg-subtle" />
          ) : data.items.length ? (
            <>
              <ul>
                {data.items.map((r, i) => (
                  <li key={r.id}>
                    <button type="button" onClick={() => open(r.id)} aria-current={r.id === id ? 'true' : undefined} className={cx('kn-in flex w-full flex-col gap-4 border-b border-border-default px-16 py-12 text-left transition-colors', r.id === id ? 'bg-bg-subtle' : 'hover:bg-cream-100')} style={{ ['--d' as string]: `${Math.min(i * 30, 300)}ms` }}>
                      <span className="flex flex-wrap items-center gap-8 text-[13px] text-text-secondary">
                        #{r.number}
                        <StatusPill t={t} lang={lang} r={r} />
                        {r.priority === 'high' && r.status !== 'solved' && <span className={cx(pill, 'bg-status-danger-bg text-status-danger')}>{t('admin.su.high')}</span>}
                      </span>
                      <span className="truncate text-[14px] font-semibold">{r.subject}</span>
                      <span className="truncate text-[13px] text-text-secondary">{[r.company, r.person].filter(Boolean).join(' · ')}</span>
                    </button>
                  </li>
                ))}
              </ul>
              {last > 1 && (
                <div className="flex items-center justify-between gap-8 px-16 py-12 text-[13px] text-text-secondary">
                  <button type="button" disabled={f.page <= 1} onClick={() => setF({ ...f, page: f.page - 1 })} aria-label={t('admin.co.prev')} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md border border-border-default disabled:opacity-40"><ChevronLeft width={16} height={16} aria-hidden /></button>
                  {t('admin.co.page', { n: `${num(f.page, lang)} / ${num(last, lang)}` })}
                  <button type="button" disabled={f.page >= last} onClick={() => setF({ ...f, page: f.page + 1 })} aria-label={t('admin.co.next')} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md border border-border-default disabled:opacity-40"><ChevronRight width={16} height={16} aria-hidden /></button>
                </div>
              )}
            </>
          ) : (
            <div className="flex flex-col items-center px-24 py-48 text-center">
              <span className="kn-pop inline-flex h-[64px] w-[64px] items-center justify-center rounded-full bg-bg-subtle text-mocha-700"><Inbox width={26} height={26} aria-hidden /></span>
              <p className="mt-12 max-w-[280px] text-latin-label-sm text-text-secondary">{f.tab === 'open' && !f.q ? t('admin.su.empty_open') : t('admin.su.empty')}</p>
            </div>
          )}
        </section>

        <section className={cx('rounded-xl border border-border-default bg-bg-surface', !id && 'hidden lg:block')}>
          {id ? (
            <>
              <div className="px-20 pt-16 lg:hidden">
                <Link to={`/support${qs(f) ? `?${qs(f)}` : ''}`} className="inline-flex items-center gap-4 text-latin-label-sm font-semibold text-text-secondary">
                  <ChevronLeft width={16} height={16} aria-hidden />
                  {t('admin.su.back')}
                </Link>
              </div>
              <Detail key={id} t={t} lang={lang} id={id} onChanged={(x) => setData((d) => (d ? { ...d, items: d.items.map((i) => (i.id === x.id ? { ...i, status: x.status, priority: x.priority, last_message_at: x.last_message_at } : i)) } : d))} />
            </>
          ) : (
            <p className="flex min-h-[320px] items-center justify-center p-24 text-latin-label-sm text-text-secondary">{t('admin.su.pick')}</p>
          )}
        </section>
      </div>
    </div>
  );
}
