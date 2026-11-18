import { Check, ChevronRight, Mail } from 'lucide-react';
import { useState, type FormEvent } from 'react';

import { cx } from '../../components/ui';
import { api, ApiError } from '../../lib/api';
import { day, type Lang, type T } from '../../lib/i18n';
import type { BlogCategory, BlogListOut, BlogPostCard, PlansOut } from '../../lib/types';
import { EMAIL_RE, ErrorSummary } from '../form';
import { rv, Spinner } from '../motion';
import { Container, FinalCta, Heading, Section } from '../parts';
import { ROUTES, useApi } from '../site';

export const postHref = (slug: string) => `${ROUTES.blog}/${slug}`;
/** Date only: noon so no time zone moves it to the day before. */
export const postDate = (d: string, lang: Lang) => day(`${d}T12:00:00`, lang);

export function CategoryPill({ t, c }: { t: T; c: BlogCategory }) {
  return <span className="rounded-full bg-sage-100 px-[10px] py-[2px] text-latin-caption-strong text-sage-700">{t(`site.blog.cat.${c}`)}</span>;
}

/** "In English" when the post isn't written in the visitor's language yet. */
function LangNote({ t, post, lang }: { t: T; post: BlogPostCard; lang: Lang }) {
  if (post.language === lang) return null;
  return <span className="rounded-full bg-cream-200 px-[10px] py-[2px] text-latin-caption-strong text-mocha-700">{t('site.blog.in_lang', { lang: t(`lang.${post.language}`) })}</span>;
}

export function PostCard({ t, lang, post, i }: { t: T; lang: Lang; post: BlogPostCard; i: number }) {
  return (
    <div {...rv('up', i % 3)}>
      <a href={postHref(post.slug)} className="kn-lift group flex h-full flex-col overflow-hidden rounded-xl border border-border-default bg-bg-surface">
        <div className="overflow-hidden">
          <img src={post.cover} alt="" width={382} height={216} loading="lazy" className="kn-zoom aspect-[382/216] w-full object-cover" />
        </div>
        <div className="flex flex-1 flex-col gap-12 p-24">
          <div className="flex flex-wrap gap-8">
            <CategoryPill t={t} c={post.category} />
            <LangNote t={t} post={post} lang={lang} />
          </div>
          <h3 className="text-latin-h3 md:text-web-h3">{post.title}</h3>
          <p className="text-latin-caption text-text-secondary">
            {t('site.blog.minutes', { n: post.read_minutes })} · {postDate(post.published_on, lang)}
          </p>
          <span className="mt-auto inline-flex items-center gap-4 pt-4 text-latin-label-sm font-semibold text-text-primary">
            <span className="kn-link">{t('site.blog.read_more')}</span>
            <ChevronRight width={14} height={14} className="kn-nudge" aria-hidden />
          </span>
        </div>
      </a>
    </div>
  );
}

function Featured({ t, lang, post }: { t: T; lang: Lang; post: BlogPostCard }) {
  return (
    <div {...rv('up', 2)} className="mt-40 md:mt-48">
      <a href={postHref(post.slug)} className="kn-lift group grid overflow-hidden rounded-xl border border-border-default bg-bg-surface md:grid-cols-[400px_1fr] lg:grid-cols-[640px_1fr]">
        <div className="overflow-hidden">
          <img src={post.cover} alt="" width={640} height={400} fetchPriority="high" className="kn-zoom aspect-[16/10] h-full w-full object-cover md:aspect-auto" />
        </div>
        <div className="flex flex-col justify-center gap-16 p-24 md:p-48">
          <div className="flex flex-wrap gap-8">
            <span className="rounded-full bg-status-success-bg px-[10px] py-[2px] text-latin-caption-strong text-status-success">{t('site.blog.featured')}</span>
            <CategoryPill t={t} c={post.category} />
            <LangNote t={t} post={post} lang={lang} />
          </div>
          <h2 className="text-web-m-h2 md:text-web-h2">{post.title}</h2>
          <p className="text-latin-body text-text-secondary">{post.summary}</p>
          <p className="text-latin-caption text-text-secondary">
            {t('site.blog.team')} · {postDate(post.published_on, lang)} · {t('site.blog.minutes', { n: post.read_minutes })}
          </p>
          <span className="inline-flex items-center gap-4 text-latin-label-sm font-semibold text-text-primary">
            <span className="kn-link">{t('site.blog.read')}</span>
            <ChevronRight width={14} height={14} className="kn-nudge" aria-hidden />
          </span>
        </div>
      </a>
    </div>
  );
}

