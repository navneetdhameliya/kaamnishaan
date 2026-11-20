import { Check, ChevronDown, CircleCheck, Info, Send } from 'lucide-react';
import { useCallback, useEffect, useState, type ReactNode } from 'react';

import { api, ApiError } from '../lib/api';
import type { T } from '../lib/i18n';
import type { EmailGroups, EmailSettingsOut } from '../lib/types';
import { cx, PageActions, Spinner, Switch, TextDialog } from '../ui';

type Form = { enabled: boolean; from_name: string; from_email: string; host: string; port: string; security: 'starttls' | 'ssl'; username: string; password: string; clearPassword: boolean; groups: EmailGroups };
const GROUPS = ['account', 'reports', 'reminders', 'team'] as const;

const toForm = (d: EmailSettingsOut): Form => {
  const s = d.settings;
  return { enabled: s.enabled, from_name: s.from_name, from_email: s.from_email ?? '', host: s.host ?? '', port: String(s.port), security: s.security, username: s.username ?? '', password: '', clearPassword: false, groups: s.groups };
};

function Section({ title, sub, children, i }: { title: string; sub: string; children: ReactNode; i: number }) {
  return (
    <section className="kn-in grid gap-16 rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24 lg:grid-cols-[280px_minmax(0,1fr)] lg:gap-32" style={{ ['--d' as string]: `${i * 80}ms` }}>
      <div>
        <h2 className="text-[20px] font-semibold leading-[28px]">{title}</h2>
        <p className="mt-4 text-[13px] text-text-secondary">{sub}</p>
      </div>
      <div className="min-w-0">{children}</div>
    </section>
  );
}

