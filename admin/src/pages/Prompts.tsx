import { Check, Pencil, RotateCcw, Trash2 } from 'lucide-react';
import { useCallback, useEffect, useState } from 'react';

import { api, ApiError } from '../lib/api';
import { day, clock, num, type Lang, type T } from '../lib/i18n';
import type { AdminPrompt, AdminPromptsOut, PromptTask } from '../lib/types';
import { cx, ErrorBanner, inputCls, PageActions, Spinner } from '../ui';

const pill = 'inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold';
const at = (iso: string, lang: Lang) => `${day(iso, lang, { year: undefined })}, ${clock(iso, lang)}`;
const usd = (n: number, lang: Lang) => num(n, lang, { style: 'currency', currency: 'USD', maximumFractionDigits: 3 });

function Tile({ label, value }: { label: string; value: string }) {
  return (
    <div className="kn-hover rounded-lg bg-bg-subtle px-12 py-8">
      <p className="text-[13px] text-text-secondary">{label}</p>
      <p className="text-[16px] font-semibold tabular-nums">{value}</p>
    </div>
  );
}

/** A21 Prompt management: each AI prompt, its draft and live versions, and how it does. */
export function Prompts({ t, lang }: { t: T; lang: Lang }) {
  const [data, setData] = useState<AdminPromptsOut | null>(null);
  const [error, setError] = useState(false);
  const [task, setTask] = useState<PromptTask>('report_draft');
  const [text, setText] = useState('');
  const [note, setNote] = useState('');
  const [editing, setEditing] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const [problem, setProblem] = useState<string | null>(null);

  const load = useCallback(() => {
    setError(false);
    api<AdminPromptsOut>('/admin/prompts').then(setData).catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, []);
  useEffect(load, [load]);

  const p: AdminPrompt | undefined = data?.prompts.find((x) => x.task === task);
  const draft = p?.versions.find((v) => v.status === 'draft');
  const live = p?.versions.find((v) => v.status === 'live');
  useEffect(() => {
    setEditing(false);
    setProblem(null);
    setText((draft ?? live)?.system_prompt ?? '');
    setNote(draft?.note ?? '');
  }, [task, draft?.version, draft?.updated_at, live?.version]); // eslint-disable-line react-hooks/exhaustive-deps

  const run = async (key: string, fn: () => Promise<AdminPromptsOut>) => {
    setBusy(key);
    setProblem(null);
    try {
      setData(await fn());
      setEditing(false);
    } catch (e) {
      setProblem(e instanceof ApiError && e.status === 422 ? t('admin.pr.err.language') : t('admin.err.save'));
    } finally {
      setBusy(null);
    }
  };

  if (error && !data)
    return (
      <div className="kn-in mx-auto mt-48 max-w-[480px] rounded-xl border border-border-default bg-bg-surface p-24 text-center">
        <p className="text-latin-body text-text-secondary">{t('admin.err.load')}</p>
        <button type="button" onClick={load} className="kn-btn mt-16 inline-flex h-[44px] items-center rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action">{t('admin.retry')}</button>
      </div>
    );
  if (!data || !p)
    return (
      <div aria-busy="true" className="grid gap-16 lg:grid-cols-[320px_minmax(0,1fr)]">
        <div className="kn-shimmer h-[260px] rounded-xl bg-bg-surface" />
        <div className="kn-shimmer h-[420px] rounded-xl bg-bg-surface" />
      </div>
    );

  const can = data.can_act;
  const shown = draft ?? live;
  const missing = editing && !text.includes('{language}');
  const saveDraft = () => run('save', () => api<AdminPromptsOut>(`/admin/prompts/${task}/draft`, { method: 'PUT', body: { system_prompt: text, note: note.trim() || null } }));
  const publish = (v: number) => run(`pub-${v}`, () => api<AdminPromptsOut>(`/admin/prompts/${task}/versions/${v}/publish`, { method: 'POST' }));

  return (
    <div className="flex flex-col gap-16">
      {can && draft && !editing && (
        <PageActions>
          <button type="button" disabled={!!busy} onClick={() => void publish(draft.version)} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-60">
            {busy === `pub-${draft.version}` ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
            {t('admin.pr.publish', { v: draft.version })}
          </button>
        </PageActions>
      )}
      <div className="grid items-start gap-16 lg:grid-cols-[300px_minmax(0,1fr)]">
        <ul className="kn-in overflow-hidden rounded-xl border border-border-default bg-bg-surface" aria-label={t('admin.nav.prompts')}>
          {data.prompts.map((x, i) => (
            <li key={x.task} className={cx(i > 0 && 'border-t border-border-default')}>
              <button type="button" onClick={() => setTask(x.task)} aria-current={x.task === task ? 'true' : undefined} className={cx('block w-full px-16 py-12 text-left transition-colors', x.task === task ? 'bg-bg-subtle' : 'hover:bg-cream-100')}>
                <span className="block font-mono text-[14px] font-semibold">{x.task.replace('_', '-')}</span>
                <span className="block text-[13px] text-text-secondary">{t(`admin.pr.task.${x.task}`)}</span>
                <span className="block text-[13px] text-text-secondary">
                  {x.live ? t('admin.pr.v_live', { v: x.live }) : t('admin.pr.none_live')}
                  {x.draft ? ` · ${t('admin.pr.v_draft', { v: x.draft })}` : ''}
                </span>
              </button>
            </li>
          ))}
        </ul>

        <section className="kn-in rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24" style={{ ['--d' as string]: '80ms' }}>
          <div className="flex flex-wrap items-center gap-8">
            <h2 className="font-mono text-[20px] font-semibold">{task.replace('_', '-')}</h2>
            {draft && <span className={cx(pill, 'bg-status-warning-bg text-status-warning')}>{t('admin.pr.v_draft', { v: draft.version })}</span>}
            {live && <span className={cx(pill, 'bg-status-success-bg text-status-success')}>{t('admin.pr.v_live', { v: live.version })}</span>}
          </div>
          <p className="mt-4 text-[14px] text-text-secondary">{t(`admin.pr.about.${task}`)}</p>

          <label htmlFor="prompt-text" className="mt-16 block text-latin-label-sm font-semibold">
            {t('admin.pr.system')} {shown && <span className="font-normal text-text-secondary">· {t(draft ? 'admin.pr.showing_draft' : 'admin.pr.showing_live', { v: shown.version })}</span>}
          </label>
          <textarea id="prompt-text" value={text} readOnly={!editing} onChange={(e) => setText(e.target.value)} rows={editing ? 18 : 12} className={cx(inputCls, 'mt-8 h-auto py-12 font-mono text-[13px] leading-[20px]', !editing && 'bg-bg-subtle')} />
          {missing && <p className="mt-4 text-[13px] text-status-danger">{t('admin.pr.err.language')}</p>}
          {editing && (
            <label className="mt-12 block">
              <span className="block text-latin-label-sm font-semibold">{t('admin.pr.note')}</span>
              <input value={note} maxLength={200} onChange={(e) => setNote(e.target.value)} placeholder={t('admin.pr.note_hint')} className={cx(inputCls, 'mt-8')} />
            </label>
          )}
          {shown?.note && !editing && <p className="mt-8 text-[13px] text-text-secondary">{t('admin.pr.note_was', { note: shown.note })}</p>}

          <p className="mt-16 text-latin-label-sm font-semibold">{t('admin.pr.vars')}</p>
          <div className="mt-8 flex flex-wrap gap-8">{p.variables.map((v) => <code key={v} className="rounded-md bg-bg-subtle px-8 py-4 text-[13px]">{`{${v}}`}</code>)}</div>
          <p className="mt-4 text-[13px] text-text-secondary">{t('admin.pr.vars_hint')}</p>

          {problem && <div className="mt-12"><ErrorBanner>{problem}</ErrorBanner></div>}
          {can && (
            <div className="mt-16 flex flex-wrap gap-12">
              {editing ? (
                <>
                  <button type="button" disabled={!!busy || missing || text.trim().length < 40} onClick={() => void saveDraft()} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-50">
                    {busy === 'save' ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
                    {t('admin.pr.save_draft')}
                  </button>
                  <button type="button" onClick={() => { setEditing(false); setText(shown?.system_prompt ?? ''); }} className="kn-btn inline-flex h-[44px] items-center rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold hover:bg-cream-300">{t('admin.us.cancel')}</button>
                </>
              ) : (
                <>
                  <button type="button" onClick={() => setEditing(true)} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold hover:bg-cream-300">
                    <Pencil width={16} height={16} aria-hidden />
                    {t(draft ? 'admin.pr.edit_draft' : 'admin.pr.new_draft', { v: (p.versions[0]?.version ?? 0) + 1 })}
                  </button>
                  {draft && (
                    <button type="button" disabled={!!busy} onClick={() => void run('discard', () => api<AdminPromptsOut>(`/admin/prompts/${task}/draft`, { method: 'DELETE' }))} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg px-16 text-latin-label-sm font-semibold text-status-danger hover:bg-status-danger-bg">
                      <Trash2 width={16} height={16} aria-hidden />
                      {t('admin.pr.discard')}
                    </button>
                  )}
                </>
              )}
            </div>
          )}

          <div className="mt-20 grid gap-12 sm:grid-cols-3">
            <Tile label={t('admin.pr.runs')} value={t('admin.pr.runs_v', { ok: num(p.stats.runs - p.stats.failed, lang), failed: num(p.stats.failed, lang) })} />
            <Tile label={t('admin.pr.avg_tokens')} value={num(p.stats.avg_tokens, lang)} />
            <Tile label={t('admin.pr.avg_cost')} value={usd(p.stats.avg_cost_usd, lang)} />
          </div>

          <h3 className="mt-24 text-[16px] font-semibold">{t('admin.pr.history')}</h3>
          <ol className="mt-8 divide-y divide-border-default text-[14px]">
            {p.versions.map((v) => (
              <li key={v.version} className="flex flex-wrap items-center justify-between gap-12 py-8">
                <span className="min-w-0">
                  <span className="font-semibold">v{v.version}</span>{' '}
                  <span className={cx(pill, 'ml-4', v.status === 'live' ? 'bg-status-success-bg text-status-success' : v.status === 'draft' ? 'bg-status-warning-bg text-status-warning' : 'bg-cream-200 text-taupe-550')}>{t(`admin.pr.st.${v.status}`)}</span>
                  <span className="block text-[13px] text-text-secondary">
                    {v.published_at ? t('admin.pr.published', { who: v.published_by ?? t('admin.pr.seed'), when: at(v.published_at, lang) }) : t('admin.pr.edited', { who: v.edited_by ?? t('admin.pr.seed'), when: at(v.updated_at, lang) })}
                    {v.reports !== null && ` · ${t('admin.pr.used', { n: num(v.reports, lang), flagged: num(v.flagged ?? 0, lang) })}`}
                  </span>
                </span>
                {can && v.status === 'retired' && (
                  <button type="button" disabled={!!busy} onClick={() => void publish(v.version)} className="kn-btn inline-flex h-[36px] items-center gap-8 rounded-lg border border-border-default px-12 text-[13px] font-semibold hover:border-mocha-500 disabled:opacity-50">
                    {busy === `pub-${v.version}` ? <Spinner /> : <RotateCcw width={14} height={14} aria-hidden />}
                    {t('admin.pr.go_back')}
                  </button>
                )}
              </li>
            ))}
          </ol>
        </section>
      </div>
    </div>
  );
}
