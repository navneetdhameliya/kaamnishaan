import { ArrowDown, ArrowUp, Check, Clock, ExternalLink, Heading2, ImagePlus, List, Pilcrow, Quote, Save, Trash2, Upload, X } from 'lucide-react';
import { useEffect, useRef, useState, type ReactNode } from 'react';

import { api, API_URL, ApiError } from '../lib/api';
import { ago, LANGS, type Lang, type T } from '../lib/i18n';
import type { AdminBlogDetail, BlogBlock, BlogContent, MediaOut } from '../lib/types';
import { cx, inputCls, navigate, PageActions, Spinner, Switch } from '../ui';
import { BlogStatePill } from './Blog';

const CATEGORIES = ['hvac', 'roofing', 'solar', 'maintenance', 'pest', 'cleaning', 'reports', 'tips', 'voice'];
const KINDS: { type: BlogBlock['type']; icon: ReactNode }[] = [
  { type: 'p', icon: <Pilcrow width={16} height={16} aria-hidden /> },
  { type: 'h2', icon: <Heading2 width={16} height={16} aria-hidden /> },
  { type: 'list', icon: <List width={16} height={16} aria-hidden /> },
  { type: 'quote', icon: <Quote width={16} height={16} aria-hidden /> },
  { type: 'image', icon: <ImagePlus width={16} height={16} aria-hidden /> },
];
type Form = { slug: string; category: string; featured: boolean; cover: string; content: Partial<Record<Lang, BlogContent>> };
const blank = (): BlogContent => ({ title: '', summary: '', author: '', blocks: [] });
const area = 'w-full rounded-lg border border-border-strong bg-bg-surface px-16 py-12 text-latin-body hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring disabled:opacity-70';
const slugify = (s: string) => s.toLowerCase().normalize('NFKD').replace(/[^\w\s-]/g, '').trim().replace(/[\s_-]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 80);

/** Where a saved picture can be seen: an uploaded key goes through the API, /img/… is on the website. */
const pic = (src: string | null | undefined, site: string) => (!src ? '' : src.startsWith('site/') ? `${API_URL}/api/v1/public/media/${src}` : src.startsWith('/') ? `${site}${src}` : src);

function Uploader({ t, label, onDone, disabled }: { t: T; label: string; onDone: (m: MediaOut) => void; disabled: boolean }) {
  const ref = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  return (
    <span className="inline-flex flex-col gap-4">
      <input ref={ref} type="file" accept="image/jpeg,image/png,image/webp" className="hidden" onChange={async (e) => {
        const f = e.target.files?.[0];
        e.target.value = '';
        if (!f) return;
        setBusy(true);
        setError(null);
        try {
          onDone(await api<MediaOut>('/admin/media?kind=blog', { method: 'PUT', file: f }));
        } catch (err) {
          setError(err instanceof ApiError && err.status === 400 ? err.message : t('admin.err.generic'));
        } finally {
          setBusy(false);
        }
      }} />
      <button type="button" disabled={disabled || busy} onClick={() => ref.current?.click()} className="kn-btn inline-flex h-[36px] items-center gap-8 self-start rounded-lg border border-border-default px-12 text-[13px] font-semibold hover:border-mocha-500 disabled:opacity-50">
        {busy ? <Spinner /> : <Upload width={14} height={14} aria-hidden />}
        {label}
      </button>
      {error && <span className="text-[13px] text-status-danger">{error}</span>}
    </span>
  );
}

