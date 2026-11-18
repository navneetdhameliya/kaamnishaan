import { Check, ChevronDown, ChevronRight, Play } from 'lucide-react';
import { useState, type ReactNode } from 'react';

import { cx } from '../components/ui';
import type { T } from '../lib/i18n';
import { LinkButton } from './Layout';
import { rv } from './motion';
import { ROUTES } from './site';

/** Max 1200 wide, 120 side margins on desktop like the Figma frames. */
export function Container({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cx('mx-auto w-full max-w-[1200px] px-16 md:px-32 xl:px-0', className)}>{children}</div>;
}

export function Section({
  id,
  tone = 'canvas',
  children,
  className,
}: {
  id?: string;
  tone?: 'canvas' | 'surface' | 'dark';
  children: ReactNode;
  className?: string;
}) {
  return (
    <section
      id={id}
      className={cx(
        'scroll-mt-[96px] py-64 md:py-[96px] xl:py-[112px]',
        tone === 'canvas' && 'bg-bg-canvas',
        tone === 'surface' && 'border-y border-border-default bg-bg-surface',
        tone === 'dark' && 'bg-espresso-950',
        className,
      )}
    >
      {children}
    </section>
  );
}

export function Heading({
  title,
  body,
  eyebrow,
  dark,
  align = 'center',
  className,
}: {
  title: string;
  body?: string;
  eyebrow?: string;
  dark?: boolean;
  align?: 'center' | 'left';
  className?: string;
}) {
  return (
    <div className={cx('flex flex-col gap-16', align === 'center' ? 'mx-auto max-w-[760px] text-center' : 'max-w-[480px]', className)}>
      {eyebrow && (
        <p {...rv('fade')} className={cx('-mb-4 text-web-eyebrow uppercase', dark ? 'text-cream-400' : 'text-mocha-700')}>
          {eyebrow}
        </p>
      )}
      <h2 {...rv('up')} className={cx('text-web-m-h2 md:text-web-h2', dark ? 'text-cream-50' : 'text-text-primary')}>
        {title}
      </h2>
      {body && (
        <p {...rv('up', 1)} className={cx('text-latin-body-lg md:text-web-body-lg', dark ? 'text-cream-400' : 'text-text-secondary')}>
          {body}
        </p>
      )}
    </div>
  );
}

/** Questions on the left, answers that open on the right (W01 FAQ, W02 Pricing questions). */
export function Faq({ t, title, body, items }: { t: T; title: string; body: string; items: { q: string; a: string }[] }) {
  const [open, setOpen] = useState(0);
  return (
    <Section id="faq">
      <Container className="flex flex-col gap-32 lg:flex-row lg:gap-[96px]">
        <div {...rv('left')} className="flex flex-col items-start gap-16 lg:w-[384px] lg:shrink-0">
          <h2 className="text-web-m-h2 md:text-web-h2">{title}</h2>
          <p className="text-latin-body-lg text-text-secondary">{body}</p>
          <a href={ROUTES.contact} className="group inline-flex items-center gap-4 text-web-label font-semibold text-text-primary">
            <span className="kn-link">{t('site.faq.talk')}</span>
            <ChevronRight width={16} height={16} className="kn-nudge" aria-hidden />
          </a>
        </div>
        <div className="flex flex-1 flex-col">
          {items.map((it, i) => {
            const isOpen = open === i;
            return (
              <div
                key={it.q}
                {...rv('up', i)}
                className={cx(
                  'border-b border-border-default transition-[background-color,border-radius,box-shadow] duration-300',
                  isOpen ? 'rounded-lg border border-border-default bg-bg-surface shadow-sm' : 'hover:bg-bg-surface/60',
                )}
              >
                <button
                  type="button"
                  aria-expanded={isOpen}
                  onClick={() => setOpen(isOpen ? -1 : i)}
                  className="flex w-full items-center justify-between gap-16 px-[24px] py-[24px] text-left"
                >
                  <span className="text-latin-h3 md:text-web-h3">{it.q}</span>
                  <ChevronDown width={20} height={20} className={cx('shrink-0 transition-transform duration-300', isOpen && 'rotate-180')} aria-hidden />
                </button>
                <div
                  className={cx(
                    'grid transition-[grid-template-rows,opacity] duration-500 ease-[cubic-bezier(.22,1,.36,1)]',
                    isOpen ? 'grid-rows-[1fr] opacity-100' : 'grid-rows-[0fr] opacity-0',
                  )}
                >
                  <p className="-mt-8 overflow-hidden px-[24px] text-latin-body text-text-secondary md:text-web-body" aria-hidden={!isOpen}>
                    <span className="block pb-[24px]">{it.a}</span>
                  </p>
                </div>
              </div>
            );
          })}
        </div>
      </Container>
    </Section>
  );
}

/** "Start proving your work today" with the manager's phone (W01, W02). */
export function FinalCta({
  t,
  trialDays,
  title,
  body,
  primary,
  spaced,
}: {
  t: T;
  /** Add space above when the section before is dark too. */
  spaced?: boolean;
  trialDays: number | null;
  title?: string;
  body?: string;
  primary?: { href: string; label: string };
}) {
  return (
    <section className={cx('bg-bg-canvas pb-64 md:pb-[112px]', spaced && 'pt-64 md:pt-[112px]')}>
      <Container>
        <div {...rv('zoom')} className="relative overflow-hidden rounded-xl bg-espresso-950 px-24 pt-48 md:px-[80px] md:pt-[88px] lg:min-h-[440px]">
          <div
            aria-hidden
            className="pointer-events-none absolute -right-[120px] -top-[100px] h-[560px] w-[560px] animate-[spin_60s_linear_infinite] rounded-full border-[56px] border-mocha-950 border-l-transparent"
          />
          <div className="relative flex flex-col gap-40 lg:flex-row lg:items-start lg:justify-between">
            <div className="flex max-w-[640px] flex-col gap-24 pb-48 lg:pb-[88px]">
              <h2 {...rv('up', 1)} className="text-web-m-display text-cream-50 md:text-web-display">
                {title ?? t('site.final.title')}
              </h2>
              {(body || trialDays != null) && (
                <p {...rv('up', 2)} className="text-latin-body-lg text-cream-400 md:text-web-body-lg">
                  {body ?? t('site.final.body', { n: trialDays ?? '' })}
                </p>
              )}
              <div {...rv('up', 3)} className="flex flex-wrap gap-16">
                <LinkButton href={primary?.href ?? ROUTES.trial} variant="light">
                  {primary?.label ?? t('site.cta.trial')}
                </LinkButton>
                <LinkButton href={ROUTES.demo} variant="outline-light" icon={<Play width={20} height={20} aria-hidden />}>
                  {t('site.cta.demo')}
                </LinkButton>
              </div>
            </div>
            <img
              src="/img/cta-phone.webp"
              alt={t('site.final.alt')}
              width={258}
              height={368}
              loading="lazy"
              className="mx-auto w-[220px] self-end transition-transform duration-700 hover:-translate-y-8 lg:mx-0 lg:mr-[40px] lg:w-[258px]"
            />
          </div>
        </div>
      </Container>
    </section>
  );
}

export function Tick({ children, light }: { children: ReactNode; light?: boolean }) {
  return (
    <span className={cx('inline-flex items-center gap-8 text-latin-label-sm font-semibold', light ? 'text-cream-400' : 'text-text-secondary')}>
      <Check width={16} height={16} className={light ? 'text-cream-400' : 'text-status-success'} aria-hidden />
      {children}
    </span>
  );
}
