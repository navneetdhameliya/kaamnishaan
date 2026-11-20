import { AlertCircle, Check, ChevronDown, ChevronLeft, ChevronRight, Info, Lock, Pencil, Phone, PhoneCall, RotateCcw } from 'lucide-react';
import { useCallback, useEffect, useState, type ReactNode } from 'react';

import { api, ApiError } from '../lib/api';
import { clock, day, num, type Lang, type T } from '../lib/i18n';
import type { AiCallSettings, AiCallsOut, CallOutcome } from '../lib/types';
import { cx, Link, PageActions, Spinner, Switch, TextDialog } from '../ui';

const PAGE_SIZE = 20;
const VOICES = ['warm', 'bright', 'formal'] as const;
const HOURS = ['10-19', '9-20', '11-18'] as const;
const ATTEMPTS = ['call_voicemail', 'two_calls', 'call_only'] as const;

function usd(v: number, lang: Lang): string {
  return num(v, lang, { style: 'currency', currency: 'USD', minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function Kpi({ label, value, sub, i }: { label: string; value: string; sub: string; i: number }) {
  return (
    <div className="kn-in" style={{ ['--d' as string]: `${i * 60}ms` }}>
      <div className="kn-hover h-full rounded-xl border border-border-default bg-bg-surface p-20">
        <p className="text-[14px] font-semibold text-text-secondary">{label}</p>
        <p className="mt-8 text-[32px] font-bold leading-[40px] tabular-nums">{value}</p>
        <p className="mt-4 text-[13px] text-text-secondary">{sub}</p>
      </div>
    </div>
  );
}

function Select({ id, label, value, options, disabled, onChange }: { id: string; label: string; value: string; options: { value: string; label: string }[]; disabled?: boolean; onChange: (v: string) => void }) {
  return (
    <div>
      <label htmlFor={id} className="block text-latin-label-sm font-semibold">
        {label}
      </label>
      <div className="relative mt-8">
        <select id={id} value={value} disabled={disabled} onChange={(e) => onChange(e.target.value)} className="h-[48px] w-full cursor-pointer appearance-none rounded-lg border border-border-strong bg-bg-surface pl-16 pr-[40px] text-latin-body hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring disabled:cursor-not-allowed disabled:opacity-70">
          {options.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>
        <ChevronDown width={18} height={18} className="pointer-events-none absolute right-16 top-1/2 -translate-y-1/2" aria-hidden />
      </div>
    </div>
  );
}

function Outcome({ t, lang, c }: { t: T; lang: Lang; c: AiCallsOut['calls'][number] }) {
  const pill = (tone: string, text: string) => <span className={cx('inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold', tone)}>{text}</span>;
  const good = 'bg-status-success-bg text-status-success';
  const bad = 'bg-status-danger-bg text-status-danger';
  const warn = 'bg-status-warning-bg text-status-warning';
  const plain = 'bg-bg-subtle text-mocha-700';
  const o: CallOutcome = c.outcome;
  if (o === 'rated') {
    const low = (c.rating ?? 5) <= 2;
    return pill(low ? bad : good, c.wants_call_back ? t('admin.ac.o.rated_call', { n: c.rating ?? 0 }) : t('admin.ac.o.rated', { n: c.rating ?? 0 }));
  }
  if (o === 'call_back') return pill(warn, c.callback_at ? t('admin.ac.o.call_back_at', { time: clock(c.callback_at, lang) }) : t('admin.ac.o.call_back'));
  const tone = { voicemail_sms: plain, no_answer: plain, opted_out: plain, wrong_person: warn, skipped_dnd: plain, failed_sms: bad, no_provider_sms: plain, no_credits_sms: warn, not_sent: bad }[o];
  return pill(tone, t(`admin.ac.o.${o}`));
}

function when(iso: string, t: T, lang: Lang): string {
  return new Date(iso).toDateString() === new Date().toDateString() ? t('admin.ac.today', { time: clock(iso, lang) }) : `${day(iso, lang, { year: undefined })} ${clock(iso, lang)}`;
}

function length(s: number): string {
  return s ? `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}` : '—';
}

/** A38 AI review calls, from GET /admin/ai-calls. */
export function AiCalls({ t, lang }: { t: T; lang: Lang }) {
  const [data, setData] = useState<AiCallsOut | null>(null);
  const [form, setForm] = useState<AiCallSettings | null>(null);
  const [page, setPage] = useState(1);
  const [error, setError] = useState(false);
  const [saving, setSaving] = useState(false);
  const [note, setNote] = useState<{ ok: boolean; text: string } | null>(null);
  const [editing, setEditing] = useState<string | null>(null);
  const [testing, setTesting] = useState(false);
  const [retrying, setRetrying] = useState(false);

  const load = useCallback(() => {
    setError(false);
    api<AiCallsOut>(`/admin/ai-calls?page=${page}&page_size=${PAGE_SIZE}`)
      .then((d) => {
        setData(d);
        setForm((f) => f ?? d.settings);
      })
      .catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, [page]);
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
        <div className="grid gap-16 sm:grid-cols-2 xl:grid-cols-5">
          {[0, 1, 2, 3, 4].map((i) => (
            <div key={i} className="kn-shimmer h-[128px] rounded-xl bg-bg-surface" />
          ))}
        </div>
        <div className="grid gap-16 xl:grid-cols-[1fr_420px]">
          <div className="kn-shimmer h-[480px] rounded-xl bg-bg-surface" />
          <div className="kn-shimmer h-[480px] rounded-xl bg-bg-surface" />
        </div>
      </div>
    );

  const k = data.kpis;
  const pct = (v: number | null) => (v === null ? '—' : num(v, lang, { style: 'percent', maximumFractionDigits: 1 }));
  const dirty = (['voice', 'language', 'hours', 'attempts', 'record'] as const).some((x) => form[x] !== data.settings[x]);
  const can = data.can_act;
  const set = (patch: Partial<AiCallSettings>) => {
    setNote(null);
    setForm({ ...form, ...patch });
  };
  const save = async () => {
    setSaving(true);
    setNote(null);
    try {
      const out = await api<AiCallSettings>('/admin/ai-calls/settings', { method: 'PUT', body: { voice: form.voice, language: form.language, hours: form.hours, attempts: form.attempts, record: form.record } });
      setData({ ...data, settings: out });
      setForm(out);
      setNote({ ok: true, text: t('admin.ac.saved') });
    } catch {
      setNote({ ok: false, text: t('admin.err.generic') });
    } finally {
      setSaving(false);
    }
  };
  const last = Math.max(1, Math.ceil(data.total / data.page_size));
  const opening = data.script.opening.replace('{company}', '{{company}}');
  const stepText = editing ? data.script.steps.find((s) => s.key === editing)?.text ?? '' : '';

  const banner: ReactNode = data.provider.down_since ? (
    <div role="alert" className="kn-in flex flex-col gap-12 rounded-xl border border-status-danger bg-status-danger-bg px-20 py-16 sm:flex-row sm:items-center">
      <AlertCircle width={22} height={22} className="shrink-0 text-status-danger" aria-hidden />
      <div className="min-w-0 flex-1">
        <p className="text-latin-label-sm font-semibold text-status-danger">{t('admin.ac.down_title', { time: clock(data.provider.down_since, lang) })}</p>
        <p className="mt-2 text-latin-label-sm">{t('admin.ac.down_body', { n: num(data.provider.waiting, lang) })}</p>
      </div>
      {can && (
        <button
          type="button"
          disabled={retrying}
          onClick={async () => {
            setRetrying(true);
            try {
              await api('/admin/ai-calls/retry', { method: 'POST' });
              load();
            } finally {
              setRetrying(false);
            }
          }}
          className="kn-btn inline-flex h-[44px] shrink-0 items-center gap-8 rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action disabled:opacity-60"
        >
          {retrying ? <Spinner /> : <RotateCcw width={16} height={16} aria-hidden />}
          {t('admin.ac.retry')}
        </button>
      )}
    </div>
  ) : !data.provider.connected ? (
    <div role="status" className="kn-in flex items-start gap-12 rounded-xl bg-status-info-bg px-16 py-12 text-status-info">
      <Info width={18} height={18} className="mt-[2px] shrink-0" aria-hidden />
      <p className="text-latin-label-sm">
        <span className="font-semibold">{t('admin.ac.off_title')}</span> {t('admin.ac.off_body')}
      </p>
    </div>
  ) : null;

  return (
    <div className="flex flex-col gap-16">
      {can && (
        <PageActions>
          <button type="button" onClick={() => setTesting(true)} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300">
            <Phone width={16} height={16} aria-hidden />
            <span className="hidden sm:inline">{t('admin.ac.test')}</span>
          </button>
          <button type="button" disabled={!dirty || saving} onClick={save} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action disabled:opacity-50">
            {saving ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
            {t('admin.ac.save')}
          </button>
        </PageActions>
      )}
      {banner}
      {note && (
        <p role={note.ok ? 'status' : 'alert'} className={cx('kn-pop rounded-lg px-16 py-12 text-latin-label-sm font-semibold', note.ok ? 'bg-status-success-bg text-status-success' : 'bg-status-danger-bg text-status-danger')}>
          {note.text}
        </p>
      )}

      <div className="grid gap-16 sm:grid-cols-2 xl:grid-cols-5">
        <Kpi i={0} label={t('admin.ac.k_calls')} value={num(k.calls, lang)} sub={data.provider.connected ? t('admin.ac.k_calls_sub') : t('admin.ac.k_sms', { n: num(k.sms_instead, lang) })} />
        <Kpi i={1} label={t('admin.ac.k_answered')} value={pct(k.answered)} sub={t('admin.ac.k_answered_sub')} />
        <Kpi i={2} label={t('admin.ac.k_rated')} value={pct(k.rated)} sub={t('admin.ac.k_rated_sub')} />
        <Kpi i={3} label={t('admin.ac.k_opted')} value={pct(k.opted_out)} sub={t('admin.ac.k_opted_sub')} />
        <Kpi i={4} label={t('admin.ac.k_cost')} value={k.cost_per_call_usd === null ? '—' : usd(k.cost_per_call_usd, lang)} sub={t('admin.ac.k_cost_sub')} />
      </div>

      <div className="grid items-start gap-16 xl:grid-cols-[minmax(0,1fr)_420px]">
        <section className="kn-in rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24" style={{ ['--d' as string]: '120ms' }}>
          <h2 className="text-[20px] font-semibold leading-[28px]">{t('admin.ac.agent')}</h2>
          <div className="mt-16 grid gap-16 sm:grid-cols-2">
            <Select id="voice" label={t('admin.ac.voice')} value={form.voice} disabled={!can} options={VOICES.map((v) => ({ value: v, label: t(`admin.ac.voice.${v}`) }))} onChange={(v) => set({ voice: v as AiCallSettings['voice'] })} />
            <Select id="language" label={t('admin.ac.language')} value={form.language} disabled={!can} options={(['report', 'en'] as const).map((v) => ({ value: v, label: t(`admin.ac.lang.${v}`) }))} onChange={(v) => set({ language: v as AiCallSettings['language'] })} />
          </div>
          <p className="mt-16 text-latin-label-sm font-semibold">{t('admin.ac.opening')}</p>
          <div className="mt-8 flex items-center gap-12 rounded-lg border border-border-default bg-bg-subtle px-16 py-12">
            <p className="min-w-0 flex-1 break-words text-latin-body">“{opening}”</p>
            <Lock width={18} height={18} className="shrink-0 text-text-secondary" aria-label={t('admin.ac.locked')} />
          </div>
          <p className="mt-8 text-[13px] text-text-secondary">{t('admin.ac.opening_note')}</p>
          <div className="mt-16 grid gap-16 sm:grid-cols-2">
            <Select id="hours" label={t('admin.ac.hours')} value={form.hours} disabled={!can} options={HOURS.map((h) => ({ value: h, label: t('admin.ac.hours_v', { from: `${h.split('-')[0].padStart(2, '0')}:00`, to: `${h.split('-')[1]}:00` }) }))} onChange={(v) => set({ hours: v as AiCallSettings['hours'] })} />
            <Select id="attempts" label={t('admin.ac.attempts')} value={form.attempts} disabled={!can} options={ATTEMPTS.map((a) => ({ value: a, label: t(`admin.ac.att.${a}`) }))} onChange={(v) => set({ attempts: v as AiCallSettings['attempts'] })} />
          </div>
          <div className="mt-12 flex flex-col gap-4">
            <Switch label={t('admin.ac.dnd')} hint={t('admin.ac.dnd_hint')} checked disabled onChange={() => undefined} />
            <Switch label={t('admin.ac.record')} hint={t('admin.ac.record_hint')} checked={form.record} disabled={!can} onChange={(on) => set({ record: on })} />
            <Switch label={t('admin.ac.only')} hint={t('admin.ac.only_hint')} checked disabled onChange={() => undefined} />
          </div>
        </section>

        <section className="kn-in rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24" style={{ ['--d' as string]: '180ms' }}>
          <div className="flex items-center justify-between gap-12">
            <h2 className="text-[20px] font-semibold leading-[28px]">{t('admin.ac.script')}</h2>
            <span className="rounded-full bg-status-success-bg px-[10px] py-[3px] text-[13px] font-semibold text-status-success">{t('admin.ac.live', { n: data.script.version })}</span>
          </div>
          <ol className="mt-12 flex flex-col">
            {data.script.steps.map((s, i) => (
              <li key={s.key} className="kn-in flex items-center gap-12 py-[6px]" style={{ ['--d' as string]: `${200 + i * 40}ms` }}>
                <span className="inline-flex h-[24px] w-[24px] shrink-0 items-center justify-center rounded-full bg-bg-subtle text-[12px] font-semibold">{num(i + 1, lang)}</span>
                <span className="min-w-0 flex-1 text-latin-label-sm font-semibold">{t(`admin.ac.step.${s.key}`)}</span>
                {can && (
                  <button type="button" onClick={() => setEditing(s.key)} aria-label={t('admin.ac.edit_step', { step: t(`admin.ac.step.${s.key}`) })} className="inline-flex h-[36px] w-[36px] shrink-0 items-center justify-center rounded-md text-text-secondary hover:bg-bg-subtle hover:text-text-primary">
                    <Pencil width={16} height={16} aria-hidden />
                  </button>
                )}
              </li>
            ))}
          </ol>
          <p className="mt-8 text-[13px] text-text-secondary">{t('admin.ac.script_note')}</p>
        </section>
      </div>

      <section className="kn-in overflow-hidden rounded-xl border border-border-default bg-bg-surface" style={{ ['--d' as string]: '240ms' }}>
        {data.calls.length === 0 ? (
          <div className="flex flex-col items-center px-24 py-48 text-center">
            <span className="kn-pop inline-flex h-[72px] w-[72px] items-center justify-center rounded-full bg-bg-subtle text-mocha-700">
              <PhoneCall width={28} height={28} aria-hidden />
            </span>
            <h2 className="mt-12 text-[20px] font-semibold">{t('admin.ac.empty_title')}</h2>
            <p className="mt-4 max-w-[420px] text-latin-label-sm text-text-secondary">{t('admin.ac.empty_body')}</p>
          </div>
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="w-full min-w-[920px] text-left">
                <thead className="bg-bg-subtle text-[13px] text-text-secondary">
                  <tr>
                    {(['c_time', 'c_company', 'c_customer', 'c_language', 'c_length', 'c_outcome', 'c_cost'] as const).map((c, i) => (
                      <th key={c} scope="col" className={cx('px-16 py-12 font-semibold', i === 0 && 'pl-20')}>
                        {t(`admin.ac.${c}`)}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-border-default text-[14px]">
                  {data.calls.map((c, i) => (
                    <tr key={c.id} className="kn-in kn-row hover:bg-cream-100" style={{ ['--d' as string]: `${Math.min(i * 30, 400)}ms` }}>
                      <td className="whitespace-nowrap py-12 pl-20 pr-16 font-semibold">{when(c.at, t, lang)}</td>
                      <td className="max-w-[200px] truncate px-16 py-12">
                        <Link to={`/companies/${c.company.value}`} className="hover:underline">
                          {c.company.label}
                        </Link>
                      </td>
                      <td className="max-w-[200px] px-16 py-12">
                        <p className="truncate font-semibold">{c.contact_name ?? '—'}</p>
                        {c.place && <p className="truncate text-[13px] text-text-secondary">{c.place}</p>}
                      </td>
                      <td className="px-16 py-12">{c.language ? t(`lang.${c.language}`) : '—'}</td>
                      <td className="px-16 py-12 tabular-nums">{length(c.seconds)}</td>
                      <td className="px-16 py-12">
                        <Outcome t={t} lang={lang} c={c} />
                      </td>
                      <td className="px-16 py-12 tabular-nums">{usd(c.cost_usd, lang)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
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
          </>
        )}
      </section>

      {editing && (
        <TextDialog
          key={editing}
          t={t}
          title={t(`admin.ac.step.${editing}`)}
          body={t('admin.ac.edit_body')}
          label={t('admin.ac.edit_label')}
          initial={stepText}
          multiline
          min={10}
          max={600}
          confirm={t('admin.ac.save_step')}
          onClose={() => setEditing(null)}
          onConfirm={async (text) => {
            try {
              const script = await api<AiCallsOut['script']>(`/admin/ai-calls/script/${editing}`, { method: 'PUT', body: { text } });
              setData({ ...data, script });
              setEditing(null);
              setNote({ ok: true, text: t('admin.ac.step_saved', { n: script.version }) });
              return null;
            } catch (e) {
              return e instanceof ApiError && e.fields?.text === 'needs_job' ? t('admin.ac.needs_job') : t('admin.err.generic');
            }
          }}
        />
      )}
      {testing && (
        <TextDialog
          t={t}
          title={t('admin.ac.test_title')}
          body={data.provider.connected ? t('admin.ac.test_body') : t('admin.ac.test_off')}
          label={t('admin.ac.test_phone')}
          type="tel"
          min={8}
          max={20}
          confirm={t('admin.ac.test_go')}
          onClose={() => setTesting(false)}
          onConfirm={async (phone) => {
            try {
              const r = await api<{ outcome: string; seconds: number }>('/admin/ai-calls/test', { method: 'POST', body: { phone } });
              setTesting(false);
              setNote({ ok: true, text: t('admin.ac.test_done', { length: length(r.seconds) }) });
              return null;
            } catch (e) {
              if (e instanceof ApiError && e.code === 'no_voice_provider') return t('admin.ac.test_off');
              if (e instanceof ApiError && e.fields?.phone) return t('admin.ac.test_bad_phone');
              return t('admin.err.generic');
            }
          }}
        />
      )}
    </div>
  );
}
