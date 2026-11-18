import { Bot, Check, Clock, Phone, Star } from 'lucide-react';

import { cx } from '../../components/ui';
import type { Lang, T } from '../../lib/i18n';
import type { ConfigOut, PlansOut } from '../../lib/types';
import { rv } from '../motion';
import { Container, Faq, FinalCta, Heading, Section } from '../parts';
import { REVIEW_ICONS } from './catalog';
import { Capabilities, facts, faqItems, FeatureHero, Related } from './FeaturePage';

const k = (t: T, s: string, p?: Record<string, string | number>) => t(`site.fp.reviews.${s}`, p);

/**
 * W31 Reviews & follow-ups. The rating link (Day 0), the Day 2 reminder, low-rating alerts and replies work today;
 * the Day 5 AI call is planned but no call is placed until a voice provider is chosen (D-88), so it says "Coming soon".
 */
export default function Reviews({ t, lang, plans, config }: { t: T; lang: Lang; plans: PlansOut | null; config: ConfigOut | null }) {
  const f = facts(plans, config, lang);
  const name = k(t, 'name');
  const days = [0, 2, 5];
  const lines = [1, 2, 3, 4, 5];
  const talk = [1, 2, 3, 4, 5];
  return (
    <>
      <FeatureHero
        t={t}
        crumb={name}
        pill={name}
        pillIcon={<Star width={16} height={16} aria-hidden />}
        title={k(t, 'title')}
        body={k(t, 'body')}
        ticks={[t('site.fp.every_plan'), k(t, 'tick1'), k(t, 'tick2')]}
      >
        <div {...rv('zoom', 1)} className="group relative mx-auto w-full max-w-[537px] lg:mx-0 lg:mt-24 lg:w-[537px] lg:shrink-0">
          <div className="overflow-hidden rounded-xl shadow-[0_16px_40px_rgba(0,0,0,0.35)]">
            <img src="/img/feat-reviews-a.webp" alt={k(t, 'alt')} width={537} height={580} fetchPriority="high" className="kn-zoom w-full" />
          </div>
        </div>
      </FeatureHero>

      <Section id="how-it-works">
        <Container>
          <Heading eyebrow={t('site.fp.how')} title={k(t, 'how_title')} />
          <ol className="mt-40 grid gap-24 md:mt-48 lg:grid-cols-3">
            {days.map((d, i) => {
              const Icon = REVIEW_ICONS.steps[i];
              const soon = i === 2;
              return (
                <li key={d} {...rv('up', i, 120)}>
                  <div className="kn-lift group flex h-full flex-col gap-16 rounded-xl border border-border-default bg-bg-surface p-24">
                    <div className="flex flex-wrap items-center gap-8">
                      <span className="inline-flex h-[40px] w-[40px] items-center justify-center rounded-lg bg-mocha-900 text-cream-50 transition-transform duration-300 group-hover:rotate-[-8deg]">
                        <Icon width={18} height={18} aria-hidden />
                      </span>
                      <span className="rounded-full bg-cream-200 px-[10px] py-4 text-latin-caption-strong text-mocha-700">{k(t, 'day', { n: d })}</span>
                      {soon && <span className="rounded-full bg-sage-100 px-[10px] py-4 text-latin-caption-strong text-sage-700">{t('site.fp.soon')}</span>}
                    </div>
                    <h3 className="text-latin-h3 md:text-web-h3">{k(t, `s${i + 1}`)}</h3>
                    <p className="text-latin-body text-text-secondary">{k(t, `s${i + 1}_b`)}</p>
                  </div>
                </li>
              );
            })}
          </ol>
          <p {...rv('up', 3)} className="mt-24 flex items-start gap-8 rounded-lg bg-status-success-bg px-16 py-12 text-latin-body text-status-success">
            <Check width={18} height={18} className="mt-[3px] shrink-0" aria-hidden />
            {k(t, 'note')}
          </p>
        </Container>
      </Section>

      <Capabilities
        eyebrow={t('site.fp.caps')}
        title={k(t, 'cap_title')}
        items={REVIEW_ICONS.caps.map((C, i) => ({
          icon: <C width={20} height={20} aria-hidden />,
          title: k(t, `c${i + 1}`),
          body: k(t, `c${i + 1}_b`),
          tag: i === 2 ? t('site.fp.soon') : undefined,
          soon: i === 2,
        }))}
      />

      <section className="bg-espresso-900 py-64 md:py-[96px] xl:py-[112px]">
        <Container className="flex flex-col gap-40 lg:flex-row lg:items-center lg:justify-between">
          <div className="flex flex-col gap-24 lg:w-[540px]">
            <div className="flex flex-wrap items-center gap-8">
              <p {...rv('fade')} className="text-web-eyebrow uppercase text-cream-400">
                {k(t, 'call_eyebrow')}
              </p>
              <span {...rv('zoom', 1)} className="rounded-full bg-cream-100/[0.12] px-[10px] py-4 text-latin-caption-strong text-cream-100">
                {t('site.fp.soon')}
              </span>
            </div>
            <h2 {...rv('up', 1)} className="text-web-m-h2 text-cream-50 md:text-web-h2">
              {k(t, 'call_title')}
            </h2>
            <p {...rv('up', 2)} className="text-latin-body-lg text-cream-400">
              {k(t, 'call_body')}
            </p>
            <ul className="flex flex-col gap-12">
              {lines.map((n, i) => (
                <li key={n} {...rv('left', i + 3, 70)} className="flex items-start gap-12 text-latin-body text-cream-200">
                  <Check width={18} height={18} className="mt-[3px] shrink-0 text-sage-300" aria-hidden />
                  {k(t, `call_l${n}`)}
                </li>
              ))}
            </ul>
          </div>
          <div {...rv('right', 1)} className="w-full lg:w-[460px]">
            <div className="flex flex-col gap-12 rounded-xl bg-mocha-700/60 p-16 transition-transform duration-500 hover:-translate-y-4 md:p-24" role="img" aria-label={k(t, 'call_alt')}>
              <p className="flex items-center gap-8 text-latin-caption-strong text-cream-200">
                <Phone width={16} height={16} aria-hidden />
                {k(t, 'call_head')}
              </p>
              {talk.map((n, i) => {
                const ai = n % 2 === 1;
                return (
                  <div
                    key={n}
                    {...rv(ai ? 'left' : 'right', i + 2, 160)}
                    className={cx('max-w-[90%] rounded-lg px-12 py-[10px]', ai ? 'bg-espresso-900 text-cream-50' : 'ml-auto bg-cream-100/[0.16] text-cream-50')}
                  >
                    <p className="mb-4 flex items-center gap-4 text-latin-caption text-cream-400">
                      {ai && <Bot width={12} height={12} aria-hidden />}
                      {ai ? k(t, 'call_ai') : k(t, 'call_customer')}
                    </p>
                    <p className="text-latin-body">{k(t, `call_m${n}`)}</p>
                  </div>
                );
              })}
              <span {...rv('zoom', 8, 120)} className="inline-flex w-fit items-center gap-[6px] rounded-full bg-status-success-bg px-12 py-[6px] text-latin-caption-strong text-status-success">
                <Clock width={14} height={14} aria-hidden />
                {k(t, 'call_saved')}
              </span>
            </div>
          </div>
        </Container>
      </section>

      <Related t={t} ids={['sharing', 'reports', 'jobs']} />
      <Faq t={t} title={k(t, 'faq_title')} body={t('site.faq.body')} items={faqItems(t, 'site.fp.reviews', 4, f)} />
      <FinalCta t={t} trialDays={plans?.trial_days ?? null} title={k(t, 'cta')} />
    </>
  );
}