function BlockEditor({ t, b, i, n, site, disabled, set, move, drop }: { t: T; b: BlogBlock; i: number; n: number; site: string; disabled: boolean; set: (b: BlogBlock) => void; move: (d: -1 | 1) => void; drop: () => void }) {
  const id = `blk-${i}`;
  return (
    <li className="kn-in rounded-lg border border-border-default bg-bg-canvas p-12">
      <div className="mb-8 flex items-center justify-between gap-8">
        <span className="inline-flex items-center gap-8 text-[13px] font-semibold text-text-secondary">
          {KINDS.find((k) => k.type === b.type)?.icon}
          {t(`admin.bl.b.${b.type}`)}
        </span>
        {!disabled && (
          <span className="flex gap-4">
            <button type="button" disabled={i === 0} onClick={() => move(-1)} aria-label={t('admin.bl.up')} className="inline-flex h-[28px] w-[28px] items-center justify-center rounded-md hover:bg-bg-subtle disabled:opacity-30"><ArrowUp width={14} height={14} aria-hidden /></button>
            <button type="button" disabled={i === n - 1} onClick={() => move(1)} aria-label={t('admin.bl.down')} className="inline-flex h-[28px] w-[28px] items-center justify-center rounded-md hover:bg-bg-subtle disabled:opacity-30"><ArrowDown width={14} height={14} aria-hidden /></button>
            <button type="button" onClick={drop} aria-label={t('admin.bl.remove')} className="inline-flex h-[28px] w-[28px] items-center justify-center rounded-md text-status-danger hover:bg-status-danger-bg"><X width={14} height={14} aria-hidden /></button>
          </span>
        )}
      </div>
      {b.type === 'h2' && <input aria-label={t('admin.bl.b.h2')} id={id} value={b.text ?? ''} maxLength={160} disabled={disabled} onChange={(e) => set({ ...b, text: e.target.value })} className={cx(inputCls, 'h-[44px] font-semibold')} />}
      {(b.type === 'p' || b.type === 'quote') && <textarea aria-label={t(`admin.bl.b.${b.type}`)} id={id} rows={b.type === 'p' ? 4 : 2} value={b.text ?? ''} maxLength={3000} disabled={disabled} onChange={(e) => set({ ...b, text: e.target.value })} className={cx(area, b.type === 'quote' && 'italic')} />}
      {b.type === 'quote' && <input aria-label={t('admin.bl.by')} placeholder={t('admin.bl.by')} value={b.by ?? ''} maxLength={120} disabled={disabled} onChange={(e) => set({ ...b, by: e.target.value })} className={cx(inputCls, 'mt-8 h-[40px]')} />}
      {b.type === 'list' && (
        <>
          <input aria-label={t('admin.bl.list_title')} placeholder={t('admin.bl.list_title')} value={b.title ?? ''} maxLength={160} disabled={disabled} onChange={(e) => set({ ...b, title: e.target.value })} className={cx(inputCls, 'h-[40px]')} />
          <textarea aria-label={t('admin.bl.list_items')} placeholder={t('admin.bl.list_items')} rows={4} value={(b.items ?? []).join('\n')} disabled={disabled} onChange={(e) => set({ ...b, items: e.target.value.split('\n') })} className={cx(area, 'mt-8')} />
        </>
      )}
      {b.type === 'image' && (
        <div className="flex flex-wrap items-start gap-12">
          {b.src ? <img src={pic(b.src, site)} alt="" className="h-[96px] w-[160px] rounded-md bg-bg-subtle object-cover" /> : <span className="flex h-[96px] w-[160px] items-center justify-center rounded-md bg-bg-subtle text-text-secondary"><ImagePlus width={24} height={24} aria-hidden /></span>}
          <div className="flex min-w-[200px] flex-1 flex-col gap-8">
            <Uploader t={t} label={t(b.src ? 'admin.bl.replace' : 'admin.bl.upload')} disabled={disabled} onDone={(m) => set({ ...b, src: m.key })} />
            <input aria-label={t('admin.bl.caption')} placeholder={t('admin.bl.caption')} value={b.caption ?? ''} maxLength={200} disabled={disabled} onChange={(e) => set({ ...b, caption: e.target.value })} className={cx(inputCls, 'h-[40px]')} />
          </div>
        </div>
      )}
    </li>
  );
}

