import { AlertTriangle, ChevronLeft, ChevronRight, Copy, Flag, FlagOff, ImageOff, Images, Lock, MapPin, Search, X } from 'lucide-react';
import { useCallback, useEffect, useRef, useState } from 'react';

import { api, ApiError } from '../lib/api';
import { clock, day, num, type Lang, type T } from '../lib/i18n';
import type { AdminPhoto, AdminPhotoDetail, AdminPhotoList } from '../lib/types';
import { cx, FilterSelect, Link, Spinner, TextDialog } from '../ui';
import { pages } from './Companies';

const PAGE_SIZE = 24;
const STAGES = ['before', 'during', 'after'] as const;
const FLAGS = ['needs_look', 'staff', 'duplicate', 'no_gps', 'far', 'early', 'clean'] as const;

type Filters = { q: string; stage: string; flag: string; company: string; job: string; page: number };

function readFilters(): Filters {
  const s = new URLSearchParams(window.location.search);
  const pick = (k: string, ok: readonly string[]) => (ok.includes(s.get(k) ?? '') ? (s.get(k) as string) : '');
  return { q: s.get('q') ?? '', stage: pick('stage', STAGES), flag: pick('flag', FLAGS), company: s.get('company') ?? '', job: s.get('job') ?? '', page: Math.max(1, Number(s.get('page')) || 1) };
}

function query(f: Filters): string {
  const p = new URLSearchParams();
  if (f.q.trim()) p.set('q', f.q.trim());
  for (const k of ['stage', 'flag', 'company', 'job'] as const) if (f[k]) p.set(k, f[k]);
  if (f.page > 1) p.set('page', String(f.page));
  return p.toString();
}

const pill = 'inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold';
const stageTone = { before: 'bg-bg-subtle text-mocha-700', during: 'bg-bg-subtle text-mocha-700', after: 'bg-status-success-bg text-status-success' };
const when = (iso: string, lang: Lang) => `${day(iso, lang, { year: undefined })} · ${clock(iso, lang)}`;

function Tags({ t, p }: { t: T; p: AdminPhoto }) {
  return (
    <div className="flex flex-wrap gap-8">
      <span className={cx(pill, stageTone[p.stage])}>{t(`admin.ev.stage.${p.stage}`)}</span>
      {p.staff_flag && <span className={cx(pill, 'bg-status-danger-bg text-status-danger')}>{t('admin.ev.flagged')}</span>}
      {p.checks.map((c) => (
        <span key={c} className={cx(pill, 'bg-status-warning-bg text-status-warning')}>{t(`admin.ev.ck.${c}`)}</span>
      ))}
    </div>
  );
}

