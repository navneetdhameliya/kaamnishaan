import { Check, ChevronLeft, ChevronRight, Link2, Mail, MessageCircle } from 'lucide-react';
import { useEffect, useState } from 'react';

import { api, ApiError } from '../../lib/api';
import type { Lang, T } from '../../lib/i18n';
import type { BlogBlock, BlogPostOut, PlansOut } from '../../lib/types';
import { LinkButton } from '../Layout';
import { rv } from '../motion';
import { Container, Section } from '../parts';
import { ROUTES } from '../site';
import { CategoryPill, Newsletter, PostCard, postDate } from './Blog';

type State = { kind: 'loading' } | { kind: 'ready'; post: BlogPostOut } | { kind: 'missing' } | { kind: 'error' };

function Block({ b, i }: { b: BlogBlock; i: number }) {
  const reveal = rv('up', Math.min(i, 3), 60);
  switch (b.type) {
    case 'h2':
      return (
        <h2 {...reveal} className="mt-16 text-latin-h3 md:text-web-h3">
          {b.text}
        </h2>
      );
    case 'quote':
      return (
        <figure {...reveal} className="border-l-4 border-sage-500 py-4 pl-20">
          <blockquote className="text-[20px] font-semibold leading-[30px] text-text-primary">“{b.text}”</blockquote>
          {b.by && <figcaption className="mt-8 text-latin-caption text-text-secondary">{b.by}</figcaption>}
        </figure>
      );
    case 'list':
      return (
        <div {...reveal} className="rounded-xl border border-border-default bg-bg-surface p-24">
          {b.title && <p className="text-latin-label font-semibold">{b.title}</p>}
          <ul className="mt-12 flex flex-col gap-8">
            {b.items.map((x) => (
              <li key={x} className="flex items-start gap-12 text-latin-body">
                <span className="mt-[3px] inline-flex h-[20px] w-[20px] shrink-0 items-center justify-center rounded-full bg-status-success-bg text-status-success">
                  <Check width={12} height={12} aria-hidden />
                </span>
                {x}
              </li>
            ))}
          </ul>
        </div>
      );
    case 'image':
      return b.src ? (
        <figure {...reveal}>
          <div className="group overflow-hidden rounded-xl">
            <img src={b.src} alt={b.caption ?? ''} loading="lazy" className="kn-zoom aspect-[16/9] w-full object-cover" />
          </div>
          {b.caption && <figcaption className="mt-8 text-latin-caption text-text-secondary">{b.caption}</figcaption>}
        </figure>
      ) : null;
    default:
      return (
        <p {...reveal} className="text-latin-body-lg text-text-secondary">
          {b.text}
        </p>
      );
  }
}

function Share({ t, post }: { t: T; post: BlogPostOut }) {
  const [copied, setCopied] = useState(false);
  const url = window.location.href;
  const text = `${post.title} ${url}`;
  const chip = 'kn-btn inline-flex h-[36px] items-center gap-[6px] rounded-full border border-border-default bg-bg-surface px-12 text-latin-label-sm font-semibold hover:border-mocha-500';
  return (
    <div className="flex flex-wrap items-center gap-8">
      <span className="mr-4 text-latin-label-sm font-semibold">{t('site.blog.share')}</span>
      <button
        type="button"
        className={chip}
        onClick={() => {
          void navigator.clipboard?.writeText(url).then(() => {
            setCopied(true);
            window.setTimeout(() => setCopied(false), 2000);
          });
        }}
      >
        {copied ? <Check width={14} height={14} aria-hidden /> : <Link2 width={14} height={14} aria-hidden />}
        <span aria-live="polite">{copied ? t('site.blog.copied') : t('site.blog.copy')}</span>
      </button>
      <a className={chip} href={`https://wa.me/?text=${encodeURIComponent(text)}`} target="_blank" rel="noreferrer">
        <MessageCircle width={14} height={14} aria-hidden />
        WhatsApp
      </a>
      <a className={chip} href={`mailto:?subject=${encodeURIComponent(post.title)}&body=${encodeURIComponent(url)}`}>
        <Mail width={14} height={14} aria-hidden />
        {t('site.blog.email')}
      </a>
    </div>
  );
}

