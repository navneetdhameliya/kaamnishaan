import { CircleAlert, Pencil, Plus, Trash2, Upload, X } from 'lucide-react';
import { useCallback, useEffect, useRef, useState } from 'react';

import { api, ApiError } from '../lib/api';
import { LANGS, type Lang, type T } from '../lib/i18n';
import type { AdminTestimonial, AdminTestimonials, MediaOut } from '../lib/types';
import { cx, ErrorBanner, Initials, inputCls, PageActions, Spinner, Switch } from '../ui';

const pill = 'inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold';
type Draft = Omit<AdminTestimonial, 'id' | 'updated_at' | 'photo_url'> & { photo_url: string | null };
const empty: Draft = { quote: {}, person_name: '', role: '', company_name: '', city: '', photo: null, photo_url: null, approved_in_writing: false, approval_note: '', on_website: false };
const body = (d: Draft) => ({ quote: d.quote, person_name: d.person_name, role: d.role, company_name: d.company_name, city: d.city || null, photo: d.photo, approved_in_writing: d.approved_in_writing, approval_note: d.approval_note || null, on_website: d.on_website });

function Editor({ t, start, id, onClose, onSaved }: { t: T; start: Draft; id: string | null; onClose: () => void; onSaved: (d: AdminTestimonials) => void }) {
  const [d, setD] = useState<Draft>(start);
  const [tab, setTab] = useState<Lang>('en');
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const file = useRef<HTMLInputElement>(null);
  const first = useRef<HTMLTextAreaElement>(null);
  useEffect(() => {
    first.current?.focus();
    const esc = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', esc);
    return () => window.removeEventListener('keydown', esc);
  }, [onClose]);
  const ready = !!d.quote.en?.trim() && !!d.person_name.trim() && !!d.role.trim() && !!d.company_name.trim();
  const go = async (key: string, fn: () => Promise<AdminTestimonials>) => {
    setBusy(key);
    setError(null);
    try {
      onSaved(await fn());
      onClose();
    } catch (e) {
      setError(e instanceof ApiError && e.status === 400 ? e.message : t('admin.err.generic'));
      setBusy(null);
    }
  };
  const field = (k: 'person_name' | 'role' | 'company_name' | 'city', max: number) => (
    <div>
      <label htmlFor={`tm-${k}`} className="text-latin-label-sm font-semibold">{t(`admin.tm.f.${k}`)}</label>
      <input id={`tm-${k}`} value={d[k] ?? ''} maxLength={max} onChange={(e) => setD({ ...d, [k]: e.target.value })} className={cx(inputCls, 'mt-8 h-[44px]')} />
    </div>
  );
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center p-16 sm:items-center">
      <button type="button" aria-hidden tabIndex={-1} onClick={() => !busy && onClose()} className="absolute inset-0 cursor-default bg-espresso-950/50" />
      <div role="dialog" aria-modal="true" aria-labelledby="tm-title" className="kn-pop relative flex max-h-[92vh] w-full max-w-[600px] flex-col rounded-xl bg-bg-surface shadow-lg">
        <div className="flex items-center justify-between border-b border-border-default p-20">
          <h2 id="tm-title" className="text-[22px] font-bold leading-[30px]">{t(id ? 'admin.tm.edit' : 'admin.tm.add')}</h2>
          <button type="button" onClick={onClose} aria-label={t('admin.lc.close')} className="kn-btn inline-flex h-[36px] w-[36px] items-center justify-center rounded-md hover:bg-bg-subtle"><X width={18} height={18} aria-hidden /></button>
        </div>
        <fieldset disabled={!!busy} className="flex min-w-0 flex-col gap-16 overflow-y-auto p-20">
          <div>
            <div role="tablist" aria-label={t('admin.no.language')} className="-mx-4 flex gap-8 overflow-x-auto px-4 pb-4">
              {LANGS.map((l) => (
                <button key={l} role="tab" type="button" aria-selected={tab === l} onClick={() => setTab(l)} className={cx('kn-btn h-[32px] shrink-0 rounded-full border px-12 text-[13px] font-semibold', tab === l ? 'border-espresso-950 bg-espresso-950 text-cream-50' : 'border-border-default hover:border-mocha-500')}>
                  {t(`lang.${l}`)}{l === 'en' && ' *'}
                </button>
              ))}
            </div>
            <label htmlFor="tm-quote" className="mt-12 block text-latin-label-sm font-semibold">{t('admin.tm.f.quote')}</label>
            <textarea id="tm-quote" ref={first} lang={tab} rows={3} maxLength={300} value={d.quote[tab] ?? ''} placeholder={tab === 'en' ? '' : d.quote.en} onChange={(e) => setD({ ...d, quote: { ...d.quote, [tab]: e.target.value } })} className="mt-8 w-full rounded-lg border border-border-strong bg-bg-surface px-16 py-12 text-latin-body hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring" />
            <p className="mt-4 text-[13px] text-text-secondary">{t('admin.tm.quote_hint')}</p>
          </div>
          <div className="grid gap-16 sm:grid-cols-2">
            {field('person_name', 80)}
            {field('role', 80)}
            {field('company_name', 120)}
            {field('city', 80)}
          </div>
          <div className="flex items-center gap-12">
            {d.photo_url ? <img src={d.photo_url} alt="" className="h-[56px] w-[56px] rounded-full object-cover" /> : <Initials name={d.person_name || '?'} className="h-[56px] w-[56px] rounded-full bg-cream-300 text-[16px] text-mocha-700" />}
            <input ref={file} type="file" accept="image/jpeg,image/png,image/webp" className="hidden" onChange={async (e) => {
              const f = e.target.files?.[0];
              e.target.value = '';
              if (!f) return;
              setBusy('photo');
              setError(null);
              try {
                const m = await api<MediaOut>('/admin/media?kind=people', { method: 'PUT', file: f });
                setD({ ...d, photo: m.key, photo_url: m.url });
              } catch (err) {
                setError(err instanceof ApiError && err.status === 400 ? err.message : t('admin.err.generic'));
              } finally {
                setBusy(null);
              }
            }} />
            <button type="button" onClick={() => file.current?.click()} className="kn-btn inline-flex h-[36px] items-center gap-8 rounded-lg border border-border-default px-12 text-[13px] font-semibold hover:border-mocha-500">
              {busy === 'photo' ? <Spinner /> : <Upload width={14} height={14} aria-hidden />}
              {t(d.photo ? 'admin.tm.photo_change' : 'admin.tm.photo_add')}
            </button>
            {d.photo && <button type="button" onClick={() => setD({ ...d, photo: null, photo_url: null })} className="text-[13px] font-semibold text-text-secondary hover:text-text-primary">{t('admin.tm.photo_remove')}</button>}
          </div>
          <div className="rounded-lg bg-bg-subtle p-16">
            <label className="flex items-start gap-12">
              <input type="checkbox" checked={d.approved_in_writing} onChange={(e) => setD({ ...d, approved_in_writing: e.target.checked, on_website: e.target.checked && d.on_website })} className="mt-[3px] h-[18px] w-[18px] shrink-0 accent-espresso-950" />
              <span>
                <span className="block text-latin-label-sm font-semibold">{t('admin.tm.approved')}</span>
                <span className="block text-[13px] text-text-secondary">{t('admin.tm.approved_hint')}</span>
              </span>
            </label>
            {d.approved_in_writing && (
              <input aria-label={t('admin.tm.note')} placeholder={t('admin.tm.note')} value={d.approval_note ?? ''} maxLength={200} onChange={(e) => setD({ ...d, approval_note: e.target.value })} className={cx(inputCls, 'kn-in mt-12 h-[40px]')} />
            )}
          </div>
          <Switch label={t('admin.tm.on_website')} hint={d.approved_in_writing ? t('admin.tm.on_hint') : t('admin.tm.needs_approval')} checked={d.on_website} disabled={!d.approved_in_writing} onChange={(v) => setD({ ...d, on_website: v })} />
          {error && <ErrorBanner>{error}</ErrorBanner>}
        </fieldset>
        <div className="flex flex-wrap items-center justify-between gap-12 border-t border-border-default p-20">
          {id ? (
            <button type="button" disabled={!!busy} onClick={() => void go('delete', () => api<AdminTestimonials>(`/admin/testimonials/${id}`, { method: 'DELETE' }))} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg px-12 text-latin-label-sm font-semibold text-status-danger hover:bg-status-danger-bg">
              {busy === 'delete' ? <Spinner /> : <Trash2 width={16} height={16} aria-hidden />}
              {t('admin.tm.delete')}
            </button>
          ) : <span />}
          <div className="flex gap-8">
            <button type="button" onClick={onClose} disabled={!!busy} className="kn-btn h-[44px] rounded-lg px-16 text-latin-label-sm font-semibold hover:bg-bg-subtle">{t('admin.us.cancel')}</button>
            <button type="button" disabled={!ready || !!busy} onClick={() => void go('save', () => api<AdminTestimonials>(id ? `/admin/testimonials/${id}` : '/admin/testimonials', { method: id ? 'PUT' : 'POST', body: body(d) }))} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-50">
              {busy === 'save' && <Spinner />}
              {t('admin.lc.save')}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

/** A27 Testimonials: quotes for the website's Home, shown only with the customer's written approval. */
export function Testimonials({ t, lang }: { t: T; lang: Lang }) {
  const [data, setData] = useState<AdminTestimonials | null>(null);
  const [error, setError] = useState(false);
  const [open, setOpen] = useState<{ id: string | null; start: Draft } | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [problem, setProblem] = useState<string | null>(null);

  const load = useCallback(() => {
    setError(false);
    api<AdminTestimonials>('/admin/testimonials').then(setData).catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, []);
  useEffect(load, [load]);
  const flip = async (x: AdminTestimonial, on: boolean) => {
    setBusy(x.id);
    setProblem(null);
    try {
      setData(await api<AdminTestimonials>(`/admin/testimonials/${x.id}`, { method: 'PUT', body: body({ ...x, on_website: on }) }));
    } catch (e) {
      setProblem(e instanceof ApiError && e.status === 400 ? e.message : t('admin.err.generic'));
    } finally {
      setBusy(null);
    }
  };
  const can = !!data?.can_act;

  if (error) return <p role="alert" className="rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">{t('admin.err.load')} <button type="button" className="underline" onClick={load}>{t('admin.retry')}</button></p>;

  return (
    <div className="flex flex-col gap-16">
      {can && (
        <PageActions>
          <button type="button" onClick={() => setOpen({ id: null, start: empty })} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed">
            <Plus width={16} height={16} aria-hidden />
            {t('admin.tm.add')}
          </button>
        </PageActions>
      )}
      <p className="kn-in flex items-center gap-8 rounded-lg bg-status-warning-bg px-16 py-12 text-latin-label-sm font-semibold text-status-warning">
        <CircleAlert width={18} height={18} className="shrink-0" aria-hidden />
        {t('admin.tm.rule')}
      </p>
      {problem && <ErrorBanner>{problem}</ErrorBanner>}
      {!data ? (
        <div aria-busy="true" className="kn-shimmer h-[220px] rounded-xl bg-bg-subtle" />
      ) : data.items.length ? (
        <ul className="grid gap-16 md:grid-cols-2 xl:grid-cols-3">
          {data.items.map((x, i) => (
            <li key={x.id} className="kn-in group flex flex-col gap-16 rounded-xl border border-border-default bg-bg-surface p-20 transition-shadow hover:shadow-md" style={{ ['--d' as string]: `${i * 60}ms` }}>
              <p className="flex-1 text-[18px] leading-[28px]">“{x.quote[lang] || x.quote.en}”</p>
              <div className="flex items-center gap-12">
                {x.photo_url ? <img src={x.photo_url} alt="" className="h-[40px] w-[40px] rounded-full object-cover" /> : <Initials name={x.person_name} className="h-[40px] w-[40px] rounded-full bg-cream-300 text-[13px] text-mocha-700" />}
                <div className="min-w-0 flex-1">
                  <p className="truncate text-[15px] font-semibold">{x.person_name}</p>
                  <p className="truncate text-[13px] text-text-secondary">{[x.role, x.company_name, x.city].filter(Boolean).join(' · ')}</p>
                </div>
                {can && (
                  <button type="button" onClick={() => setOpen({ id: x.id, start: { ...x } })} aria-label={t('admin.tm.edit')} className="kn-btn inline-flex h-[36px] w-[36px] items-center justify-center rounded-md text-text-secondary hover:bg-bg-subtle hover:text-text-primary">
                    <Pencil width={16} height={16} aria-hidden />
                  </button>
                )}
              </div>
              <div className="flex items-center justify-between gap-12 border-t border-border-default pt-12">
                <span className={cx(pill, x.on_website ? 'bg-status-success-bg text-status-success' : x.approved_in_writing ? 'bg-bg-subtle text-text-secondary' : 'bg-status-warning-bg text-status-warning')} title={x.approval_note ?? undefined}>
                  {t(x.on_website ? 'admin.tm.st.on' : x.approved_in_writing ? 'admin.tm.st.hidden' : 'admin.tm.st.waiting')}
                </span>
                <span className="flex items-center gap-8">
                  {busy === x.id && <Spinner />}
                  <button type="button" role="switch" aria-checked={x.on_website} aria-label={t('admin.tm.on_website')} disabled={!can || !x.approved_in_writing || busy === x.id} onClick={() => void flip(x, !x.on_website)} className={cx('relative inline-flex h-[24px] w-[44px] shrink-0 items-center rounded-full transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-focus-ring disabled:cursor-not-allowed', x.on_website ? 'bg-espresso-950' : 'bg-taupe-400')}>
                    <span aria-hidden className={cx('inline-block h-[18px] w-[18px] rounded-full bg-cream-50 shadow transition-transform', x.on_website ? 'translate-x-[23px]' : 'translate-x-[3px]')} />
                  </button>
                </span>
              </div>
            </li>
          ))}
        </ul>
      ) : (
        <p className="rounded-xl border border-dashed border-border-default px-24 py-48 text-center text-latin-label-sm text-text-secondary">{t('admin.tm.none')}</p>
      )}
      {open && <Editor t={t} start={open.start} id={open.id} onClose={() => setOpen(null)} onSaved={setData} />}
    </div>
  );
}
