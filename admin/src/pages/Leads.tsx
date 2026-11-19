import { CalendarClock, Check, ChevronLeft, ChevronRight, Download, Inbox, Mail, MessageSquareText, Phone, Search } from 'lucide-react';
import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';

import { api, ApiError, download } from '../lib/api';
import { ago, day, num, type Lang, type T } from '../lib/i18n';
import type { LeadDetail, LeadList, LeadRow, LeadStatus } from '../lib/types';
import { cx, ErrorBanner, Link, navigate, Spinner } from '../ui';

const TABS = ['new', 'demo', 'contact', 'newsletter', 'done'] as const;
type Tab = (typeof TABS)[number];
const STATUSES: LeadStatus[] = ['new', 'contacted', 'done', 'spam'];
const PAGE_SIZE = 20;
const ticket = (n: number) => `KN-${n}`;
const demoTime = (iso: string, lang: Lang) => day(iso, lang, { weekday: 'short', year: undefined, hour: 'numeric', minute: '2-digit' });

const STATUS_LOOK: Record<LeadStatus, string> = {
  new: 'bg-status-danger-bg text-status-danger',
  contacted: 'bg-status-warning-bg text-status-warning',
  done: 'bg-status-success-bg text-status-success',
  spam: 'bg-cream-200 text-taupe-550',
};

function StatusPill({ t, status, extra }: { t: T; status: LeadStatus; extra?: string }) {
  return (
    <span className={cx('inline-flex whitespace-nowrap rounded-full px-[10px] py-[2px] text-[12px] font-semibold', STATUS_LOOK[status])}>
      {t(`admin.ld.st.${status}`)}
      {extra && ` · ${extra}`}
    </span>
  );
}

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-16 py-8">
      <dt className="shrink-0 text-[14px] text-text-secondary">{label}</dt>
      <dd className="min-w-0 break-words text-right text-[14px] font-semibold">{children}</dd>
    </div>
  );
}

