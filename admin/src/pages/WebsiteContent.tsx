import { Check, ExternalLink, RotateCcw, Save } from 'lucide-react';
import { useCallback, useEffect, useMemo, useState } from 'react';

import { api, ApiError } from '../lib/api';
import { ago, BUILT_IN, LANGS, num, plural, type Lang, type T } from '../lib/i18n';
import type { AdminPageField, AdminPageOut, AdminPagesOut } from '../lib/types';
import { cx, inputCls, Link, PageActions, Spinner } from '../ui';

type Edits = Record<string, Partial<Record<Lang, string>>>;
const pill = 'inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold';

const pageName = (t: T, p: { page: string; trade: string | null }) =>
  p.trade ? t('admin.wc.page.industry', { trade: t(`admin.wc.trade.${p.trade}`) }) : t(`admin.wc.page.${p.page}`);

/** What a field shows now: the unsaved edit, else the saved draft, else live, else the built-in text. */
function shown(f: AdminPageField, lang: Lang, edits: Edits): string {
  const e = edits[f.key]?.[lang];
  if (e !== undefined) return e;
  const v = f.values[lang];
  if (v?.has_draft) return v.draft ?? BUILT_IN[lang][f.key] ?? '';
  return v?.live ?? BUILT_IN[lang][f.key] ?? '';
}

function FieldInput({ t, lang, f, edits, setEdits, disabled }: { t: T; lang: Lang; f: AdminPageField; edits: Edits; setEdits: (e: Edits) => void; disabled: boolean }) {
  const value = shown(f, lang, edits);
  const builtIn = BUILT_IN[lang][f.key] ?? '';
  const v = f.values[lang];
  const unsaved = edits[f.key]?.[lang] !== undefined;
  const state = unsaved ? 'unsaved' : v?.has_draft ? 'draft' : v?.live != null ? 'changed' : null;
  const id = `f-${f.key}-${lang}`;
  const set = (x: string) => setEdits({ ...edits, [f.key]: { ...edits[f.key], [lang]: x } });
  const label = t(`admin.wc.f.${f.label}`, { n: f.n ?? '' });
  const props = { id, lang, value, disabled, maxLength: f.max, onChange: (e: { target: { value: string } }) => set(e.target.value) };
  return (
    <div className="kn-in">
      <div className="flex flex-wrap items-center justify-between gap-8">
        <label htmlFor={id} className="text-latin-label-sm font-semibold">
          {label}
          {state && <span className={cx(pill, 'ml-8', state === 'changed' ? 'bg-status-success-bg text-status-success' : 'bg-status-warning-bg text-status-warning')}>{t(`admin.wc.state.${state}`)}</span>}
        </label>
        {value !== builtIn && !disabled && (
          <button type="button" onClick={() => set(builtIn)} className="inline-flex items-center gap-4 text-[13px] font-semibold text-text-secondary hover:text-text-primary">
            <RotateCcw width={12} height={12} aria-hidden />
            {t('admin.wc.original')}
          </button>
        )}
      </div>
      {f.multiline ? (
        <textarea {...props} rows={3} className="mt-8 w-full rounded-lg border border-border-strong bg-bg-surface px-16 py-12 text-latin-body hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring disabled:opacity-70" />
      ) : (
        <input {...props} className={cx(inputCls, 'mt-8 h-[48px] disabled:opacity-70')} />
      )}
      <p className={cx('mt-4 text-[13px] tabular-nums', value.length > f.max * 0.9 ? 'text-status-warning' : 'text-text-secondary')}>
        {t('admin.wc.chars', { n: value.length, max: f.max })}
        {/\{\w+\}/.test(builtIn) && <> · {t('admin.wc.keep', { parts: [...new Set(builtIn.match(/\{\w+\}/g))].join(' ') })}</>}
      </p>
    </div>
  );
}

