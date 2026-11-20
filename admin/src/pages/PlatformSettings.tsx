import { AlertTriangle, Check, ChevronDown, Lock } from 'lucide-react';
import { useCallback, useEffect, useState, type ReactNode } from 'react';

import { api, ApiError } from '../lib/api';
import type { T } from '../lib/i18n';
import type { PlatformOut, PlatformSettings as Settings } from '../lib/types';
import { cx, PageActions, Spinner, Switch } from '../ui';

type Form = { support_email: string; support_whatsapp: string; default_country: string; signups: boolean; ai_drafting: boolean; ai_assistant: boolean; maintenance: boolean; max_photo_mb: string };

const toForm = (s: Settings): Form => ({
  support_email: s.support_email ?? '', support_whatsapp: s.support_whatsapp ?? '', default_country: s.default_country ?? '',
  signups: s.signups, ai_drafting: s.ai_drafting, ai_assistant: s.ai_assistant, maintenance: s.maintenance, max_photo_mb: String(s.max_photo_mb),
});

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

/** A32 Platform settings, from GET /admin/platform-settings. Only super admins can change them. */
export function PlatformSettings({ t }: { t: T }) {
  const [data, setData] = useState<PlatformOut | null>(null);
  const [form, setForm] = useState<Form | null>(null);
  const [error, setError] = useState(false);
  const [saving, setSaving] = useState(false);
  const [note, setNote] = useState<{ ok: boolean; text: string } | null>(null);
  const [fields, setFields] = useState<Record<string, string>>({});
  const [confirm, setConfirm] = useState(false);

  const load = useCallback(() => {
    setError(false);
    api<PlatformOut>('/admin/platform-settings')
      .then((d) => {
        setData(d);
        setForm(toForm(d.settings));
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
        {[200, 240, 140].map((h, i) => <div key={i} className="kn-shimmer rounded-xl bg-bg-surface" style={{ height: h }} />)}
      </div>
    );

  const can = data.can_act;
  const dirty = JSON.stringify(form) !== JSON.stringify(toForm(data.settings));
  const set = (patch: Partial<Form>) => { setNote(null); setFields({}); setForm({ ...form, ...patch }); };
  const save = async () => {
    const mb = Number(form.max_photo_mb);
    if (!Number.isInteger(mb) || mb < 2 || mb > 25) {
      setFields({ max_photo_mb: 'range' });
      setNote({ ok: false, text: t('admin.ps.fix') });
      return;
    }
    if (form.maintenance && !data.settings.maintenance && !confirm) return setConfirm(true);
    setConfirm(false);
    setSaving(true);
    setNote(null);
    try {
      const body = { ...form, support_email: form.support_email.trim() || null, support_whatsapp: form.support_whatsapp.trim() || null, default_country: form.default_country || null, max_photo_mb: mb };
      const out = await api<PlatformOut>('/admin/platform-settings', { method: 'PUT', body });
      setData(out);
      setForm(toForm(out.settings));
      setNote({ ok: true, text: t('admin.ps.saved') });
    } catch (e) {
      if (e instanceof ApiError && e.status === 422) {
        setFields(e.fields);
        setNote({ ok: false, text: t('admin.ps.fix') });
      } else setNote({ ok: false, text: t('admin.err.generic') });
    } finally {
      setSaving(false);
    }
  };
  const input = (f: string) => cx('mt-8 h-[48px] w-full rounded-lg border bg-bg-surface px-16 text-latin-body placeholder:text-taupe-500 hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring disabled:opacity-70', fields[f] ? 'border-status-danger' : 'border-border-strong');
  const err = (f: string) => fields[f] && <p className="mt-4 text-[13px] font-semibold text-status-danger">{t(`admin.ps.e.${f}`)}</p>;
  const serverCountry = data.countries.find((c) => c.value === data.server.default_country)?.label ?? data.server.default_country;

  return (
    <div className="flex flex-col gap-16">
      {can && (
        <PageActions>
          <button type="button" disabled={!dirty || saving} onClick={() => void save()} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action disabled:opacity-50">
            {saving ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
            {t('admin.ps.save')}
          </button>
        </PageActions>
      )}
      {data.settings.maintenance && (
        <p role="alert" className="kn-in flex items-start gap-12 rounded-xl border border-status-danger bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">
          <AlertTriangle width={18} height={18} className="mt-[1px] shrink-0" aria-hidden />
          {t('admin.ps.maintenance_on')}
        </p>
      )}
      {!can && <p className="text-[13px] text-text-secondary">{t('admin.ps.super_only')}</p>}
      {note && (
        <p role={note.ok ? 'status' : 'alert'} className={cx('kn-pop rounded-lg px-16 py-12 text-latin-label-sm font-semibold', note.ok ? 'bg-status-success-bg text-status-success' : 'bg-status-danger-bg text-status-danger')}>
          {note.text}
        </p>
      )}

      <Section i={0} title={t('admin.ps.general')} sub={t('admin.ps.general_sub')}>
        <div className="grid gap-16 sm:grid-cols-2">
          <div>
            <p className="text-latin-label-sm font-semibold">{t('admin.ps.name')}</p>
            <div className="mt-8 flex h-[48px] items-center justify-between rounded-lg border border-border-default bg-bg-subtle px-16 text-latin-body">
              KaamNishaan
              <Lock width={16} height={16} className="text-text-secondary" aria-label={t('admin.ps.name_locked')} />
            </div>
          </div>
          <div>
            <label htmlFor="ps-country" className="block text-latin-label-sm font-semibold">
              {t('admin.ps.country')}
            </label>
            <div className="relative">
              <select id="ps-country" value={form.default_country} disabled={!can} onChange={(e) => set({ default_country: e.target.value })} className={cx(input('default_country'), 'cursor-pointer appearance-none pr-[40px]')}>
                <option value="">{t('admin.ps.server_value', { value: serverCountry })}</option>
                {data.countries.map((c) => (
                  <option key={c.value} value={c.value}>
                    {c.label}
                  </option>
                ))}
              </select>
              <ChevronDown width={18} height={18} className="pointer-events-none absolute right-16 top-1/2 mt-4 -translate-y-1/2" aria-hidden />
            </div>
            <p className="mt-4 text-[13px] text-text-secondary">{t('admin.ps.country_hint')}</p>
          </div>
          <div>
            <label htmlFor="ps-email" className="block text-latin-label-sm font-semibold">
              {t('admin.ps.email')}
            </label>
            <input id="ps-email" type="email" value={form.support_email} disabled={!can} placeholder={data.server.support_email ?? 'support@kaamnishaan.com'} onChange={(e) => set({ support_email: e.target.value })} className={input('support_email')} />
            {err('support_email')}
          </div>
          <div>
            <label htmlFor="ps-wa" className="block text-latin-label-sm font-semibold">
              {t('admin.ps.whatsapp')}
            </label>
            <input id="ps-wa" type="tel" value={form.support_whatsapp} disabled={!can} placeholder={data.server.support_whatsapp ?? '+91 98765 43210'} onChange={(e) => set({ support_whatsapp: e.target.value })} className={input('support_whatsapp')} />
            {err('support_whatsapp')}
          </div>
        </div>
        <p className="mt-12 text-[13px] text-text-secondary">{t('admin.ps.empty_hint')}</p>
      </Section>

      <Section i={1} title={t('admin.ps.features')} sub={t('admin.ps.features_sub')}>
        <div className="flex flex-col gap-4">
          <Switch label={t('admin.ps.f.signups')} hint={t('admin.ps.f.signups_hint')} checked={form.signups} disabled={!can} onChange={(on) => set({ signups: on })} />
          <Switch label={t('admin.ps.f.ai_drafting')} hint={t(data.server.ai_key ? 'admin.ps.f.ai_drafting_hint' : 'admin.ps.f.no_key')} checked={form.ai_drafting} disabled={!can} onChange={(on) => set({ ai_drafting: on })} />
          <Switch label={t('admin.ps.f.ai_assistant')} hint={t(data.server.ai_key ? 'admin.ps.f.ai_assistant_hint' : 'admin.ps.f.no_key')} checked={form.ai_assistant} disabled={!can} onChange={(on) => set({ ai_assistant: on })} />
          <Switch label={t('admin.ps.f.maintenance')} hint={t('admin.ps.f.maintenance_hint')} checked={form.maintenance} disabled={!can} onChange={(on) => set({ maintenance: on })} />
        </div>
      </Section>

      <Section i={2} title={t('admin.ps.limits')} sub={t('admin.ps.limits_sub')}>
        <div className="grid gap-16 sm:grid-cols-2">
          <div>
            <label htmlFor="ps-photo" className="block text-latin-label-sm font-semibold">
              {t('admin.ps.photo')}
            </label>
            <input id="ps-photo" type="number" inputMode="numeric" min={2} max={25} value={form.max_photo_mb} disabled={!can} onChange={(e) => set({ max_photo_mb: e.target.value })} className={input('max_photo_mb')} />
            {fields.max_photo_mb ? err('max_photo_mb') : <p className="mt-4 text-[13px] text-text-secondary">{t('admin.ps.photo_hint')}</p>}
          </div>
        </div>
        <p className="mt-12 text-[13px] text-text-secondary">{t('admin.ps.limits_note')}</p>
      </Section>

      {confirm && (
        <div className="fixed inset-0 z-50 flex items-end justify-center p-16 sm:items-center">
          <button type="button" aria-hidden tabIndex={-1} onClick={() => setConfirm(false)} className="absolute inset-0 cursor-default bg-espresso-950/50" />
          <div role="alertdialog" aria-modal="true" aria-labelledby="mt-title" className="kn-pop relative w-full max-w-[460px] rounded-xl bg-bg-surface p-24 shadow-lg">
            <h2 id="mt-title" className="text-[22px] font-bold leading-[30px]">
              {t('admin.ps.confirm_title')}
            </h2>
            <p className="mt-8 text-latin-body text-text-secondary">{t('admin.ps.confirm_body')}</p>
            <div className="mt-20 flex flex-col-reverse gap-12 sm:flex-row sm:justify-end">
              <button type="button" onClick={() => setConfirm(false)} className="kn-btn inline-flex h-[44px] items-center justify-center rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold hover:bg-cream-300">
                {t('admin.us.cancel')}
              </button>
              <button type="button" onClick={() => void save()} className="kn-btn inline-flex h-[44px] items-center justify-center rounded-lg bg-status-danger px-20 text-latin-label-sm font-semibold text-cream-50 hover:brightness-95">
                {t('admin.ps.confirm_go')}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