/** W26 Blog article from GET /public/blog/{slug}. */
export default function BlogPost({ t, lang, slug, plans }: { t: T; lang: Lang; slug: string; plans: PlansOut | null }) {
  const [state, setState] = useState<State>({ kind: 'loading' });
  const [tick, setTick] = useState(0);
  useEffect(() => {
    let live = true;
    api<BlogPostOut>(`/public/blog/${encodeURIComponent(slug)}?locale=${lang}`)
      .then((post) => {
        if (!live) return;
        setState({ kind: 'ready', post });
        document.title = `${post.title} · KaamNishaan`;
      })
      .catch((e) => live && setState(e instanceof ApiError && e.status === 404 ? { kind: 'missing' } : { kind: 'error' }));
    return () => {
      live = false;
    };
  }, [slug, lang, tick]);

  if (state.kind !== 'ready') {
    return (
      <Section>
        <Container className="flex min-h-[40vh] flex-col items-center justify-center gap-16 text-center">
          {state.kind === 'loading' ? (
            <div className="kn-shimmer h-[320px] w-full max-w-[760px] rounded-xl bg-bg-surface" aria-busy="true" />
          ) : (
            <>
              <h1 className="text-web-m-h2 md:text-web-h2">{state.kind === 'missing' ? t('site.blog.missing') : t('site.err.generic')}</h1>
              {state.kind === 'error' ? (
                <button type="button" onClick={() => setTick((n) => n + 1)} className="font-semibold underline">
                  {t('site.indp.retry')}
                </button>
              ) : (
                <LinkButton href={ROUTES.blog} variant="primary">
                  {t('site.blog.all_posts')}
                </LinkButton>
              )}
            </>
          )}
        </Container>
      </Section>
    );
  }

  const { post } = state;
  const trial = plans?.trial_days;
  return (
    <>
      <article className="bg-bg-canvas pb-64 pt-32 md:pb-[96px] md:pt-48">
        <Container>
          <nav aria-label={t('site.fp.crumb_label')} {...rv('fade')} className="mx-auto mb-32 flex max-w-[760px] items-center gap-8 text-latin-label-sm font-semibold text-text-secondary">
            <a href={ROUTES.blog} className="kn-link inline-flex items-center gap-4 hover:text-text-primary">
              <ChevronLeft width={14} height={14} aria-hidden />
              {t('site.blog.eyebrow')}
            </a>
            <ChevronRight width={14} height={14} aria-hidden />
            <span aria-current="page" className="text-text-primary">
              {t(`site.blog.cat.${post.category}`)}
            </span>
          </nav>
          <header className="mx-auto flex max-w-[760px] flex-col gap-16">
            <div {...rv('up', 0)} className="flex flex-wrap gap-8">
              <CategoryPill t={t} c={post.category} />
              {post.language !== lang && (
                <span className="rounded-full bg-cream-200 px-[10px] py-[2px] text-latin-caption-strong text-mocha-700">{t('site.blog.in_lang', { lang: t(`lang.${post.language}`) })}</span>
              )}
            </div>
            <h1 {...rv('up', 1)} className="text-[34px] font-bold leading-[42px] tracking-[-0.01em] md:text-web-display">
              {post.title}
            </h1>
            <div {...rv('up', 2)} className="flex items-center gap-12">
              <img src="/brand-mark-dark.svg" alt="" width={36} height={36} className="h-[36px] w-[36px] rounded-md" />
              <div className="flex flex-col">
                <span className="text-latin-label-sm font-semibold">{post.author}</span>
                <span className="text-latin-caption text-text-secondary">
                  {postDate(post.published_on, lang)} · {t('site.blog.minutes', { n: post.read_minutes })}
                </span>
              </div>
            </div>
          </header>
          <div {...rv('zoom', 2)} className="group mx-auto mt-40 max-w-[1000px] overflow-hidden rounded-xl">
            <img src={post.cover} alt="" width={1000} height={460} fetchPriority="high" className="kn-zoom aspect-[1000/460] w-full object-cover" />
          </div>
          <div className="mx-auto mt-40 flex max-w-[760px] flex-col gap-20">
            <p {...rv('up')} className="text-[20px] leading-[32px] text-text-primary">
              {post.summary}
            </p>
            {post.blocks.map((b, i) => (
              <Block key={i} b={b} i={i} />
            ))}
            <div className="mt-16 border-t border-border-default pt-24">
              <Share t={t} post={post} />
            </div>
            <div {...rv('zoom')} className="relative mt-16 overflow-hidden rounded-xl bg-espresso-950 p-32">
              <div aria-hidden className="pointer-events-none absolute -right-[80px] -top-[80px] h-[240px] w-[240px] animate-[spin_60s_linear_infinite] rounded-full border-[32px] border-mocha-950 border-l-transparent" />
              <div className="relative flex flex-col gap-12">
                <h2 className="text-latin-h3 text-cream-50 md:text-web-h3">{t('site.blog.box_title')}</h2>
                {trial != null && <p className="text-latin-body text-cream-400">{t('site.final.body', { n: trial })}</p>}
                <div className="mt-8">
                  <LinkButton href={ROUTES.trial} variant="light">
                    {t('site.cta.trial')}
                  </LinkButton>
                </div>
              </div>
            </div>
          </div>
        </Container>
      </article>
      {post.related.length > 0 && (
        <Section tone="surface">
          <Container>
            <div className="flex flex-wrap items-end justify-between gap-16">
              <div className="flex flex-col gap-8">
                <p {...rv('fade')} className="text-web-eyebrow uppercase text-mocha-700">
                  {t('site.blog.keep')}
                </p>
                <h2 {...rv('up')} className="text-web-m-h2 md:text-web-h2">
                  {t('site.blog.related')}
                </h2>
              </div>
              <a {...rv('left', 1)} href={ROUTES.blog} className="group inline-flex items-center gap-4 text-web-label font-semibold">
                <span className="kn-link">{t('site.blog.all_posts')}</span>
                <ChevronRight width={16} height={16} className="kn-nudge" aria-hidden />
              </a>
            </div>
            <div className="mt-32 grid gap-24 md:grid-cols-3">
              {post.related.map((p, i) => (
                <PostCard key={p.slug} t={t} lang={lang} post={p} i={i} />
              ))}
            </div>
          </Container>
        </Section>
      )}
      <Newsletter t={t} lang={lang} />
    </>
  );
}
