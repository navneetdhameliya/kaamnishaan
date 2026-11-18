import { Briefcase, Camera, ChevronRight, CircleCheck, LayoutGrid, Languages, ListChecks, Mic, Sparkles, Upload } from 'lucide-react';
import { Fragment } from 'react';

import type { Lang, T } from '../../lib/i18n';
import type { ConfigOut, PlansOut } from '../../lib/types';
import { IconDot } from '../Home';
import { rv } from '../motion';
import { Container, Faq, FinalCta, Heading, Section } from '../parts';
import { FEATURES, featureHref } from './catalog';
import { facts, faqItems, FeatureHero, HeroVisual } from './FeaturePage';

const FLOW = [Briefcase, Camera, ListChecks, Mic, Sparkles, CircleCheck, Upload];

/** W08 Features overview: every feature in one grid, then how one job moves through them. */
export default function Overview({ t, lang, plans, config }: { t: T; lang: Lang; plans: PlansOut | null; config: ConfigOut | null }) {
  const f = facts(plans, config, lang);
  const count = FEATURES.length;
  const flow = FLOW;
  return (
    <>
      <FeatureHero
        t={t}
        crumb={t('site.fp.overview')}
        pill={t('site.fp.ov.pill')}
        pillIcon={<LayoutGrid width={16} height={16} aria-hidden />}
        title={t('site.fp.ov.title', { n: count })}
        body={t('site.fp.ov.body')}
        ticks={[t('site.fp.every_plan'), t('site.hero.offline'), ...(config ? [t('site.fp.ov.langs', { n: f.langs })] : [])]}
      >
        <HeroVisual
          id="overview"
          kind="phones"
          alt={t('site.fp.ov.alt')}
          chips={[
            { chip: { icon: Sparkles, tone: 'sage' }, title: t('site.fp.ov.chip1'), sub: t('site.fp.ov.chip1_sub') },
            { chip: { icon: Languages, tone: 'cream' }, title: t('site.fp.ov.chip2'), sub: t('site.fp.ov.chip2_sub') },
          ]}
        />
      </FeatureHero>

      <Section id="all-features">
        <Container>
          <Heading eyebrow={t('site.fp.ov.grid_eyebrow', { n: count })} title={t('site.fp.ov.grid_title')} align="left" className="max-w-[760px]" />
          <div className="mt-40 grid gap-24 sm:grid-cols-2 md:mt-48 lg:grid-cols-3">
            {FEATURES.map((ft, i) => {
              const Icon = ft.icon;
              const wide = ft.id === 'reviews';
              return (
                <div key={ft.id} {...rv('up', i % 3)} className={wide ? 'sm:col-span-2 lg:col-span-3' : undefined}>
                  <a
                    href={featureHref(ft.id)}
                    className={
                      'kn-lift group flex h-full overflow-hidden rounded-xl border border-border-default bg-bg-surface hover:border-mocha-300 ' +
                      (wide ? 'flex-col md:flex-row' : 'flex-col')
                    }
                  >
                    <div className={'relative overflow-hidden bg-bg-canvas ' + (wide ? 'h-[220px] md:h-auto md:w-[45%]' : 'h-[220px]')}>
                      <img
                        src={`/img/feat-${ft.id}-a.webp`}
                        alt=""
                        loading="lazy"
                        className={
                          wide
                            ? 'kn-zoom absolute inset-0 h-full w-full object-cover object-top'
                            : 'absolute left-1/2 -translate-x-1/2 drop-shadow-[0_12px_24px_rgba(59,41,33,0.18)] transition-transform duration-500 group-hover:-translate-y-8 ' +
                              (ft.id === 'sharing' ? 'top-32 w-[300px] rounded-md' : 'top-24 w-[200px]')
                        }
                      />
                    </div>
                    <div className="flex flex-1 flex-col gap-12 p-24 md:justify-center">
                      <div className="flex items-center gap-12">
                        <IconDot size={40}>
                          <Icon width={20} height={20} aria-hidden />
                        </IconDot>
                        <h3 className="text-latin-h3 md:text-web-h3">{t(`site.fp.${ft.id}.name`)}</h3>
                      </div>
                      <p className="text-latin-body text-text-secondary">{t(`site.fp.${ft.id}.card`)}</p>
                      <span className="mt-auto inline-flex items-center gap-4 pt-4 text-latin-label-sm font-semibold text-text-primary md:mt-0">
                        <span className="kn-link">{t('site.fp.learn')}</span>
                        <ChevronRight width={14} height={14} className="kn-nudge" aria-hidden />
                      </span>
                    </div>
                  </a>
                </div>
              );
            })}
          </div>
        </Container>
      </Section>

      <Section tone="dark">
        <Container>
          <Heading title={t('site.fp.ov.fit_title')} body={t('site.fp.ov.fit_body')} dark />
          <ol className="mt-40 flex flex-col items-stretch gap-12 md:mt-48 lg:flex-row lg:items-stretch lg:gap-8">
            {flow.map((Icon, i) => (
              <Fragment key={i}>
                <li {...rv('up', i, 80)} className="lg:flex-1">
                  <div className="group flex h-full items-center gap-12 rounded-lg border border-cream-100/[0.12] bg-cream-100/[0.04] p-16 transition-[background-color,border-color,transform] duration-300 hover:-translate-y-4 hover:border-sage-300/60 hover:bg-cream-100/[0.08] lg:flex-col lg:items-start lg:gap-8">
                    <span className="inline-flex h-[36px] w-[36px] shrink-0 items-center justify-center rounded-full bg-cream-100/[0.1] text-cream-200 transition-transform duration-300 group-hover:scale-110">
                      <Icon width={18} height={18} aria-hidden />
                    </span>
                    <span className="flex flex-col">
                      <span className="text-latin-label-sm font-semibold text-cream-50">
                        {i + 1} · {t(`site.fp.ov.f${i + 1}`)}
                      </span>
                      <span className="text-latin-caption text-cream-400">{t(`site.fp.ov.f${i + 1}_b`)}</span>
                    </span>
                  </div>
                </li>
                {i < flow.length - 1 && (
                  <ChevronRight aria-hidden width={16} height={16} className="mx-auto hidden shrink-0 self-center text-cream-400 lg:block" />
                )}
              </Fragment>
            ))}
          </ol>
        </Container>
      </Section>

      <Faq t={t} title={t('site.faq.title')} body={t('site.faq.body')} items={faqItems(t, 'site.fp.ov', 4, f)} />
      <FinalCta t={t} trialDays={plans?.trial_days ?? null} title={t('site.fp.ov.cta')} />
    </>
  );
}
