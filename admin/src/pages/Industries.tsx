import { Check, Plus } from 'lucide-react';
import { useCallback, useEffect, useRef, useState } from 'react';

import { api, ApiError } from '../lib/api';
import { num, type Lang, type T } from '../lib/i18n';
import type { AdminIndustriesOut, AdminIndustry } from '../lib/types';
import { cx, ErrorBanner, inputCls, PageActions, Spinner, Switch } from '../ui';

const LANGS = ['en', 'hi', 'gu', 'es', 'fr'] as const;
const pill = 'inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold';
const slugOf = (s: string) => s.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 48);

function Edit({ t, item, nextSort, onClose, onSaved }: { t: T; item: AdminIndustry | null; nextSort: number; onClose: () => void; onSaved: (d: AdminIndustriesOut) => void }) {
  const [name, setName] = useState<Record<string, string>>(() => Object.fromEntries(LANGS.map((l) => [l, item?.name[l] ?? ''])));
  const [slug, setSlug] = useState(item?.slug ?? '');
  const [touched, setTouched] = useState(!!item);
  const [live, setLive] = useState(item ? item.status === 'live' : false);
  const [sort, setSort] = useState(String(item?.sort ?? nextSort));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const first = useRef<HTMLInputElement>(null);
  useEffect(() => first.current?.focus(), []);
  useEffect(() => {
    const esc = (e: globalThis.KeyboardEvent) => e.key === 'Escape' && !busy && onClose();
    window.addEventListener('keydown', esc);
    return () => window.removeEventListener('keydown', esc);
  }, [busy, onClose]);

  const save = async () => {
    if (!name.en.trim()) return setError(t('admin.pl.err.name'));
    if (!item && !/^[a-z][a-z0-9-]{1,46}[a-z0-9]$/.test(slug)) return setError(t('admin.in.err.slug'));
    setBusy(true);
    setError(null);
    try {
      const body = { ...(item ? {} : { slug }), name: Object.fromEntries(Object.entries(name).filter(([, v]) => v.trim())), status: live ? 'live' : 'draft', sort: Number(sort) || 0 };
      onSaved(await api<AdminIndustriesOut>(item ? `/admin/industries/${item.slug}` : '/admin/industries', { method: item ? 'PUT' : 'POST', body }));
    } catch (e) {
      setError(e instanceof ApiError && e.code === 'industry_exists' ? t('admin.in.err.exists') : t('admin.err.save'));
      setBusy(false);
    }
  };
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center p-16 sm:items-center">
      <button type="button" aria-hidden tabIndex={-1} onClick={() => !busy && onClose()} className="absolute inset-0 cursor-default bg-espresso-950/50" />
      <div role="dialog" aria-modal="true" aria-labelledby="ind-title" className="kn-pop relative max-h-[90vh] w-full max-w-[560px] overflow-y-auto rounded-xl bg-bg-surface p-24 shadow-lg">
        <h2 id="ind-title" className="text-[22px] font-bold leading-[30px]">{item ? t('admin.in.edit_title', { name: item.name.en }) : t('admin.in.add_title')}</h2>
        <fieldset className="mt-16">
          <legend className="text-latin-label-sm font-semibold">{t('admin.in.f_name')}</legend>
          <div className="mt-8 grid gap-8 sm:grid-cols-2">
            {LANGS.map((l, i) => (
              <label key={l} className="block">
                <span className="text-[13px] text-text-secondary">{t(`lang.${l}`)}</span>
                <input ref={i === 0 ? first : undefined} value={name[l]} maxLength={48} onChange={(e) => { setName({ ...name, [l]: e.target.value }); if (l === 'en' && !touched) setSlug(slugOf(e.target.value)); }} className={cx(inputCls, 'mt-4')} />
              </label>
            ))}
          </div>
        </fieldset>
        <label className="mt-16 block">
          <span className="block text-latin-label-sm font-semibold">{t('admin.in.f_slug')}</span>
          <input value={slug} disabled={!!item} maxLength={48} onChange={(e) => { setTouched(true); setSlug(e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, '')); }} className={cx(inputCls, 'mt-8 font-mono')} />
          <span className="mt-4 block text-[13px] text-text-secondary">{t(item ? 'admin.in.slug_fixed' : 'admin.in.slug_hint')}</span>
        </label>
        <label className="mt-16 block">
          <span className="block text-latin-label-sm font-semibold">{t('admin.in.f_sort')}</span>
          <input inputMode="numeric" value={sort} onChange={(e) => setSort(e.target.value.replace(/\D/g, ''))} className={cx(inputCls, 'mt-8 w-[120px] tabular-nums')} />
        </label>
        <div className="mt-12">
          <Switch label={t('admin.in.f_live')} hint={t('admin.in.f_live_hint')} checked={live} onChange={setLive} />
        </div>
        {error && <div className="mt-12"><ErrorBanner>{error}</ErrorBanner></div>}
        <div className="mt-20 flex flex-col-reverse gap-12 sm:flex-row sm:justify-end">
          <button type="button" onClick={onClose} disabled={busy} className="kn-btn inline-flex h-[44px] items-center justify-center rounded-lg bg-bg-subtle px-20 text-latin-label-sm font-semibold hover:bg-cream-300">{t('admin.us.cancel')}</button>
          <button type="button" onClick={() => void save()} disabled={busy} className="kn-btn inline-flex h-[44px] items-center justify-center gap-8 rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-60">
            {busy ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
            {t('admin.pl.save')}
          </button>
        </div>
      </div>
    </div>
  );
}

