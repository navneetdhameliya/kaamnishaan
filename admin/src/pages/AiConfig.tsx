import { Check, KeyRound, Lock } from 'lucide-react';
import { useCallback, useEffect, useState } from 'react';

import { api, ApiError } from '../lib/api';
import { num, type Lang, type T } from '../lib/i18n';
import type { AdminAiConfigOut, AiConfig as Cfg } from '../lib/types';
import { cx, inputCls, PageActions, Spinner, Switch } from '../ui';
import { Panel } from './Dashboard';

const usd = (n: number, lang: Lang) => num(n, lang, { style: 'currency', currency: 'USD', maximumFractionDigits: 2 });

function Field({ label, hint, children }: { label: string; hint?: string; children: React.ReactNode }) {
  return (
    <label className="mt-16 block first:mt-0">
      <span className="block text-latin-label-sm font-semibold">{label}</span>
      <div className="mt-8">{children}</div>
      {hint && <span className="mt-4 block text-[13px] text-text-secondary">{hint}</span>}
    </label>
  );
}

/** A19 AI configuration: models, monthly budget, tokens per report, fallback and personal-data masking. */
export function AiConfig({ t, lang }: { t: T; lang: Lang }) {
  const [data, setData] = useState<AdminAiConfigOut | null>(null);
  const [form, setForm] = useState<Cfg | null>(null);
  const [budget, setBudget] = useState('');
  const [tokens, setTokens] = useState('');
  const [error, setError] = useState(false);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<{ ok: boolean; text: string } | null>(null);

  const take = (d: AdminAiConfigOut) => {
    setData(d);
    setForm(d.config);
    setBudget(d.config.monthly_budget_usd ? String(d.config.monthly_budget_usd) : '');
    setTokens(String(d.config.max_tokens_report));
  };
  const load = useCallback(() => {
    setError(false);
    api<AdminAiConfigOut>('/admin/ai-config').then(take).catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, []);
  useEffect(load, [load]);
  useEffect(() => {
    if (!notice) return;
    const tm = window.setTimeout(() => setNotice(null), 4000);
    return () => window.clearTimeout(tm);
  }, [notice]);

  if (error && !data)
    return (
      <div className="kn-in mx-auto mt-48 max-w-[480px] rounded-xl border border-border-default bg-bg-surface p-24 text-center">
        <p className="text-latin-body text-text-secondary">{t('admin.err.load')}</p>
        <button type="button" onClick={load} className="kn-btn mt-16 inline-flex h-[44px] items-center rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action">{t('admin.retry')}</button>
      </div>
    );
  if (!data || !form)
    return (
      <div aria-busy="true" className="grid gap-16 lg:grid-cols-2">
        <div className="kn-shimmer h-[420px] rounded-xl bg-bg-surface" />
        <div className="kn-shimmer h-[420px] rounded-xl bg-bg-surface" />
      </div>
    );

  const can = data.can_act;
  const next: Cfg = { ...form, monthly_budget_usd: budget.trim() ? Number(budget) : 0, max_tokens_report: Number(tokens) };
  const valid = Number.isFinite(next.monthly_budget_usd) && next.monthly_budget_usd >= 0 && Number.isInteger(next.max_tokens_report) && next.max_tokens_report >= 500 && next.max_tokens_report <= 16000;
  const dirty = JSON.stringify(next) !== JSON.stringify(data.config);
  const pct = data.config.monthly_budget_usd ? Math.round((data.month_spend_usd / data.config.monthly_budget_usd) * 100) : null;

  const save = async () => {
    setBusy(true);
    try {
      take(await api<AdminAiConfigOut>('/admin/ai-config', { method: 'PUT', body: next }));
      setNotice({ ok: true, text: t('admin.pl.saved') });
    } catch {
      setNotice({ ok: false, text: t('admin.err.save') });
    } finally {
      setBusy(false);
    }
  };
  const select = (value: string, options: string[], on: (v: string) => void) => (
    <select disabled={!can} value={value} onChange={(e) => on(e.target.value)} className={inputCls}>
      {options.map((o) => <option key={o} value={o}>{o}</option>)}
    </select>
  );

  return (
    <div className="flex flex-col gap-16">
      {can && (
        <PageActions>
          <button type="button" disabled={!dirty || !valid || busy} onClick={() => void save()} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-50">
            {busy ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
            {t('admin.ac.save')}
          </button>
        </PageActions>
      )}
      <p className={cx('kn-in flex items-center gap-8 rounded-xl px-16 py-12 text-[14px] font-semibold', data.key_set ? 'bg-bg-subtle text-mocha-700' : 'bg-status-warning-bg text-status-warning')}>
        <KeyRound width={16} height={16} aria-hidden />
        {t(data.key_set ? 'admin.ac.key_on' : 'admin.ac.key_off')}
      </p>
      {!can && <p className="text-[14px] text-text-secondary">{t('admin.ac.view_only')}</p>}
      {notice && <p role="status" className={cx('kn-pop rounded-lg px-16 py-12 text-latin-label-sm font-semibold', notice.ok ? 'bg-status-success-bg text-status-success' : 'bg-status-danger-bg text-status-danger')}>{notice.text}</p>}

      <div className="grid items-start gap-16 lg:grid-cols-2">
        <Panel i={1} title={t('admin.ac.models')}>
          <div className="mt-16">
            <Field label={t('admin.ac.text_model')} hint={t('admin.ac.text_model_hint')}>{select(form.text_model, data.text_models, (v) => setForm({ ...form, text_model: v }))}</Field>
            <Field label={t('admin.ac.speech_model')} hint={t('admin.ac.speech_model_hint')}>{select(form.transcribe_model, data.transcribe_models, (v) => setForm({ ...form, transcribe_model: v }))}</Field>
            <Field label={t('admin.ac.photo_model')} hint={t('admin.ac.photo_model_hint')}>
              <select disabled value="none" className={inputCls}><option value="none">{t('admin.ac.not_used')}</option></select>
            </Field>
            <Field label={t('admin.ac.fallback')} hint={t(`admin.ac.fallback_hint.${form.fallback}`)}>
              <select disabled={!can} value={form.fallback} onChange={(e) => setForm({ ...form, fallback: e.target.value as Cfg['fallback'] })} className={inputCls}>
                {(['error', 'template'] as const).map((f) => <option key={f} value={f}>{t(`admin.ac.fb.${f}`)}</option>)}
              </select>
            </Field>
          </div>
        </Panel>

        <Panel i={2} title={t('admin.ac.limits')}>
          <div className="mt-16">
            <Field label={t('admin.ac.budget')} hint={pct === null ? t('admin.ac.budget_none', { spent: usd(data.month_spend_usd, lang) }) : t('admin.ac.budget_now', { spent: usd(data.month_spend_usd, lang), pct: num(pct, lang) })}>
              <div className="relative">
                <span className="pointer-events-none absolute left-12 top-1/2 -translate-y-1/2 text-text-secondary">$</span>
                <input disabled={!can} inputMode="decimal" value={budget} placeholder={t('admin.pl.no_limit')} onChange={(e) => setBudget(e.target.value.replace(/[^\d.]/g, ''))} className={cx(inputCls, 'pl-[28px] tabular-nums')} />
              </div>
            </Field>
            {pct !== null && pct >= 80 && <p className={cx('mt-8 rounded-lg px-12 py-8 text-[13px] font-semibold', pct >= 100 ? 'bg-status-danger-bg text-status-danger' : 'bg-status-warning-bg text-status-warning')}>{t(pct >= 100 ? 'admin.ac.over' : 'admin.ac.near')}</p>}
            <Field label={t('admin.ac.tokens')} hint={t('admin.ac.tokens_hint')}>
              <input disabled={!can} inputMode="numeric" value={tokens} onChange={(e) => setTokens(e.target.value.replace(/\D/g, ''))} aria-invalid={!valid} className={cx(inputCls, 'tabular-nums', !valid && 'border-status-danger')} />
            </Field>
            <div className="mt-16 flex flex-col gap-8 border-t border-border-default pt-12">
              <Switch label={t('admin.ac.evidence')} hint={t('admin.ac.evidence_hint')} checked disabled onChange={() => undefined} />
              <Switch label={t('admin.ac.invented')} hint={t('admin.ac.invented_hint')} checked disabled onChange={() => undefined} />
              <Switch label={t('admin.ac.mask')} hint={t('admin.ac.mask_hint')} checked={form.mask_contacts} disabled={!can} onChange={(v) => setForm({ ...form, mask_contacts: v })} />
              <Switch label={t('admin.ac.train')} hint={t('admin.ac.train_hint')} checked={false} disabled onChange={() => undefined} />
            </div>
            <p className="mt-8 flex items-center gap-8 text-[13px] text-text-secondary"><Lock width={12} height={12} aria-hidden />{t('admin.ac.locked')}</p>
          </div>
        </Panel>
      </div>
    </div>
  );
}
