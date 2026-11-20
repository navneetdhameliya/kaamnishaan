import { Check, Copy, KeyRound, Minus, Power, UserPlus } from 'lucide-react';
import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';

import { api, ApiError } from '../lib/api';
import { ago, type Lang, type T } from '../lib/i18n';
import type { RoleRow, RolesOut, StaffLink, StaffRole, StaffRow } from '../lib/types';
import { cx, ErrorBanner, Initials, inputCls, PageActions, Spinner } from '../ui';

const ROLES: StaffRole[] = ['super_admin', 'admin', 'support'];
const pill = 'inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold';
const ghostBtn = 'kn-btn inline-flex h-[36px] items-center gap-6 rounded-lg border border-border-default px-12 text-[13px] font-semibold hover:border-mocha-500 disabled:opacity-50';

/** A tick, a dash, or a short "only if…" note. */
function Cell({ t, cell }: { t: T; cell: RoleRow['cells'][string] }) {
  if (cell.value === 'yes') return <Check aria-label={t('admin.ro.yes')} className="mx-auto h-[18px] w-[18px] text-status-success" />;
  if (cell.value === 'no') return <Minus aria-label={t('admin.ro.no')} className="mx-auto h-[18px] w-[18px] text-taupe-400" />;
  return <span className={cx(pill, 'bg-status-warning-bg text-status-warning')}>{t(`admin.ro.note.${cell.note}`)}</span>;
}

