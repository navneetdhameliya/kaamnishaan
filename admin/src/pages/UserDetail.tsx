import { ChevronLeft, LogOut, Power, ShieldOff } from 'lucide-react';
import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';

import { api, ApiError } from '../lib/api';
import { ago, clock, day, num, plural, type Lang, type T } from '../lib/i18n';
import { session } from '../lib/session';
import type { UserDetail as Detail } from '../lib/types';
import { cx, ErrorBanner, Initials, Link, Spinner } from '../ui';
import { RolePill } from './Users';

type Action = 'sign-out' | 'deactivate' | 'reactivate';

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-16 py-8">
      <dt className="shrink-0 text-[14px] text-text-secondary">{label}</dt>
      <dd className="min-w-0 break-words text-right text-[14px] font-semibold">{children}</dd>
    </div>
  );
}

function when(iso: string, t: T, lang: Lang): string {
  const d = new Date(iso);
  const today = new Date();
  const y = new Date();
  y.setDate(today.getDate() - 1);
  if (d.toDateString() === today.toDateString()) return clock(iso, lang);
  if (d.toDateString() === y.toDateString()) return t('admin.yesterday');
  return day(iso, lang, { year: undefined });
}

/** Asks for a reason, then runs the action. Escape or Cancel closes it. */
function Confirm({ t, action, name, userId, onClose, onDone }: { t: T; action: Action; name: string; userId: string; onClose: () => void; onDone: (d: Detail) => void }) {
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const ref = useRef<HTMLTextAreaElement>(null);
  useEffect(() => {
    ref.current?.focus();
    const esc = (e: KeyboardEvent) => e.key === 'Escape' && !busy && onClose();
    window.addEventListener('keydown', esc);
    return () => window.removeEventListener('keydown', esc);
  }, [busy, onClose]);
  const text = {
    'sign-out': ['admin.us.confirm_sign_out', 'admin.us.confirm_sign_out_body', 'admin.us.sign_out'],
    deactivate: ['admin.us.confirm_off', 'admin.us.confirm_off_body', 'admin.us.deactivate'],
    reactivate: ['admin.us.confirm_on', 'admin.us.confirm_on_body', 'admin.us.reactivate'],
  }[action];
  const go = async () => {
    if (reason.trim().length < 3) return setError(t('admin.us.reason_short'));
    setBusy(true);
    setError(null);
    try {
      onDone(await api<Detail>(`/admin/users/${userId}/${action}`, { method: 'POST', body: { reason: reason.trim() } }));
    } catch (e) {
      setError(e instanceof ApiError && e.status === 403 ? t('admin.us.not_allowed') : e instanceof ApiError && e.status === 0 ? t('admin.err.offline') : t('admin.err.generic'));
      setBusy(false);
    }
  };
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center p-16 sm:items-center" role="presentation">
      <button type="button" aria-hidden tabIndex={-1} onClick={() => !busy && onClose()} className="absolute inset-0 cursor-default bg-espresso-950/50" />
      <div role="dialog" aria-modal="true" aria-labelledby="confirm-title" className="kn-pop relative w-full max-w-[460px] rounded-xl bg-bg-surface p-24 shadow-lg">
        <h2 id="confirm-title" className="text-[22px] font-bold leading-[30px]">
          {t(text[0], { name })}
        </h2>
        <p className="mt-8 text-latin-body text-text-secondary">{t(text[1])}</p>
        <label htmlFor="reason" className="mt-20 block text-latin-label-sm font-semibold">
          {t('admin.us.reason')}
        </label>
        <textarea id="reason" ref={ref} value={reason} onChange={(e) => setReason(e.target.value)} maxLength={300} rows={3} className="mt-8 w-full rounded-lg border border-border-strong bg-bg-surface p-12 text-latin-body hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring" />
        {error && (
          <div className="mt-12">
            <ErrorBanner>{error}</ErrorBanner>
          </div>
        )}
        <div className="mt-20 flex flex-col-reverse gap-12 sm:flex-row sm:justify-end">
          <button type="button" onClick={onClose} disabled={busy} className="kn-btn inline-flex h-[44px] items-center justify-center rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold hover:bg-cream-300">
            {t('admin.us.cancel')}
          </button>
          <button
            type="button"
            onClick={() => void go()}
            disabled={busy}
            className={cx('kn-btn inline-flex h-[44px] items-center justify-center gap-8 rounded-lg px-20 text-latin-label-sm font-semibold text-cream-50 disabled:opacity-60', action === 'deactivate' ? 'bg-status-danger hover:brightness-95' : 'bg-action-primary hover:bg-action-primary-pressed')}
          >
            {busy && <Spinner />}
            {t(text[2])}
          </button>
        </div>
      </div>
    </div>
  );
}

