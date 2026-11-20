import { Check, ChevronDown, ChevronLeft, ChevronRight, Download, FileUp, RotateCcw, Search, X } from 'lucide-react';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';

import { api, ApiError } from '../lib/api';
import { ago, BUILT_IN, LANGS, num, plural, type Lang, type T } from '../lib/i18n';
import type { AdminTextChange, AdminTextRow, AdminTextsOut } from '../lib/types';
import { cx, ErrorBanner, PageActions, Spinner } from '../ui';

const PAGE_SIZE = 50;
const AREAS = ['app', 'site', 'admin'] as const;
type Area = (typeof AREAS)[number];
const STATUSES = ['not_reviewed', 'changed', 'reviewed', 'all'] as const;
type Status = (typeof STATUSES)[number];
const OTHERS = LANGS.filter((l) => l !== 'en');
const pill = 'inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold';

const areaOf = (key: string): Area => (key.startsWith('admin.') ? 'admin' : key.startsWith('site.') || key.startsWith('web.') ? 'site' : 'app');
const KEYS = Object.keys(BUILT_IN.en);
type Rows = Map<string, AdminTextRow>; // "key|lang"
const id = (key: string, lang: string) => `${key}|${lang}`;
const current = (rows: Rows, key: string, lang: Lang) => rows.get(id(key, lang))?.value ?? BUILT_IN[lang][key] ?? '';
const reviewed = (rows: Rows, key: string, lang: Lang) => lang === 'en' || !!rows.get(id(key, lang))?.reviewed_at;
const placeholders = (s: string) => [...new Set(s.match(/\{\w+\}/g) ?? [])].sort().join(' ');