function Matrix({ t, rows, cols, prefix, i }: { t: T; rows: RoleRow[]; cols: string[]; prefix: string; i: number }) {
  return (
    <div className="kn-in overflow-hidden rounded-xl border border-border-default bg-bg-surface" style={{ ['--d' as string]: `${i * 80}ms` }}>
      <div className="overflow-x-auto">
        <table className="w-full min-w-[720px] text-left">
          <thead className="bg-bg-subtle text-[13px] text-text-secondary">
            <tr>
              <th scope="col" className="py-12 pl-20 pr-16 font-semibold">{t('admin.ro.c_permission')}</th>
              {cols.map((c) => (
                <th key={c} scope="col" className="px-16 py-12 text-center font-semibold">{t(`admin.ro.col.${c}`)}</th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-border-default text-[14px]">
            {rows.map((r, j) => (
              <tr key={r.key} className="kn-in transition-colors hover:bg-cream-100" style={{ ['--d' as string]: `${i * 80 + j * 30}ms` }}>
                <th scope="row" className="py-12 pl-20 pr-16 font-medium">{t(`admin.ro.${prefix}.${r.key}`)}</th>
                {cols.map((c) => (
                  <td key={c} className="px-16 py-12 text-center">
                    <Cell t={t} cell={r.cells[c]} />
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function Heading({ title, sub, children }: { title: string; sub: string; children?: ReactNode }) {
  return (
    <div className="kn-in flex flex-wrap items-end justify-between gap-12">
      <div className="min-w-0">
        <h2 className="text-[20px] font-semibold leading-[28px]">{title}</h2>
        <p className="mt-4 text-[13px] text-text-secondary">{sub}</p>
      </div>
      {children}
    </div>
  );
}

/** A small modal shell with Escape to close. */
function Dialog({ title, body, busy, onClose, children }: { title: string; body?: string; busy?: boolean; onClose: () => void; children: ReactNode }) {
  useEffect(() => {
    const esc = (e: globalThis.KeyboardEvent) => e.key === 'Escape' && !busy && onClose();
    window.addEventListener('keydown', esc);
    return () => window.removeEventListener('keydown', esc);
  }, [busy, onClose]);
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center p-16 sm:items-center">
      <button type="button" aria-hidden tabIndex={-1} onClick={() => !busy && onClose()} className="absolute inset-0 cursor-default bg-espresso-950/50" />
      <div role="dialog" aria-modal="true" aria-labelledby="dlg-title" className="kn-pop relative w-full max-w-[480px] rounded-xl bg-bg-surface p-24 shadow-lg">
        <h2 id="dlg-title" className="text-[22px] font-bold leading-[30px]">{title}</h2>
        {body && <p className="mt-8 text-latin-body text-text-secondary">{body}</p>}
        {children}
      </div>
    </div>
  );
}

const cancelBtn = 'kn-btn inline-flex h-[44px] items-center justify-center rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold hover:bg-cream-300';
const okBtn = (danger?: boolean) => cx('kn-btn inline-flex h-[44px] items-center justify-center gap-8 rounded-lg px-20 text-latin-label-sm font-semibold text-cream-50 disabled:opacity-60', danger ? 'bg-status-danger hover:brightness-95' : 'bg-action-primary hover:bg-action-primary-pressed');

function Confirm({ t, title, body, confirm, danger, onClose, onConfirm }: { t: T; title: string; body: string; confirm: string; danger?: boolean; onClose: () => void; onConfirm: () => Promise<string | null> }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const go = async () => {
    setBusy(true);
    setError(null);
    const err = await onConfirm();
    if (err) { setError(err); setBusy(false); }
  };
  return (
    <Dialog title={title} body={body} busy={busy} onClose={onClose}>
      {error && <div className="mt-12"><ErrorBanner>{error}</ErrorBanner></div>}
      <div className="mt-20 flex flex-col-reverse gap-12 sm:flex-row sm:justify-end">
        <button type="button" onClick={onClose} disabled={busy} className={cancelBtn}>{t('admin.us.cancel')}</button>
        <button type="button" onClick={() => void go()} disabled={busy} className={okBtn(danger)}>{busy && <Spinner />}{confirm}</button>
      </div>
    </Dialog>
  );
}

function Invite({ t, onClose, onDone }: { t: T; onClose: () => void; onDone: (l: StaffLink) => void }) {
  const [f, setF] = useState({ name: '', email: '', role: 'support' as StaffRole });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [fields, setFields] = useState<Record<string, string>>({});
  const ref = useRef<HTMLInputElement>(null);
  useEffect(() => ref.current?.focus(), []);
  const go = async () => {
    const errs: Record<string, string> = {};
    if (f.name.trim().length < 2) errs.name = t('admin.ro.err.name');
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(f.email.trim())) errs.email = t('admin.ro.err.email');
    setFields(errs);
    if (Object.keys(errs).length) return;
    setBusy(true);
    setError(null);
    try {
      onDone(await api<StaffLink>('/admin/staff', { method: 'POST', body: { name: f.name.trim(), email: f.email.trim(), role: f.role } }));
    } catch (e) {
      if (e instanceof ApiError && e.code === 'staff_exists') setFields({ email: t('admin.ro.err.exists') });
      else setError(t('admin.err.save'));
      setBusy(false);
    }
  };
  const field = (key: 'name' | 'email', type: string) => (
    <div className="mt-16">
      <label htmlFor={`inv-${key}`} className="block text-latin-label-sm font-semibold">{t(`admin.ro.f_${key}`)}</label>
      <input id={`inv-${key}`} ref={key === 'name' ? ref : undefined} type={type} value={f[key]} maxLength={key === 'name' ? 120 : 254} onChange={(e) => setF({ ...f, [key]: e.target.value })} aria-invalid={!!fields[key]} className={cx(inputCls, 'mt-8', fields[key] && 'border-status-danger')} />
      {fields[key] && <p className="mt-4 text-[13px] text-status-danger">{fields[key]}</p>}
    </div>
  );
  return (
    <Dialog title={t('admin.ro.invite_title')} body={t('admin.ro.invite_body')} busy={busy} onClose={onClose}>
      {field('name', 'text')}
      {field('email', 'email')}
      <fieldset className="mt-16">
        <legend className="text-latin-label-sm font-semibold">{t('admin.ro.f_role')}</legend>
        <div className="mt-8 grid gap-8">
          {ROLES.map((r) => (
            <label key={r} className={cx('flex cursor-pointer items-start gap-12 rounded-lg border p-12 transition-colors hover:border-mocha-500', f.role === r ? 'border-espresso-950 bg-cream-100' : 'border-border-default')}>
              <input type="radio" name="role" checked={f.role === r} onChange={() => setF({ ...f, role: r })} className="mt-4 accent-espresso-950" />
              <span className="min-w-0">
                <span className="block text-[14px] font-semibold">{t(`admin.ro.col.${r}`)}</span>
                <span className="block text-[13px] text-text-secondary">{t(`admin.ro.role_hint.${r}`)}</span>
              </span>
            </label>
          ))}
        </div>
      </fieldset>
      {error && <div className="mt-12"><ErrorBanner>{error}</ErrorBanner></div>}
      <div className="mt-20 flex flex-col-reverse gap-12 sm:flex-row sm:justify-end">
        <button type="button" onClick={onClose} disabled={busy} className={cancelBtn}>{t('admin.us.cancel')}</button>
        <button type="button" onClick={() => void go()} disabled={busy} className={okBtn()}>{busy && <Spinner />}{t('admin.ro.invite_send')}</button>
      </div>
    </Dialog>
  );
}

/** The setup link is shown once; there's no email, so it's shared by hand. */
function LinkShown({ t, data, onClose }: { t: T; data: StaffLink; onClose: () => void }) {
  const [copied, setCopied] = useState(false);
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(data.setup_link);
      setCopied(true);
    } catch {
      /* the link stays visible to copy by hand */
    }
  };
  return (
    <Dialog title={t('admin.ro.link_title')} body={t('admin.ro.link_body', { name: data.staff.name })} onClose={onClose}>
      <div className="mt-16 break-all rounded-lg border border-border-default bg-bg-subtle p-12 font-mono text-[13px]">{data.setup_link}</div>
      <p className="mt-8 text-[13px] text-text-secondary">{t('admin.ro.link_note')}</p>
      <div className="mt-20 flex flex-col-reverse gap-12 sm:flex-row sm:justify-end">
        <button type="button" onClick={onClose} className={cancelBtn}>{t('admin.ro.done')}</button>
        <button type="button" onClick={() => void copy()} className={okBtn()}>
          {copied ? <Check className="h-[16px] w-[16px]" /> : <Copy className="h-[16px] w-[16px]" />}
          {t(copied ? 'admin.ro.copied' : 'admin.ro.copy')}
        </button>
      </div>
    </Dialog>
  );
}

function StatusPill({ t, s }: { t: T; s: StaffRow }) {
  if (s.status === 'disabled') return <span className={cx(pill, 'bg-status-danger-bg text-status-danger')}>{t('admin.ro.st.disabled')}</span>;
  if (s.status === 'invited') return <span className={cx(pill, 'bg-status-warning-bg text-status-warning')}>{t('admin.ro.st.invited')}</span>;
  return <span className={cx(pill, 'bg-status-success-bg text-status-success')}>{t('admin.ro.st.active')}</span>;
}

type Ask = { kind: 'off' | 'on' | 'link'; s: StaffRow } | { kind: 'role'; s: StaffRow; role: StaffRole };

/** A10 Roles and permissions, from GET /admin/roles. The table reflects the rules the server enforces. */
export function Roles({ t, lang }: { t: T; lang: Lang }) {
  const [data, setData] = useState<RolesOut | null>(null);
  const [error, setError] = useState(false);
  const [inviting, setInviting] = useState(false);
  const [shown, setShown] = useState<StaffLink | null>(null);
  const [ask, setAsk] = useState<Ask | null>(null);

  const load = useCallback(() => {
    setError(false);
    api<RolesOut>('/admin/roles').then(setData).catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, []);
  useEffect(load, [load]);

  if (error && !data)
    return (
      <div className="kn-in mx-auto mt-48 max-w-[480px] rounded-xl border border-border-default bg-bg-surface p-24 text-center">
        <p className="text-latin-body text-text-secondary">{t('admin.err.load')}</p>
        <button type="button" onClick={load} className="kn-btn mt-16 inline-flex h-[44px] items-center rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action">{t('admin.retry')}</button>
      </div>
    );
  if (!data)
    return (
      <div aria-busy="true" className="flex flex-col gap-16">
        {[420, 180, 260].map((h, i) => <div key={i} className="kn-shimmer rounded-xl bg-bg-surface" style={{ height: h }} />)}
      </div>
    );

  const swap = (row: StaffRow) => setData({ ...data, staff: data.staff.map((s) => (s.id === row.id ? row : s)) });
  const errText = (e: unknown) => {
    const code = e instanceof ApiError ? e.code : '';
    return ['last_super_admin', 'not_yourself', 'staff_disabled'].includes(code) ? t(`admin.ro.err.${code}`) : t('admin.err.save');
  };
  const run = async (a: Ask): Promise<string | null> => {
    try {
      if (a.kind === 'link') {
        const l = await api<StaffLink>(`/admin/staff/${a.s.id}/setup-link`, { method: 'POST' });
        swap(l.staff);
        setShown(l);
      } else {
        const body = a.kind === 'role' ? { role: a.role } : { active: a.kind === 'on' };
        swap(await api<StaffRow>(`/admin/staff/${a.s.id}`, { method: 'PATCH', body }));
      }
      setAsk(null);
      return null;
    } catch (e) {
      return errText(e);
    }
  };
  const can = data.can_act;

  return (
    <div className="flex flex-col gap-24">
      {can && (
        <PageActions>
          <button type="button" onClick={() => setInviting(true)} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed">
            <UserPlus className="h-[16px] w-[16px]" />
            {t('admin.ro.invite')}
          </button>
        </PageActions>
      )}

      <Heading title={t('admin.ro.matrix_title')} sub={t('admin.ro.matrix_sub')} />
      <Matrix t={t} rows={data.matrix} cols={['super_admin', 'owner', 'manager', 'technician', 'customer']} prefix="row" i={1} />

      <Heading title={t('admin.ro.staff_title')} sub={t('admin.ro.staff_sub')} />
      <Matrix t={t} rows={data.staff_matrix} cols={['super_admin', 'admin', 'support']} prefix="srow" i={2} />

      <Heading title={t('admin.ro.people_title')} sub={t(can ? 'admin.ro.people_sub' : 'admin.ro.people_view')} />
      <div className="kn-in overflow-hidden rounded-xl border border-border-default bg-bg-surface" style={{ ['--d' as string]: '240ms' }}>
        <div className="overflow-x-auto">
          <table className="w-full min-w-[860px] text-left">
            <thead className="bg-bg-subtle text-[13px] text-text-secondary">
              <tr>
                {(['c_name', 'c_role', 'c_status', 'c_login', ...(can ? ['c_actions'] : [])] as const).map((c, i) => (
                  <th key={c} scope="col" className={cx('px-16 py-12 font-semibold', i === 0 && 'pl-20')}>{t(`admin.ro.${c}`)}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-border-default text-[14px]">
              {data.staff.map((s, i) => (
                <tr key={s.id} className={cx('kn-in transition-colors hover:bg-cream-100', s.status === 'disabled' && 'text-text-secondary')} style={{ ['--d' as string]: `${240 + Math.min(i * 30, 300)}ms` }}>
                  <td className="py-12 pl-20 pr-16">
                    <div className="flex items-center gap-12">
                      <Initials name={s.name} className="h-[36px] w-[36px] rounded-full bg-cream-300 text-[13px] text-mocha-700" />
                      <div className="min-w-0">
                        <p className="truncate font-semibold">{s.name}{s.me && <span className="text-[13px] font-normal text-text-secondary"> {t('admin.ro.you')}</span>}</p>
                        <p className="truncate text-[13px] text-text-secondary">{s.email}</p>
                      </div>
                    </div>
                  </td>
                  <td className="px-16 py-12">
                    {can && !s.me ? (
                      <select aria-label={t('admin.ro.c_role')} value={s.role} onChange={(e) => setAsk({ kind: 'role', s, role: e.target.value as StaffRole })} className="h-[36px] rounded-lg border border-border-default bg-bg-surface px-8 text-[14px] hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring">
                        {ROLES.map((r) => <option key={r} value={r}>{t(`admin.ro.col.${r}`)}</option>)}
                      </select>
                    ) : (
                      t(`admin.ro.col.${s.role}`)
                    )}
                  </td>
                  <td className="px-16 py-12"><StatusPill t={t} s={s} /></td>
                  <td className="px-16 py-12">{s.last_login_at ? ago(s.last_login_at, lang) : t('admin.co.never')}</td>
                  {can && (
                    <td className="px-16 py-12">
                      {s.me ? (
                        <span className="text-[13px] text-text-secondary">—</span>
                      ) : (
                        <div className="flex flex-wrap gap-8">
                          <button type="button" disabled={s.status === 'disabled'} onClick={() => setAsk({ kind: 'link', s })} className={ghostBtn}>
                            <KeyRound className="h-[14px] w-[14px]" />
                            {t('admin.ro.new_link')}
                          </button>
                          <button type="button" onClick={() => setAsk({ kind: s.status === 'disabled' ? 'on' : 'off', s })} className={cx(ghostBtn, s.status !== 'disabled' && 'text-status-danger')}>
                            <Power className="h-[14px] w-[14px]" />
                            {t(s.status === 'disabled' ? 'admin.ro.turn_on' : 'admin.ro.turn_off')}
                          </button>
                        </div>
                      )}
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {inviting && (
        <Invite t={t} onClose={() => setInviting(false)} onDone={(l) => { setInviting(false); setData({ ...data, staff: [...data.staff, l.staff] }); setShown(l); }} />
      )}
      {shown && <LinkShown t={t} data={shown} onClose={() => setShown(null)} />}
      {ask && (
        <Confirm
          t={t}
          danger={ask.kind === 'off' || ask.kind === 'link'}
          title={t(`admin.ro.ask.${ask.kind}.title`, { name: ask.s.name })}
          body={t(`admin.ro.ask.${ask.kind}.body`, { name: ask.s.name, role: ask.kind === 'role' ? t(`admin.ro.col.${ask.role}`) : '' })}
          confirm={t(`admin.ro.ask.${ask.kind}.confirm`)}
          onClose={() => setAsk(null)}
          onConfirm={() => run(ask)}
        />
      )}
    </div>
  );
}