/** A09 User details: profile, companies, the last 30 days, and the two account actions. */
export function UserDetail({ t, lang, id, onName }: { t: T; lang: Lang; id: string; onName: (n: string) => void }) {
  const [d, setD] = useState<Detail | null>(null);
  const [error, setError] = useState<'missing' | 'load' | null>(null);
  const [action, setAction] = useState<Action | null>(null);
  const [done, setDone] = useState<string | null>(null);
  const canAct = session.get()?.staff.role !== 'support';
  const load = useCallback(() => {
    setError(null);
    api<Detail>(`/admin/users/${id}`)
      .then((x) => {
        setD(x);
        onName(x.name || t('admin.us.no_name'));
      })
      .catch((e) => {
        if (e instanceof ApiError && (e.status === 404 || e.status === 422)) setError('missing');
        else if (!(e instanceof ApiError && e.status === 401)) setError('load');
      });
  }, [id, onName, t]);
  useEffect(load, [load]);

  const back = (
    <Link to="/users" className="group inline-flex w-fit items-center gap-4 text-latin-label-sm font-semibold text-text-secondary hover:text-text-primary">
      <ChevronLeft width={16} height={16} className="transition-transform group-hover:-translate-x-[3px]" aria-hidden />
      {t('admin.us.back')}
    </Link>
  );
  if (error)
    return (
      <div className="flex flex-col gap-16">
        {back}
        <div className="kn-in mx-auto mt-24 max-w-[480px] rounded-xl border border-border-default bg-bg-surface p-24 text-center">
          <p className="text-latin-body text-text-secondary">{t(error === 'missing' ? 'admin.us.not_found' : 'admin.err.load')}</p>
          {error === 'load' && (
            <button type="button" onClick={load} className="kn-btn mt-16 inline-flex h-[44px] items-center rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action">
              {t('admin.retry')}
            </button>
          )}
        </div>
      </div>
    );
  if (!d)
    return (
      <div aria-busy="true" className="flex flex-col gap-24">
        <div className="kn-shimmer h-[120px] rounded-xl bg-bg-surface" />
        <div className="grid gap-24 lg:grid-cols-2">
          <div className="kn-shimmer h-[260px] rounded-xl bg-bg-surface" />
          <div className="kn-shimmer h-[260px] rounded-xl bg-bg-surface" />
        </div>
      </div>
    );

  const name = d.name || t('admin.us.no_name');
  const main = d.companies.find((c) => c.status === 'active') ?? d.companies[0];
  const pill =
    d.status === 'disabled'
      ? ['bg-status-danger-bg text-status-danger', t('admin.us.st.disabled')]
      : d.status === 'invited'
        ? ['bg-bg-subtle text-mocha-700', t('admin.us.st.invited')]
        : ['bg-status-success-bg text-status-success', t(d.on_job ? 'admin.us.status_on_job' : 'admin.us.status_active')];

  return (
    <div className="flex flex-col gap-24">
      <div className="flex flex-wrap items-center justify-between gap-12">
        {back}
        {canAct && !d.deleted_at && (
          <div className="flex flex-wrap gap-12">
            {d.status !== 'disabled' && (
              <button type="button" onClick={() => setAction('sign-out')} disabled={!d.active_sessions} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-50">
                <LogOut width={16} height={16} aria-hidden />
                {t('admin.us.sign_out')}
              </button>
            )}
            {d.status === 'disabled' ? (
              <button type="button" onClick={() => setAction('reactivate')} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed">
                <Power width={16} height={16} aria-hidden />
                {t('admin.us.reactivate')}
              </button>
            ) : (
              <button type="button" onClick={() => setAction('deactivate')} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-status-danger px-16 text-latin-label-sm font-semibold text-cream-50 hover:brightness-95">
                <ShieldOff width={16} height={16} aria-hidden />
                {t('admin.us.deactivate')}
              </button>
            )}
          </div>
        )}
      </div>

      {done && (
        <p role="status" className="kn-pop rounded-lg bg-status-success-bg px-16 py-12 text-latin-label-sm font-semibold text-status-success">
          {done}
        </p>
      )}
      {d.deleted_at ? (
        <p role="note" className="rounded-lg bg-bg-subtle px-16 py-12 text-latin-label-sm font-semibold text-text-secondary">
          {t('admin.ud.deleted', { day: day(d.deleted_at, lang) })}
        </p>
      ) : (
        d.status === 'disabled' && (
          <p role="note" className="rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">
            {t('admin.us.disabled_note')}
          </p>
        )
      )}

      <section className="kn-in flex flex-col gap-16 rounded-xl border border-border-default bg-bg-surface p-20 sm:flex-row sm:items-center sm:p-24">
        <Initials name={name} className="h-[64px] w-[64px] rounded-full bg-cream-300 text-[22px] text-mocha-700 sm:h-[72px] sm:w-[72px]" />
        <div className="min-w-0 flex-1">
          <h2 className="text-[26px] font-bold leading-[34px] sm:text-[32px] sm:leading-[40px]">{name}</h2>
          {main && (
            <p className="mt-4 text-[14px] text-text-secondary">
              {t(`admin.co.role.${main.role}`)} ·{' '}
              <Link to={`/companies/${main.company_id}`} className="kn-link font-semibold text-text-primary">
                {main.company}
              </Link>
              {main.joined_at && ` · ${t('admin.us.joined', { date: day(main.joined_at, lang) })}`}
            </p>
          )}
        </div>
        <span className={cx('w-fit rounded-full px-12 py-4 text-[13px] font-semibold', pill[0])}>{pill[1]}</span>
      </section>

      <div className="grid gap-24 lg:grid-cols-2">
        <section className="kn-in rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24" style={{ ['--d' as string]: '60ms' }}>
          <h2 className="text-[20px] font-semibold">{t('admin.us.profile')}</h2>
          <dl className="mt-8">
            {d.phone && <Row label={t('admin.us.phone')}>{d.phone}</Row>}
            {d.email && (
              <Row label={t('admin.us.email')}>
                {d.email} <span className={cx('font-normal', d.email_verified ? 'text-status-success' : 'text-text-secondary')}>· {t(d.email_verified ? 'admin.us.verified' : 'admin.us.not_verified')}</span>
              </Row>
            )}
            <Row label={t('admin.us.login')}>{d.login === 'phone' ? t('admin.us.login_phone_long') : t(`admin.us.login.${d.login}`)}</Row>
            <Row label={t('admin.us.app_language')}>{t(`lang.${d.app_language}`)}</Row>
            {main && <Row label={t('admin.us.report_language')}>{t(`lang.${main.report_language}`)}</Row>}
            {d.device && <Row label={t('admin.us.device')}>{d.device}</Row>}
            <Row label={t('admin.us.sessions')}>{plural(t, 'admin.us.n_devices', d.active_sessions, { n: num(d.active_sessions, lang) })}</Row>
            <Row label={t('admin.co.last_active')}>{d.last_seen_at ? ago(d.last_seen_at, lang) : t('admin.co.never')}</Row>
            <Row label={t('admin.us.since')}>{day(d.created_at, lang)}</Row>
          </dl>
          {d.companies.length > 1 && (
            <>
              <h3 className="mt-16 text-[16px] font-semibold">{t('admin.us.companies')}</h3>
              <ul className="mt-8 divide-y divide-border-default">
                {d.companies.map((c) => (
                  <li key={c.membership_id} className="flex items-center justify-between gap-12 py-8">
                    <Link to={`/companies/${c.company_id}`} className="kn-link truncate text-[14px] font-semibold">
                      {c.company}
                    </Link>
                    <span className="flex shrink-0 items-center gap-8">
                      <RolePill t={t} role={c.role} />
                      {c.status !== 'active' && <span className="text-[13px] text-text-secondary">{t(`admin.us.st.${c.status}`)}</span>}
                    </span>
                  </li>
                ))}
              </ul>
            </>
          )}
        </section>

        <section className="kn-in rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24" style={{ ['--d' as string]: '120ms' }}>
          <h2 className="text-[20px] font-semibold">{t('admin.us.last30')}</h2>
          <div className="mt-16 grid grid-cols-3 gap-12">
            {(
              [
                ['admin.us.jobs', d.jobs_30d],
                ['admin.us.reports', d.reports_30d],
                ['admin.us.changes', d.changes_asked_30d],
              ] as const
            ).map(([k, v], i) => (
              <div key={k} className="kn-in kn-hover rounded-lg bg-bg-subtle p-12 sm:p-16" style={{ ['--d' as string]: `${160 + i * 60}ms` }}>
                <p className="text-[28px] font-bold leading-[36px] tabular-nums">{num(v, lang)}</p>
                <p className="text-[13px] text-text-secondary">{t(k)}</p>
              </div>
            ))}
          </div>
          {d.activity.length ? (
            <ul className="mt-16 flex flex-col gap-12">
              {d.activity.map((a, i) => (
                <li key={`${a.action}-${a.at}-${i}`} className="flex gap-12">
                  <span aria-hidden className="mt-[8px] h-[6px] w-[6px] shrink-0 rounded-full bg-espresso-950" />
                  <div>
                    <p className="text-[14px] font-semibold">{t(`admin.us.a.${a.action}`)}</p>
                    <p className="text-[13px] text-text-secondary">{when(a.at, t, lang)}</p>
                  </div>
                </li>
              ))}
            </ul>
          ) : (
            <p className="mt-16 text-latin-label-sm text-text-secondary">{t('admin.us.no_activity')}</p>
          )}
        </section>
      </div>

      {action && (
        <Confirm
          t={t}
          action={action}
          name={name}
          userId={d.id}
          onClose={() => setAction(null)}
          onDone={(x) => {
            setD(x);
            setDone(t({ 'sign-out': 'admin.us.done_sign_out', deactivate: 'admin.us.done_off', reactivate: 'admin.us.done_on' }[action]));
            setAction(null);
          }}
        />
      )}
    </div>
  );
}