/** "a,b" lines with quotes, as spreadsheets save them. */
function parseCsv(text: string): string[][] {
  const out: string[][] = [];
  let row: string[] = [];
  let cell = '';
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i]!;
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') (cell += '"'), i++;
      else if (c === '"') quoted = false;
      else cell += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') row.push(cell), (cell = '');
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(cell);
      if (row.some((x) => x !== '')) out.push(row);
      (row = []), (cell = '');
    } else cell += c;
  }
  row.push(cell);
  if (row.some((x) => x !== '')) out.push(row);
  return out;
}
const csvCell = (s: string) => (/[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s);

/** A filter like FilterSelect, but always one of its options. */
function Pick({ label, value, options, onChange }: { label: string; value: string; options: { value: string; label: string }[]; onChange: (v: string) => void }) {
  return (
    <label className="relative inline-flex h-[44px] items-center rounded-lg border border-border-default bg-bg-surface pl-12 pr-[34px] text-latin-label-sm font-semibold transition-colors hover:border-mocha-500">
      <span aria-hidden>{label}:&nbsp;</span>
      <select value={value} onChange={(e) => onChange(e.target.value)} aria-label={label} className="max-w-[200px] cursor-pointer appearance-none truncate bg-transparent focus:outline-none">
        {options.map((o) => (
          <option key={o.value} value={o.value}>{o.label}</option>
        ))}
      </select>
      <ChevronDown width={16} height={16} className="pointer-events-none absolute right-12" aria-hidden />
    </label>
  );
}

/** One text in all 5 languages: change it, put the original back, mark it checked. */
function Editor({ t, k, rows, canAct, onClose, onSaved }: { t: T; k: string; rows: Rows; canAct: boolean; onClose: () => void; onSaved: (d: AdminTextsOut) => void }) {
  const [vals, setVals] = useState<Record<Lang, string>>(() => Object.fromEntries(LANGS.map((l) => [l, current(rows, k, l)])) as Record<Lang, string>);
  const [rev, setRev] = useState<Record<Lang, boolean>>(() => Object.fromEntries(LANGS.map((l) => [l, reviewed(rows, k, l)])) as Record<Lang, boolean>);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const first = useRef<HTMLTextAreaElement>(null);
  useEffect(() => {
    first.current?.focus();
    const esc = (e: KeyboardEvent) => e.key === 'Escape' && !busy && onClose();
    window.addEventListener('keydown', esc);
    return () => window.removeEventListener('keydown', esc);
  }, [busy, onClose]);
  const need = placeholders(BUILT_IN.en[k] ?? '');
  const draft = LANGS.some((l) => rows.get(id(k, l))?.has_draft);

  const changes: AdminTextChange[] = LANGS.flatMap((l) => {
    const c: AdminTextChange = { key: k, lang: l };
    const v = vals[l].trim();
    const next = !v || v === BUILT_IN[l][k] ? null : v;
    if (next !== (rows.get(id(k, l))?.value ?? null)) Object.assign(c, { set_value: true, value: next });
    if (l !== 'en' && rev[l] !== reviewed(rows, k, l)) c.reviewed = rev[l];
    return c.set_value || c.reviewed !== undefined ? [c] : [];
  });
  const save = async () => {
    setBusy(true);
    setError(null);
    try {
      onSaved(await api<AdminTextsOut>('/admin/texts', { method: 'PUT', body: { changes } }));
      onClose();
    } catch (e) {
      setError(e instanceof ApiError && e.status === 400 ? e.message : t('admin.err.generic'));
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center p-16 sm:items-center">
      <button type="button" aria-hidden tabIndex={-1} onClick={() => !busy && onClose()} className="absolute inset-0 cursor-default bg-espresso-950/50" />
      <div role="dialog" aria-modal="true" aria-labelledby="text-key" className="kn-pop relative flex max-h-[90vh] w-full max-w-[640px] flex-col rounded-xl bg-bg-surface shadow-lg">
        <div className="flex items-start justify-between gap-12 border-b border-border-default p-20">
          <div className="min-w-0">
            <h2 id="text-key" className="break-all font-mono text-[16px] font-semibold">{k}</h2>
            <p className="mt-4 text-[13px] text-text-secondary">
              {t(`admin.lc.area.${areaOf(k)}`)}
              {need && <> · {t('admin.wc.keep', { parts: need })}</>}
            </p>
          </div>
          <button type="button" onClick={onClose} aria-label={t('admin.lc.close')} className="kn-btn inline-flex h-[36px] w-[36px] shrink-0 items-center justify-center rounded-md hover:bg-bg-subtle"><X width={18} height={18} aria-hidden /></button>
        </div>
        <div className="flex flex-col gap-16 overflow-y-auto p-20">
          {draft && <p className="rounded-lg bg-status-warning-bg px-12 py-8 text-[13px] text-status-warning">{t('admin.lc.has_draft')}</p>}
          {LANGS.map((l, i) => {
            const fid = `lc-${l}`;
            const changed = vals[l].trim() !== (BUILT_IN[l][k] ?? '');
            return (
              <div key={l}>
                <div className="flex flex-wrap items-center justify-between gap-8">
                  <label htmlFor={fid} className="text-latin-label-sm font-semibold">{t(`lang.${l}`)}{l === 'en' && <span className="ml-8 text-[13px] font-normal text-text-secondary">{t('admin.lc.source')}</span>}</label>
                  <div className="flex items-center gap-12">
                    {changed && canAct && (
                      <button type="button" onClick={() => setVals({ ...vals, [l]: BUILT_IN[l][k] ?? '' })} className="inline-flex items-center gap-4 text-[13px] font-semibold text-text-secondary hover:text-text-primary">
                        <RotateCcw width={12} height={12} aria-hidden />
                        {t('admin.wc.original')}
                      </button>
                    )}
                    {l !== 'en' && (
                      <label className="inline-flex items-center gap-4 text-[13px] font-semibold">
                        <input type="checkbox" disabled={!canAct} checked={rev[l]} onChange={(e) => setRev({ ...rev, [l]: e.target.checked })} className="h-[16px] w-[16px] accent-espresso-950" />
                        {t('admin.lc.checked')}
                      </label>
                    )}
                  </div>
                </div>
                <textarea id={fid} ref={i === 0 ? first : undefined} lang={l} rows={2} maxLength={2000} disabled={!canAct || busy} value={vals[l]}
                  onChange={(e) => { setVals({ ...vals, [l]: e.target.value }); if (l !== 'en') setRev({ ...rev, [l]: true }); }}
                  className={cx('mt-8 w-full rounded-lg border bg-bg-surface px-12 py-8 text-latin-body hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring disabled:opacity-70', changed ? 'border-status-warning' : 'border-border-strong')} />
              </div>
            );
          })}
          {error && <ErrorBanner>{error}</ErrorBanner>}
        </div>
        {canAct && (
          <div className="flex flex-wrap items-center justify-between gap-12 border-t border-border-default p-20">
            <p className="text-[13px] text-text-secondary">{t('admin.lc.live_note')}</p>
            <div className="flex gap-8">
              <button type="button" onClick={onClose} disabled={busy} className="kn-btn h-[44px] rounded-lg px-16 text-latin-label-sm font-semibold hover:bg-bg-subtle">{t('admin.us.cancel')}</button>
              <button type="button" onClick={() => void save()} disabled={busy || !changes.length} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-50">
                {busy ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
                {t('admin.lc.save')}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

/** A25 Localized content: every text in the app, website and admin panel, in 5 languages. */
export function Texts({ t, lang }: { t: T; lang: Lang }) {
  const [data, setData] = useState<AdminTextsOut | null>(null);
  const [error, setError] = useState(false);
  const [area, setArea] = useState<Area>('app');
  const [status, setStatus] = useState<Status>('not_reviewed');
  const [focus, setFocus] = useState<Lang>('hi');
  const [typed, setTyped] = useState('');
  const [q, setQ] = useState('');
  const [page, setPage] = useState(1);
  const [open, setOpen] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [notice, setNotice] = useState<{ ok: boolean; text: string } | null>(null);
  const [incoming, setIncoming] = useState<AdminTextChange[] | null>(null);
  const file = useRef<HTMLInputElement>(null);

  const load = useCallback(() => {
    setError(false);
    api<AdminTextsOut>('/admin/texts').then(setData).catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, []);
  useEffect(load, [load]);
  useEffect(() => {
    const tm = window.setTimeout(() => (setQ(typed.trim().toLowerCase()), setPage(1)), 250);
    return () => window.clearTimeout(tm);
  }, [typed]);

  const rows: Rows = useMemo(() => new Map((data?.rows ?? []).map((r) => [id(r.key, r.lang), r])), [data]);
  const inArea = useMemo(() => KEYS.filter((k) => areaOf(k) === area), [area]);
  const cover = useMemo(
    () => Object.fromEntries(LANGS.map((l) => [l, { done: inArea.filter((k) => reviewed(rows, k, l)).length, changed: inArea.filter((k) => rows.get(id(k, l))?.value != null).length }])) as Record<Lang, { done: number; changed: number }>,
    [inArea, rows],
  );
  const shown = useMemo(
    () =>
      inArea.filter((k) => {
        if (status === 'not_reviewed' && reviewed(rows, k, focus)) return false;
        if (status === 'reviewed' && !reviewed(rows, k, focus)) return false;
        if (status === 'changed' && !LANGS.some((l) => rows.get(id(k, l))?.value != null)) return false;
        return !q || k.toLowerCase().includes(q) || LANGS.some((l) => current(rows, k, l).toLowerCase().includes(q));
      }),
    [inArea, status, focus, q, rows],
  );
  const last = Math.max(1, Math.ceil(shown.length / PAGE_SIZE));
  const slice = shown.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);
  const can = !!data?.can_act;

  const send = async (changes: AdminTextChange[], done: string) => {
    setNotice(null);
    try {
      let out: AdminTextsOut | null = null;
      for (let i = 0; i < changes.length; i += 2000) out = await api<AdminTextsOut>('/admin/texts', { method: 'PUT', body: { changes: changes.slice(i, i + 2000) } });
      if (out) setData(out);
      setNotice({ ok: true, text: done });
    } catch (e) {
      setNotice({ ok: false, text: e instanceof ApiError && e.status === 400 ? e.message : t('admin.err.generic') });
    }
  };
  const markShown = async () => {
    setBusy('mark');
    await send(shown.filter((k) => !reviewed(rows, k, focus)).map((k) => ({ key: k, lang: focus, reviewed: true })), t('admin.lc.marked', { n: num(shown.length, lang), lang: t(`lang.${focus}`) }));
    setBusy(null);
  };
  const exportCsv = () => {
    const lines = [['key', ...LANGS].join(','), ...shown.map((k) => [k, ...LANGS.map((l) => current(rows, k, l))].map(csvCell).join(','))];
    const url = URL.createObjectURL(new Blob(['﻿' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' }));
    const a = Object.assign(document.createElement('a'), { href: url, download: `kaamnishaan-texts-${area}.csv` });
    a.click();
    URL.revokeObjectURL(url);
  };
  const readFile = async (f: File) => {
    setNotice(null);
    const table = parseCsv(await f.text());
    const head = (table[0] ?? []).map((h) => h.trim().replace(/^﻿/, '').toLowerCase());
    const col = (name: string) => head.indexOf(name);
    if (col('key') < 0 || !LANGS.some((l) => col(l) >= 0)) return setNotice({ ok: false, text: t('admin.lc.bad_file') });
    const changes: AdminTextChange[] = [];
    let unknown = 0;
    for (const r of table.slice(1)) {
      const k = r[col('key')]?.trim() ?? '';
      if (!(k in BUILT_IN.en)) {
        if (k) unknown++;
        continue;
      }
      for (const l of LANGS) {
        const c = col(l);
        const v = c >= 0 ? r[c]?.trim() : undefined;
        if (!v || v === current(rows, k, l)) continue;
        changes.push({ key: k, lang: l, set_value: true, value: v === BUILT_IN[l][k] ? null : v, reviewed: l === 'en' ? undefined : true });
      }
    }
    if (!changes.length) return setNotice({ ok: true, text: unknown ? t('admin.lc.no_changes_unknown', { n: num(unknown, lang) }) : t('admin.lc.no_changes') });
    setIncoming(changes);
  };

  if (error)
    return (
      <p role="alert" className="rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">
        {t('admin.err.load')}{' '}
        <button type="button" className="underline" onClick={load}>{t('admin.retry')}</button>
      </p>
    );

  return (
    <div className="flex flex-col gap-16">
      <PageActions>
        <button type="button" disabled={!data || !shown.length} onClick={exportCsv} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-60">
          <Download width={16} height={16} aria-hidden />
          {t('admin.rv.export')}
        </button>
        {can && (
          <>
            <input ref={file} type="file" accept=".csv,text/csv" className="hidden" onChange={(e) => { const f = e.target.files?.[0]; e.target.value = ''; if (f) void readFile(f); }} />
            <button type="button" onClick={() => file.current?.click()} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed">
              <FileUp width={16} height={16} aria-hidden />
              {t('admin.lc.import')}
            </button>
          </>
        )}
      </PageActions>

      <div className="kn-in flex flex-wrap gap-12">
        <label className="relative min-w-[240px] flex-1">
          <span className="sr-only">{t('admin.lc.search')}</span>
          <Search width={18} height={18} className="pointer-events-none absolute left-12 top-1/2 -translate-y-1/2 text-text-secondary" aria-hidden />
          <input type="search" value={typed} onChange={(e) => setTyped(e.target.value)} placeholder={t('admin.lc.search')} className="h-[44px] w-full rounded-lg border border-border-strong bg-bg-surface pl-[38px] pr-12 text-[14px] placeholder:text-taupe-500 hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring" />
        </label>
        <Pick label={t('admin.lc.area')} value={area} options={AREAS.map((a) => ({ value: a, label: t(`admin.lc.area.${a}`) }))} onChange={(v) => (setArea((v || 'app') as Area), setPage(1))} />
        <Pick label={t('admin.lc.status')} value={status} options={STATUSES.map((s) => ({ value: s, label: t(`admin.lc.st.${s}`, { lang: t(`lang.${focus}`) }) }))} onChange={(v) => (setStatus((v || 'all') as Status), setPage(1))} />
      </div>

      <div className="grid grid-cols-2 gap-12 sm:grid-cols-3 lg:grid-cols-5">
        {LANGS.map((l, i) => {
          const pct = inArea.length ? Math.floor((cover[l].done / inArea.length) * 100) : 0;
          const on = focus === l && l !== 'en';
          return (
            <button key={l} type="button" aria-pressed={on} disabled={l === 'en'} onClick={() => (setFocus(l), setPage(1))} style={{ ['--d' as string]: `${i * 50}ms` }}
              className={cx('kn-in rounded-xl border bg-bg-surface p-16 text-left transition-colors', on ? 'border-espresso-950 ring-1 ring-espresso-950' : 'border-border-default enabled:hover:border-mocha-500')}>
              <span className="block text-latin-label-sm font-semibold">{t(`lang.${l}`)}</span>
              <span className="mt-4 block text-[24px] font-bold tabular-nums">{l === 'en' ? t('admin.lc.source') : `${num(pct, lang)}%`}</span>
              <span className="mt-4 flex flex-wrap items-center gap-8">
                <span className={cx(pill, l === 'en' || pct === 100 ? 'bg-status-success-bg text-status-success' : 'bg-status-warning-bg text-status-warning')}>{t(l === 'en' || pct === 100 ? 'admin.lc.ready' : 'admin.lc.needs_review')}</span>
                {cover[l].changed > 0 && <span className="text-[13px] text-text-secondary">{t('admin.lc.changed_n', { n: num(cover[l].changed, lang) })}</span>}
              </span>
            </button>
          );
        })}
      </div>
      <p className="-mt-8 text-[13px] text-text-secondary">{t('admin.lc.cover_hint', { n: num(inArea.length, lang) })}</p>

      {notice && <p role="status" className={cx('kn-pop rounded-lg px-16 py-12 text-latin-label-sm font-semibold', notice.ok ? 'bg-status-success-bg text-status-success' : 'bg-status-danger-bg text-status-danger')}>{notice.text}</p>}

      <section className="kn-in overflow-hidden rounded-xl border border-border-default bg-bg-surface">
        <div className="flex flex-wrap items-center justify-between gap-12 border-b border-border-default px-16 py-12">
          <p className="text-[13px] text-text-secondary">{plural(t, 'admin.lc.count', shown.length, { n: num(shown.length, lang) })}</p>
          {can && status === 'not_reviewed' && shown.length > 0 && (
            <button type="button" disabled={!!busy} onClick={() => void markShown()} className="kn-btn inline-flex h-[36px] items-center gap-8 rounded-lg border border-border-default px-12 text-[13px] font-semibold hover:border-mocha-500 disabled:opacity-50">
              {busy === 'mark' ? <Spinner /> : <Check width={14} height={14} aria-hidden />}
              {plural(t, 'admin.lc.mark_all', shown.length, { n: num(shown.length, lang), lang: t(`lang.${focus}`) })}
            </button>
          )}
        </div>
        {!data ? (
          <div aria-busy="true" className="kn-shimmer m-12 h-[400px] rounded-lg bg-bg-subtle" />
        ) : slice.length ? (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[960px] table-fixed text-left">
              <thead className="bg-bg-subtle text-[13px] font-semibold text-text-secondary">
                <tr>
                  <th scope="col" className="w-[22%] px-16 py-12">{t('admin.lc.key')}</th>
                  {['en' as Lang, focus, ...OTHERS.filter((l) => l !== focus)].map((l) => (
                    <th key={l} scope="col" className={cx('px-16 py-12', l === focus && 'text-text-primary')}>{t(`lang.${l}`)}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {slice.map((k, i) => (
                  <tr key={k} onClick={() => setOpen(k)} tabIndex={0} onKeyDown={(e) => e.key === 'Enter' && setOpen(k)} className="kn-in cursor-pointer border-t border-border-default align-top transition-colors hover:bg-cream-100 focus:bg-cream-100 focus:outline-none" style={{ ['--d' as string]: `${Math.min(i * 15, 300)}ms` }}>
                    <td className="break-all px-16 py-12 font-mono text-[13px] font-semibold">{k}</td>
                    {['en' as Lang, focus, ...OTHERS.filter((l) => l !== focus)].map((l) => {
                      const r = rows.get(id(k, l));
                      return (
                        <td key={l} lang={l} className="px-16 py-12 text-[14px]">
                          <span className="line-clamp-3 break-words">{current(rows, k, l)}</span>
                          <span className="mt-4 flex flex-wrap gap-4">
                            {r?.value != null && <span className={cx(pill, 'bg-status-warning-bg px-[8px] py-0 text-[12px] text-status-warning')}>{t('admin.lc.changed')}</span>}
                            {l !== 'en' && r?.reviewed_at && <span className={cx(pill, 'bg-status-success-bg px-[8px] py-0 text-[12px] text-status-success')} title={t('admin.lc.by', { who: r.reviewed_by ?? '—', ago: ago(r.reviewed_at, lang) })}>{t('admin.lc.checked')}</span>}
                          </span>
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="px-24 py-48 text-center text-latin-label-sm text-text-secondary">{status === 'not_reviewed' && !q ? t('admin.lc.all_checked', { lang: t(`lang.${focus}`) }) : t('admin.lc.empty')}</p>
        )}
        {last > 1 && (
          <div className="flex items-center justify-between gap-8 border-t border-border-default px-16 py-12 text-[13px] text-text-secondary">
            <button type="button" disabled={page <= 1} onClick={() => setPage(page - 1)} aria-label={t('admin.co.prev')} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md border border-border-default disabled:opacity-40"><ChevronLeft width={16} height={16} aria-hidden /></button>
            {t('admin.co.page', { n: `${num(page, lang)} / ${num(last, lang)}` })}
            <button type="button" disabled={page >= last} onClick={() => setPage(page + 1)} aria-label={t('admin.co.next')} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md border border-border-default disabled:opacity-40"><ChevronRight width={16} height={16} aria-hidden /></button>
          </div>
        )}
      </section>

      {open && data && <Editor key={open} t={t} k={open} rows={rows} canAct={can} onClose={() => setOpen(null)} onSaved={(d) => (setData(d), setNotice({ ok: true, text: t('admin.lc.saved') }))} />}
      {incoming && (
        <div className="fixed inset-0 z-50 flex items-end justify-center p-16 sm:items-center">
          <button type="button" aria-hidden tabIndex={-1} onClick={() => busy !== 'import' && setIncoming(null)} className="absolute inset-0 cursor-default bg-espresso-950/50" />
          <div role="dialog" aria-modal="true" aria-labelledby="imp-title" className="kn-pop relative w-full max-w-[460px] rounded-xl bg-bg-surface p-24 shadow-lg">
            <h2 id="imp-title" className="text-[22px] font-bold leading-[30px]">{t('admin.lc.import_title')}</h2>
            <p className="mt-8 text-latin-body text-text-secondary">{t('admin.lc.import_body', { n: num(incoming.length, lang), keys: num(new Set(incoming.map((c) => c.key)).size, lang) })}</p>
            <div className="mt-20 flex justify-end gap-8">
              <button type="button" disabled={busy === 'import'} onClick={() => setIncoming(null)} className="kn-btn h-[44px] rounded-lg px-16 text-latin-label-sm font-semibold hover:bg-bg-subtle">{t('admin.us.cancel')}</button>
              <button type="button" disabled={busy === 'import'} onClick={async () => { setBusy('import'); await send(incoming, t('admin.lc.imported', { n: num(incoming.length, lang) })); setBusy(null); setIncoming(null); }} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed">
                {busy === 'import' ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
                {t('admin.lc.apply')}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