/** The right side: everything the person sent, plus status and a staff-only note. */
function Detail({ t, lang, id, onChanged }: { t: T; lang: Lang; id: string; onChanged: (row: LeadDetail) => void }) {
  const [d, setD] = useState<LeadDetail | null>(null);
  const [error, setError] = useState<'missing' | 'load' | null>(null);
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState<'status' | 'note' | null>(null);
  const [saved, setSaved] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  const load = useCallback(() => {
    setError(null);
    setD(null);
    api<LeadDetail>(`/admin/leads/${id}?locale=${lang}`)
      .then((x) => {
        setD(x);
        setNote(x.note ?? '');
      })
      .catch((e) => {
        if (e instanceof ApiError && (e.status === 404 || e.status === 422)) setError('missing');
        else if (!(e instanceof ApiError && e.status === 401)) setError('load');
      });
  }, [id, lang]);
  useEffect(load, [load]);

  const save = async (body: { status?: LeadStatus; note?: string }, which: 'status' | 'note') => {
    setBusy(which);
    setSaveError(null);
    try {
      const x = await api<LeadDetail>(`/admin/leads/${id}?locale=${lang}`, { method: 'PATCH', body });
      setD(x);
      setNote(x.note ?? '');
      onChanged(x);
      if (which === 'note') {
        setSaved(true);
        window.setTimeout(() => setSaved(false), 1800);
      }
    } catch (e) {
      setSaveError(t(e instanceof ApiError && e.status === 0 ? 'admin.err.offline' : 'admin.err.generic'));
    } finally {
      setBusy(null);
    }
  };

  if (error) return <p className="p-24 text-latin-body text-text-secondary">{t(error === 'missing' ? 'admin.ld.not_found' : 'admin.err.load')}</p>;
  if (!d) return <div aria-busy="true" className="kn-shimmer m-24 h-[360px] rounded-lg bg-bg-subtle" />;

  return (
    <div key={d.id} className="kn-in p-20 sm:p-24">
      <h2 className="text-[22px] font-bold leading-[30px]">
        <span className="text-text-secondary">{ticket(d.number)} · </span>
        {d.kind === 'newsletter' ? d.email : d.company || d.name}
      </h2>
      <div className="mt-8 flex flex-wrap gap-8">
        <span className="rounded-full bg-bg-subtle px-[10px] py-[2px] text-[12px] font-semibold text-mocha-700">{t(`admin.ld.kind.${d.kind}`)}</span>
        {d.kind !== 'newsletter' && <StatusPill t={t} status={d.status} />}
        {d.topic && <span className="rounded-full bg-bg-subtle px-[10px] py-[2px] text-[12px] font-semibold text-mocha-700">{t(`site.ct.topic.${d.topic}`)}</span>}
      </div>

      {d.company_id && (
        <p className="mt-16 flex items-center gap-8 rounded-lg bg-status-info-bg px-12 py-8 text-[14px] font-semibold text-status-info">
          <Check width={16} height={16} aria-hidden />
          <Link to={`/companies/${d.company_id}`} className="kn-link">
            {t('admin.ld.signed_up', { name: d.company_name ?? '' })}
          </Link>
        </p>
      )}

      <dl className="mt-12">
        {d.kind !== 'newsletter' && <Row label={t('admin.us.c_name')}>{d.name}</Row>}
        <Row label={t('admin.ld.email')}>{d.email}</Row>
        {d.phone && <Row label={t('admin.ld.phone')}>{d.phone}</Row>}
        {d.company && <Row label={t('admin.ld.company')}>{d.company}</Row>}
        {d.team_size && <Row label={t('admin.ld.team')}>{t('admin.ld.people', { n: d.team_size })}</Row>}
        {d.trade && <Row label={t('admin.ld.trade')}>{d.trade}</Row>}
        {d.starts_at && <Row label={t('admin.ld.when')}>{demoTime(d.starts_at, lang)}</Row>}
        <Row label={t('admin.ld.lang')}>{t(`lang.${d.lang}`)}</Row>
        <Row label={t('admin.ld.received')}>
          {day(d.created_at, lang)} · {ago(d.created_at, lang)}
        </Row>
      </dl>

      {d.message && (
        <>
          <h3 className="mt-16 text-[14px] font-semibold text-text-secondary">{t('admin.ld.message')}</h3>
          <p className="mt-8 whitespace-pre-wrap break-words rounded-lg bg-bg-subtle p-16 text-latin-body">{d.message}</p>
        </>
      )}

      <div className="mt-16 flex flex-wrap gap-12">
        <a href={`mailto:${d.email}?subject=${encodeURIComponent(`KaamNishaan · ${ticket(d.number)}`)}`} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed">
          <Mail width={16} height={16} aria-hidden />
          {t('admin.ld.reply')}
        </a>
        {d.phone && (
          <a href={`tel:${d.phone.replace(/\s/g, '')}`} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300">
            <Phone width={16} height={16} aria-hidden />
            {t('admin.ld.call')}
          </a>
        )}
      </div>

      {d.kind !== 'newsletter' && (
        <div className="mt-24 border-t border-border-default pt-20">
          <p id="lead-status" className="text-latin-label-sm font-semibold">
            {t('admin.ld.status')}
          </p>
          <div role="radiogroup" aria-labelledby="lead-status" className="mt-8 flex flex-wrap gap-8">
            {STATUSES.map((s) => (
              <button
                key={s}
                type="button"
                role="radio"
                aria-checked={d.status === s}
                disabled={busy !== null}
                onClick={() => d.status !== s && void save({ status: s }, 'status')}
                className={cx('kn-btn h-[36px] rounded-full border px-16 text-latin-label-sm font-semibold transition-colors', d.status === s ? 'border-espresso-950 bg-espresso-950 text-cream-50' : 'border-border-default bg-bg-surface hover:border-mocha-500')}
              >
                {t(`admin.ld.st.${s}`)}
              </button>
            ))}
            {busy === 'status' && <Spinner className="self-center" />}
          </div>
          <label htmlFor="lead-note" className="mt-16 block text-latin-label-sm font-semibold">
            {t('admin.ld.note')}
          </label>
          <textarea id="lead-note" value={note} onChange={(e) => setNote(e.target.value)} maxLength={2000} rows={3} className="mt-8 w-full rounded-lg border border-border-strong bg-bg-surface p-12 text-latin-body hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring" />
          {saveError && (
            <div className="mt-8">
              <ErrorBanner>{saveError}</ErrorBanner>
            </div>
          )}
          <div className="mt-8 flex flex-wrap items-center justify-between gap-12">
            <p className="text-[13px] text-text-secondary">{d.handled_by && d.handled_at ? t('admin.ld.handled', { name: d.handled_by, when: ago(d.handled_at, lang) }) : ''}</p>
            <button type="button" disabled={busy !== null || note === (d.note ?? '')} onClick={() => void save({ note }, 'note')} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-50">
              {busy === 'note' ? <Spinner /> : saved ? <Check width={16} height={16} className="kn-pop" aria-hidden /> : null}
              <span aria-live="polite">{t(saved ? 'admin.ld.saved' : 'admin.ld.save')}</span>
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

/** Website leads (no Figma screen; laid out like A28 Support tickets): list on the left, the lead on the right. */
export function Leads({ t, lang, id }: { t: T; lang: Lang; id: string | null }) {
  const read = () => {
    const s = new URLSearchParams(window.location.search);
    const tab = s.get('tab') as Tab;
    return { tab: TABS.includes(tab) ? tab : ('new' as Tab), q: s.get('q') ?? '', page: Math.max(1, Number(s.get('page')) || 1) };
  };
  const [f, setF] = useState(read);
  const [typed, setTyped] = useState(f.q);
  const [data, setData] = useState<LeadList | null>(null);
  const [error, setError] = useState(false);
  const [exporting, setExporting] = useState(false);
  const seq = useRef(0);

  const qs = useCallback((x: typeof f) => {
    const p = new URLSearchParams();
    if (x.tab !== 'new') p.set('tab', x.tab);
    if (x.q.trim()) p.set('q', x.q.trim());
    if (x.page > 1) p.set('page', String(x.page));
    return p.toString();
  }, []);

  useEffect(() => {
    const q = qs(f);
    window.history.replaceState(null, '', `/leads${id ? `/${id}` : ''}${q ? `?${q}` : ''}`);
    const n = ++seq.current;
    setError(false);
    api<LeadList>(`/admin/leads?tab=${f.tab}${f.q.trim() ? `&q=${encodeURIComponent(f.q.trim())}` : ''}&page=${f.page}&page_size=${PAGE_SIZE}`)
      .then((d) => n === seq.current && setData(d))
      .catch((e) => n === seq.current && !(e instanceof ApiError && e.status === 401) && setError(true));
  }, [f, id, qs]);

  useEffect(() => {
    if (typed === f.q) return;
    const tm = window.setTimeout(() => setF((x) => ({ ...x, q: typed, page: 1 })), 300);
    return () => window.clearTimeout(tm);
  }, [typed, f.q]);

  const open = (leadId: string) => {
    const q = qs(f);
    navigate(`/leads/${leadId}${q ? `?${q}` : ''}`);
  };
  const onChanged = (x: LeadDetail) =>
    setData((d) => {
      if (!d) return d;
      const was = d.items.find((i) => i.id === x.id);
      const counts = { ...d.counts };
      if (was && was.status !== x.status && x.kind !== 'newsletter') {
        if (was.status === 'new') counts.new -= 1;
        else counts.done -= 1;
        if (x.status === 'new') counts.new += 1;
        else counts.done += 1;
      }
      return { ...d, counts, items: d.items.map((i) => (i.id === x.id ? { ...i, status: x.status } : i)) };
    });
  const last = data ? Math.max(1, Math.ceil(data.total / data.page_size)) : 1;

  const item = (r: LeadRow, i: number) => (
    <li key={r.id}>
      <button
        type="button"
        onClick={() => open(r.id)}
        aria-current={r.id === id ? 'true' : undefined}
        className={cx('kn-in flex w-full flex-col gap-4 border-b border-border-default px-16 py-12 text-left transition-colors', r.id === id ? 'bg-bg-subtle' : 'hover:bg-cream-100')}
        style={{ ['--d' as string]: `${Math.min(i * 30, 300)}ms` }}
      >
        <span className="flex flex-wrap items-center gap-8 text-[13px] text-text-secondary">
          {ticket(r.number)}
          {r.kind === 'newsletter' ? null : r.kind === 'demo' && r.starts_at ? (
            <StatusPill t={t} status={r.status} extra={t('admin.ld.demo_at', { when: demoTime(r.starts_at, lang) })} />
          ) : (
            <StatusPill t={t} status={r.status} extra={r.status === 'new' ? ago(r.created_at, lang) : undefined} />
          )}
        </span>
        <span className="flex items-center gap-8 text-[14px] font-semibold">
          {r.kind === 'demo' ? <CalendarClock width={15} height={15} className="shrink-0 text-mocha-700" aria-hidden /> : r.kind === 'contact' ? <MessageSquareText width={15} height={15} className="shrink-0 text-mocha-700" aria-hidden /> : <Mail width={15} height={15} className="shrink-0 text-mocha-700" aria-hidden />}
          <span className="truncate">{r.kind === 'newsletter' ? r.email : r.preview ?? r.company ?? r.name}</span>
        </span>
        {r.kind !== 'newsletter' && <span className="truncate text-[13px] text-text-secondary">{[r.name, r.company].filter(Boolean).join(' · ')}</span>}
        {r.kind === 'newsletter' && <span className="text-[13px] text-text-secondary">{day(r.created_at, lang)}</span>}
      </button>
    </li>
  );

  return (
    <div className="flex flex-col gap-16">
      <div className="flex flex-wrap items-center justify-between gap-12">
        <div role="tablist" aria-label={t('admin.ld.tabs')} className="kn-in -mx-4 flex gap-8 overflow-x-auto px-4 pb-4">
          {TABS.map((tab) => {
            const on = f.tab === tab;
            return (
              <button key={tab} role="tab" aria-selected={on} type="button" onClick={() => setF({ tab, q: f.q, page: 1 })} className={cx('kn-btn h-[36px] shrink-0 rounded-full border px-16 text-latin-label-sm font-semibold transition-colors', on ? 'border-espresso-950 bg-espresso-950 text-cream-50' : 'border-border-default bg-bg-surface hover:border-mocha-500')}>
                {t(`admin.ld.tab.${tab}`)}
                {data && <span className={cx('ml-[6px] tabular-nums', on ? 'text-cream-300' : 'text-text-secondary')}>{num(data.counts[tab], lang)}</span>}
              </button>
            );
          })}
        </div>
        {f.tab === 'newsletter' && (
          <button
            type="button"
            disabled={exporting || !data?.counts.newsletter}
            onClick={async () => {
              setExporting(true);
              try {
                await download('/admin/leads/newsletter.csv', 'kaamnishaan-newsletter.csv');
              } catch {
                setError(true);
              } finally {
                setExporting(false);
              }
            }}
            className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg border border-border-default bg-bg-surface px-16 text-latin-label-sm font-semibold hover:border-mocha-500 disabled:opacity-50"
          >
            {exporting ? <Spinner /> : <Download width={16} height={16} aria-hidden />}
            {t('admin.ld.export')}
          </button>
        )}
      </div>

      {error && (
        <p role="alert" className="rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">
          {t('admin.err.load')}{' '}
          <button type="button" className="underline" onClick={() => setF({ ...f })}>
            {t('admin.retry')}
          </button>
        </p>
      )}

      <div className="grid items-start gap-16 lg:grid-cols-[380px_1fr]">
        {/* list (on a phone it hides while a lead is open) */}
        <section className={cx('kn-in overflow-hidden rounded-xl border border-border-default bg-bg-surface', id && 'hidden lg:block')}>
          <label className="relative block border-b border-border-default p-12">
            <span className="sr-only">{t('admin.ld.search')}</span>
            <Search width={18} height={18} className="pointer-events-none absolute left-[24px] top-1/2 -translate-y-1/2 text-text-secondary" aria-hidden />
            <input type="search" value={typed} onChange={(e) => setTyped(e.target.value)} placeholder={t('admin.ld.search')} className="h-[40px] w-full rounded-lg border border-border-strong bg-bg-surface pl-[38px] pr-12 text-[14px] placeholder:text-taupe-500 hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring" />
          </label>
          {!data ? (
            <div aria-busy="true" className="kn-shimmer m-12 h-[320px] rounded-lg bg-bg-subtle" />
          ) : data.items.length ? (
            <>
              <ul>{data.items.map(item)}</ul>
              {last > 1 && (
                <div className="flex items-center justify-between gap-8 px-16 py-12 text-[13px] text-text-secondary">
                  <button type="button" disabled={f.page <= 1} onClick={() => setF({ ...f, page: f.page - 1 })} aria-label={t('admin.co.prev')} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md border border-border-default disabled:opacity-40">
                    <ChevronLeft width={16} height={16} aria-hidden />
                  </button>
                  {t('admin.co.page', { n: `${num(f.page, lang)} / ${num(last, lang)}` })}
                  <button type="button" disabled={f.page >= last} onClick={() => setF({ ...f, page: f.page + 1 })} aria-label={t('admin.co.next')} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md border border-border-default disabled:opacity-40">
                    <ChevronRight width={16} height={16} aria-hidden />
                  </button>
                </div>
              )}
            </>
          ) : (
            <div className="flex flex-col items-center px-24 py-48 text-center">
              <span className="kn-pop inline-flex h-[64px] w-[64px] items-center justify-center rounded-full bg-bg-subtle text-mocha-700">
                <Inbox width={26} height={26} aria-hidden />
              </span>
              <p className="mt-12 max-w-[280px] text-latin-label-sm text-text-secondary">{f.tab === 'new' && !f.q ? t('admin.ld.empty_new') : t('admin.ld.empty')}</p>
            </div>
          )}
        </section>

        {/* the open lead */}
        <section className={cx('rounded-xl border border-border-default bg-bg-surface', !id && 'hidden lg:block')}>
          {id ? (
            <>
              <div className="px-20 pt-16 lg:hidden">
                <Link to={`/leads${qs(f) ? `?${qs(f)}` : ''}`} className="inline-flex items-center gap-4 text-latin-label-sm font-semibold text-text-secondary">
                  <ChevronLeft width={16} height={16} aria-hidden />
                  {t('admin.ld.back')}
                </Link>
              </div>
              <Detail key={id} t={t} lang={lang} id={id} onChanged={onChanged} />
            </>
          ) : (
            <p className="flex min-h-[320px] items-center justify-center p-24 text-latin-label-sm text-text-secondary">{t('admin.ld.pick')}</p>
          )}
        </section>
      </div>
    </div>
  );
}
