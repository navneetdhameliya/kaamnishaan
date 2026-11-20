import { Check, ChevronLeft, ChevronRight, Download, Search } from 'lucide-react';
import { useCallback, useEffect, useRef, useState } from 'react';

import { api, ApiError, download } from '../lib/api';
import { money, num, type Lang, type T } from '../lib/i18n';
import type { CreditRow, CreditsOut } from '../lib/types';
import { cx, ErrorBanner, Link, PageActions, Spinner, Switch } from '../ui';

const PAGE_SIZE = 20;
type Rules = { sms: string; whatsapp: string; ai_call: string; plans: Record<string, string> };

function Kpi({ label, value, sub, danger, i }: { label: string; value: string; sub: string; danger?: boolean; i: number }) {
  return (
    <div className="kn-in" style={{ ['--d' as string]: `${i * 60}ms` }}>
      <div className="kn-hover h-full rounded-xl border border-border-default bg-bg-surface p-20">
        <p className="text-[14px] font-semibold text-text-secondary">{label}</p>
        <p className={cx('mt-8 text-[32px] font-bold leading-[40px] tabular-nums', danger && 'text-status-danger')}>{value}</p>
        <p className="mt-4 text-[13px] text-text-secondary">{sub}</p>
      </div>
    </div>
  );
}

function StatusPill({ t, lang, r }: { t: T; lang: Lang; r: CreditRow }) {
  const base = 'inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold';
  if (r.status === 'out') return <span className={cx(base, 'bg-status-danger-bg text-status-danger')}>{t('admin.cr.st.out')}</span>;
  if (r.status === 'low') return <span className={cx(base, 'bg-status-warning-bg text-status-warning')}>{t('admin.cr.st.low', { pct: num(r.included ? r.used / r.included : 0, lang, { style: 'percent' }) })}</span>;
  if (r.status === 'unlimited') return <span className={cx(base, 'bg-bg-subtle text-mocha-700')}>{t('admin.cr.st.unlimited')}</span>;
  return <span className={cx(base, 'bg-status-success-bg text-status-success')}>{t('admin.cr.st.ok')}</span>;
}

function AdjustDialog({ t, lang, row, onClose, onDone }: { t: T; lang: Lang; row: CreditRow; onClose: () => void; onDone: () => void }) {
  const [n, setN] = useState('');
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const ref = useRef<HTMLInputElement>(null);
  useEffect(() => {
    ref.current?.focus();
    const esc = (e: globalThis.KeyboardEvent) => e.key === 'Escape' && !busy && onClose();
    window.addEventListener('keydown', esc);
    return () => window.removeEventListener('keydown', esc);
  }, [busy, onClose]);
  const go = async () => {
    const credits = Number(n);
    if (!Number.isInteger(credits) || credits === 0) return setError(t('admin.cr.e.number'));
    if (reason.trim().length < 3) return setError(t('admin.us.reason_short'));
    setBusy(true);
    setError(null);
    try {
      await api(`/admin/companies/${row.company_id}/credits`, { method: 'POST', body: { credits, reason: reason.trim() } });
      onDone();
    } catch (e) {
      setError(e instanceof ApiError && e.code === 'not_enough' ? t('admin.cr.e.not_enough', { n: num(row.topup_left, lang) }) : t('admin.err.generic'));
      setBusy(false);
    }
  };
  const cls = 'mt-8 w-full rounded-lg border border-border-strong bg-bg-surface px-12 text-latin-body hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring';
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center p-16 sm:items-center">
      <button type="button" aria-hidden tabIndex={-1} onClick={() => !busy && onClose()} className="absolute inset-0 cursor-default bg-espresso-950/50" />
      <div role="dialog" aria-modal="true" aria-labelledby="adjust-title" className="kn-pop relative w-full max-w-[460px] rounded-xl bg-bg-surface p-24 shadow-lg">
        <h2 id="adjust-title" className="text-[22px] font-bold leading-[30px]">
          {t('admin.cr.adjust_title', { company: row.company })}
        </h2>
        <p className="mt-8 text-latin-body text-text-secondary">{t('admin.cr.adjust_body', { n: num(row.topup_left, lang) })}</p>
        <label htmlFor="adjust-n" className="mt-20 block text-latin-label-sm font-semibold">
          {t('admin.cr.adjust_credits')}
        </label>
        <input id="adjust-n" ref={ref} type="number" inputMode="numeric" step={1} value={n} onChange={(e) => setN(e.target.value)} placeholder="500" className={cx(cls, 'h-[48px]')} />
        <label htmlFor="adjust-reason" className="mt-16 block text-latin-label-sm font-semibold">
          {t('admin.us.reason')}
        </label>
        <textarea id="adjust-reason" value={reason} onChange={(e) => setReason(e.target.value)} maxLength={300} rows={2} className={cx(cls, 'py-12')} />
        {error && (
          <div className="mt-12">
            <ErrorBanner>{error}</ErrorBanner>
          </div>
        )}
        <div className="mt-20 flex flex-col-reverse gap-12 sm:flex-row sm:justify-end">
          <button type="button" onClick={onClose} disabled={busy} className="kn-btn inline-flex h-[44px] items-center justify-center rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold hover:bg-cream-300">
            {t('admin.us.cancel')}
          </button>
          <button type="button" onClick={() => void go()} disabled={busy} className="kn-btn inline-flex h-[44px] items-center justify-center gap-8 rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-cream-50 hover:bg-action-primary-pressed disabled:opacity-60">
            {busy && <Spinner />}
            {t('admin.cr.adjust_go')}
          </button>
        </div>
      </div>
    </div>
  );
}