function Panel({ t, lang, id, canAct, onClose, onChanged }: { t: T; lang: Lang; id: string; canAct: boolean; onClose: () => void; onChanged: (p: AdminPhotoDetail) => void }) {
  const [d, setD] = useState<AdminPhotoDetail | null>(null);
  const [error, setError] = useState(false);
  const [flagging, setFlagging] = useState(false);
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    setD(null);
    setError(false);
    api<AdminPhotoDetail>(`/admin/evidence/${id}`).then(setD).catch(() => setError(true));
  }, [id]);
  useEffect(() => {
    const esc = (e: globalThis.KeyboardEvent) => e.key === 'Escape' && !flagging && onClose();
    window.addEventListener('keydown', esc);
    return () => window.removeEventListener('keydown', esc);
  }, [flagging, onClose]);

  const save = async (note: string | null): Promise<string | null> => {
    setBusy(true);
    try {
      const out = await api<AdminPhotoDetail>(`/admin/evidence/${id}/flag`, note === null ? { method: 'DELETE' } : { method: 'PUT', body: { note } });
      setD(out);
      onChanged(out);
      setFlagging(false);
      return null;
    } catch {
      return t('admin.err.save');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-40 flex justify-end">
      <button type="button" aria-hidden tabIndex={-1} onClick={onClose} className="absolute inset-0 cursor-default bg-espresso-950/50" />
      <aside role="dialog" aria-modal="true" aria-label={t('admin.ev.photo')} className="kn-slide relative flex h-full w-full max-w-[560px] flex-col overflow-y-auto bg-bg-surface shadow-lg">
        <div className="sticky top-0 z-10 flex items-center justify-between border-b border-border-default bg-bg-surface px-20 py-12">
          <h2 className="text-[20px] font-semibold">{t('admin.ev.photo')}</h2>
          <button type="button" onClick={onClose} aria-label={t('admin.ev.close')} className="inline-flex h-[36px] w-[36px] items-center justify-center rounded-full hover:bg-bg-subtle"><X width={18} height={18} aria-hidden /></button>
        </div>
        {error ? (
          <p className="p-24 text-latin-label-sm text-status-danger">{t('admin.err.load')}</p>
        ) : !d ? (
          <div aria-busy="true" className="kn-shimmer m-20 h-[320px] rounded-lg bg-bg-subtle" />
        ) : (
          <div className="kn-in flex flex-col gap-16 p-20">
            <a href={d.image_url} target="_blank" rel="noreferrer" className="block overflow-hidden rounded-lg bg-bg-subtle">
              <img src={d.image_url} alt={t('admin.ev.alt', { stage: t(`admin.ev.stage.${d.stage}`), job: d.job.customer })} className="max-h-[420px] w-full object-contain" />
            </a>
            <Tags t={t} p={d} />
            {d.staff_flag && (
              <div className="rounded-lg bg-status-danger-bg p-12 text-[14px]">
                <p className="font-semibold text-status-danger">{t('admin.ev.flag_by', { who: d.staff_flag.by ?? '—', when: when(d.staff_flag.at, lang) })}</p>
                <p className="mt-4 break-words">{d.staff_flag.note}</p>
              </div>
            )}
            <dl className="divide-y divide-border-default text-[14px]">
              {[
                [t('admin.ev.job'), <Link key="j" to={`/jobs/${d.job.id}`} className="font-semibold hover:underline">{`${d.job.customer} · #${d.job.number}`}</Link>],
                [t('admin.ev.company'), <Link key="c" to={`/companies/${d.company.value}`} className="font-semibold hover:underline">{d.company.label}</Link>],
                [t('admin.ev.taken'), `${when(d.taken_at, lang)}${d.taken_by ? ` · ${d.taken_by}` : ''}`],
                [t('admin.ev.job_created'), when(d.job_created_at, lang)],
                [t('admin.ev.place'), !d.gps ? t('admin.ev.no_gps') : d.distance_m === null ? t('admin.ev.gps_on') : t('admin.ev.from_site', { m: num(d.distance_m, lang) })],
                [t('admin.ev.file'), `${d.width && d.height ? `${d.width}×${d.height} · ` : ''}${num(Math.max(1, Math.round(d.size / 1024)), lang)} KB${d.locked ? ` · ${t('admin.ev.locked')}` : ''}`],
              ].map(([k, v], i) => (
                <div key={i} className="flex flex-wrap justify-between gap-x-16 gap-y-2 py-8">
                  <dt className="text-text-secondary">{k}</dt>
                  <dd className="min-w-0 text-right">{v}</dd>
                </div>
              ))}
            </dl>
            {d.fingerprint && (
              <p className="break-all font-mono text-[12px] text-text-secondary" title={t('admin.ev.fingerprint')}>
                {t('admin.ev.fingerprint')}: {d.fingerprint}
              </p>
            )}
            {d.twins.length > 0 && (
              <div className="rounded-lg border border-status-warning p-12">
                <p className="flex items-center gap-8 text-[14px] font-semibold text-status-warning"><Copy width={14} height={14} aria-hidden />{t('admin.ev.twins', { n: num(d.twins.length, lang) })}</p>
                <ul className="mt-8 flex flex-col gap-4 text-[14px]">
                  {d.twins.map((x) => (
                    <li key={x.id} className="flex flex-wrap justify-between gap-8">
                      <Link to={`/jobs/${x.job.id}`} className="font-semibold hover:underline">{`${x.job.customer} · #${x.job.number}`}</Link>
                      <span className="text-text-secondary">{x.company.label} · {day(x.taken_at, lang)}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}
            {canAct && (
              <div className="flex flex-wrap gap-12">
                {d.staff_flag ? (
                  <button type="button" disabled={busy} onClick={() => void save(null)} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-60">
                    {busy ? <Spinner /> : <FlagOff width={16} height={16} aria-hidden />}
                    {t('admin.ev.unflag')}
                  </button>
                ) : (
                  <button type="button" onClick={() => setFlagging(true)} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed">
                    <Flag width={16} height={16} aria-hidden />
                    {t('admin.ev.flag')}
                  </button>
                )}
              </div>
            )}
          </div>
        )}
      </aside>
      {flagging && <TextDialog t={t} title={t('admin.ev.flag_title')} body={t('admin.ev.flag_body')} label={t('admin.ev.flag_note')} min={3} max={300} multiline confirm={t('admin.ev.flag')} onClose={() => setFlagging(false)} onConfirm={(note) => save(note)} />}
    </div>
  );
}

/** A13 Evidence review: every company's photos, with the server's own checks and staff flags. */
export function Evidence({ t, lang }: { t: T; lang: Lang }) {
  const [f, setF] = useState<Filters>(readFilters);
  const [typed, setTyped] = useState(f.q);
  const [data, setData] = useState<AdminPhotoList | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [open, setOpen] = useState<string | null>(null);
  const seq = useRef(0);

  useEffect(() => {
    const q = query(f);
    window.history.replaceState(null, '', `/evidence${q ? `?${q}` : ''}`);
    const n = ++seq.current;
    setLoading(true);
    setError(false);
    api<AdminPhotoList>(`/admin/evidence?${q}${q ? '&' : ''}page_size=${PAGE_SIZE}`)
      .then((d) => n === seq.current && setData(d))
      .catch((e) => n === seq.current && !(e instanceof ApiError && e.status === 401) && setError(true))
      .finally(() => n === seq.current && setLoading(false));
  }, [f]);
  useEffect(() => {
    if (typed === f.q) return;
    const tm = window.setTimeout(() => setF((x) => ({ ...x, q: typed, page: 1 })), 300);
    return () => window.clearTimeout(tm);
  }, [typed, f.q]);

  const set = (patch: Partial<Filters>) => setF((x) => ({ ...x, ...patch, page: 1 }));
  const onChanged = useCallback((p: AdminPhotoDetail) => setData((x) => (x ? { ...x, items: x.items.map((i) => (i.id === p.id ? { ...i, staff_flag: p.staff_flag } : i)) } : x)), []);
  const close = useCallback(() => setOpen(null), []);
  const last = data ? Math.max(1, Math.ceil(data.total / data.page_size)) : 1;
  const filtered = !!(f.q || f.stage || f.flag || f.company || f.job);

  return (
    <div className="flex flex-col gap-16">
      {data && data.needs_look > 0 && f.flag !== 'needs_look' && (
        <div className="kn-in flex flex-wrap items-center justify-between gap-12 rounded-xl border border-status-warning bg-status-warning-bg px-16 py-12">
          <p className="flex items-center gap-8 text-[14px] font-semibold text-status-warning"><AlertTriangle width={16} height={16} aria-hidden />{t('admin.ev.needs', { n: num(data.needs_look, lang) })}</p>
          <button type="button" onClick={() => set({ flag: 'needs_look' })} className="kn-btn h-[36px] rounded-lg bg-bg-surface px-12 text-[13px] font-semibold hover:bg-cream-100">{t('admin.ev.show')}</button>
        </div>
      )}
      {f.job && (
        <div className="kn-in flex flex-wrap items-center gap-8 text-[14px]">
          <span className="text-text-secondary">{t('admin.ev.one_job')}</span>
          <Link to={`/jobs/${f.job}`} className="font-semibold hover:underline">{data?.items[0] ? `${data.items[0].job.customer} · #${data.items[0].job.number}` : '…'}</Link>
          <button type="button" onClick={() => set({ job: '' })} aria-label={t('admin.co.clear')} className="inline-flex h-[28px] w-[28px] items-center justify-center rounded-full hover:bg-bg-subtle"><X width={14} height={14} aria-hidden /></button>
        </div>
      )}
      <div className="kn-in flex flex-wrap items-center gap-12">
        <label className="relative min-w-[240px] flex-1">
          <span className="sr-only">{t('admin.ev.search')}</span>
          <Search width={18} height={18} className="pointer-events-none absolute left-12 top-1/2 -translate-y-1/2 text-text-secondary" aria-hidden />
          <input type="search" value={typed} onChange={(e) => setTyped(e.target.value)} placeholder={t('admin.ev.search')} className="h-[44px] w-full rounded-lg border border-border-strong bg-bg-surface pl-[40px] pr-12 text-latin-label-sm placeholder:text-taupe-500 hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring" />
        </label>
        <FilterSelect label={t('admin.ev.f_stage')} value={f.stage} allLabel={t('admin.co.f_all')} options={STAGES.map((s) => ({ value: s, label: t(`admin.ev.stage.${s}`) }))} onChange={(v) => set({ stage: v })} />
        <FilterSelect label={t('admin.ev.f_flag')} value={f.flag} allLabel={t('admin.ev.f_any')} options={FLAGS.map((s) => ({ value: s, label: t(`admin.ev.f.${s}`) }))} onChange={(v) => set({ flag: v })} />
        <FilterSelect label={t('admin.rv.f_company')} value={f.company} allLabel={t('admin.co.f_all')} options={data?.companies ?? []} onChange={(v) => set({ company: v })} />
      </div>

      {error && (
        <p role="alert" className="rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">
          {t('admin.err.load')}{' '}
          <button type="button" className="underline" onClick={() => setF({ ...f })}>{t('admin.retry')}</button>
        </p>
      )}

      {!data ? (
        <div aria-busy="true" className="grid gap-16 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {Array.from({ length: 8 }, (_, i) => <div key={i} className="kn-shimmer h-[270px] rounded-xl bg-bg-surface" />)}
        </div>
      ) : data.total === 0 ? (
        <div className="kn-in flex flex-col items-center rounded-xl border border-border-default bg-bg-surface px-24 py-48 text-center">
          <span className="kn-pop inline-flex h-[88px] w-[88px] items-center justify-center rounded-full bg-bg-subtle text-mocha-700">
            {filtered ? <Search width={32} height={32} aria-hidden /> : <Images width={32} height={32} aria-hidden />}
          </span>
          <h2 className="mt-16 text-[24px] font-bold">{filtered ? t('admin.ev.empty_title') : t('admin.ev.none_title')}</h2>
          <p className="mt-8 max-w-[420px] text-latin-body text-text-secondary">{filtered ? t('admin.co.empty_body') : t('admin.ev.none_body')}</p>
          {filtered && (
            <button type="button" onClick={() => { setTyped(''); setF({ q: '', stage: '', flag: '', company: '', job: '', page: 1 }); }} className="kn-btn mt-20 inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold hover:bg-cream-300">
              <X width={16} height={16} aria-hidden />
              {t('admin.co.clear')}
            </button>
          )}
        </div>
      ) : (
        <>
          <ul className={cx('grid gap-16 transition-opacity sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4', loading && 'opacity-60')} aria-busy={loading}>
            {data.items.map((p, i) => {
              const warn = p.staff_flag || p.checks.length > 0;
              return (
                <li key={p.id} className="kn-in" style={{ ['--d' as string]: `${Math.min(i * 30, 400)}ms` }}>
                  <button type="button" onClick={() => setOpen(p.id)} className={cx('kn-hover group flex h-full w-full flex-col overflow-hidden rounded-xl border bg-bg-surface text-left', p.staff_flag ? 'border-2 border-status-danger' : warn ? 'border-2 border-status-warning' : 'border-border-default')}>
                    <div className="relative aspect-[4/3] w-full overflow-hidden bg-bg-subtle">
                      {p.thumb_url ? (
                        <img src={p.thumb_url} alt="" loading="lazy" className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-[1.04]" />
                      ) : (
                        <span className="flex h-full w-full items-center justify-center text-taupe-500"><ImageOff width={28} height={28} aria-label={t('admin.ev.processing')} /></span>
                      )}
                    </div>
                    <div className="flex flex-1 flex-col gap-8 p-12">
                      <Tags t={t} p={p} />
                      <p className="truncate text-[15px] font-semibold">{p.job.customer}</p>
                      <p className="flex flex-wrap items-center gap-x-8 text-[13px] text-text-secondary">
                        <span>{when(p.taken_at, lang)}</span>
                        <span className="inline-flex items-center gap-4"><MapPin width={12} height={12} aria-hidden />{t(p.gps ? 'admin.ev.gps_yes' : 'admin.ev.gps_no')}</span>
                        {p.locked && <span className="inline-flex items-center gap-4"><Lock width={12} height={12} aria-hidden />{t('admin.ev.locked')}</span>}
                      </p>
                      <p className="truncate text-[13px] text-text-secondary">{p.company.label}</p>
                    </div>
                  </button>
                </li>
              );
            })}
          </ul>
          <div className="flex flex-wrap items-center justify-between gap-12">
            <p className="text-[13px] text-text-secondary">
              {t('admin.co.showing', { from: num((data.page - 1) * data.page_size + 1, lang), to: num(Math.min(data.page * data.page_size, data.total), lang), total: num(data.total, lang) })}
            </p>
            {last > 1 && (
              <nav aria-label={t('admin.nav.evidence')} className="flex items-center gap-4">
                <button type="button" disabled={f.page <= 1} onClick={() => setF({ ...f, page: f.page - 1 })} aria-label={t('admin.co.prev')} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md border border-border-default hover:border-mocha-500 disabled:opacity-40"><ChevronLeft width={16} height={16} aria-hidden /></button>
                {pages(f.page, last).map((p, i) =>
                  p === '…' ? <span key={`gap-${i}`} className="px-4 text-text-secondary">…</span> : (
                    <button key={p} type="button" onClick={() => setF({ ...f, page: p })} aria-label={t('admin.co.page', { n: p })} aria-current={p === f.page ? 'page' : undefined} className={cx('inline-flex h-[32px] min-w-[32px] items-center justify-center rounded-md px-8 text-[13px] font-semibold', p === f.page ? 'bg-espresso-950 text-cream-50' : 'border border-border-default hover:border-mocha-500')}>{num(p, lang)}</button>
                  ),
                )}
                <button type="button" disabled={f.page >= last} onClick={() => setF({ ...f, page: f.page + 1 })} aria-label={t('admin.co.next')} className="inline-flex h-[32px] w-[32px] items-center justify-center rounded-md border border-border-default hover:border-mocha-500 disabled:opacity-40"><ChevronRight width={16} height={16} aria-hidden /></button>
              </nav>
            )}
          </div>
        </>
      )}
      {open && data && <Panel t={t} lang={lang} id={open} canAct={data.can_act} onClose={close} onChanged={onChanged} />}
    </div>
  );
}