/** A24 Website content: change the website's headlines, FAQs and search-engine texts, then publish. */
export function WebsiteContent({ t, lang, page: picked }: { t: T; lang: Lang; page: string | null }) {
  const [list, setList] = useState<AdminPagesOut | null>(null);
  const [data, setData] = useState<AdminPageOut | null>(null);
  const [error, setError] = useState(false);
  const [edits, setEdits] = useState<Edits>({});
  const [tab, setTab] = useState<Lang>('en');
  const [busy, setBusy] = useState<string | null>(null);
  const [notice, setNotice] = useState<{ ok: boolean; text: string } | null>(null);
  const page = picked ?? 'home';

  const loadList = useCallback(() => {
    api<AdminPagesOut>('/admin/website-content').then(setList).catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, []);
  useEffect(loadList, [loadList]);
  useEffect(() => {
    setData(null);
    setEdits({});
    setNotice(null);
    api<AdminPageOut>(`/admin/website-content/${page}`).then(setData).catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, [page]);

  const pending = useMemo(() => {
    if (!data) return {};
    const out: Record<string, Partial<Record<Lang, string | null>>> = {};
    for (const s of data.sections)
      for (const f of s.fields)
        for (const l of LANGS) {
          const e = edits[f.key]?.[l];
          if (e === undefined) continue;
          const v = f.values[l];
          const before = v?.has_draft ? v.draft : v?.live ?? null;
          const next = e.trim() === '' || e === BUILT_IN[l][f.key] ? null : e;
          if (next !== before) (out[f.key] ??= {})[l] = next;
        }
    return out;
  }, [data, edits]);
  const unsaved = Object.values(pending).reduce((n, x) => n + Object.keys(x).length, 0);
  const can = !!list?.can_act;

  const after = (d: AdminPageOut, text: string) => {
    setData(d);
    setEdits({});
    setNotice({ ok: true, text });
    loadList();
  };
  const fail = (e: unknown) => setNotice({ ok: false, text: e instanceof ApiError && e.status === 400 ? e.message : t('admin.err.generic') });
  const save = async (): Promise<boolean> => {
    if (!unsaved) return true;
    const d = await api<AdminPageOut>(`/admin/website-content/${page}`, { method: 'PUT', body: { values: pending } });
    after(d, t('admin.wc.saved'));
    return true;
  };
  const run = async (key: string, fn: () => Promise<void>) => {
    setBusy(key);
    setNotice(null);
    try {
      await fn();
    } catch (e) {
      fail(e);
    } finally {
      setBusy(null);
    }
  };
  const publish = () =>
    run('publish', async () => {
      await save();
      after(await api<AdminPageOut>(`/admin/website-content/${page}/publish`, { method: 'POST' }), t('admin.wc.published'));
    });
  const preview = () => {
    const w = window.open('about:blank', '_blank'); // opened now, so the browser doesn't block it
    void run('preview', async () => {
      try {
        await save();
        const { url } = await api<{ url: string }>(`/admin/website-content/${page}/preview`, { method: 'POST', body: { lang: tab } });
        if (w) w.location.href = url;
        else window.open(url, '_blank');
      } catch (e) {
        w?.close();
        throw e;
      }
    });
  };
  const discard = () => run('discard', async () => after(await api<AdminPageOut>(`/admin/website-content/${page}/discard`, { method: 'POST' }), t('admin.wc.discarded')));
  const drafts = (data?.drafts ?? 0) + unsaved;

  if (error)
    return (
      <p role="alert" className="rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">
        {t('admin.err.load')}
      </p>
    );

  return (
    <div className="grid items-start gap-16 lg:grid-cols-[300px_1fr]">
      {can && (
        <PageActions>
          <button type="button" disabled={!data || !!busy} onClick={preview} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-60">
            {busy === 'preview' ? <Spinner /> : <ExternalLink width={16} height={16} aria-hidden />}
            {t('admin.wc.preview')}
          </button>
          <button type="button" disabled={!data || !!busy || drafts === 0} onClick={() => void publish()} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-50">
            {busy === 'publish' ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
            {t('admin.wc.publish')}
          </button>
        </PageActions>
      )}

      <nav aria-label={t('admin.wc.pages')} className={cx('kn-in overflow-hidden rounded-xl border border-border-default bg-bg-surface', picked && 'hidden lg:block')}>
        {!list ? (
          <div aria-busy="true" className="kn-shimmer m-12 h-[360px] rounded-lg bg-bg-subtle" />
        ) : (
          <ul>
            {list.pages.map((p) => (
              <li key={p.page}>
                <Link to={`/website-content/${p.page}`} aria-current={p.page === page ? 'page' : undefined} className={cx('kn-in block border-b border-border-default px-16 py-12 transition-colors last:border-0', p.page === page ? 'bg-bg-subtle' : 'hover:bg-cream-100')}>
                  <span className="block text-[15px] font-semibold">{pageName(t, p)}</span>
                  <span className={cx('block text-[13px]', p.drafts ? 'font-semibold text-status-warning' : 'text-text-secondary')}>
                    {p.drafts ? plural(t, 'admin.wc.drafts', p.drafts, { n: num(p.drafts, lang) }) : p.edited_at ? t('admin.wc.edited', { ago: ago(p.edited_at, lang) }) : t('admin.wc.built_in')}
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </nav>

      <section className={cx('min-w-0 rounded-xl border border-border-default bg-bg-surface', !picked && 'hidden lg:block')}>
        {!data ? (
          <div aria-busy="true" className="kn-shimmer m-20 h-[480px] rounded-lg bg-bg-subtle" />
        ) : (
          <div className="kn-in flex flex-col gap-20 p-20 sm:p-24">
            <Link to="/website-content" className="inline-flex items-center gap-4 text-latin-label-sm font-semibold text-text-secondary lg:hidden">← {t('admin.wc.pages')}</Link>
            <div className="flex flex-wrap items-center gap-12">
              <h2 className="text-[22px] font-bold leading-[30px]">{pageName(t, data)}</h2>
              {drafts > 0 && <span className={cx(pill, 'bg-status-warning-bg text-status-warning')}>{t('admin.wc.unpublished')}</span>}
              <a href={`${list?.web_url ?? ''}${data.path}`} target="_blank" rel="noreferrer" className="kn-link text-[13px] text-text-secondary">{data.path}</a>
            </div>
            {data.edited_at && <p className="-mt-12 text-[13px] text-text-secondary">{t('admin.wc.last', { ago: ago(data.edited_at, lang), who: data.edited_by ?? '—' })}</p>}
            {!can && <p className="rounded-lg bg-bg-subtle px-16 py-12 text-latin-label-sm text-text-secondary">{t('admin.wc.read_only')}</p>}
            {notice && <p role="status" className={cx('kn-pop rounded-lg px-16 py-12 text-latin-label-sm font-semibold', notice.ok ? 'bg-status-success-bg text-status-success' : 'bg-status-danger-bg text-status-danger')}>{notice.text}</p>}

            <div role="tablist" aria-label={t('admin.no.language')} className="-mx-4 flex gap-8 overflow-x-auto px-4 pb-4">
              {LANGS.map((l) => (
                <button key={l} role="tab" type="button" aria-selected={tab === l} onClick={() => setTab(l)} className={cx('kn-btn h-[32px] shrink-0 rounded-full border px-12 text-[13px] font-semibold', tab === l ? 'border-espresso-950 bg-espresso-950 text-cream-50' : 'border-border-default hover:border-mocha-500')}>
                  {t(`lang.${l}`)}
                </button>
              ))}
            </div>

            {data.sections.map((s) => (
              <fieldset key={s.key} className="flex min-w-0 flex-col gap-16 border-t border-border-default pt-16 first-of-type:border-0 first-of-type:pt-0">
                <legend className="mb-12 text-[17px] font-semibold">{t(`admin.wc.s.${s.key}`)}</legend>
                {s.key === 'seo' && <p className="-mt-8 text-[13px] text-text-secondary">{t('admin.wc.seo_hint')}</p>}
                {s.fields.map((f) => (
                  <FieldInput key={`${f.key}-${tab}`} t={t} lang={tab} f={f} edits={edits} setEdits={setEdits} disabled={!can || !!busy} />
                ))}
              </fieldset>
            ))}

            {can && (
              <div className="sticky bottom-0 -mx-20 -mb-20 flex flex-wrap items-center justify-between gap-12 border-t border-border-default bg-bg-surface px-20 py-12 sm:-mx-24 sm:-mb-24 sm:px-24">
                <p className="text-[13px] text-text-secondary">{drafts ? plural(t, 'admin.wc.pending', drafts, { n: num(drafts, lang) }) : t('admin.wc.nothing')}</p>
                <div className="flex flex-wrap gap-8">
                  {(data.drafts > 0 || unsaved > 0) && (
                    <button type="button" disabled={!!busy} onClick={() => (unsaved ? setEdits({}) : void discard())} className="kn-btn inline-flex h-[40px] items-center rounded-lg px-12 text-latin-label-sm font-semibold text-text-secondary hover:bg-bg-subtle disabled:opacity-50">
                      {busy === 'discard' ? <Spinner /> : t(unsaved ? 'admin.wc.undo' : 'admin.wc.discard')}
                    </button>
                  )}
                  <button type="button" disabled={!unsaved || !!busy} onClick={() => void run('save', async () => void (await save()))} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-50">
                    {busy === 'save' ? <Spinner /> : <Save width={16} height={16} aria-hidden />}
                    {t('admin.wc.save')}
                  </button>
                </div>
              </div>
            )}
          </div>
        )}
      </section>
    </div>
  );
}

