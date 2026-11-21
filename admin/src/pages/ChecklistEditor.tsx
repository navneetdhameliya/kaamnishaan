import { Archive, ArrowDown, ArrowUp, Camera, Check, ChevronLeft, ImagePlus, Languages, Pencil, Plus, Send, Trash2, Undo2, X } from 'lucide-react';
import { useCallback, useEffect, useState, type FormEvent } from 'react';

import { api, ApiError } from '../lib/api';
import { day, LANGS, num, plural, type Lang, type T } from '../lib/i18n';
import { session } from '../lib/session';
import type { ChecklistDetail, ChecklistQuestion, LangState } from '../lib/types';
import { cx, ErrorBanner, Link, Spinner } from '../ui';

const TYPES = ['yes_no', 'pass_fail', 'number', 'text', 'choice', 'photo', 'signature'] as const;
type QType = (typeof TYPES)[number];
const PHOTO_FOR: Record<QType, ('none' | 'always' | 'if_no' | 'if_fail')[]> = {
  yes_no: ['none', 'if_no', 'always'],
  pass_fail: ['none', 'if_fail', 'always'],
  number: ['none', 'always'],
  text: ['none', 'always'],
  choice: ['none', 'always'],
  photo: ['none'],
  signature: ['none'],
};
const PHOTO_LABEL = { none: 'admin.cl.photo_none', always: 'cb.photo_always', if_no: 'cb.photo_if_no', if_fail: 'cb.photo_if_fail' } as const;
const STATE_LOOK: Record<LangState, string> = {
  ready: 'bg-status-success-bg text-status-success',
  review: 'bg-status-warning-bg text-status-warning',
  missing: 'bg-status-danger-bg text-status-danger',
};
const input = 'h-[44px] w-full rounded-lg border border-border-strong bg-bg-surface px-12 text-latin-body hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring';

type Draft = {
  type: QType;
  text: string;
  help: string;
  options: string[];
  unit: string;
  min: string;
  max: string;
  photo_rule: 'none' | 'always' | 'if_no' | 'if_fail';
  required: boolean;
  cond_q: string;
  cond_v: string;
};

const blank = (): Draft => ({ type: 'yes_no', text: '', help: '', options: ['', ''], unit: '', min: '', max: '', photo_rule: 'none', required: true, cond_q: '', cond_v: '' });

function fromQuestion(q: ChecklistQuestion, src: string): Draft {
  return {
    type: q.type,
    text: q.text[src] ?? '',
    help: q.help[src] ?? '',
    options: q.options.map((o) => o.label[src] ?? ''),
    unit: q.unit ?? '',
    min: q.min_value?.toString() ?? '',
    max: q.max_value?.toString() ?? '',
    photo_rule: q.photo_rule,
    required: q.required,
    cond_q: q.condition?.question_id ?? '',
    cond_v: q.condition?.equals ?? '',
  };
}

function answers(t: T, q: ChecklistQuestion, src: string): { value: string; label: string }[] {
  if (q.type === 'yes_no') return [{ value: 'yes', label: t('admin.cl.yes') }, { value: 'no', label: t('admin.cl.no') }];
  if (q.type === 'pass_fail') return [{ value: 'pass', label: t('admin.cl.pass') }, { value: 'fail', label: t('admin.cl.fail') }];
  if (q.type === 'choice') return q.options.map((o) => ({ value: o.key, label: o.label[src] ?? o.key }));
  return [];
}

