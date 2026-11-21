import { Check, Copy, ExternalLink, KeyRound, LogOut, Monitor, Save } from 'lucide-react';
import { useEffect, useState } from 'react';

import { api, ApiError } from '../lib/api';
import { ago, LANGS, num, type Lang, type T } from '../lib/i18n';
import { session } from '../lib/session';
import type { AdminLocalizationOut, AdminStorageOut, StaffDevice, StaffOut } from '../lib/types';
import { cx, ErrorBanner, inputCls, Link, OtpInput, PageActions, Spinner, Switch } from '../ui';
import { Panel } from './Dashboard';

const pill = 'inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold';
const COLORS = { photos: 'bg-espresso-950', voice: 'bg-mocha-300', pdfs: 'bg-status-success' } as const;

/** 1,234,567 bytes -> "1.2 MB" */
export function bytes(n: number, lang: Lang): string {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let i = 0;
  let v = n;
  while (v >= 1024 && i < units.length - 1) (v /= 1024), i++;
  return `${num(i ? Math.round(v * 10) / 10 : v, lang)} ${units[i]}`;
}

const Failed = ({ t }: { t: T }) => <p role="alert" className="rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">{t('admin.err.load')}</p>;

/** A34 Storage settings: what is stored and how files are protected. Read only (see D-129). */
export function Storage({ t, lang }: { t: T; lang: Lang }) {
  const [d, setD] = useState<AdminStorageOut | null>(null);
  const [error, setError] = useState(false);
  useEffect(() => {
    api<AdminStorageOut>('/admin/storage').then(setD).catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, []);
  if (error) return <Failed t={t} />;
  if (!d) return <div aria-busy="true" className="kn-shimmer h-[420px] rounded-xl bg-bg-subtle" />;
  const total = Math.max(d.total_bytes, 1);
  return (
    <div className="flex flex-col gap-16">
      <Panel i={0} title={t('admin.st.used')} right={<p className="text-[17px] font-semibold tabular-nums">{bytes(d.total_bytes, lang)}</p>}>
        <div className="flex h-[12px] overflow-hidden rounded-full bg-cream-200" role="img" aria-label={d.kinds.map((k) => `${t(`admin.st.k.${k.kind}`)} ${bytes(k.bytes, lang)}`).join(', ')}>
          {d.kinds.map((k, i) => <div key={k.kind} className={cx('kn-fill h-full', COLORS[k.kind])} style={{ width: `${(k.bytes / total) * 100}%`, ['--d' as string]: `${i * 120}ms` }} />)}
        </div>
        <ul className="mt-12 flex flex-wrap gap-x-24 gap-y-8 text-[14px]">
          {d.kinds.map((k) => (
            <li key={k.kind} className="flex items-center gap-8">
              <span aria-hidden className={cx('h-[10px] w-[10px] rounded-full', COLORS[k.kind])} />
              <span className="font-semibold">{t(`admin.st.k.${k.kind}`)} {bytes(k.bytes, lang)}</span>
              <span className="text-text-secondary">{t('admin.st.files', { n: num(k.files, lang) })}</span>
            </li>
          ))}
        </ul>
        <p className="mt-12 text-[13px] text-text-secondary">{t('admin.st.used_note')}</p>
      </Panel>
      <div className="grid items-start gap-16 lg:grid-cols-2">
        <Panel i={1} title={t('admin.st.files_title')}>
          <dl className="flex flex-col divide-y divide-border-default text-[14px]">
            {[
              [t('admin.st.where'), d.provider === 'r2' ? t('admin.st.r2', { bucket: d.bucket }) : t('admin.st.local')],
              [t('admin.st.max_photo'), <span key="m">{t('admin.st.max_photo_v', { n: num(d.max_photo_mb, lang) })} · <Link to="/settings" className="kn-link">{t('admin.st.change_there')}</Link></span>],
              [t('admin.st.keep'), t('admin.st.keep_v')],
              [t('admin.st.links'), t('admin.st.links_v', { n: num(d.link_minutes, lang) })],
            ].map(([k, v], i) => (
              <div key={i} className="flex flex-wrap justify-between gap-8 py-12 first:pt-0">
                <dt className="font-semibold">{k}</dt>
                <dd className="text-text-secondary">{v}</dd>
              </div>
            ))}
          </dl>
          {d.provider === 'local' && <p className="mt-12 rounded-lg bg-status-warning-bg px-12 py-8 text-[13px] font-semibold text-status-warning">{t('admin.st.local_warn')}</p>}
        </Panel>
        <Panel i={2} title={t('admin.st.security')} sub={t('admin.st.security_sub')}>
          <div className="flex flex-col divide-y divide-border-default">
            {(['encrypt', 'signed', 'lock', 'gps'] as const).map((k) => (
              <div key={k} className="py-4">
                <Switch label={t(`admin.st.s.${k}`)} hint={t(`admin.st.s.${k}_hint`, { n: num(k === 'lock' ? d.locked_evidence : d.link_minutes, lang) })} checked disabled onChange={() => undefined} />
              </div>
            ))}
          </div>
        </Panel>
      </div>
      {d.top_companies.length > 0 && (
        <Panel i={3} title={t('admin.st.top')}>
          <ul className="flex flex-col gap-12">
            {d.top_companies.map((c, i) => (
              <li key={c.id} className="kn-in" style={{ ['--d' as string]: `${i * 40}ms` }}>
                <p className="flex justify-between gap-12 text-[14px]">
                  <Link to={`/companies/${c.id}`} className="truncate font-semibold hover:underline">{c.name}</Link>
                  <span className="tabular-nums text-text-secondary">{bytes(c.bytes, lang)}</span>
                </p>
                <div className="mt-4 h-[6px] overflow-hidden rounded-full bg-cream-200">
                  <div className="kn-fill h-full rounded-full bg-mocha-500" style={{ width: `${(c.bytes / Math.max(d.top_companies[0]!.bytes, 1)) * 100}%` }} />
                </div>
              </li>
            ))}
          </ul>
        </Panel>
      )}
    </div>
  );
}

function Checked({ t, lang, pct }: { t: T; lang: Lang; pct: number }) {
  return pct >= 100 ? (
    <span className={cx(pill, 'bg-status-success-bg text-status-success')}>{t('admin.lz.ready')}</span>
  ) : (
    <span className={cx(pill, 'bg-status-warning-bg text-status-warning')}>{t('admin.lz.review', { n: num(pct, lang) })}</span>
  );
}

/** A35 Localization settings: the 5 languages, how far people checked them, and the new-company report language. */
export function Localization({ t, lang }: { t: T; lang: Lang }) {
  const [d, setD] = useState<AdminLocalizationOut | null>(null);
  const [error, setError] = useState(false);
  const [rl, setRl] = useState('en');
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<{ ok: boolean; text: string } | null>(null);
  useEffect(() => {
    api<AdminLocalizationOut>('/admin/localization').then((x) => (setD(x), setRl(x.report_language))).catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, []);
  if (error) return <Failed t={t} />;
  if (!d) return <div aria-busy="true" className="kn-shimmer h-[420px] rounded-xl bg-bg-subtle" />;
  const save = async () => {
    setBusy(true);
    setNotice(null);
    try {
      const x = await api<AdminLocalizationOut>('/admin/localization', { method: 'PUT', body: { report_language: rl } });
      setD(x);
      setNotice({ ok: true, text: t('admin.lz.saved') });
    } catch {
      setNotice({ ok: false, text: t('admin.err.generic') });
    } finally {
      setBusy(false);
    }
  };
  const on = <span className={cx(pill, 'bg-status-success-bg text-status-success')}>{t('admin.lz.on')}</span>;
  return (
    <div className="flex flex-col gap-16">
      {d.can_act && (
        <PageActions>
          <button type="button" disabled={busy || rl === d.report_language} onClick={() => void save()} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-50">
            {busy ? <Spinner /> : <Save width={16} height={16} aria-hidden />}
            {t('admin.lz.save')}
          </button>
        </PageActions>
      )}
      {notice && <p role="status" className={cx('kn-pop rounded-lg px-16 py-12 text-latin-label-sm font-semibold', notice.ok ? 'bg-status-success-bg text-status-success' : 'bg-status-danger-bg text-status-danger')}>{notice.text}</p>}
      <section className="kn-in overflow-hidden rounded-xl border border-border-default bg-bg-surface">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[760px] text-left">
            <thead className="bg-bg-subtle text-[13px] text-text-secondary">
              <tr>
                {(['c_lang', 'c_code', 'c_app', 'c_site', 'c_reports', 'c_voice'] as const).map((c, i) => <th key={c} scope="col" className={cx('px-16 py-12 font-semibold', i === 0 && 'pl-20')}>{t(`admin.lz.${c}`)}</th>)}
              </tr>
            </thead>
            <tbody className="divide-y divide-border-default text-[14px]">
              {d.languages.map((l, i) => (
                <tr key={l.code} className="kn-in hover:bg-cream-100" style={{ ['--d' as string]: `${i * 50}ms` }}>
                  <td className="py-12 pl-20 pr-16">
                    <span lang={l.code} className="block font-semibold">{l.native_name}</span>
                    {l.code === 'en' && <span className="text-[13px] text-text-secondary">{t('admin.lz.source')}</span>}
                  </td>
                  <td className="px-16 py-12 font-mono">{l.code}</td>
                  <td className="px-16 py-12"><Checked t={t} lang={lang} pct={l.app_checked} /></td>
                  <td className="px-16 py-12"><Checked t={t} lang={lang} pct={l.site_checked} /></td>
                  <td className="px-16 py-12">{on}</td>
                  <td className="px-16 py-12">{on}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="border-t border-border-default px-20 py-12 text-[13px] text-text-secondary">
          {t('admin.lz.table_note')} <Link to="/localized-content" className="kn-link">{t('admin.nav.texts')}</Link>
        </p>
      </section>
      <div className="grid items-start gap-16 lg:grid-cols-2">
        <Panel i={1} title={t('admin.lz.defaults')}>
          <div className="flex flex-col gap-16">
            <div>
              <label htmlFor="lz-report" className="text-latin-label-sm font-semibold">{t('admin.lz.report_lang')}</label>
              <select id="lz-report" value={rl} disabled={!d.can_act || busy} onChange={(e) => setRl(e.target.value)} className={cx(inputCls, 'mt-8 h-[48px]')}>
                {LANGS.map((l) => <option key={l} value={l}>{t(`lang.${l}`)}</option>)}
              </select>
              <p className="mt-4 text-[13px] text-text-secondary">{t('admin.lz.report_lang_hint')}</p>
            </div>
            <dl className="flex flex-col divide-y divide-border-default text-[14px]">
              {(['fallback', 'dates', 'currency'] as const).map((k) => (
                <div key={k} className="flex flex-wrap justify-between gap-8 py-12">
                  <dt className="font-semibold">{t(`admin.lz.${k}`)}</dt>
                  <dd className="text-text-secondary">{t(`admin.lz.${k}_v`)}</dd>
                </div>
              ))}
            </dl>
          </div>
        </Panel>
        <Panel i={2} title={t('admin.lz.rules')} sub={t('admin.lz.rules_sub')}>
          <div className="flex flex-col divide-y divide-border-default">
            {(['own', 'company', 'voice', 'auto'] as const).map((k) => (
              <div key={k} className="py-4">
                <Switch label={t(`admin.lz.r.${k}`)} hint={t(`admin.lz.r.${k}_hint`)} checked={k !== 'auto'} disabled onChange={() => undefined} />
              </div>
            ))}
          </div>
        </Panel>
      </div>
    </div>
  );
}

/** A36 My profile: name and panel language, password, recovery codes and the devices logged in. */
export function Profile({ t, lang, onLang }: { t: T; lang: Lang; onLang: (l: Lang) => void }) {
  const me = session.get()!.staff;
  const [name, setName] = useState(me.name);
  const [pick, setPick] = useState<Lang>((me.lang as Lang) ?? lang);
  const [busy, setBusy] = useState<string | null>(null);
  const [notice, setNotice] = useState<{ ok: boolean; text: string } | null>(null);
  const [devices, setDevices] = useState<StaffDevice[] | null>(null);
  const [pw, setPw] = useState({ current: '', next: '', code: '' });
  const [pwError, setPwError] = useState<string | null>(null);
  const [codes, setCodes] = useState<string[] | null>(null);
  const [rcCode, setRcCode] = useState('');
  const [rcError, setRcError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    api<{ items: StaffDevice[] }>('/admin/me/sessions').then((x) => setDevices(x.items)).catch(() => setDevices([]));
  }, []);
  const err = (e: unknown) => (e instanceof ApiError && (e.status === 400 || e.status === 429) ? e.message : t('admin.err.generic'));
  const saveDetails = async () => {
    setBusy('details');
    setNotice(null);
    try {
      const out = await api<StaffOut>('/admin/me', { method: 'PUT', body: { name: name.trim(), lang: pick } });
      const s = session.get();
      if (s) session.set({ ...s, staff: out });
      onLang(pick);
      setNotice({ ok: true, text: 'admin.pf.saved' });
    } catch (e) {
      setNotice({ ok: false, text: err(e) });
    } finally {
      setBusy(null);
    }
  };
  const changePw = async () => {
    setBusy('pw');
    setPwError(null);
    try {
      await api('/admin/me/password', { method: 'POST', body: { current_password: pw.current, new_password: pw.next, code: pw.code } });
      setPw({ current: '', next: '', code: '' });
      setNotice({ ok: true, text: 'admin.pf.pw_done' });
      setDevices((d) => d?.filter((x) => x.current) ?? d);
    } catch (e) {
      setPwError(err(e));
    } finally {
      setBusy(null);
    }
  };
  const newCodes = async () => {
    setBusy('codes');
    setRcError(null);
    try {
      setCodes((await api<{ recovery_codes: string[] }>('/admin/me/recovery-codes', { method: 'POST', body: { code: rcCode } })).recovery_codes);
      setRcCode('');
      const s = session.get();
      if (s) session.set({ ...s, staff: { ...s.staff, recovery_codes_left: 8 } });
    } catch (e) {
      setRcError(err(e));
    } finally {
      setBusy(null);
    }
  };
  const endDevice = async (id: string) => {
    setBusy(id);
    try {
      setDevices((await api<{ items: StaffDevice[] }>(`/admin/me/sessions/${id}`, { method: 'DELETE' })).items);
    } catch (e) {
      setNotice({ ok: false, text: err(e) });
    } finally {
      setBusy(null);
    }
  };
  const left = session.get()?.staff.recovery_codes_left ?? me.recovery_codes_left;
  const section = (title: string, sub: string, body: React.ReactNode, i: number) => (
    <section className="kn-in grid gap-16 rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24 lg:grid-cols-[280px_1fr]" style={{ ['--d' as string]: `${i * 60}ms` }}>
      <div>
        <h2 className="text-[20px] font-semibold leading-[28px]">{title}</h2>
        <p className="mt-4 text-[13px] text-text-secondary">{sub}</p>
      </div>
      <div className="min-w-0">{body}</div>
    </section>
  );

  return (
    <div className="flex flex-col gap-16">
      <PageActions>
        <button type="button" disabled={!!busy || !name.trim() || (name.trim() === me.name && pick === (me.lang ?? lang))} onClick={() => void saveDetails()} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-50">
          {busy === 'details' ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
          {t('admin.pf.save')}
        </button>
      </PageActions>
      {notice && <p role="status" className={cx('kn-pop rounded-lg px-16 py-12 text-latin-label-sm font-semibold', notice.ok ? 'bg-status-success-bg text-status-success' : 'bg-status-danger-bg text-status-danger')}>{notice.ok ? t(notice.text) : notice.text}</p>}

      {section(t('admin.pf.details'), t('admin.pf.details_sub'), (
        <div className="grid gap-16 sm:grid-cols-2">
          <div>
            <label htmlFor="pf-name" className="text-latin-label-sm font-semibold">{t('admin.pf.name')}</label>
            <input id="pf-name" value={name} maxLength={120} onChange={(e) => setName(e.target.value)} className={cx(inputCls, 'mt-8 h-[48px]')} />
          </div>
          <div>
            <label htmlFor="pf-email" className="text-latin-label-sm font-semibold">{t('admin.pf.email')}</label>
            <input id="pf-email" value={me.email} readOnly className={cx(inputCls, 'mt-8 h-[48px] bg-bg-subtle text-text-secondary')} />
            <p className="mt-4 text-[13px] text-text-secondary">{t('admin.pf.email_hint')}</p>
          </div>
          <div>
            <label htmlFor="pf-lang" className="text-latin-label-sm font-semibold">{t('admin.pf.lang')}</label>
            <select id="pf-lang" value={pick} onChange={(e) => setPick(e.target.value as Lang)} className={cx(inputCls, 'mt-8 h-[48px]')}>
              {LANGS.map((l) => <option key={l} value={l}>{t(`lang.${l}`)}</option>)}
            </select>
          </div>
          <div>
            <p className="text-latin-label-sm font-semibold">{t('admin.pf.role')}</p>
            <p className="mt-8 flex h-[48px] items-center"><span className={cx(pill, 'bg-bg-subtle text-mocha-700')}>{t(`admin.role.${me.role}`)}</span></p>
          </div>
        </div>
      ), 0)}

      {section(t('admin.pf.security'), t('admin.pf.security_sub'), (
        <div className="flex flex-col gap-20">
          <div className="flex flex-col divide-y divide-border-default">
            <div className="pb-4"><Switch label={t('admin.pf.two_step')} hint={t('admin.pf.two_step_hint')} checked disabled onChange={() => undefined} /></div>
            <div className="pt-4"><Switch label={t('admin.pf.alerts')} hint={t('admin.pf.alerts_hint')} checked={false} disabled onChange={() => undefined} /></div>
          </div>
          <form className="rounded-lg border border-border-default p-16" onSubmit={(e) => (e.preventDefault(), void changePw())}>
            <h3 className="flex items-center gap-8 text-[16px] font-semibold"><KeyRound width={16} height={16} aria-hidden />{t('admin.pf.pw')}</h3>
            <div className="mt-12 grid gap-12 sm:grid-cols-2">
              <div>
                <label htmlFor="pf-cur" className="text-latin-label-sm font-semibold">{t('admin.pf.pw_current')}</label>
                <input id="pf-cur" type="password" autoComplete="current-password" value={pw.current} onChange={(e) => setPw({ ...pw, current: e.target.value })} className={cx(inputCls, 'mt-8 h-[44px]')} />
              </div>
              <div>
                <label htmlFor="pf-new" className="text-latin-label-sm font-semibold">{t('admin.pf.pw_new')}</label>
                <input id="pf-new" type="password" autoComplete="new-password" value={pw.next} onChange={(e) => setPw({ ...pw, next: e.target.value })} className={cx(inputCls, 'mt-8 h-[44px]')} />
              </div>
            </div>
            <p className="mt-12 text-latin-label-sm font-semibold">{t('admin.pf.code')}</p>
            <div className="mt-8 max-w-[360px]"><OtpInput t={t} value={pw.code} onChange={(v) => setPw({ ...pw, code: v })} idPrefix="pf-otp" invalid={!!pwError} /></div>
            {pwError && <div className="mt-12"><ErrorBanner>{pwError}</ErrorBanner></div>}
            <p className="mt-8 text-[13px] text-text-secondary">{t('admin.pf.pw_hint')}</p>
            <button type="submit" disabled={!!busy || !pw.current || pw.next.length < 8 || pw.code.length !== 6} className="kn-btn mt-12 inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-50">
              {busy === 'pw' && <Spinner />}
              {t('admin.pf.pw_save')}
            </button>
          </form>
          <div className="rounded-lg border border-border-default p-16">
            <h3 className="text-[16px] font-semibold">{t('admin.pf.codes')}</h3>
            <p className="mt-4 text-[13px] text-text-secondary">{t('admin.pf.codes_left', { n: num(left, lang) })}</p>
            {codes ? (
              <div className="kn-pop mt-12">
                <ul className="grid grid-cols-2 gap-8 rounded-lg bg-bg-subtle p-12 font-mono text-[15px] sm:grid-cols-4">{codes.map((c) => <li key={c}>{c}</li>)}</ul>
                <p className="mt-8 text-[13px] font-semibold text-status-warning">{t('admin.pf.codes_once')}</p>
                <button type="button" onClick={() => void navigator.clipboard?.writeText(codes.join('\n')).then(() => setCopied(true))} className="kn-btn mt-8 inline-flex h-[36px] items-center gap-8 rounded-lg border border-border-default px-12 text-[13px] font-semibold hover:border-mocha-500">
                  {copied ? <Check width={14} height={14} aria-hidden /> : <Copy width={14} height={14} aria-hidden />}
                  {t(copied ? 'admin.pf.copied' : 'admin.pf.copy')}
                </button>
              </div>
            ) : (
              <div className="mt-12 flex flex-wrap items-end gap-12">
                <div className="max-w-[360px] flex-1"><OtpInput t={t} value={rcCode} onChange={setRcCode} idPrefix="pf-rc" invalid={!!rcError} /></div>
                <button type="button" disabled={!!busy || rcCode.length !== 6} onClick={() => void newCodes()} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-50">
                  {busy === 'codes' && <Spinner />}
                  {t('admin.pf.codes_new')}
                </button>
              </div>
            )}
            {rcError && <div className="mt-12"><ErrorBanner>{rcError}</ErrorBanner></div>}
          </div>
        </div>
      ), 1)}

      {section(t('admin.pf.sessions'), t('admin.pf.sessions_sub'), !devices ? (
        <div aria-busy="true" className="kn-shimmer h-[96px] rounded-lg bg-bg-subtle" />
      ) : (
        <ul className="flex flex-col divide-y divide-border-default">
          {devices.map((d) => (
            <li key={d.id} className="kn-in flex flex-wrap items-center gap-12 py-12 first:pt-0">
              <Monitor width={20} height={20} className="shrink-0 text-text-secondary" aria-hidden />
              <div className="min-w-0 flex-1">
                <p className="text-[15px] font-semibold">{d.device}{d.ip && <span className="font-normal text-text-secondary"> · {d.ip}</span>}</p>
                <p className="text-[13px] text-text-secondary">{d.current ? t('admin.pf.this_device') : t('admin.pf.last_used', { ago: ago(d.last_used_at ?? d.started_at, lang) })}</p>
              </div>
              {d.current ? (
                <span className={cx(pill, 'bg-status-success-bg text-status-success')}>{t('admin.pf.current')}</span>
              ) : (
                <button type="button" disabled={busy === d.id} onClick={() => void endDevice(d.id)} className="kn-btn inline-flex h-[36px] items-center gap-8 rounded-lg px-12 text-[13px] font-semibold text-status-danger hover:bg-status-danger-bg disabled:opacity-50">
                  {busy === d.id ? <Spinner /> : <LogOut width={14} height={14} aria-hidden />}
                  {t('admin.pf.end')}
                </button>
              )}
            </li>
          ))}
        </ul>
      ), 2)}
      <p className="text-[13px] text-text-secondary">{t('admin.pf.reset_note')} <Link to="/roles" className="kn-link inline-flex items-center gap-4">{t('admin.nav.roles')}<ExternalLink width={12} height={12} aria-hidden /></Link></p>
    </div>
  );
}