/** A40 Usage and credits, from GET /admin/credits. */
export function Credits({ t, lang }: { t: T; lang: Lang }) {
  const [data, setData] = useState<CreditsOut | null>(null);
  const [form, setForm] = useState<Rules | null>(null);
  const [q, setQ] = useState('');
  const [typed, setTyped] = useState('');
  const [page, setPage] = useState(1);
  const [error, setError] = useState(false);
  const [saving, setSaving] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [note, setNote] = useState<{ ok: boolean; text: string } | null>(null);
  const [fieldErr, setFieldErr] = useState<Record<string, string>>({});
  const [adjusting, setAdjusting] = useState<CreditRow | null>(null);

  const toForm = (d: CreditsOut): Rules => ({
    sms: String(d.rules.sms), whatsapp: String(d.rules.whatsapp), ai_call: String(d.rules.ai_call),
    plans: Object.fromEntries(d.plans.map((p) => [p.code, p.monthly_credits === null ? '' : String(p.monthly_credits)])),
  });
  const load = useCallback(() => {
    setError(false);
    api<CreditsOut>(`/admin/credits?page=${page}&page_size=${PAGE_SIZE}&locale=${lang}${q ? `&q=${encodeURIComponent(q)}` : ''}`)
      .then((d) => {
        setData(d);
        setForm((f) => f ?? toForm(d));
      })
      .catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, [page, q, lang]);
  useEffect(load, [load]);
  useEffect(() => {
    if (typed === q) return;
    const tm = window.setTimeout(() => { setQ(typed.trim()); setPage(1); }, 300);
    return () => window.clearTimeout(tm);
  }, [typed, q]);

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
        <div className="grid gap-16 sm:grid-cols-2 xl:grid-cols-4">
          {[0, 1, 2, 3].map((i) => <div key={i} className="kn-shimmer h-[128px] rounded-xl bg-bg-surface" />)}
        </div>
        <div className="kn-shimmer h-[420px] rounded-xl bg-bg-surface" />
      </div>
    );

  const k = data.kpis;
  const can = data.can_act;
  const saved = toForm(data);
  const dirty = JSON.stringify(saved) !== JSON.stringify(form);
  const set = (patch: Partial<Rules>) => { setNote(null); setFieldErr({}); setForm({ ...form, ...patch }); };
  const save = async () => {
    const errs: Record<string, string> = {};
    const int = (v: string, lo: number, hi: number) => /^\d+$/.test(v) && Number(v) >= lo && Number(v) <= hi;
    if (!int(form.sms, 1, 20)) errs.sms = 'range';
    if (!int(form.whatsapp, 1, 20)) errs.whatsapp = 'range';
    if (!int(form.ai_call, 1, 100)) errs.ai_call = 'range';
    for (const [code, v] of Object.entries(form.plans)) if (v !== '' && !int(v, 0, 1_000_000)) errs[`plans.${code}`] = 'range';
    if (Object.keys(errs).length) {
      setFieldErr(errs);
      setNote({ ok: false, text: t('admin.cr.fix') });
      return;
    }
    setSaving(true);
    try {
      const plans = Object.fromEntries(Object.entries(form.plans).map(([c, v]) => [c, v === '' ? null : Number(v)]));
      await api('/admin/credits/rules', { method: 'PUT', body: { sms: Number(form.sms), whatsapp: Number(form.whatsapp), ai_call: Number(form.ai_call), plans } });
      const d = await api<CreditsOut>(`/admin/credits?page=${page}&page_size=${PAGE_SIZE}&locale=${lang}${q ? `&q=${encodeURIComponent(q)}` : ''}`);
      setData(d);
      setForm(toForm(d));
      setNote({ ok: true, text: t('admin.cr.saved') });
    } catch (e) {
      if (e instanceof ApiError && e.status === 422) setFieldErr(e.fields);
      setNote({ ok: false, text: t('admin.err.generic') });
    } finally {
      setSaving(false);
    }
  };
  const last = Math.max(1, Math.ceil(data.total / data.page_size));
  const pct = k.included_30d ? num(k.used_30d / k.included_30d, lang, { style: 'percent' }) : '—';
  const numberCls = (f: string) => cx('h-[40px] w-[96px] rounded-lg border bg-bg-surface px-12 text-right text-latin-body tabular-nums hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring disabled:opacity-70', fieldErr[f] ? 'border-status-danger' : 'border-border-strong');

  return (
    <div className="flex flex-col gap-16">
      <PageActions>
        <button
          type="button"
          disabled={exporting}
          onClick={async () => {
            setExporting(true);
            try {
              await download(`/admin/credits.csv?locale=${lang}${q ? `&q=${encodeURIComponent(q)}` : ''}`, 'kaamnishaan-credits.csv');
            } finally {
              setExporting(false);
            }
          }}
          className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-60"
        >
          {exporting ? <Spinner /> : <Download width={16} height={16} aria-hidden />}
          <span className="hidden sm:inline">{t('admin.cr.export')}</span>
        </button>
        {can && (
          <button type="button" disabled={!dirty || saving} onClick={save} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action disabled:opacity-50">
            {saving ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
            {t('admin.cr.save')}
          </button>
        )}
      </PageActions>

      <div className="grid gap-16 sm:grid-cols-2 xl:grid-cols-4">
        <Kpi i={0} label={t('admin.cr.k_used')} value={num(k.used_30d, lang)} sub={t('admin.cr.k_used_sub', { pct })} />
        <Kpi i={1} label={t('admin.cr.k_topups')} value={num(k.topup_credits_30d, lang)} sub={t('admin.cr.k_topups_sub', { n: num(k.topups_30d, lang) })} />
        <Kpi i={2} label={t('admin.cr.k_sent')} value={num(k.sms_30d + k.whatsapp_30d + k.calls_30d, lang)} sub={t('admin.cr.k_sent_sub', { sms: num(k.sms_30d, lang), wa: num(k.whatsapp_30d, lang), calls: num(k.calls_30d, lang) })} />
        <Kpi i={3} label={t('admin.cr.k_out')} value={num(k.out_of_credits, lang)} danger={k.out_of_credits > 0} sub={t('admin.cr.k_out_sub', { n: num(k.paused_requests, lang) })} />
      </div>

      {note && (
        <p role={note.ok ? 'status' : 'alert'} className={cx('kn-pop rounded-lg px-16 py-12 text-latin-label-sm font-semibold', note.ok ? 'bg-status-success-bg text-status-success' : 'bg-status-danger-bg text-status-danger')}>
          {note.text}
        </p>
      )}

      <div className="grid items-start gap-16 xl:grid-cols-[minmax(0,1fr)_420px]">
        <section className="kn-in rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24" style={{ ['--d' as string]: '120ms' }}>
          <h2 className="text-[20px] font-semibold leading-[28px]">{t('admin.cr.rules')}</h2>
          <div className="mt-16 flex flex-col gap-8">
            {(['sms', 'whatsapp', 'ai_call'] as const).map((f) => (
              <label key={f} htmlFor={`rule-${f}`} className="flex items-center justify-between gap-12 rounded-lg bg-bg-subtle px-16 py-8">
                <span className="text-latin-label-sm font-semibold">{t(`admin.cr.rule.${f}`)}</span>
                <span className="flex items-center gap-8">
                  <input id={`rule-${f}`} type="number" inputMode="numeric" min={1} max={f === 'ai_call' ? 100 : 20} value={form[f]} disabled={!can} onChange={(e) => set({ [f]: e.target.value })} aria-invalid={!!fieldErr[f]} className={numberCls(f)} />
                  <span className="w-[56px] text-[13px] text-text-secondary">{t('admin.cr.credits_unit')}</span>
                </span>
              </label>
            ))}
            <div className="flex items-center justify-between gap-12 rounded-lg bg-bg-subtle px-16 py-12">
              <span className="text-latin-label-sm font-semibold">{t('admin.cr.rule.email')}</span>
              <span className="text-latin-label-sm font-semibold">{t('admin.cr.free')}</span>
            </div>
            <div className="flex items-center justify-between gap-12 rounded-lg bg-bg-subtle px-16 py-12">
              <span className="text-latin-label-sm font-semibold">{t('admin.cr.rollover')}</span>
              <span className="text-latin-label-sm font-semibold">{t('admin.cr.rollover_v')}</span>
            </div>
          </div>
          <p className="mt-16 text-latin-label-sm font-semibold">{t('admin.cr.at_zero')}</p>
          <div className="mt-4 flex flex-col">
            <Switch label={t('admin.cr.z.pause')} hint={t('admin.cr.z.pause_hint')} checked disabled onChange={() => undefined} />
            <Switch label={t('admin.cr.z.email')} hint={t('admin.cr.z.email_hint')} checked disabled onChange={() => undefined} />
            <Switch label={t('admin.cr.z.warn')} hint={t('admin.cr.z.warn_hint')} checked={false} disabled onChange={() => undefined} />
          </div>
        </section>

        <section className="kn-in rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24" style={{ ['--d' as string]: '180ms' }}>
          <h2 className="text-[20px] font-semibold leading-[28px]">{t('admin.cr.per_plan')}</h2>
          <ul className="mt-12 flex flex-col">
            {data.plans.map((p) => (
              <li key={p.code} className="flex items-center justify-between gap-12 py-8">
                <label htmlFor={`plan-${p.code}`} className="min-w-0">
                  <span className="block text-latin-label-sm font-semibold">{p.name}</span>
                  <span className="block text-[13px] text-text-secondary">{t(p.companies === 1 ? 'admin.cr.companies_one' : 'admin.cr.companies', { n: num(p.companies, lang) })}</span>
                </label>
                <span className="flex items-center gap-8">
                  <input id={`plan-${p.code}`} type="number" inputMode="numeric" min={0} value={form.plans[p.code] ?? ''} placeholder={t('admin.cr.no_limit')} disabled={!can} onChange={(e) => set({ plans: { ...form.plans, [p.code]: e.target.value } })} aria-invalid={!!fieldErr[`plans.${p.code}`]} className={cx(numberCls(`plans.${p.code}`), 'w-[120px] placeholder:text-taupe-500')} />
                  <span className="w-[56px] text-[13px] text-text-secondary">{t('admin.cr.per_month')}</span>
                </span>
              </li>
            ))}
          </ul>
          <p className="mt-4 text-[13px] text-text-secondary">{t('admin.cr.plan_note')}</p>
          <p className="mt-16 text-latin-label-sm font-semibold">{t('admin.cr.packs')}</p>
          <ul className="mt-8 flex flex-wrap gap-8">
            {data.packs.map((p) => (
              <li key={p.credits} className="rounded-lg bg-bg-subtle px-12 py-8 text-latin-label-sm font-semibold">
                {t('admin.cr.pack', { n: num(p.credits, lang), price: p.prices.map((x) => money(x.amount, x.currency, lang)).join(' / ') })}
              </li>
            ))}
          </ul>
        </section>
      </div>

      <section className="kn-in overflow-hidden rounded-xl border border-border-default bg-bg-surface" style={{ ['--d' as string]: '240ms' }}>
        <label className="relative block border-b border-border-default p-12">
          <span className="sr-only">{t('admin.cr.search')}</span>
          <Search width={18} height={18} className="pointer-events-none absolute left-[24px] top-1/2 -translate-y-1/2 text-text-secondary" aria-hidden />
          <input type="search" value={typed} onChange={(e) => setTyped(e.target.value)} placeholder={t('admin.cr.search')} className="h-[40px] w-full max-w-[420px] rounded-lg border border-border-strong bg-bg-surface pl-[38px] pr-12 text-[14px] placeholder:text-taupe-500 hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring" />
        </label>
        {data.items.length === 0 ? (
          <p className="px-24 py-48 text-center text-latin-label-sm text-text-secondary">{q ? t('admin.cr.none_match') : t('admin.cr.none')}</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[880px] text-left">
              <thead className="bg-bg-subtle text-[13px] text-text-secondary">
                <tr>
                  {(['c_company', 'c_plan', 'c_included', 'c_used', 'c_topups', 'c_status'] as const).map((c, i) => (
                    <th key={c} scope="col" className={cx('px-16 py-12 font-semibold', i === 0 && 'pl-20')}>
                      {t(`admin.cr.${c}`)}
                    </th>
                  ))}
                  <th scope="col" className="px-16 py-12">
                    <span className="sr-only">{t('admin.cr.adjust')}</span>
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border-default text-[14px]">
                {data.items.map((r, i) => {
                  const share = r.included ? Math.min(1, r.used / r.included) : 0;
                  return (
                    <tr key={r.company_id} className="kn-in kn-row hover:bg-cream-100" style={{ ['--d' as string]: `${Math.min(i * 30, 400)}ms` }}>
                      <td className="max-w-[240px] truncate py-12 pl-20 pr-16 font-semibold">
                        <Link to={`/companies/${r.company_id}`} className="hover:underline">
                          {r.company}
                        </Link>
                      </td>
                      <td className="px-16 py-12">{r.plan}</td>
                      <td className="px-16 py-12 tabular-nums">{r.included === null ? t('admin.cr.no_limit') : num(r.included, lang)}</td>
                      <td className="w-[200px] px-16 py-12">
                        <p className="text-[13px] font-semibold tabular-nums">{num(r.used, lang)}</p>
                        {r.included !== null && (
                          <div className="mt-4 h-[6px] overflow-hidden rounded-full bg-bg-subtle" aria-hidden>
                            <div className={cx('kn-fill h-full rounded-full', r.status === 'out' ? 'bg-status-danger' : r.status === 'low' ? 'bg-status-warning' : 'bg-espresso-950')} style={{ width: `${share * 100}%` }} />
                          </div>
                        )}
                      </td>
                      <td className="px-16 py-12 text-[13px]">
                        {r.topups || r.topup_left ? (
                          <>
                            <p>{t(r.topups === 1 ? 'admin.cr.topups_one' : 'admin.cr.topups', { n: num(r.topups, lang) })}</p>
                            <p className="text-text-secondary">{t('admin.cr.left', { n: num(r.topup_left, lang) })}</p>
                          </>
                        ) : (
                          '—'
                        )}
                      </td>
                      <td className="px-16 py-12">
                        <StatusPill t={t} lang={lang} r={r} />
                      </td>
                      <td className="px-16 py-12 text-right">
                        {can && r.status !== 'unlimited' && (
                          <button type="button" onClick={() => setAdjusting(r)} className="kn-btn inline-flex h-[32px] items-center rounded-md border border-border-strong px-12 text-[13px] font-semibold hover:border-mocha-500">
                            {t('admin.cr.adjust')}
                          </button>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
        {last > 1 && (
          <div className="flex items-center justify-between gap-8 border-t border-border-default px-20 py-12 text-[13px] text-text-secondary">
            <button type="button" disabled={page <= 1} onClick={() => setPage(page - 1)} aria-label={t('admin.co.prev')} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md border border-border-default disabled:opacity-40">
              <ChevronLeft width={16} height={16} aria-hidden />
            </button>
            {t('admin.co.page', { n: `${num(page, lang)} / ${num(last, lang)}` })}
            <button type="button" disabled={page >= last} onClick={() => setPage(page + 1)} aria-label={t('admin.co.next')} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md border border-border-default disabled:opacity-40">
              <ChevronRight width={16} height={16} aria-hidden />
            </button>
          </div>
        )}
      </section>

      {adjusting && (
        <AdjustDialog
          t={t}
          lang={lang}
          row={adjusting}
          onClose={() => setAdjusting(null)}
          onDone={() => {
            setNote({ ok: true, text: t('admin.cr.adjusted', { company: adjusting.company }) });
            setAdjusting(null);
            load();
          }}
        />
      )}
    </div>
  );
}
