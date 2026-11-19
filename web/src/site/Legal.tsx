import { ChevronUp, Clock, FileText, Lock, Mail, Printer, TriangleAlert } from 'lucide-react';
import { useEffect, useState } from 'react';

import { cx } from '../components/ui';
import { day, type Lang, type T } from '../lib/i18n';
import type { LegalOut } from '../lib/types';
import { rv } from './motion';
import { Container } from './parts';
import { ROUTES, useApi } from './site';

/** Which section is on screen, for the "On this page" list. */
function useActive(ids: string[]) {
  const [active, setActive] = useState(ids[0] ?? '');
  useEffect(() => {
    if (!ids.length || typeof IntersectionObserver === 'undefined') return;
    const seen = new Map<string, boolean>();
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => seen.set(e.target.id, e.isIntersecting));
        const first = ids.find((id) => seen.get(id));
        if (first) setActive(first);
      },
      { rootMargin: '-96px 0px -60% 0px' },
    );
    ids.forEach((id) => {
      const el = document.getElementById(id);
      if (el) io.observe(el);
    });
    return () => io.disconnect();
  }, [ids.join('|')]); // eslint-disable-line react-hooks/exhaustive-deps
  return active;
}

/** W06 Privacy policy and W07 Terms, from GET /public/legal/{doc}. Company details come from the server's settings. */
export default function Legal({ t, lang, doc }: { t: T; lang: Lang; doc: 'privacy' | 'terms' }) {
  const [data, retry] = useApi<LegalOut>(`/public/legal/${doc}?locale=${lang}`);
  const d = data.kind === 'ready' ? data.data : null;
  const ids = d ? d.sections.map((s) => s.id) : [];
  const active = useActive(ids);

  useEffect(() => {
    if (d) document.title = `${d.title} · KaamNishaan`;
  }, [d]);

  return (
    <>
      <section className="border-b border-border-default bg-bg-surface py-40 md:py-48">
        <Container className="flex flex-col items-start gap-16">
          <span {...rv('up', 0)} className="inline-flex items-center gap-[6px] rounded-full bg-cream-200 px-12 py-[6px] text-web-eyebrow uppercase text-mocha-700">
            <Lock width={14} height={14} aria-hidden />
            {t('site.legal.eyebrow')}
          </span>
          <h1 {...rv('up', 1)} className="text-[34px] font-bold leading-[42px] md:text-web-display">
            {d?.title ?? t(doc === 'privacy' ? 'site.foot.privacy' : 'site.foot.terms')}
          </h1>
          {d && (
            <div {...rv('up', 2)} className="flex flex-wrap items-center gap-x-24 gap-y-8 text-latin-label-sm text-text-secondary">
              <span className="inline-flex items-center gap-[6px]">
                <Clock width={14} height={14} aria-hidden />
                {t('site.legal.updated', { date: day(`${d.updated_on}T12:00:00`, lang, { month: 'long' }) })}
              </span>
              <span className="inline-flex items-center gap-[6px]">
                <FileText width={14} height={14} aria-hidden />
                {t('site.legal.minutes', { n: d.read_minutes })}
              </span>
              <button type="button" onClick={() => window.print()} className="kn-link inline-flex items-center gap-[6px] font-semibold text-text-primary print:hidden">
                <Printer width={14} height={14} aria-hidden />
                {t('site.legal.print')}
              </button>
            </div>
          )}
        </Container>
      </section>

      <section className="bg-bg-canvas py-40 md:py-[64px]">
        <Container>
          {data.kind === 'loading' ? (
            <div className="kn-shimmer h-[480px] rounded-xl bg-bg-surface" aria-busy="true" />
          ) : data.kind === 'error' || !d ? (
            <p className="text-latin-body text-text-secondary">
              {t('site.err.generic')}{' '}
              <button type="button" onClick={retry} className="font-semibold text-text-primary underline">
                {t('site.indp.retry')}
              </button>
            </p>
          ) : (
            <div className="grid gap-40 lg:grid-cols-[240px_1fr] lg:gap-64">
              <nav aria-label={t('site.legal.toc')} className="hidden lg:block print:hidden">
                <div className="sticky top-[112px] flex flex-col gap-4">
                  <p className="mb-8 text-web-eyebrow uppercase text-text-secondary">{t('site.legal.toc')}</p>
                  {d.sections.map((s) => (
                    <a
                      key={s.id}
                      href={`#${s.id}`}
                      aria-current={active === s.id ? 'location' : undefined}
                      className={cx(
                        'border-l-2 py-[6px] pl-12 text-latin-label-sm transition-colors duration-200 hover:text-text-primary',
                        active === s.id ? 'border-espresso-950 font-semibold text-text-primary' : 'border-border-default text-text-secondary',
                      )}
                    >
                      {s.heading}
                    </a>
                  ))}
                  <button
                    type="button"
                    onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
                    className="kn-link mt-16 inline-flex w-fit items-center gap-4 text-latin-label-sm font-semibold text-mocha-700"
                  >
                    <ChevronUp width={14} height={14} aria-hidden />
                    {t('site.legal.top')}
                  </button>
                </div>
              </nav>
              <div className="flex max-w-[760px] flex-col gap-32">
                {!d.complete && (
                  <p role="note" className="flex items-start gap-12 rounded-lg bg-status-warning-bg p-16 text-latin-body text-status-warning">
                    <TriangleAlert width={18} height={18} className="mt-[3px] shrink-0" aria-hidden />
                    {t('site.legal.draft')}
                  </p>
                )}
                {lang !== 'en' && d.language === lang && (
                  <p role="note" className="rounded-lg bg-bg-surface p-16 text-latin-caption text-text-secondary">
                    {t('site.legal.translation')}
                  </p>
                )}
                <p {...rv('up')} className="text-latin-body-lg text-text-primary">
                  {d.intro}
                </p>
                {d.sections.map((s) => (
                  <section key={s.id} id={s.id} className="scroll-mt-[112px]" {...rv('up')}>
                    <h2 className="text-latin-h3 md:text-web-h3">{s.heading}</h2>
                    <div className="mt-12 flex flex-col gap-12">
                      {s.blocks.map((b, i) =>
                        b.type === 'list' ? (
                          <ul key={i} className="flex flex-col gap-8 pl-4">
                            {b.items.map((x) => (
                              <li key={x} className="flex items-start gap-12 text-latin-body text-text-primary">
                                <span aria-hidden className="mt-[10px] h-[6px] w-[6px] shrink-0 rounded-full bg-mocha-700" />
                                {x}
                              </li>
                            ))}
                          </ul>
                        ) : (
                          <p key={i} className="text-latin-body text-text-secondary">
                            {b.text}
                          </p>
                        ),
                      )}
                    </div>
                  </section>
                ))}
                <div {...rv('up')} className="kn-lift flex items-start gap-16 rounded-xl border border-border-default bg-bg-surface p-24 print:hidden">
                  <span className="inline-flex h-[40px] w-[40px] shrink-0 items-center justify-center rounded-full bg-sage-100 text-sage-700">
                    <Mail width={18} height={18} aria-hidden />
                  </span>
                  <div className="flex flex-col gap-4">
                    <p className="text-latin-label font-semibold">{t(doc === 'privacy' ? 'site.legal.q_privacy' : 'site.legal.q_terms')}</p>
                    <p className="text-latin-body text-text-secondary">
                      {t('site.legal.q_body')}{' '}
                      <a href={ROUTES.contact} className="font-semibold text-text-primary underline">
                        {t('site.foot.contact')}
                      </a>
                    </p>
                  </div>
                </div>
              </div>
            </div>
          )}
        </Container>
      </section>
    </>
  );
}