/** Add or change a question (always in the source language, English). */
function QuestionForm({ t, d, earlier, initial, busy, error, onSave, onCancel }: { t: T; d: ChecklistDetail; earlier: ChecklistQuestion[]; initial: Draft; busy: boolean; error: string | null; onSave: (x: Draft) => void; onCancel: () => void }) {
  const [x, setX] = useState<Draft>(initial);
  const set = (p: Partial<Draft>) => setX((v) => ({ ...v, ...p }));
  const condQ = earlier.find((q) => q.id === x.cond_q);
  const submit = (e: FormEvent) => {
    e.preventDefault();
    onSave(x);
  };
  return (
    <form noValidate onSubmit={submit} className="kn-in flex flex-col gap-12 rounded-lg border border-mocha-500 bg-bg-surface p-16">
      {error && <ErrorBanner>{error}</ErrorBanner>}
      <div className="grid gap-12 sm:grid-cols-[200px_1fr]">
        <label className="text-latin-label-sm font-semibold">
          {t('cb.answer_type')}
          <select value={x.type} onChange={(e) => set({ type: e.target.value as QType, photo_rule: 'none' })} className={`${input} mt-4`}>
            {TYPES.map((ty) => (
              <option key={ty} value={ty}>
                {t(`cb.t_${ty}`)}
              </option>
            ))}
          </select>
        </label>
        <label className="text-latin-label-sm font-semibold">
          {t('cb.question')}
          <input value={x.text} onChange={(e) => set({ text: e.target.value })} maxLength={200} placeholder={t('cb.question_hint')} className={`${input} mt-4`} />
        </label>
      </div>
      <label className="text-latin-label-sm font-semibold">
        {t('admin.cl.help')}
        <input value={x.help} onChange={(e) => set({ help: e.target.value })} maxLength={300} className={`${input} mt-4`} />
      </label>
      {x.type === 'choice' && (
        <fieldset className="flex flex-col gap-8">
          <legend className="text-latin-label-sm font-semibold">{t('admin.cl.options')}</legend>
          {x.options.map((o, i) => (
            <div key={i} className="flex gap-8">
              <input value={o} onChange={(e) => set({ options: x.options.map((v, j) => (j === i ? e.target.value : v)) })} maxLength={80} aria-label={`${t('admin.cl.options')} ${i + 1}`} className={input} />
              <button type="button" disabled={x.options.length <= 2} onClick={() => set({ options: x.options.filter((_, j) => j !== i) })} aria-label={t('admin.cl.remove_option', { n: i + 1 })} className="inline-flex h-[44px] w-[44px] shrink-0 items-center justify-center rounded-lg bg-bg-subtle disabled:opacity-40">
                <X width={16} height={16} aria-hidden />
              </button>
            </div>
          ))}
          {x.options.length < 12 && (
            <button type="button" onClick={() => set({ options: [...x.options, ''] })} className="inline-flex w-fit items-center gap-4 text-latin-label-sm font-semibold text-mocha-700">
              <Plus width={16} height={16} aria-hidden />
              {t('admin.cl.add_option')}
            </button>
          )}
        </fieldset>
      )}
      {x.type === 'number' && (
        <div className="grid grid-cols-3 gap-12">
          <label className="text-latin-label-sm font-semibold">
            {t('cb.unit')}
            <input value={x.unit} onChange={(e) => set({ unit: e.target.value })} maxLength={16} placeholder={t('cb.unit_hint')} className={`${input} mt-4`} />
          </label>
          <label className="text-latin-label-sm font-semibold">
            {t('admin.cl.min')}
            <input type="number" value={x.min} onChange={(e) => set({ min: e.target.value })} className={`${input} mt-4`} />
          </label>
          <label className="text-latin-label-sm font-semibold">
            {t('admin.cl.max')}
            <input type="number" value={x.max} onChange={(e) => set({ max: e.target.value })} className={`${input} mt-4`} />
          </label>
        </div>
      )}
      <div className="grid gap-12 sm:grid-cols-2">
        {PHOTO_FOR[x.type].length > 1 && (
          <label className="text-latin-label-sm font-semibold">
            {t('admin.cl.photo')}
            <select value={x.photo_rule} onChange={(e) => set({ photo_rule: e.target.value as Draft['photo_rule'] })} className={`${input} mt-4`}>
              {PHOTO_FOR[x.type].map((r) => (
                <option key={r} value={r}>
                  {t(PHOTO_LABEL[r])}
                </option>
              ))}
            </select>
          </label>
        )}
        <label className="flex items-center gap-12 self-end py-8 text-latin-label-sm font-semibold">
          <input type="checkbox" checked={x.required} onChange={(e) => set({ required: e.target.checked })} className="h-[20px] w-[20px] accent-[#2b1d16]" />
          {t('admin.cl.required')}
        </label>
      </div>
      {earlier.some((q) => answers(t, q, d.source_language).length) && (
        <div className="grid gap-12 sm:grid-cols-2">
          <label className="text-latin-label-sm font-semibold">
            {t('admin.cl.show_if')}
            <select value={x.cond_q} onChange={(e) => set({ cond_q: e.target.value, cond_v: '' })} className={`${input} mt-4`}>
              <option value="">{t('admin.cl.always')}</option>
              {earlier
                .filter((q) => answers(t, q, d.source_language).length)
                .map((q) => (
                  <option key={q.id} value={q.id}>
                    Q{q.position} · {q.text[d.source_language]}
                  </option>
                ))}
            </select>
          </label>
          {condQ && (
            <label className="text-latin-label-sm font-semibold">
              {t('admin.cl.answer_is')}
              <select value={x.cond_v} onChange={(e) => set({ cond_v: e.target.value })} className={`${input} mt-4`}>
                <option value="" disabled>
                  —
                </option>
                {answers(t, condQ, d.source_language).map((a) => (
                  <option key={a.value} value={a.value}>
                    {a.label}
                  </option>
                ))}
              </select>
            </label>
          )}
        </div>
      )}
      <p className="text-latin-caption text-text-secondary">{t('cb.translate_note')}</p>
      <div className="flex justify-end gap-12">
        <button type="button" onClick={onCancel} className="kn-btn h-[44px] rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300">
          {t('admin.cl.cancel')}
        </button>
        <button type="submit" disabled={busy || !x.text.trim()} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-60">
          {busy && <Spinner />}
          {t('cb.save_q')}
        </button>
      </div>
    </form>
  );
}