/** A22 Industries: the trades offered at sign-up, their ready-made checklists and companies. */
export function Industries({ t, lang }: { t: T; lang: Lang }) {
  const [data, setData] = useState<AdminIndustriesOut | null>(null);
  const [error, setError] = useState(false);
  const [open, setOpen] = useState<AdminIndustry | 'new' | null>(null);
  const load = useCallback(() => {
    setError(false);
    api<AdminIndustriesOut>('/admin/industries').then(setData).catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, []);
  useEffect(load, [load]);

  if (error && !data)
    return (
      <div className="kn-in mx-auto mt-48 max-w-[480px] rounded-xl border border-border-default bg-bg-surface p-24 text-center">
        <p className="text-latin-body text-text-secondary">{t('admin.err.load')}</p>
        <button type="button" onClick={load} className="kn-btn mt-16 inline-flex h-[44px] items-center rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action">{t('admin.retry')}</button>
      </div>
    );
  if (!data) return <div aria-busy="true" className="kn-shimmer h-[420px] rounded-xl bg-bg-surface" />;
  const can = data.can_act;

  return (
    <div className="flex flex-col gap-16">
      {can && (
        <PageActions>
          <button type="button" onClick={() => setOpen('new')} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed">
            <Plus width={16} height={16} aria-hidden />
            {t('admin.in.add')}
          </button>
        </PageActions>
      )}
      <div className="kn-in overflow-hidden rounded-xl border border-border-default bg-bg-surface">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[760px] text-left">
            <thead className="bg-bg-subtle text-[13px] text-text-secondary">
              <tr>
                {(['c_industry', 'c_checklist', 'c_ready', 'c_companies', 'c_status'] as const).map((c, i) => (
                  <th key={c} scope="col" className={cx('px-16 py-12 font-semibold', i === 0 && 'pl-20')}>{t(`admin.in.${c}`)}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-border-default text-[14px]">
              {data.items.map((x, i) => (
                <tr key={x.slug} onClick={can ? () => setOpen(x) : undefined} className={cx('kn-in transition-colors hover:bg-cream-100', can && 'cursor-pointer')} style={{ ['--d' as string]: `${Math.min(i * 30, 400)}ms` }}>
                  <td className="py-12 pl-20 pr-16">
                    {can ? <button type="button" className="font-semibold hover:underline">{x.name[lang] || x.name.en}</button> : <span className="font-semibold">{x.name[lang] || x.name.en}</span>}
                    <span className="block font-mono text-[12px] text-text-secondary">{x.slug}</span>
                  </td>
                  <td className="px-16 py-12">{x.default_checklist ? t('admin.in.checklist', { name: x.default_checklist, n: num(x.default_questions ?? 0, lang) }) : <span className="text-text-secondary">{t('admin.in.not_set')}</span>}</td>
                  <td className="px-16 py-12 tabular-nums">{num(x.checklists, lang)}</td>
                  <td className="px-16 py-12 tabular-nums">{num(x.companies, lang)}</td>
                  <td className="px-16 py-12">
                    <span className={cx(pill, x.status === 'live' ? 'bg-status-success-bg text-status-success' : 'bg-status-warning-bg text-status-warning')}>{t(`admin.in.st.${x.status}`)}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      <p className="text-[13px] text-text-secondary">{t('admin.in.note')}</p>
      {open && (
        <Edit t={t} item={open === 'new' ? null : open} nextSort={Math.max(0, ...data.items.map((x) => x.sort)) + 1} onClose={() => setOpen(null)} onSaved={(d) => { setData(d); setOpen(null); }} />
      )}
    </div>
  );
}