/** POST /public/newsletter: one email, stored once. */
export function Newsletter({ t, lang }: { t: T; lang: Lang }) {
  const [email, setEmail] = useState('');
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);
  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!EMAIL_RE.test(email.trim())) return setError(t('site.login.err_email'));
    setError(null);
    setBusy(true);
    try {
      await api('/public/newsletter', { method: 'POST', body: { email: email.trim(), lang } });
      setDone(true);
    } catch (err) {
      setError(err instanceof ApiError && err.status === 429 ? t('site.err.wait') : err instanceof ApiError && err.status === 0 ? t('site.err.offline') : t('site.err.generic'));
    } finally {
      setBusy(false);
    }
  }
  return (
    <Section tone="surface" id="newsletter">
      <Container>
        <Heading eyebrow={t('site.blog.news_eyebrow')} title={t('site.blog.news_title')} body={t('site.blog.news_body')} />
        <div {...rv('up', 2)} className="mx-auto mt-32 max-w-[480px]">
          {done ? (
            <p role="status" className="kn-pop flex items-center justify-center gap-8 rounded-lg bg-status-success-bg px-16 py-16 text-latin-body font-semibold text-status-success">
              <Check width={18} height={18} aria-hidden />
              {t('site.blog.news_done')}
            </p>
          ) : (
            <form noValidate onSubmit={(e) => void submit(e)} className="flex flex-col gap-12">
              {error && <ErrorSummary>{error}</ErrorSummary>}
              <label htmlFor="news-email" className="text-latin-label-sm font-semibold">
                {t('site.trial.email')}
              </label>
              <div className="flex flex-col gap-12 sm:flex-row">
                <input
                  id="news-email"
                  type="email"
                  autoComplete="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="name@company.com"
                  aria-invalid={!!error || undefined}
                  className={cx(
                    'h-[52px] flex-1 rounded-lg border bg-bg-surface px-12 text-latin-body placeholder:text-taupe-500 focus:outline-none focus:ring-2 focus:ring-focus-ring',
                    error ? 'border-[1.5px] border-status-danger' : 'border-border-strong hover:border-mocha-500',
                  )}
                />
                <button
                  type="submit"
                  disabled={busy}
                  className="kn-btn inline-flex h-[52px] items-center justify-center gap-8 rounded-lg bg-action-primary px-24 text-latin-label font-semibold text-text-on-action hover:bg-action-primary-pressed disabled:opacity-60"
                >
                  {busy ? <Spinner /> : <Mail width={18} height={18} aria-hidden />}
                  {t('site.blog.subscribe')}
                </button>
              </div>
            </form>
          )}
          <p className="mt-16 text-center text-latin-caption text-text-secondary">
            {t('site.blog.news_note')}{' '}
            <a href={ROUTES.privacy} className="font-semibold text-text-primary underline">
              {t('site.foot.privacy')}
            </a>
          </p>
        </div>
      </Container>
    </Section>
  );
}

/** W25 Blog list: featured guide, category filter and the rest, all from GET /public/blog. */
export default function Blog({ t, lang, plans }: { t: T; lang: Lang; plans: PlansOut | null }) {
  const [cat, setCat] = useState<BlogCategory | null>(null);
  const [all] = useApi<BlogListOut>(`/public/blog?locale=${lang}`);
  const [data, retry] = useApi<BlogListOut>(`/public/blog?locale=${lang}${cat ? `&category=${cat}` : ''}`);
  const categories = all.kind === 'ready' ? all.data.categories : [];
  const list = data.kind === 'ready' ? data.data : null;
  return (
    <>
      <Section>
        <Container>
          <Heading eyebrow={t('site.blog.eyebrow')} title={t('site.blog.title')} body={t('site.blog.body')} />
          {categories.length > 1 && (
            <div {...rv('up', 2)} role="group" aria-label={t('site.blog.filter')} className="mt-32 flex flex-wrap justify-center gap-8">
              {[null, ...categories].map((c) => (
                <button
                  key={c ?? 'all'}
                  type="button"
                  aria-pressed={cat === c}
                  onClick={() => setCat(c)}
                  className={cx(
                    'kn-btn h-[36px] rounded-full border px-16 text-latin-label-sm font-semibold transition-colors',
                    cat === c ? 'border-espresso-950 bg-espresso-950 text-cream-50' : 'border-border-default bg-bg-surface text-text-primary hover:border-mocha-500',
                  )}
                >
                  {c ? t(`site.blog.cat.${c}`) : t('site.blog.all')}
                </button>
              ))}
            </div>
          )}
          {data.kind === 'loading' && !list ? (
            <div className="mt-40 grid gap-24 md:grid-cols-3" aria-busy="true">
              {[0, 1, 2].map((i) => (
                <div key={i} className="kn-shimmer h-[360px] rounded-xl bg-bg-surface" />
              ))}
            </div>
          ) : data.kind === 'error' ? (
            <p className="mt-40 text-center text-latin-body text-text-secondary">
              {t('site.err.generic')}{' '}
              <button type="button" onClick={retry} className="font-semibold text-text-primary underline">
                {t('site.indp.retry')}
              </button>
            </p>
          ) : list ? (
            <>
              {list.featured && <Featured t={t} lang={lang} post={list.featured} />}
              {list.items.length > 0 ? (
                <>
                  {list.featured && (
                    <div className="mt-64 flex flex-col gap-8">
                      <p {...rv('fade')} className="text-web-eyebrow uppercase text-mocha-700">
                        {t('site.blog.latest')}
                      </p>
                      <h2 {...rv('up')} className="text-web-m-h2 md:text-web-h2">
                        {t('site.blog.more')}
                      </h2>
                    </div>
                  )}
                  <div className={cx('grid gap-24 md:grid-cols-2 lg:grid-cols-3', list.featured ? 'mt-32' : 'mt-40')}>
                    {list.items.map((p, i) => (
                      <PostCard key={p.slug} t={t} lang={lang} post={p} i={i} />
                    ))}
                  </div>
                </>
              ) : (
                !list.featured && <p className="mt-40 text-center text-latin-body text-text-secondary">{t('site.blog.empty')}</p>
              )}
            </>
          ) : null}
        </Container>
      </Section>
      <Newsletter t={t} lang={lang} />
      <FinalCta t={t} trialDays={plans?.trial_days ?? null} title={t('site.blog.cta')} />
    </>
  );
}