/** A26: write or edit a post in 5 languages, then publish it now or at a set time. */
export function BlogEditor({ t, lang, id, onName }: { t: T; lang: Lang; id: string; onName: (n: string) => void }) {
  const isNew = id === 'new';
  const [d, setD] = useState<AdminBlogDetail | null>(null);
  const [form, setForm] = useState<Form | null>(isNew ? { slug: '', category: 'tips', featured: false, cover: '', content: { en: blank() } } : null);
  const [tab, setTab] = useState<Lang>('en');
  const [slugTouched, setSlugTouched] = useState(!isNew);
  const [dirty, setDirty] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const [notice, setNotice] = useState<{ ok: boolean; text: string } | null>(null);
  const [when, setWhen] = useState('');
  const [error, setError] = useState(false);
  const [site, setSite] = useState('');
  const [sure, setSure] = useState(false);
  const can = isNew || !!d?.can_act;

  const take = (x: AdminBlogDetail) => {
    setD(x);
    setSite(x.site_url);
    setForm({ slug: x.slug, category: x.category, featured: x.featured, cover: x.cover, content: x.content as Form['content'] });
    setDirty(false);
    onName(x.content.en?.title || x.slug);
  };
  useEffect(() => {
    if (isNew) return onName(t('admin.bl.new'));
    api<AdminBlogDetail>(`/admin/blog/${id}`).then(take).catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, [id]); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    const warn = (e: BeforeUnloadEvent) => {
      if (dirty) e.preventDefault();
    };
    window.addEventListener('beforeunload', warn);
    return () => window.removeEventListener('beforeunload', warn);
  }, [dirty]);

  if (error) return <p role="alert" className="rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">{t('admin.err.load')}</p>;
  if (!form) return <div aria-busy="true" className="kn-shimmer h-[600px] rounded-xl bg-bg-subtle" />;

  const c = form.content[tab] ?? blank();
  const edit = (next: Partial<Form>) => {
    setForm({ ...form, ...next });
    setDirty(true);
  };
  const editC = (next: Partial<BlogContent>) => {
    const content = { ...form.content, [tab]: { ...c, ...next } };
    const extra = tab === 'en' && next.title !== undefined && !slugTouched ? { slug: slugify(next.title) } : {};
    edit({ content, ...extra });
  };
  const blocks = c.blocks;
  const setBlocks = (bs: BlogBlock[]) => editC({ blocks: bs });
  const filled = (l: Lang) => !!form.content[l]?.title;

  const run = async (key: string, fn: () => Promise<void>) => {
    setBusy(key);
    setNotice(null);
    try {
      await fn();
    } catch (e) {
      setNotice({ ok: false, text: e instanceof ApiError && e.status === 400 ? e.message : t('admin.err.generic') });
    } finally {
      setBusy(null);
    }
  };
  const body = () => ({
    ...form,
    content: Object.fromEntries(Object.entries(form.content).filter(([, x]) => x && (x.title || x.summary || x.blocks.length))),
  });
  const save = async (open = true) => {
    if (isNew) {
      const x = await api<AdminBlogDetail>('/admin/blog', { method: 'POST', body: body() });
      setDirty(false);
      if (open) navigate(`/blog/${x.id}`, true);
      return x;
    }
    const x = await api<AdminBlogDetail>(`/admin/blog/${id}`, { method: 'PUT', body: body() });
    take(x);
    return x;
  };
  const publish = (at: string | null) =>
    run(at ? 'schedule' : 'publish', async () => {
      const saved = dirty || isNew ? await save(false) : d!;
      const x = await api<AdminBlogDetail>(`/admin/blog/${saved.id}/publish`, { method: 'POST', body: { at: at ? new Date(at).toISOString() : null } });
      if (isNew) return navigate(`/blog/${x.id}`, true);
      take(x);
      setNotice({ ok: true, text: t(at ? 'admin.bl.scheduled' : 'admin.bl.published') });
    });
  const minWhen = new Date(Date.now() + 10 * 60_000 - new Date().getTimezoneOffset() * 60_000).toISOString().slice(0, 16);

  return (
    <div className="grid items-start gap-16 xl:grid-cols-[1fr_340px]">
      {can && (
        <PageActions>
          {d?.state === 'published' && (
            <a href={d.web_url} target="_blank" rel="noreferrer" className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300">
              <ExternalLink width={16} height={16} aria-hidden />
              {t('admin.bl.view')}
            </a>
          )}
          <button type="button" disabled={!!busy || (!dirty && !isNew)} onClick={() => void run('save', async () => { await save(); setNotice({ ok: true, text: t('admin.bl.saved') }); })} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-50">
            {busy === 'save' ? <Spinner /> : <Save width={16} height={16} aria-hidden />}
            {t(d?.state === 'published' ? 'admin.bl.save_live' : 'admin.bl.save')}
          </button>
        </PageActions>
      )}

      <section className="kn-in min-w-0 rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24">
        {notice && <p role="status" className={cx('kn-pop mb-16 rounded-lg px-16 py-12 text-latin-label-sm font-semibold', notice.ok ? 'bg-status-success-bg text-status-success' : 'bg-status-danger-bg text-status-danger')}>{notice.text}</p>}
        <div role="tablist" aria-label={t('admin.no.language')} className="-mx-4 flex gap-8 overflow-x-auto px-4 pb-4">
          {LANGS.map((l) => (
            <button key={l} role="tab" type="button" aria-selected={tab === l} onClick={() => setTab(l)} className={cx('kn-btn inline-flex h-[32px] shrink-0 items-center gap-4 rounded-full border px-12 text-[13px] font-semibold', tab === l ? 'border-espresso-950 bg-espresso-950 text-cream-50' : 'border-border-default hover:border-mocha-500')}>
              {filled(l) && <Check width={12} height={12} aria-hidden />}
              {t(`lang.${l}`)}
              {l === 'en' && <span aria-hidden>*</span>}
            </button>
          ))}
        </div>
        <p className="mt-4 text-[13px] text-text-secondary">{t('admin.bl.lang_hint')}</p>

        <fieldset disabled={!can || !!busy} className="mt-16 flex min-w-0 flex-col gap-16">
          <div>
            <label htmlFor="bl-title" className="text-latin-label-sm font-semibold">{t('admin.bl.title')}</label>
            <input id="bl-title" lang={tab} value={c.title} maxLength={120} onChange={(e) => editC({ title: e.target.value })} className={cx(inputCls, 'mt-8 h-[48px] text-[18px] font-semibold')} />
          </div>
          <div>
            <label htmlFor="bl-summary" className="text-latin-label-sm font-semibold">{t('admin.bl.summary')}</label>
            <textarea id="bl-summary" lang={tab} rows={2} value={c.summary} maxLength={300} onChange={(e) => editC({ summary: e.target.value })} className={cx(area, 'mt-8')} />
          </div>
          <div>
            <label htmlFor="bl-author" className="text-latin-label-sm font-semibold">{t('admin.bl.author')}</label>
            <input id="bl-author" lang={tab} value={c.author} maxLength={80} placeholder="KaamNishaan team" onChange={(e) => editC({ author: e.target.value })} className={cx(inputCls, 'mt-8 h-[44px]')} />
          </div>
          <div>
            <p className="text-latin-label-sm font-semibold">{t('admin.bl.body')}</p>
            {blocks.length ? (
              <ol className="mt-8 flex flex-col gap-12">
                {blocks.map((b, i) => (
                  <BlockEditor key={`${tab}-${i}`} t={t} b={b} i={i} n={blocks.length} site={site} disabled={!can}
                    set={(nb) => setBlocks(blocks.map((x, j) => (j === i ? nb : x)))}
                    move={(dir) => { const bs = [...blocks]; [bs[i], bs[i + dir]] = [bs[i + dir]!, bs[i]!]; setBlocks(bs); }}
                    drop={() => setBlocks(blocks.filter((_, j) => j !== i))} />
                ))}
              </ol>
            ) : (
              <p className="mt-8 rounded-lg border border-dashed border-border-default px-16 py-24 text-center text-[13px] text-text-secondary">{t('admin.bl.empty_body')}</p>
            )}
            {can && (
              <div className="mt-12 flex flex-wrap items-center gap-8">
                <span className="text-[13px] text-text-secondary">{t('admin.bl.add')}</span>
                {KINDS.map((k) => (
                  <button key={k.type} type="button" onClick={() => setBlocks([...blocks, k.type === 'list' ? { type: 'list', title: '', items: [] } : { type: k.type, text: '' }])} className="kn-btn inline-flex h-[32px] items-center gap-4 rounded-full border border-border-default px-12 text-[13px] font-semibold hover:border-mocha-500">
                    {k.icon}
                    {t(`admin.bl.b.${k.type}`)}
                  </button>
                ))}
              </div>
            )}
          </div>
        </fieldset>
      </section>

      <aside className="flex flex-col gap-16">
        <section className="kn-in rounded-xl border border-border-default bg-bg-surface p-20" style={{ ['--d' as string]: '80ms' }}>
          <div className="flex flex-wrap items-center justify-between gap-8">
            <h2 className="text-[17px] font-semibold">{t('admin.bl.publishing')}</h2>
            {d && <BlogStatePill t={t} lang={lang} state={d.state} at={d.publish_at} />}
          </div>
          {d && <p className="mt-4 text-[13px] text-text-secondary">{t('admin.bl.last', { ago: ago(d.updated_at, lang), who: d.updated_by ?? '—' })}</p>}
          {can && (
            <div className="mt-16 flex flex-col gap-12">
              {d?.state !== 'published' && (
                <>
                  <button type="button" disabled={!!busy} onClick={() => void publish(null)} className="kn-btn inline-flex h-[44px] items-center justify-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-50">
                    {busy === 'publish' ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
                    {t('admin.bl.publish_now')}
                  </button>
                  <div className="flex gap-8">
                    <label htmlFor="bl-when" className="sr-only">{t('admin.bl.when')}</label>
                    <input id="bl-when" type="datetime-local" min={minWhen} value={when} onChange={(e) => setWhen(e.target.value)} className={cx(inputCls, 'h-[44px] min-w-0 flex-1 px-12 text-[14px]')} />
                    <button type="button" disabled={!!busy || !when} onClick={() => void publish(when)} className="kn-btn inline-flex h-[44px] shrink-0 items-center gap-8 rounded-lg border border-border-default px-12 text-latin-label-sm font-semibold hover:border-mocha-500 disabled:opacity-50">
                      {busy === 'schedule' ? <Spinner /> : <Clock width={16} height={16} aria-hidden />}
                      {t('admin.bl.schedule')}
                    </button>
                  </div>
                  <p className="text-[13px] text-text-secondary">{t('admin.bl.publish_hint')}</p>
                </>
              )}
              {d && d.state !== 'draft' && (
                <button type="button" disabled={!!busy} onClick={() => void run('unpublish', async () => { take(await api<AdminBlogDetail>(`/admin/blog/${id}/unpublish`, { method: 'POST' })); setNotice({ ok: true, text: t('admin.bl.unpublished') }); })} className="kn-btn inline-flex h-[40px] items-center justify-center rounded-lg border border-border-default px-16 text-latin-label-sm font-semibold hover:border-mocha-500 disabled:opacity-50">
                  {busy === 'unpublish' ? <Spinner /> : t('admin.bl.unpublish')}
                </button>
              )}
              {d && d.state !== 'published' && (
                sure ? (
                  <div className="kn-pop rounded-lg bg-status-danger-bg p-12">
                    <p className="text-[13px] font-semibold text-status-danger">{t('admin.bl.delete_q')}</p>
                    <div className="mt-8 flex gap-8">
                      <button type="button" disabled={!!busy} onClick={() => void run('delete', async () => { await api(`/admin/blog/${id}`, { method: 'DELETE' }); setDirty(false); navigate('/blog'); })} className="kn-btn inline-flex h-[36px] items-center gap-8 rounded-lg bg-status-danger px-12 text-[13px] font-semibold text-cream-50 disabled:opacity-50">
                        {busy === 'delete' ? <Spinner /> : <Trash2 width={14} height={14} aria-hidden />}
                        {t('admin.bl.delete_yes')}
                      </button>
                      <button type="button" onClick={() => setSure(false)} className="kn-btn h-[36px] rounded-lg px-12 text-[13px] font-semibold hover:bg-bg-surface">{t('admin.us.cancel')}</button>
                    </div>
                  </div>
                ) : (
                  <button type="button" disabled={!!busy} onClick={() => setSure(true)} className="kn-btn inline-flex h-[40px] items-center justify-center gap-8 rounded-lg px-16 text-latin-label-sm font-semibold text-status-danger hover:bg-status-danger-bg disabled:opacity-50">
                    <Trash2 width={16} height={16} aria-hidden />
                    {t('admin.bl.delete')}
                  </button>
                )
              )}
            </div>
          )}
        </section>

        <section className="kn-in rounded-xl border border-border-default bg-bg-surface p-20" style={{ ['--d' as string]: '160ms' }}>
          <h2 className="text-[17px] font-semibold">{t('admin.bl.settings')}</h2>
          <fieldset disabled={!can || !!busy} className="mt-16 flex min-w-0 flex-col gap-16">
            <div>
              <p className="text-latin-label-sm font-semibold">{t('admin.bl.cover')}</p>
              {form.cover ? <img src={pic(form.cover, site)} alt="" className="mt-8 aspect-[16/9] w-full rounded-lg bg-bg-subtle object-cover" /> : <p className="mt-8 flex aspect-[16/9] items-center justify-center rounded-lg bg-bg-subtle text-[13px] text-text-secondary">{t('admin.bl.no_cover')}</p>}
              <div className="mt-8"><Uploader t={t} label={t(form.cover ? 'admin.bl.replace' : 'admin.bl.upload')} disabled={!can} onDone={(m) => edit({ cover: m.key })} /></div>
            </div>
            <div>
              <label htmlFor="bl-cat" className="text-latin-label-sm font-semibold">{t('admin.bl.category')}</label>
              <select id="bl-cat" value={form.category} onChange={(e) => edit({ category: e.target.value })} className={cx(inputCls, 'mt-8 h-[44px]')}>
                {CATEGORIES.map((x) => <option key={x} value={x}>{t(`site.blog.cat.${x}`)}</option>)}
              </select>
            </div>
            <div>
              <label htmlFor="bl-slug" className="text-latin-label-sm font-semibold">{t('admin.bl.slug')}</label>
              <div className="mt-8 flex items-center rounded-lg border border-border-strong bg-bg-surface pl-12 focus-within:ring-2 focus-within:ring-focus-ring">
                <span className="shrink-0 text-[14px] text-text-secondary">/blog/</span>
                <input id="bl-slug" value={form.slug} maxLength={120} disabled={d?.state === 'published'} onChange={(e) => { setSlugTouched(true); edit({ slug: slugify(e.target.value) || e.target.value.toLowerCase() }); }} className="h-[44px] min-w-0 flex-1 bg-transparent pr-12 text-[14px] focus:outline-none disabled:opacity-70" />
              </div>
              {d?.state === 'published' && <p className="mt-4 text-[13px] text-text-secondary">{t('admin.bl.slug_locked')}</p>}
            </div>
            <Switch label={t('admin.bl.featured')} hint={t('admin.bl.featured_hint')} checked={form.featured} disabled={!can} onChange={(v) => edit({ featured: v })} />
          </fieldset>
        </section>
      </aside>
    </div>
  );
}
