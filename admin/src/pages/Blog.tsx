import { Plus, Search, Star } from 'lucide-react';
import { useCallback, useEffect, useRef, useState } from 'react';

import { api, ApiError } from '../lib/api';
import { day, LANGS, num, type Lang, type T } from '../lib/i18n';
import type { AdminBlogList, AdminBlogRow, BlogState } from '../lib/types';
import { cx, FilterSelect, Link, navigate } from '../ui';

const pill = 'inline-flex whitespace-nowrap rounded-full px-[10px] py-[3px] text-[13px] font-semibold';

export function BlogStatePill({ t, lang, state, at }: { t: T; lang: Lang; state: BlogState; at: string | null }) {
  if (state === 'published') return <span className={cx(pill, 'bg-status-success-bg text-status-success')}>{t('admin.bl.st.published')}</span>;
  if (state === 'scheduled') return <span className={cx(pill, 'bg-cream-300 text-mocha-700')}>{t('admin.bl.st.scheduled_on', { day: at ? day(at, lang, { year: undefined }) : '' })}</span>;
  return <span className={cx(pill, 'bg-status-warning-bg text-status-warning')}>{t('admin.bl.st.draft')}</span>;
}

/** The top-bar button: start a new post. */
export function NewPost({ t }: { t: T }) {
  return (
    <Link to="/blog/new" className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed">
      <Plus width={16} height={16} aria-hidden />
      {t('admin.bl.new')}
    </Link>
  );
}

/** A26 Blog management: every post with its state, newest work first. */
export function Blog({ t, lang }: { t: T; lang: Lang }) {
  const [data, setData] = useState<AdminBlogList | null>(null);
  const [error, setError] = useState(false);
  const [typed, setTyped] = useState('');
  const [q, setQ] = useState('');
  const [state, setState] = useState('');
  const [language, setLanguage] = useState('');
  const seq = useRef(0);

  const load = useCallback(() => {
    const n = ++seq.current;
    setError(false);
    const p = new URLSearchParams();
    if (q) p.set('q', q);
    if (state) p.set('state', state);
    if (language) p.set('lang', language);
    api<AdminBlogList>(`/admin/blog?${p}`)
      .then((d) => n === seq.current && setData(d))
      .catch((e) => n === seq.current && !(e instanceof ApiError && e.status === 401) && setError(true));
  }, [q, state, language]);
  useEffect(load, [load]);
  useEffect(() => {
    const tm = window.setTimeout(() => setQ(typed.trim()), 300);
    return () => window.clearTimeout(tm);
  }, [typed]);

  const row = (p: AdminBlogRow, i: number) => (
    <tr key={p.id} onClick={() => navigate(`/blog/${p.id}`)} className="kn-in group cursor-pointer transition-colors hover:bg-cream-100" style={{ ['--d' as string]: `${Math.min(i * 30, 400)}ms` }}>
      <td className="py-12 pl-20 pr-16">
        <div className="flex items-center gap-12">
          <img src={p.cover_url} alt="" loading="lazy" className="h-[40px] w-[64px] shrink-0 rounded-md bg-bg-subtle object-cover transition-transform duration-300 group-hover:scale-105" />
          <div className="min-w-0">
            <Link to={`/blog/${p.id}`} className="line-clamp-2 font-semibold group-hover:underline">
              {p.title}
              {p.featured && <Star width={14} height={14} className="ml-4 inline fill-status-warning text-status-warning" aria-label={t('admin.bl.featured')} />}
            </Link>
            <p className="text-[13px] text-text-secondary">{t(`site.blog.cat.${p.category}`)} · {t('site.blog.minutes', { n: num(p.read_minutes, lang) })}</p>
          </div>
        </div>
      </td>
      <td className="px-16 py-12">{p.author || '—'}</td>
      <td className="px-16 py-12">
        <span className="flex flex-wrap gap-4">
          {LANGS.map((l) => (
            <span key={l} title={t(`lang.${l}`)} className={cx('rounded px-[6px] py-[1px] text-[12px] font-semibold uppercase', p.languages.includes(l) ? 'bg-bg-subtle text-text-primary' : 'text-taupe-400 line-through')}>{l}</span>
          ))}
        </span>
      </td>
      <td className="px-16 py-12"><BlogStatePill t={t} lang={lang} state={p.state} at={p.publish_at} /></td>
      <td className="px-16 py-12 tabular-nums text-text-secondary">{p.state === 'published' && p.publish_at ? day(p.publish_at, lang, { year: undefined }) : '—'}</td>
    </tr>
  );

  return (
    <div className="flex flex-col gap-16">
      <div className="kn-in flex flex-wrap gap-12">
        <label className="relative min-w-[240px] flex-1">
          <span className="sr-only">{t('admin.bl.search')}</span>
          <Search width={18} height={18} className="pointer-events-none absolute left-12 top-1/2 -translate-y-1/2 text-text-secondary" aria-hidden />
          <input type="search" value={typed} onChange={(e) => setTyped(e.target.value)} placeholder={t('admin.bl.search')} className="h-[44px] w-full rounded-lg border border-border-strong bg-bg-surface pl-[38px] pr-12 text-[14px] placeholder:text-taupe-500 hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring" />
        </label>
        <FilterSelect label={t('admin.bl.f_state')} value={state} allLabel={t('admin.bl.all')} options={(['published', 'scheduled', 'draft'] as const).map((s) => ({ value: s, label: `${t(`admin.bl.st.${s}`)}${data ? ` (${num(data.counts[s], lang)})` : ''}` }))} onChange={setState} />
        <FilterSelect label={t('admin.bl.f_lang')} value={language} allLabel={t('admin.bl.all')} options={LANGS.map((l) => ({ value: l, label: t(`lang.${l}`) }))} onChange={setLanguage} />
      </div>
      {error && (
        <p role="alert" className="rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">
          {t('admin.err.load')}{' '}
          <button type="button" className="underline" onClick={load}>{t('admin.retry')}</button>
        </p>
      )}
      <section className="kn-in overflow-hidden rounded-xl border border-border-default bg-bg-surface">
        {!data ? (
          <div aria-busy="true" className="kn-shimmer m-12 h-[320px] rounded-lg bg-bg-subtle" />
        ) : data.items.length ? (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[900px] text-left">
              <thead className="bg-bg-subtle text-[13px] text-text-secondary">
                <tr>
                  {(['c_post', 'c_author', 'c_lang', 'c_state', 'c_date'] as const).map((c, i) => (
                    <th key={c} scope="col" className={cx('px-16 py-12 font-semibold', i === 0 && 'pl-20')}>{t(`admin.bl.${c}`)}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-border-default text-[14px]">{data.items.map(row)}</tbody>
            </table>
          </div>
        ) : (
          <p className="px-24 py-48 text-center text-latin-label-sm text-text-secondary">{q || state || language ? t('admin.bl.none_match') : t('admin.bl.none')}</p>
        )}
      </section>
    </div>
  );
}
