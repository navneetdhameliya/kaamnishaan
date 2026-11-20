import { Check, Clock, Megaphone, Send, X } from 'lucide-react';
import { useCallback, useEffect, useState } from 'react';

import { api, ApiError } from '../lib/api';
import { clock, day, LANGS, num, type Lang, type T } from '../lib/i18n';
import type { AdminAnnouncement, AdminNotificationsOut, Audience, CompanyList } from '../lib/types';
import { cx, ErrorBanner, inputCls, Spinner, Switch } from '../ui';
import { Panel } from './Dashboard';

const AUDIENCES: Audience[] = ['everyone', 'owners_managers', 'owners', 'company'];
const pill = 'inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold';
const at = (iso: string, lang: Lang) => `${day(iso, lang)}, ${clock(iso, lang)}`;
type Texts = Record<Lang, string>;
const empty = (): Texts => ({ en: '', hi: '', gu: '', es: '', fr: '' });

/** Picks one company by name for a company-only announcement. */
function CompanyPick({ t, value, onChange, disabled }: { t: T; value: { id: string; name: string } | null; onChange: (c: { id: string; name: string } | null) => void; disabled: boolean }) {
  const [q, setQ] = useState('');
  const [hits, setHits] = useState<{ id: string; name: string }[]>([]);
  useEffect(() => {
    if (q.trim().length < 2) return setHits([]);
    const tm = window.setTimeout(() => {
      api<CompanyList>(`/admin/companies?q=${encodeURIComponent(q.trim())}&page_size=6`)
        .then((d) => setHits(d.items.map((c) => ({ id: c.id, name: c.name }))))
        .catch(() => setHits([]));
    }, 250);
    return () => window.clearTimeout(tm);
  }, [q]);
  if (value)
    return (
      <p className="flex items-center justify-between gap-8 rounded-lg bg-bg-subtle px-16 py-12 text-latin-label-sm font-semibold">
        {value.name}
        <button type="button" disabled={disabled} onClick={() => onChange(null)} aria-label={t('admin.no.change_company')} className="kn-btn inline-flex h-[32px] w-[32px] items-center justify-center rounded-md hover:bg-cream-300">
          <X width={16} height={16} aria-hidden />
        </button>
      </p>
    );
  return (
    <div>
      <label htmlFor="ann-company" className="text-latin-label-sm font-semibold">{t('admin.no.company')}</label>
      <input id="ann-company" type="search" disabled={disabled} value={q} onChange={(e) => setQ(e.target.value)} placeholder={t('admin.no.company_hint')} className={cx(inputCls, 'mt-8 h-[44px]')} />
      {hits.length > 0 && (
        <ul className="kn-menu mt-4 overflow-hidden rounded-lg border border-border-default bg-bg-surface">
          {hits.map((c) => (
            <li key={c.id}>
              <button type="button" onClick={() => onChange(c)} className="w-full px-16 py-[10px] text-left text-[14px] hover:bg-cream-100">{c.name}</button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function AnnouncementRow({ t, lang, a, i, canAct, busy, onCancel }: { t: T; lang: Lang; a: AdminAnnouncement; i: number; canAct: boolean; busy: boolean; onCancel: () => void }) {
  const state = a.cancelled_at ? 'cancelled' : a.sent_at ? 'sent' : 'scheduled';
  return (
    <li className="kn-in flex flex-col gap-4 border-b border-border-default py-12 last:border-0 sm:flex-row sm:items-start sm:justify-between sm:gap-16" style={{ ['--d' as string]: `${Math.min(i * 40, 400)}ms` }}>
      <div className="min-w-0">
        <p className="flex flex-wrap items-center gap-8">
          <span className="truncate text-[15px] font-semibold">{a.title[lang] || a.title.en}</span>
          <span className={cx(pill, state === 'sent' ? 'bg-status-success-bg text-status-success' : state === 'scheduled' ? 'bg-status-warning-bg text-status-warning' : 'bg-bg-subtle text-text-secondary')}>{t(`admin.no.state.${state}`)}</span>
        </p>
        <p className="mt-2 line-clamp-2 text-[13px] text-text-secondary">{a.body[lang] || a.body.en}</p>
        <p className="mt-4 text-[13px] text-text-secondary">
          {[
            a.audience === 'company' ? a.company : t(`admin.no.aud.${a.audience}`),
            state === 'sent' ? t('admin.no.sent_to', { n: num(a.recipients, lang) }) : null,
            at(a.sent_at ?? a.send_at, lang),
            a.by,
            t('admin.no.langs', { n: num(Object.keys(a.title).length, lang) }),
          ].filter(Boolean).join(' · ')}
        </p>
      </div>
      {state === 'scheduled' && canAct && (
        <button type="button" disabled={busy} onClick={onCancel} className="kn-btn inline-flex h-[36px] shrink-0 items-center gap-8 self-start rounded-lg border border-border-default px-12 text-[13px] font-semibold hover:border-status-danger hover:text-status-danger disabled:opacity-50">
          {busy ? <Spinner /> : <X width={14} height={14} aria-hidden />}
          {t('admin.no.cancel')}
        </button>
      )}
    </li>
  );
}

/** A29 Notifications: which automatic in-app messages go out, and announcements to the app's Messages. */
export function Notifications({ t, lang }: { t: T; lang: Lang }) {
  const [data, setData] = useState<AdminNotificationsOut | null>(null);
  const [error, setError] = useState(false);
  const [saving, setSaving] = useState<string | null>(null);
  const [notice, setNotice] = useState<{ ok: boolean; text: string } | null>(null);

  const [audience, setAudience] = useState<Audience>('everyone');
  const [company, setCompany] = useState<{ id: string; name: string } | null>(null);
  const [tab, setTab] = useState<Lang>('en');
  const [title, setTitle] = useState<Texts>(empty);
  const [body, setBody] = useState<Texts>(empty);
  const [later, setLater] = useState(false);
  const [when, setWhen] = useState('');
  const [sending, setSending] = useState(false);
  const [problem, setProblem] = useState<string | null>(null);
  const [cancelling, setCancelling] = useState<string | null>(null);

  const load = useCallback(() => {
    setError(false);
    api<AdminNotificationsOut>('/admin/notifications').then(setData).catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, []);
  useEffect(load, [load]);

  const flip = async (kind: string, on: boolean) => {
    if (!data) return;
    const before = data;
    const rules = data.rules.map((r) => (r.kind === kind ? { ...r, on } : r));
    setData({ ...data, rules });
    setSaving(kind);
    setNotice(null);
    try {
      const next = await api<AdminNotificationsOut>('/admin/notifications/rules', { method: 'PUT', body: { on: Object.fromEntries(rules.filter((r) => r.available).map((r) => [r.kind, r.on])) } });
      setData(next);
      setNotice({ ok: true, text: t('admin.no.saved') });
    } catch {
      setData(before);
      setNotice({ ok: false, text: t('admin.err.generic') });
    } finally {
      setSaving(null);
    }
  };

  const ready = !!title.en.trim() && !!body.en.trim() && (audience !== 'company' || !!company) && (!later || !!when);
  const reach = audience === 'company' ? null : data?.audience_sizes[audience] ?? 0;
  const send = async () => {
    setSending(true);
    setProblem(null);
    try {
      const next = await api<AdminNotificationsOut>('/admin/announcements', {
        method: 'POST',
        body: { audience, company_id: audience === 'company' ? company?.id : null, title, body, send_at: later && when ? new Date(when).toISOString() : null },
      });
      setData(next);
      setTitle(empty());
      setBody(empty());
      setLater(false);
      setWhen('');
      setTab('en');
      setNotice({ ok: true, text: t(later ? 'admin.no.scheduled' : 'admin.no.sent', { n: num(next.announcements[0]?.recipients ?? 0, lang) }) });
    } catch (e) {
      setProblem(e instanceof ApiError && e.status === 422 ? t('admin.no.check') : t('admin.err.generic'));
    } finally {
      setSending(false);
    }
  };
  const cancel = async (id: string) => {
    setCancelling(id);
    try {
      setData(await api<AdminNotificationsOut>(`/admin/announcements/${id}`, { method: 'DELETE' }));
    } catch {
      setNotice({ ok: false, text: t('admin.err.generic') });
    } finally {
      setCancelling(null);
    }
  };

  if (error)
    return (
      <p role="alert" className="rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">
        {t('admin.err.load')}{' '}
        <button type="button" className="underline" onClick={load}>{t('admin.retry')}</button>
      </p>
    );
  if (!data) return <div aria-busy="true" className="kn-shimmer h-[480px] rounded-xl bg-bg-subtle" />;
  const can = data.can_act;
  const minWhen = new Date(Date.now() + 5 * 60_000 - new Date().getTimezoneOffset() * 60_000).toISOString().slice(0, 16);

  return (
    <div className="flex flex-col gap-16">
      {notice && (
        <p role="status" className={cx('kn-pop rounded-lg px-16 py-12 text-latin-label-sm font-semibold', notice.ok ? 'bg-status-success-bg text-status-success' : 'bg-status-danger-bg text-status-danger')}>
          {notice.text}
        </p>
      )}
      {!can && <p className="rounded-lg bg-bg-subtle px-16 py-12 text-latin-label-sm text-text-secondary">{t('admin.no.read_only')}</p>}

      <div className="grid items-start gap-16 xl:grid-cols-[1fr_1fr]">
        <Panel i={0} title={t('admin.no.auto')} sub={t('admin.no.auto_sub')}>
          <div className="flex flex-col divide-y divide-border-default">
            {data.rules.map((r) => (
              <div key={r.kind} className="py-4">
                <Switch
                  label={t(`admin.no.kind.${r.kind}`)}
                  hint={r.available ? `${t(`admin.no.to.${r.to}`)} · ${t('admin.no.in_app')}` : t('admin.no.needs_email')}
                  checked={r.on}
                  disabled={!can || !r.available || saving === r.kind}
                  onChange={(v) => void flip(r.kind, v)}
                />
              </div>
            ))}
          </div>
        </Panel>

        <Panel i={1} title={t('admin.no.announce')} sub={t('admin.no.announce_sub')}>
          <fieldset disabled={!can || sending} className="flex flex-col gap-16">
            <div>
              <label htmlFor="ann-audience" className="text-latin-label-sm font-semibold">{t('admin.no.audience')}</label>
              <select id="ann-audience" value={audience} onChange={(e) => setAudience(e.target.value as Audience)} className={cx(inputCls, 'mt-8 h-[44px]')}>
                {AUDIENCES.map((a) => (
                  <option key={a} value={a}>
                    {a === 'company' ? t('admin.no.aud.company') : t('admin.no.aud_n', { who: t(`admin.no.aud.${a}`), n: num(data.audience_sizes[a] ?? 0, lang) })}
                  </option>
                ))}
              </select>
            </div>
            {audience === 'company' && <CompanyPick t={t} value={company} onChange={setCompany} disabled={!can} />}

            <div>
              <div role="tablist" aria-label={t('admin.no.language')} className="-mx-4 flex gap-8 overflow-x-auto px-4 pb-4">
                {LANGS.map((l) => {
                  const done = !!title[l].trim() && !!body[l].trim();
                  return (
                    <button key={l} role="tab" type="button" aria-selected={tab === l} onClick={() => setTab(l)} className={cx('kn-btn inline-flex h-[32px] shrink-0 items-center gap-4 rounded-full border px-12 text-[13px] font-semibold', tab === l ? 'border-espresso-950 bg-espresso-950 text-cream-50' : 'border-border-default hover:border-mocha-500')}>
                      {done && <Check width={12} height={12} aria-hidden />}
                      {t(`lang.${l}`)}
                      {l === 'en' && <span aria-hidden>*</span>}
                    </button>
                  );
                })}
              </div>
              <p className="mt-4 text-[13px] text-text-secondary">{t('admin.no.lang_hint')}</p>
              <label htmlFor="ann-title" className="mt-12 block text-latin-label-sm font-semibold">{t('admin.no.title')}</label>
              <input id="ann-title" lang={tab} value={title[tab]} maxLength={80} onChange={(e) => setTitle({ ...title, [tab]: e.target.value })} placeholder={tab === 'en' ? t('admin.no.title_hint') : title.en} className={cx(inputCls, 'mt-8 h-[44px]')} />
              <label htmlFor="ann-body" className="mt-12 block text-latin-label-sm font-semibold">{t('admin.no.body')}</label>
              <textarea id="ann-body" lang={tab} rows={4} value={body[tab]} maxLength={600} onChange={(e) => setBody({ ...body, [tab]: e.target.value })} placeholder={tab === 'en' ? t('admin.no.body_hint') : body.en} className="mt-8 w-full rounded-lg border border-border-strong bg-bg-surface px-16 py-12 text-latin-body placeholder:text-taupe-500 hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring" />
              <p className="mt-4 text-right text-[13px] tabular-nums text-text-secondary">{num(body[tab].length, lang)} / {num(600, lang)}</p>
            </div>

            <div role="radiogroup" aria-label={t('admin.no.when')} className="flex flex-wrap gap-8">
              {([false, true] as const).map((x) => (
                <button key={String(x)} type="button" role="radio" aria-checked={later === x} onClick={() => setLater(x)} className={cx('kn-btn inline-flex h-[36px] items-center gap-8 rounded-full border px-16 text-latin-label-sm font-semibold', later === x ? 'border-espresso-950 bg-espresso-950 text-cream-50' : 'border-border-default hover:border-mocha-500')}>
                  {x ? <Clock width={14} height={14} aria-hidden /> : <Send width={14} height={14} aria-hidden />}
                  {t(x ? 'admin.no.later' : 'admin.no.now')}
                </button>
              ))}
            </div>
            {later && (
              <div className="kn-in">
                <label htmlFor="ann-when" className="text-latin-label-sm font-semibold">{t('admin.no.send_at')}</label>
                <input id="ann-when" type="datetime-local" min={minWhen} value={when} onChange={(e) => setWhen(e.target.value)} className={cx(inputCls, 'mt-8 h-[44px]')} />
              </div>
            )}

            {problem && <ErrorBanner>{problem}</ErrorBanner>}
            <div className="flex flex-wrap items-center justify-between gap-12">
              <p className="text-[13px] text-text-secondary">{reach === null ? t('admin.no.reach_company') : t('admin.no.reach', { n: num(reach, lang) })}</p>
              <button type="button" disabled={!ready || sending || !can} onClick={() => void send()} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-50">
                {sending ? <Spinner /> : later ? <Clock width={16} height={16} aria-hidden /> : <Megaphone width={16} height={16} aria-hidden />}
                {t(later ? 'admin.no.schedule' : 'admin.no.send')}
              </button>
            </div>
          </fieldset>
        </Panel>
      </div>

      <Panel i={2} title={t('admin.no.recent')}>
        {data.announcements.length ? (
          <ul>
            {data.announcements.map((a, i) => (
              <AnnouncementRow key={a.id} t={t} lang={lang} a={a} i={i} canAct={can} busy={cancelling === a.id} onCancel={() => void cancel(a.id)} />
            ))}
          </ul>
        ) : (
          <p className="py-24 text-center text-latin-label-sm text-text-secondary">{t('admin.no.none')}</p>
        )}
      </Panel>
    </div>
  );
}