/** A33 Email settings, from GET /admin/email-settings. Only super admins can change them. */
export function EmailSettings({ t }: { t: T }) {
  const [data, setData] = useState<EmailSettingsOut | null>(null);
  const [form, setForm] = useState<Form | null>(null);
  const [error, setError] = useState(false);
  const [saving, setSaving] = useState(false);
  const [testing, setTesting] = useState(false);
  const [note, setNote] = useState<{ ok: boolean; text: string } | null>(null);
  const [fields, setFields] = useState<Record<string, string>>({});

  const load = useCallback(() => {
    setError(false);
    api<EmailSettingsOut>('/admin/email-settings')
      .then((d) => {
        setData(d);
        setForm(toForm(d));
      })
      .catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, []);
  useEffect(load, [load]);

  if (error && !data)
    return (
      <div className="kn-in mx-auto mt-48 max-w-[480px] rounded-xl border border-border-default bg-bg-surface p-24 text-center">
        <p className="text-latin-body text-text-secondary">{t('admin.err.load')}</p>
        <button type="button" onClick={load} className="kn-btn mt-16 inline-flex h-[44px] items-center rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action">
          {t('admin.retry')}
        </button>
      </div>
    );
  if (!data || !form)
    return (
      <div aria-busy="true" className="flex flex-col gap-16">
        {[160, 240, 260].map((h, i) => <div key={i} className="kn-shimmer rounded-xl bg-bg-surface" style={{ height: h }} />)}
      </div>
    );

  const can = data.can_act;
  const dirty = JSON.stringify(form) !== JSON.stringify(toForm(data));
  const set = (patch: Partial<Form>) => { setNote(null); setFields({}); setForm({ ...form, ...patch }); };
  const save = async () => {
    const errs: Record<string, string> = {};
    const port = Number(form.port);
    if (!Number.isInteger(port) || port < 1 || port > 65535) errs.port = 'invalid';
    if (form.enabled && !form.host.trim()) errs.host = 'required';
    if (form.enabled && !form.from_email.trim()) errs.from_email = 'required';
    if (!form.from_name.trim()) errs.from_name = 'required';
    if (Object.keys(errs).length) {
      setFields(errs);
      setNote({ ok: false, text: t('admin.em.fix') });
      return;
    }
    setSaving(true);
    try {
      const body = {
        enabled: form.enabled, from_name: form.from_name.trim(), from_email: form.from_email.trim() || null, host: form.host.trim() || null, port,
        security: form.security, username: form.username.trim() || null, password: form.clearPassword ? '' : form.password || null, groups: form.groups,
      };
      const out = await api<EmailSettingsOut>('/admin/email-settings', { method: 'PUT', body });
      setData(out);
      setForm(toForm(out));
      setNote({ ok: true, text: t(out.live ? 'admin.em.saved_live' : 'admin.em.saved') });
    } catch (e) {
      if (e instanceof ApiError && e.status === 422) {
        // only "required" has its own words; anything else on a field means "not valid"
        setFields(Object.fromEntries(Object.entries(e.fields).map(([k, v]) => [k, v === 'required' ? 'required' : k === 'port' ? 'invalid' : 'value_error'])));
        setNote({ ok: false, text: t('admin.em.fix') });
      } else setNote({ ok: false, text: t('admin.err.generic') });
    } finally {
      setSaving(false);
    }
  };
  const input = (f: string) => cx('mt-8 h-[48px] w-full rounded-lg border bg-bg-surface px-16 text-latin-body placeholder:text-taupe-500 hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring disabled:opacity-70', fields[f] ? 'border-status-danger' : 'border-border-strong');
  const err = (f: string) => fields[f] && <p className="mt-4 text-[13px] font-semibold text-status-danger">{t(`admin.em.e.${fields[f]}`)}</p>;
  const field = (id: string, f: keyof Form, label: string, props: Record<string, unknown> = {}) => (
    <div>
      <label htmlFor={id} className="block text-latin-label-sm font-semibold">
        {label}
      </label>
      <input id={id} value={form[f] as string} disabled={!can} onChange={(e) => set({ [f]: e.target.value } as Partial<Form>)} aria-invalid={!!fields[f]} className={input(f)} {...props} />
      {err(f)}
    </div>
  );

  return (
    <div className="flex flex-col gap-16">
      {can && (
        <PageActions>
          <button type="button" disabled={dirty || !data.settings.host} title={dirty ? t('admin.em.save_first') : undefined} onClick={() => setTesting(true)} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-50">
            <Send width={16} height={16} aria-hidden />
            <span className="hidden sm:inline">{t('admin.em.test')}</span>
          </button>
          <button type="button" disabled={!dirty || saving} onClick={() => void save()} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action disabled:opacity-50">
            {saving ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
            {t('admin.em.save')}
          </button>
        </PageActions>
      )}
      {data.live ? (
        <p role="status" className="kn-in flex items-start gap-12 rounded-xl bg-status-success-bg px-16 py-12 text-latin-label-sm font-semibold text-status-success">
          <CircleCheck width={18} height={18} className="mt-[1px] shrink-0" aria-hidden />
          {t('admin.em.live', { from: data.settings.from_email ?? '' })}
        </p>
      ) : (
        <p role="status" className="kn-in flex items-start gap-12 rounded-xl bg-status-info-bg px-16 py-12 text-latin-label-sm text-status-info">
          <Info width={18} height={18} className="mt-[1px] shrink-0" aria-hidden />
          <span>
            <span className="font-semibold">{t('admin.em.off_title')}</span> {t('admin.em.off_body')}
          </span>
        </p>
      )}
      {!can && <p className="text-[13px] text-text-secondary">{t('admin.em.super_only')}</p>}
      {note && (
        <p role={note.ok ? 'status' : 'alert'} className={cx('kn-pop rounded-lg px-16 py-12 text-latin-label-sm font-semibold', note.ok ? 'bg-status-success-bg text-status-success' : 'bg-status-danger-bg text-status-danger')}>
          {note.text}
        </p>
      )}

      <Section i={0} title={t('admin.em.sender')} sub={t('admin.em.sender_sub')}>
        <div className="grid gap-16 sm:grid-cols-2">
          {field('em-from-name', 'from_name', t('admin.em.from_name'), { maxLength: 80 })}
          {field('em-from', 'from_email', t('admin.em.from_email'), { type: 'email', placeholder: 'no-reply@kaamnishaan.com' })}
        </div>
      </Section>

      <Section i={1} title={t('admin.em.smtp')} sub={t('admin.em.smtp_sub')}>
        <div className="grid gap-16 sm:grid-cols-2">
          {field('em-host', 'host', t('admin.em.host'), { placeholder: 'smtp-relay.brevo.com', autoComplete: 'off' })}
          <div className="grid grid-cols-2 gap-12">
            {field('em-port', 'port', t('admin.em.port'), { type: 'number', inputMode: 'numeric' })}
            <div>
              <label htmlFor="em-sec" className="block text-latin-label-sm font-semibold">
                {t('admin.em.security')}
              </label>
              <div className="relative">
                <select id="em-sec" value={form.security} disabled={!can} onChange={(e) => set({ security: e.target.value as Form['security'], port: e.target.value === 'ssl' ? '465' : '587' })} className={cx(input('security'), 'cursor-pointer appearance-none pr-[36px]')}>
                  <option value="starttls">STARTTLS</option>
                  <option value="ssl">SSL/TLS</option>
                </select>
                <ChevronDown width={18} height={18} className="pointer-events-none absolute right-12 top-1/2 mt-4 -translate-y-1/2" aria-hidden />
              </div>
            </div>
          </div>
          {field('em-user', 'username', t('admin.em.username'), { autoComplete: 'off' })}
          <div>
            <label htmlFor="em-pass" className="block text-latin-label-sm font-semibold">
              {t('admin.em.password')}
            </label>
            <input id="em-pass" type="password" autoComplete="new-password" value={form.password} disabled={!can || form.clearPassword} placeholder={data.settings.password_set && !form.clearPassword ? t('admin.em.password_set') : ''} onChange={(e) => set({ password: e.target.value })} className={input('password')} />
            {data.settings.password_set && can && (
              <label className="mt-8 inline-flex cursor-pointer items-center gap-8 text-[13px] text-text-secondary">
                <input type="checkbox" checked={form.clearPassword} onChange={(e) => set({ clearPassword: e.target.checked, password: '' })} className="h-[16px] w-[16px] accent-espresso-950" />
                {t('admin.em.password_clear')}
              </label>
            )}
          </div>
        </div>
        <p className="mt-12 text-[13px] text-text-secondary">{t('admin.em.smtp_note')}</p>
      </Section>

      <Section i={2} title={t('admin.em.emails')} sub={t('admin.em.emails_sub')}>
        <Switch label={t('admin.em.enabled')} hint={t('admin.em.enabled_hint')} checked={form.enabled} disabled={!can} onChange={(on) => set({ enabled: on })} />
        <div className={cx('mt-8 flex flex-col gap-4 border-t border-border-default pt-8', !form.enabled && 'opacity-60')}>
          {GROUPS.map((g) => (
            <Switch key={g} label={t(`admin.em.g.${g}`)} hint={t(`admin.em.g.${g}_hint`)} checked={form.groups[g]} disabled={!can || !form.enabled} onChange={(on) => set({ groups: { ...form.groups, [g]: on } })} />
          ))}
        </div>
      </Section>

      {testing && (
        <TextDialog
          t={t}
          title={t('admin.em.test_title')}
          body={t('admin.em.test_body')}
          label={t('admin.em.test_to')}
          type="email"
          min={5}
          max={200}
          confirm={t('admin.em.test_go')}
          onClose={() => setTesting(false)}
          onConfirm={async (to) => {
            try {
              const r = await api<{ to: string }>('/admin/email-settings/test', { method: 'POST', body: { to } });
              setTesting(false);
              setNote({ ok: true, text: t('admin.em.test_sent', { to: r.to }) });
              return null;
            } catch (e) {
              if (e instanceof ApiError && e.code === 'smtp_failed') return t('admin.em.test_failed', { reason: e.message });
              if (e instanceof ApiError && e.code === 'email_not_set') return t('admin.em.save_first');
              if (e instanceof ApiError && e.status === 422) return t('admin.em.e.email');
              return t('admin.err.generic');
            }
          }}
        />
      )}
    </div>
  );
}