function body(x: Draft, d: ChecklistDetail, existing?: ChecklistQuestion) {
  const opts =
    x.type === 'choice'
      ? x.options
          .map((label, i) => ({ label: label.trim(), key: existing?.options[i]?.key }))
          .filter((o) => o.label)
          .map((o) => (o.key ? { key: o.key, label: o.label } : { label: o.label }))
      : [];
  const cond = x.cond_q && x.cond_v ? { question_id: x.cond_q, equals: x.cond_v } : null;
  const b: Record<string, unknown> = {
    text: x.text.trim(),
    help: x.help.trim() || (existing ? '' : null),
    options: opts,
    unit: x.type === 'number' ? x.unit.trim() || null : null,
    min_value: x.type === 'number' && x.min !== '' ? Number(x.min) : null,
    max_value: x.type === 'number' && x.max !== '' ? Number(x.max) : null,
    photo_rule: x.photo_rule,
    required: x.required,
  };
  if (existing) {
    if (cond) b.condition = cond;
    else if (existing.condition) b.clear_condition = true;
    if (b.help === '' && !existing.help[d.source_language]) delete b.help;
  } else {
    b.type = x.type;
    b.condition = cond;
  }
  return b;
}

/** One checklist template: its questions in each language, translations and publishing. */
export function ChecklistEditor({ t, lang, id, onName }: { t: T; lang: Lang; id: string; onName: (n: string) => void }) {
  const [d, setD] = useState<ChecklistDetail | null>(null);
  const [error, setError] = useState<'missing' | 'load' | null>(null);
  const [view, setView] = useState<string>('en');
  const [editing, setEditing] = useState<string | 'new' | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [tr, setTr] = useState<Record<string, string>>({});
  const [name, setName] = useState('');
  const canEdit = session.get()?.staff.role !== 'support';

  const take = useCallback(
    (x: ChecklistDetail) => {
      setD(x);
      onName(x.name[lang] || x.name[x.source_language] || '');
    },
    [lang, onName],
  );
  const load = useCallback(() => {
    setError(null);
    api<ChecklistDetail>(`/admin/checklist-templates/${id}?locale=${lang}`)
      .then((x) => {
        take(x);
        setView((v) => v || x.source_language);
      })
      .catch((e) => {
        if (e instanceof ApiError && (e.status === 404 || e.status === 422)) setError('missing');
        else if (!(e instanceof ApiError && e.status === 401)) setError('load');
      });
  }, [id, lang, take]);
  useEffect(load, [load]);
  useEffect(() => {
    if (d) setName(d.name[view] ?? '');
    setTr({});
  }, [view, d?.id, d?.version]); // eslint-disable-line react-hooks/exhaustive-deps

  const call = async (key: string, path: string, method: string, payload?: unknown, done?: string) => {
    setBusy(key);
    setFormError(null);
    try {
      const x = await api<ChecklistDetail>(`/admin/checklist-templates/${id}${path}?locale=${lang}`, { method, body: payload });
      take(x);
      if (done) setNotice(done);
      return true;
    } catch (e) {
      const msg = e instanceof ApiError ? (e.status === 403 ? t('admin.cl.read_only') : e.status === 0 ? t('admin.err.offline') : e.message) : t('admin.err.generic');
      setFormError(msg);
      return false;
    } finally {
      setBusy(null);
    }
  };

  /** The reference photo: the file itself is the body. */
  const setReference = async (q: ChecklistQuestion, file: File) => {
    setBusy(`r-${q.id}`);
    setFormError(null);
    try {
      take(await api<ChecklistDetail>(`/admin/checklist-templates/${id}/questions/${q.id}/reference?locale=${lang}`, { method: 'PUT', file }));
      setNotice(t('admin.cl.ref_saved'));
    } catch (e) {
      setFormError(e instanceof ApiError && e.status === 400 ? e.message : t('admin.err.generic'));
    } finally {
      setBusy(null);
    }
  };

  const back = (
    <Link to="/checklist-templates" className="group inline-flex w-fit items-center gap-4 text-latin-label-sm font-semibold text-text-secondary hover:text-text-primary">
      <ChevronLeft width={16} height={16} className="transition-transform group-hover:-translate-x-[3px]" aria-hidden />
      {t('admin.cl.back')}
    </Link>
  );
  if (error)
    return (
      <div className="flex flex-col gap-16">
        {back}
        <p className="kn-in mx-auto mt-24 max-w-[480px] rounded-xl border border-border-default bg-bg-surface p-24 text-center text-latin-body text-text-secondary">{t(error === 'missing' ? 'admin.cl.not_found' : 'admin.err.load')}</p>
      </div>
    );
  if (!d) return <div aria-busy="true" className="kn-shimmer h-[480px] rounded-xl bg-bg-surface" />;

  const src = d.source_language;
  const isSrc = view === src;
  const qs = d.questions;
  const pill = (s: LangState) => <span className={cx('rounded-full px-8 py-[2px] text-[12px] font-semibold', STATE_LOOK[s])}>{t(`admin.cl.lstate.${s}`)}</span>;
  const status = (q: ChecklistQuestion): LangState => (!q.text[view] ? 'missing' : q.text_status[view] === 'ready' || isSrc ? 'ready' : 'review');
  const saveQuestion = async (x: Draft, q?: ChecklistQuestion) => {
    const ok = q ? await call(`q-${q.id}`, `/questions/${q.id}`, 'PATCH', body(x, d, q)) : await call('new', '/questions', 'POST', body(x, d));
    if (ok) setEditing(null);
  };

  return (
    <div className="flex flex-col gap-24">
      {back}
      {/* header */}
      <section className="kn-in flex flex-col gap-16 rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24">
        <div className="flex flex-wrap items-start justify-between gap-16">
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-8">
              <span className={cx('rounded-full px-[10px] py-[3px] text-[13px] font-semibold', d.status === 'published' ? 'bg-status-success-bg text-status-success' : 'bg-cream-200 text-taupe-550')}>{t(`admin.cl.st.${d.status}`)}</span>
              {d.trade_name && <span className="rounded-full bg-bg-subtle px-[10px] py-[3px] text-[13px] font-semibold text-mocha-700">{d.trade_name}</span>}
              {d.minutes && <span className="text-[13px] text-text-secondary">~{num(d.minutes, lang)} min</span>}
            </div>
            <p className="mt-8 text-[13px] text-text-secondary">
              {plural(t, 'admin.cl.n_questions', qs.length, { n: num(qs.length, lang) })} · {t('admin.cl.used_by', { n: num(d.used_by, lang) })} · v{d.version} · {day(d.updated_at, lang)}
            </p>
          </div>
          {canEdit && (
            <div className="flex flex-wrap gap-8">
              {d.status !== 'published' ? (
                <button type="button" disabled={!!busy || !qs.length} onClick={() => void call('status', '', 'PATCH', { status: 'published' }, t('admin.cl.saved'))} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-50">
                  <Send width={16} height={16} aria-hidden />
                  {t('admin.cl.publish')}
                </button>
              ) : (
                <button type="button" disabled={!!busy} onClick={() => void call('status', '', 'PATCH', { status: 'draft' }, t('admin.cl.saved'))} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300">
                  <Undo2 width={16} height={16} aria-hidden />
                  {t('admin.cl.unpublish')}
                </button>
              )}
              {d.status !== 'archived' && (
                <button type="button" disabled={!!busy} onClick={() => void call('status', '', 'PATCH', { status: 'archived' }, t('admin.cl.saved'))} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300">
                  <Archive width={16} height={16} aria-hidden />
                  {t('admin.cl.archive')}
                </button>
              )}
            </div>
          )}
        </div>
        <p role="note" className="rounded-lg bg-bg-subtle px-12 py-8 text-[13px] text-text-secondary">
          {t(d.status === 'published' ? 'admin.cl.live_note' : 'admin.cl.draft_note')}
        </p>
        {/* name in the language being viewed */}
        <form
          noValidate
          onSubmit={(e) => {
            e.preventDefault();
            if (!name.trim() || name.trim() === (d.name[view] ?? '')) return;
            void call('name', '', 'PATCH', isSrc ? { name: name.trim() } : { names: { [view]: name.trim() } }, t('admin.cl.saved'));
          }}
          className="flex flex-col gap-8 sm:flex-row sm:items-end"
        >
          <label className="flex-1 text-latin-label-sm font-semibold">
            {isSrc ? t('admin.cl.name') : t('admin.cl.name_in', { lang: t(`lang.${view}`) })}
            <input value={name} onChange={(e) => setName(e.target.value)} maxLength={120} disabled={!canEdit} placeholder={d.name[src]} className={`${input} mt-4`} />
          </label>
          {canEdit && (
            <button type="submit" disabled={busy === 'name' || !name.trim() || name.trim() === (d.name[view] ?? '')} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-50">
              {busy === 'name' ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
              {t('admin.ld.save')}
            </button>
          )}
        </form>
      </section>

      {notice && (
        <p role="status" className="kn-pop -my-8 rounded-lg bg-status-success-bg px-16 py-8 text-latin-label-sm font-semibold text-status-success">
          {notice}
        </p>
      )}
      {formError && !editing && <ErrorBanner>{formError}</ErrorBanner>}

      {/* languages */}
      <section className="kn-in rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24" style={{ ['--d' as string]: '60ms' }}>
        <div className="flex flex-wrap items-center justify-between gap-12">
          <div role="tablist" aria-label={t('admin.cl.languages')} className="-mx-4 flex gap-8 overflow-x-auto px-4 pb-4">
            {LANGS.map((l) => {
              const on = view === l;
              const st = d.languages[l];
              return (
                <button key={l} role="tab" aria-selected={on} type="button" onClick={() => (setView(l), setEditing(null))} className={cx('kn-btn inline-flex h-[36px] shrink-0 items-center gap-8 rounded-full border px-16 text-latin-label-sm font-semibold transition-colors', on ? 'border-espresso-950 bg-espresso-950 text-cream-50' : 'border-border-default bg-bg-surface hover:border-mocha-500')}>
                  <span aria-hidden className={cx('h-[8px] w-[8px] rounded-full', st === 'ready' ? 'bg-status-success' : st === 'review' ? 'bg-status-warning' : 'bg-status-danger')} />
                  {t(`lang.${l}`)}
                  <span className="sr-only">{t(`admin.cl.lstate.${st}`)}</span>
                </button>
              );
            })}
          </div>
          {canEdit && (
            <div className="flex flex-wrap gap-8">
              {!isSrc && d.languages[view] === 'review' && (
                <button type="button" disabled={!!busy} onClick={() => void call('approve', '/approve', 'POST', { language: view }, t('admin.cl.saved'))} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-bg-subtle px-12 text-latin-label-sm font-semibold hover:bg-cream-300">
                  {busy === 'approve' ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
                  {t('admin.cl.approve', { lang: t(`lang.${view}`) })}
                </button>
              )}
              <button
                type="button"
                disabled={!!busy || !d.ai_available || !qs.length}
                title={d.ai_available ? undefined : t('admin.cl.no_ai')}
                onClick={async () => {
                  setBusy('translate');
                  try {
                    const r = await api<{ queued: number; ai_available: boolean }>(`/admin/checklist-templates/${id}/translate`, { method: 'POST' });
                    setNotice(r.queued ? t('admin.cl.translate_sent', { n: r.queued }) : t('admin.cl.translate_none'));
                    window.setTimeout(load, 4000);
                  } catch {
                    setFormError(t('admin.err.generic'));
                  } finally {
                    setBusy(null);
                  }
                }}
                className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg border border-border-default bg-bg-surface px-12 text-latin-label-sm font-semibold hover:border-mocha-500 disabled:opacity-50"
              >
                {busy === 'translate' ? <Spinner /> : <Languages width={16} height={16} aria-hidden />}
                {t('admin.cl.translate')}
              </button>
            </div>
          )}
        </div>
        {!d.ai_available && <p className="mt-8 text-[13px] text-text-secondary">{t('admin.cl.no_ai')}</p>}
        {!isSrc && <p className="mt-8 text-[13px] text-text-secondary">{t('admin.cl.only_source')}</p>}

        {/* questions */}
        <ol className="mt-16 flex flex-col gap-12">
          {qs.map((q, i) =>
            editing === q.id ? (
              <li key={q.id}>
                <QuestionForm t={t} d={d} earlier={qs.filter((o) => o.position < q.position)} initial={fromQuestion(q, src)} busy={busy === `q-${q.id}`} error={formError} onSave={(x) => void saveQuestion(x, q)} onCancel={() => (setEditing(null), setFormError(null))} />
              </li>
            ) : (
              <li key={q.id} className="kn-in kn-hover rounded-lg border border-border-default p-16" style={{ ['--d' as string]: `${Math.min(i * 40, 400)}ms` }}>
                <div className="flex flex-wrap items-start justify-between gap-8">
                  <div className="min-w-0 flex-1">
                    <p className="flex flex-wrap items-center gap-8 text-[13px] text-text-secondary">
                      <span className="font-semibold text-text-primary">Q{q.position}</span>
                      <span className="rounded-full bg-bg-subtle px-8 py-[2px] font-semibold text-mocha-700">{t(`cb.t_${q.type}`)}</span>
                      {q.photo_rule !== 'none' && (
                        <span className="inline-flex items-center gap-4">
                          <Camera width={14} height={14} aria-hidden />
                          {t(PHOTO_LABEL[q.photo_rule])}
                        </span>
                      )}
                      {!q.required && <span>{t('admin.cl.optional')}</span>}
                      {q.unit && <span>{q.unit}{q.min_value !== null || q.max_value !== null ? ` · ${q.min_value ?? '…'}–${q.max_value ?? '…'}` : ''}</span>}
                      {q.condition && (() => {
                        const dep = qs.find((o) => o.id === q.condition?.question_id);
                        const a = dep && answers(t, dep, src).find((x) => x.value === q.condition?.equals);
                        return dep ? <span>{t('admin.cl.shown_if', { n: dep.position, v: a?.label ?? q.condition.equals })}</span> : null;
                      })()}
                      {!isSrc && pill(status(q))}
                    </p>
                    <p className="mt-8 text-[15px] font-semibold">{q.text[view] || <span className="font-normal italic text-text-secondary">{q.text[src]}</span>}</p>
                    {(q.help[view] || (isSrc && q.help[src])) && <p className="mt-4 text-[13px] text-text-secondary">{q.help[view]}</p>}
                    {q.options.length > 0 && (
                      <ul className="mt-8 flex flex-wrap gap-8">
                        {q.options.map((o) => (
                          <li key={o.key} className="rounded-md bg-bg-subtle px-8 py-[2px] text-[13px]">
                            {o.label[view] || o.label[src]}
                          </li>
                        ))}
                      </ul>
                    )}
                    {(q.reference_image_url || (canEdit && isSrc)) && (
                      <div className="mt-12 flex flex-wrap items-center gap-12">
                        {q.reference_image_url && (
                          <a href={q.reference_image_url} target="_blank" rel="noreferrer" className="group block overflow-hidden rounded-md" title={t('admin.cl.ref')}>
                            <img src={q.reference_image_url} alt={t('admin.cl.ref')} className="h-[72px] w-[112px] bg-bg-subtle object-cover transition-transform duration-300 group-hover:scale-105" />
                          </a>
                        )}
                        {canEdit && isSrc && (
                          <span className="flex flex-wrap items-center gap-8">
                            <label className={cx('kn-btn inline-flex h-[32px] cursor-pointer items-center gap-8 rounded-full border border-border-default px-12 text-[13px] font-semibold hover:border-mocha-500', busy && 'pointer-events-none opacity-50')}>
                              {busy === `r-${q.id}` ? <Spinner /> : <ImagePlus width={14} height={14} aria-hidden />}
                              {t(q.reference_image_url ? 'admin.cl.ref_change' : 'admin.cl.ref_add')}
                              <input type="file" accept="image/jpeg,image/png,image/webp" className="sr-only" onChange={(e) => { const f = e.target.files?.[0]; e.target.value = ''; if (f) void setReference(q, f); }} />
                            </label>
                            {q.reference_image_url && (
                              <button type="button" disabled={!!busy} onClick={() => void call(`r-${q.id}`, `/questions/${q.id}/reference`, 'DELETE', undefined, t('admin.cl.ref_removed'))} className="text-[13px] font-semibold text-text-secondary hover:text-status-danger disabled:opacity-50">
                                {t('admin.cl.ref_remove')}
                              </button>
                            )}
                            {!q.reference_image_url && <span className="text-[13px] text-text-secondary">{t('admin.cl.ref_hint')}</span>}
                          </span>
                        )}
                      </div>
                    )}
                  </div>
                  {canEdit && isSrc && (
                    <div className="flex shrink-0 gap-4">
                      <button type="button" disabled={!!busy || i === 0} onClick={() => void call(`m-${q.id}`, `/questions/${q.id}`, 'PATCH', { position: q.position - 1 })} aria-label={`Q${q.position} ↑`} className="inline-flex h-[36px] w-[36px] items-center justify-center rounded-md hover:bg-bg-subtle disabled:opacity-30">
                        <ArrowUp width={16} height={16} aria-hidden />
                      </button>
                      <button type="button" disabled={!!busy || i === qs.length - 1} onClick={() => void call(`m-${q.id}`, `/questions/${q.id}`, 'PATCH', { position: q.position + 1 })} aria-label={`Q${q.position} ↓`} className="inline-flex h-[36px] w-[36px] items-center justify-center rounded-md hover:bg-bg-subtle disabled:opacity-30">
                        <ArrowDown width={16} height={16} aria-hidden />
                      </button>
                      <button type="button" disabled={!!busy} onClick={() => (setEditing(q.id), setFormError(null))} aria-label={`${t('admin.cl.edit')} Q${q.position}`} className="inline-flex h-[36px] w-[36px] items-center justify-center rounded-md hover:bg-bg-subtle">
                        <Pencil width={16} height={16} aria-hidden />
                      </button>
                      <button type="button" disabled={!!busy} onClick={() => window.confirm(t('admin.cl.delete_confirm')) && void call(`d-${q.id}`, `/questions/${q.id}`, 'DELETE')} aria-label={`${t('cb.delete_q')} Q${q.position}`} className="inline-flex h-[36px] w-[36px] items-center justify-center rounded-md text-status-danger hover:bg-status-danger-bg">
                        <Trash2 width={16} height={16} aria-hidden />
                      </button>
                    </div>
                  )}
                </div>
                {canEdit && !isSrc && (
                  <form
                    noValidate
                    className="mt-12 flex flex-col gap-8 sm:flex-row"
                    onSubmit={(e) => {
                      e.preventDefault();
                      const v = (tr[q.id] ?? q.text[view] ?? '').trim();
                      if (v) void call(`t-${q.id}`, `/questions/${q.id}`, 'PATCH', { translations: { [view]: v } }, t('admin.cl.saved'));
                    }}
                  >
                    <label className="sr-only" htmlFor={`tr-${q.id}`}>
                      {t('admin.cl.translation')} · {t(`lang.${view}`)}
                    </label>
                    <input id={`tr-${q.id}`} value={tr[q.id] ?? q.text[view] ?? ''} onChange={(e) => setTr((m) => ({ ...m, [q.id]: e.target.value }))} maxLength={200} placeholder={q.text[src]} lang={view} className={input} />
                    <button type="submit" disabled={busy === `t-${q.id}` || !(tr[q.id] ?? q.text[view] ?? '').trim() || (tr[q.id] === undefined && status(q) === 'ready')} className="kn-btn inline-flex h-[44px] shrink-0 items-center justify-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-50">
                      {busy === `t-${q.id}` ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
                      {status(q) === 'review' && tr[q.id] === undefined ? t('admin.cl.mark_checked') : t('admin.cl.save_tr')}
                    </button>
                  </form>
                )}
              </li>
            ),
          )}
        </ol>
        {qs.length === 0 && <p className="mt-16 text-latin-body text-text-secondary">{t('cb.empty_body')}</p>}
        {canEdit && isSrc && (
          <div className="mt-16">
            {editing === 'new' ? (
              <QuestionForm t={t} d={d} earlier={qs} initial={blank()} busy={busy === 'new'} error={formError} onSave={(x) => void saveQuestion(x)} onCancel={() => (setEditing(null), setFormError(null))} />
            ) : (
              <button type="button" onClick={() => (setEditing('new'), setFormError(null))} disabled={!!editing} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg border border-dashed border-mocha-500 px-16 text-latin-label-sm font-semibold text-mocha-700 hover:bg-bg-subtle">
                <Plus width={16} height={16} aria-hidden />
                {t('cb.add')}
              </button>
            )}
          </div>
        )}
      </section>
    </div>
  );
}

