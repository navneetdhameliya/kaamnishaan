import { Check, Globe, Lock, Mic, Sparkles, UserCheck } from 'lucide-react';
import type { CSSProperties } from 'react';

import type { Lang, T } from '../lib/i18n';
import type { ConfigOut, PlansOut } from '../lib/types';
import { rv } from './motion';
import { Container, FinalCta, Heading, Section } from './parts';
import { num, ROUTES } from './site';
import { FeatureHero, HeroChip, UseCases } from './features/FeaturePage';

const k = (t: T, s: string, p?: Record<string, string | number>) => t(`site.about.${s}`, p);

/** Two phones on a dark panel: the technician's day and the voice note screen (Figma 560 × 600). */
function Visual({ t }: { t: T }) {
  return (
    <div className="relative mx-auto aspect-[560/600] w-full max-w-[560px] lg:mx-0 lg:w-[560px] lg:shrink-0" role="img" aria-label={k(t, 'alt')}>
      <div {...rv('zoom', 0)} className="absolute inset-0 rounded-xl border border-cream-100/[0.06] bg-cream-100/[0.04]" />
      <div {...rv('up', 1, 160)} className="absolute left-[7.1%] top-[5%] w-[43.4%]">
        <img
          src="/img/hero-phone-today.webp"
          alt=""
          width={243}
          height={516}
          fetchPriority="high"
          style={{ '--f': '-1.5s' } as CSSProperties}
          className="kn-float w-full drop-shadow-[0_16px_32px_rgba(0,0,0,0.35)]"
        />
      </div>
      <div {...rv('up', 3, 160)} className="absolute left-[54.6%] top-[19.3%] w-[44.6%]">
        <img src="/img/feat-voice-a.webp" alt="" width={272} height={580} className="kn-float w-full drop-shadow-[0_16px_32px_rgba(0,0,0,0.35)]" />
      </div>
      <HeroChip i={0} className="left-[-8%] top-[80%]" chip={{ icon: UserCheck, tone: 'success' }} title={k(t, 'chip1')} sub={k(t, 'chip1_sub')} />
      <HeroChip i={1} className="left-[57%] top-[3%]" chip={{ icon: Mic, tone: 'cream' }} title={k(t, 'chip2')} sub={k(t, 'chip2_sub')} />
    </div>
  );
}

const PEOPLE = ['hvac', 'solar', 'cleaning', 'pest'];
const VALUES = [Check, Sparkles, Globe, Lock];

/** W24 About: who KaamNishaan is for and what it believes. Trades and languages come from GET /config. */
export default function About({ t, lang, config, plans }: { t: T; lang: Lang; config: ConfigOut | null; plans: PlansOut | null }) {
  const langs = config?.languages ?? [];
  return (
    <>
      <FeatureHero
        t={t}
        root={{ href: '/', label: k(t, 'crumb') }}
        crumb={t('site.foot.about')}
        pill={k(t, 'pill')}
        pillIcon={<Globe width={16} height={16} aria-hidden />}
        title={k(t, 'title')}
        body={k(t, 'body')}
        ticks={[k(t, 'tick1'), ...(config ? [t('site.about.langs', { n: num(langs.length, lang) })] : []), t('site.hero.offline')]}
      >
        <Visual t={t} />
      </FeatureHero>

      <Section>
        <Container>
          <Heading eyebrow={k(t, 'why_eyebrow')} title={k(t, 'why_title')} body={k(t, 'why_body')} />
          <div className="mt-40 flex flex-col gap-40 md:mt-48 lg:flex-row lg:items-center lg:justify-between">
            <div className="flex flex-col gap-16 lg:w-[564px]">
              {[1, 2, 3].map((n) => (
                <p key={n} {...rv('up', n)} className="text-latin-body-lg text-text-secondary">
                  {k(t, `why_p${n}`)}
                </p>
              ))}
            </div>
            <figure className="lg:w-[564px]">
              <div className="grid grid-cols-2 gap-16">
                {PEOPLE.map((p, i) => (
                  <div key={p} {...rv('zoom', i, 110)} className="group overflow-hidden rounded-lg">
                    <img src={`/img/ind-${p}-photo.webp`} alt="" width={272} height={180} loading="lazy" className="kn-zoom aspect-[272/180] w-full object-cover" />
                  </div>
                ))}
              </div>
              <figcaption {...rv('fade', 4)} className="mt-12 text-latin-caption text-text-secondary">
                {k(t, 'why_caption')}
              </figcaption>
            </figure>
          </div>
        </Container>
      </Section>

      <Section tone="surface">
        <Container>
          <Heading eyebrow={k(t, 'values_eyebrow')} title={k(t, 'values_title')} body={k(t, 'values_body')} />
          <div className="mt-40 grid gap-24 sm:grid-cols-2 md:mt-48 lg:grid-cols-4">
            {VALUES.map((Icon, i) => (
              <div key={i} {...rv('up', i)}>
                <div className="kn-lift group flex h-full flex-col gap-12 rounded-xl border border-border-default bg-bg-canvas p-24">
                  <span className="inline-flex h-[40px] w-[40px] items-center justify-center rounded-full bg-bg-surface text-mocha-700 transition-transform duration-300 group-hover:rotate-[-8deg] group-hover:scale-110">
                    <Icon width={18} height={18} aria-hidden />
                  </span>
                  <h3 className="mt-4 text-latin-h3 md:text-web-h3">{k(t, `v${i + 1}`)}</h3>
                  <p className="text-latin-body text-text-secondary">{k(t, `v${i + 1}_b`)}</p>
                </div>
              </div>
            ))}
          </div>
        </Container>
      </Section>

      <UseCases t={t} eyebrow={k(t, 'ind_eyebrow')} title={k(t, 'ind_title')} body={k(t, 'ind_body')} trades={config?.trades ?? []} counts />

      {langs.length > 0 && (
        <Section tone="dark">
          <Container>
            <Heading title={k(t, 'lang_title')} body={k(t, 'lang_body', { n: num(langs.length, lang) })} dark />
            <ul className="mt-40 grid grid-cols-2 gap-16 sm:grid-cols-3 md:mt-48 lg:grid-cols-5">
              {langs.map((l, i) => (
                <li key={l.code} {...rv('up', i, 80)}>
                  <div className="flex h-full flex-col items-center gap-8 rounded-lg border border-cream-100/[0.12] bg-cream-100/[0.04] px-12 py-24 text-center transition-[background-color,border-color,transform] duration-300 hover:-translate-y-4 hover:border-cream-200/40 hover:bg-cream-100/[0.08]">
                    <span lang={l.code} className="text-web-h3 text-cream-50">
                      {l.native_name}
                    </span>
                    <span className="text-latin-caption text-cream-400">{k(t, 'lang_line', { lang: t(`lang.${l.code}`) })}</span>
                  </div>
                </li>
              ))}
            </ul>
          </Container>
        </Section>
      )}

      <FinalCta
        t={t}
        trialDays={plans?.trial_days ?? null}
        title={k(t, 'cta')}
        body={k(t, 'cta_body')}
        primary={{ href: ROUTES.contact, label: k(t, 'contact') }}
        spaced={langs.length > 0}
      />
    </>
  );
}
