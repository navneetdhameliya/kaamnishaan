import { Check, ChevronRight, Play } from 'lucide-react';
import type { CSSProperties, ReactNode } from 'react';

import { cx } from '../../components/ui';
import type { Lang, T } from '../../lib/i18n';
import type { ConfigOut, PlansOut, TradeOut } from '../../lib/types';
import { Assistant, IconDot, ReportDemo, TRADE_PHOTO } from '../Home';
import { LinkButton } from '../Layout';
import { rv } from '../motion';
import { Container, Faq, FinalCta, Heading, Section, Tick } from '../parts';
import { num, ROUTES } from '../site';
import { feature, featureHref, type Chip, type FeatureId, type FeaturePageSpec } from './catalog';

const TONE: Record<Chip['tone'], string> = {
  success: 'bg-status-success-bg text-status-success',
  sage: 'bg-sage-100 text-sage-700',
  cream: 'bg-cream-200 text-mocha-700',
};

/** Numbers the feature pages put into their sentences, all from GET /plans and GET /config. */
export function facts(plans: PlansOut | null, config: ConfigOut | null, lang: Lang) {
  const pro = plans?.plans.find((p) => p.most_popular);
  const free = plans?.plans.find((p) => p.price?.amount === 0) ?? plans?.plans[0];
  const n = (v: number | null | undefined) => (v == null ? '' : num(v, lang));
  return {
    ready: !!plans,
    trial: plans?.trial_days ?? '',
    plan: pro?.name ?? '',
    free: free?.name ?? '',
    ai_free: n(free?.ai_questions_monthly),
    ai_pro: n(pro?.ai_questions_monthly),
    credits_pro: n(pro?.monthly_credits),
    sms: n(plans?.credit_rules.sms),
    whatsapp: n(plans?.credit_rules.whatsapp),
    ai_call: n(plans?.credit_rules.ai_call),
    langs: config ? num(config.languages.length, lang) : '',
  };
}
export type Facts = ReturnType<typeof facts>;

export function Breadcrumb({ t, here, root }: { t: T; here: string; root?: { href: string; label: string } }) {
  return (
    <nav aria-label={t('site.fp.crumb_label')} {...rv('fade')} className="mb-32 flex items-center gap-8 text-latin-label-sm font-semibold text-cream-400 lg:mb-48">
      <a href={root?.href ?? ROUTES.features} className="kn-link hover:text-cream-50">
        {root?.label ?? t('site.fp.crumb')}
      </a>
      <ChevronRight width={14} height={14} aria-hidden />
      <span aria-current="page" className="text-cream-200">
        {here}
      </span>
    </nav>
  );
}

/** A floating proof chip on the hero picture. */
export function HeroChip({ chip, title, sub, i, className }: { chip: Chip; title: string; sub: string; i: number; className: string }) {
  const Icon = chip.icon;
  return (
    <div {...rv('zoom', 4 + i, 140)} className={cx('absolute z-10 hidden sm:block', className)}>
      <div
        style={{ '--f': `${i * -2.5}s` } as CSSProperties}
        className="kn-float flex items-center gap-12 rounded-full bg-cream-50 py-[10px] pl-12 pr-20 shadow-md transition-transform duration-300 hover:scale-105"
      >
        <span className={cx('inline-flex h-[36px] w-[36px] shrink-0 items-center justify-center rounded-full', TONE[chip.tone])}>
          <Icon width={18} height={18} aria-hidden />
        </span>
        <span className="flex flex-col whitespace-nowrap">
          <span className="text-latin-label-sm font-semibold text-text-primary">{title}</span>
          <span className="text-latin-caption text-text-secondary">{sub}</span>
        </span>
      </div>
    </div>
  );
}

/** Dark hero shared by every feature page: words on the left, the picture on the right. */
export function FeatureHero({
  t,
  crumb,
  pill,
  pillIcon,
  title,
  body,
  ticks,
  children,
  secondary,
  root,
}: {
  t: T;
  crumb: string;
  root?: { href: string; label: string };
  pill: string;
  pillIcon: ReactNode;
  title: string;
  body: string;
  ticks: string[];
  children: ReactNode;
  secondary?: { href: string; label: string };
}) {
  return (
    <section className="relative overflow-hidden bg-espresso-950 pb-64 pt-32 md:pb-[88px] lg:min-h-[760px]">
      <div
        aria-hidden
        className="pointer-events-none absolute -right-[260px] -top-[220px] hidden h-[720px] w-[720px] animate-[spin_90s_linear_infinite] rounded-full border-[72px] border-mocha-950 border-b-transparent lg:block"
      />
      <Container className="relative">
        <Breadcrumb t={t} here={crumb} root={root} />
        <div className="flex flex-col gap-48 lg:flex-row lg:items-start lg:justify-between lg:gap-24">
          <div className="flex flex-col items-start gap-32 lg:mt-24 lg:w-[560px] lg:shrink-0">
            <span
              {...rv('up', 0)}
              className="inline-flex items-center gap-8 rounded-full border border-cream-100/[0.14] bg-cream-100/[0.08] px-12 py-[6px] text-latin-label-sm font-semibold text-cream-200"
            >
              {pillIcon}
              {pill}
            </span>
            <div className="flex flex-col gap-24">
              <h1 {...rv('up', 1, 120)} className="text-[40px] font-bold leading-[48px] tracking-[-0.015em] text-cream-50 md:text-web-display-xl">
                {title}
              </h1>
              <p {...rv('up', 2, 120)} className="text-latin-body-lg text-cream-400 md:text-web-body-lg">
                {body}
              </p>
            </div>
            <div {...rv('up', 3, 120)} className="flex w-full flex-col gap-16 sm:w-auto sm:flex-row">
              <LinkButton href={ROUTES.trial} variant="light">
                {t('site.cta.trial')}
              </LinkButton>
              <LinkButton href={secondary?.href ?? ROUTES.demo} variant="outline-light" icon={secondary ? undefined : <Play width={20} height={20} aria-hidden />}>
                {secondary?.label ?? t('site.cta.demo')}
              </LinkButton>
            </div>
            <div {...rv('up', 4, 120)} className="flex flex-wrap gap-x-24 gap-y-8">
              {ticks.map((x) => (
                <Tick key={x} light>
                  {x}
                </Tick>
              ))}
            </div>
          </div>
          {children}
        </div>
      </Container>
    </section>
  );
}

/** Two phones (or the report page in a browser and a phone) on a dark panel, 560 × 600 like the Figma frame. */
export function HeroVisual({
  id,
  kind,
  alt,
  chips,
}: {
  id: string;
  kind: 'phones' | 'browser';
  alt: string;
  chips: { chip: Chip; title: string; sub: string }[];
}) {
  const browser = kind === 'browser';
  return (
    <div className="relative mx-auto aspect-[560/600] w-full max-w-[560px] lg:mx-0 lg:w-[560px] lg:shrink-0" role="img" aria-label={alt}>
      {!browser && <div {...rv('zoom', 0)} className="absolute inset-0 rounded-xl border border-cream-100/[0.06] bg-cream-100/[0.04]" />}
      {browser ? (
        <>
          <div {...rv('up', 1, 160)} className="absolute left-0 top-[2.7%] w-full">
            <div className="group overflow-hidden rounded-[14px] shadow-[0_16px_40px_rgba(0,0,0,0.35)]">
              <img src={`/img/feat-${id}-a.webp`} alt="" width={560} height={400} fetchPriority="high" className="kn-zoom w-full" />
            </div>
          </div>
          <div {...rv('up', 3, 160)} className="absolute left-[60.7%] top-[11.7%] w-[42%]">
            <img src={`/img/feat-${id}-b.webp`} alt="" width={272} height={580} className="kn-float w-full drop-shadow-[0_16px_32px_rgba(0,0,0,0.4)]" />
          </div>
        </>
      ) : (
        <>
          <div {...rv('up', 1, 160)} className="absolute left-[7.1%] top-[5%] w-[48.6%]">
            <img
              src={`/img/feat-${id}-a.webp`}
              alt=""
              width={272}
              height={580}
              fetchPriority="high"
              style={{ '--f': '-1.5s' } as CSSProperties}
              className="kn-float w-full drop-shadow-[0_16px_32px_rgba(0,0,0,0.35)]"
            />
          </div>
          <div {...rv('up', 3, 160)} className="absolute left-[54.6%] top-[19.3%] w-[44.6%]">
            <img src={`/img/feat-${id}-b.webp`} alt="" width={250} height={532} className="kn-float w-full drop-shadow-[0_16px_32px_rgba(0,0,0,0.35)]" />
          </div>
        </>
      )}
      {chips[0] && <HeroChip i={0} className={browser ? 'left-[-6%] top-[78%]' : 'left-[-8%] top-[80%]'} {...chips[0]} />}
      {chips[1] && <HeroChip i={1} className={browser ? 'left-[56%] top-[88%]' : 'left-[57%] top-[5%]'} {...chips[1]} />}
    </div>
  );
}

/** Four numbered cards with a photo each. */
export function Steps({ eyebrow, title, body, items }: { eyebrow: string; title: string; body: string; items: { img: string; title: string; body: string }[] }) {
  return (
    <Section id="how-it-works">
      <Container>
        <Heading eyebrow={eyebrow} title={title} body={body} />
        <ol className="mt-40 grid gap-24 sm:grid-cols-2 md:mt-48 lg:grid-cols-4">
          {items.map((s, i) => (
            <li key={s.title} {...rv('up', i)}>
              <div className="kn-lift group flex h-full flex-col overflow-hidden rounded-xl border border-border-default bg-bg-surface">
                <div className="overflow-hidden">
                  <img src={s.img} alt="" width={382} height={216} loading="lazy" className="kn-zoom aspect-[280/176] w-full object-cover" />
                </div>
                <div className="flex flex-col gap-12 p-24">
                  <span className="inline-flex h-[28px] w-[28px] items-center justify-center rounded-full bg-mocha-900 text-latin-caption-strong text-cream-50 transition-transform duration-300 group-hover:scale-110">
                    {i + 1}
                  </span>
                  <h3 className="text-latin-h3 md:text-web-h3">{s.title}</h3>
                  <p className="text-latin-body text-text-secondary">{s.body}</p>
                </div>
              </div>
            </li>
          ))}
        </ol>
      </Container>
    </Section>
  );
}

export function Capabilities({
  eyebrow,
  title,
  body,
  items,
}: {
  eyebrow: string;
  title: string;
  body?: string;
  items: { icon: ReactNode; title: string; body: string; tag?: string; soon?: boolean }[];
}) {
  return (
    <Section tone="surface">
      <Container>
        <Heading eyebrow={eyebrow} title={title} body={body} />
        <div className="mt-40 grid gap-24 sm:grid-cols-2 md:mt-48 lg:grid-cols-3">
          {items.map((c, i) => (
            <div key={c.title} {...rv('up', i)}>
              <div className="kn-lift group flex h-full flex-col items-start gap-16 rounded-xl border border-border-default bg-bg-canvas p-24 hover:border-mocha-300 md:p-[24px]">
                <div className="flex w-full items-center justify-between gap-8">
                  <span className="inline-flex h-[44px] w-[44px] items-center justify-center rounded-full bg-bg-surface text-mocha-700 transition-transform duration-300 group-hover:rotate-[-8deg] group-hover:scale-110">
                    {c.icon}
                  </span>
                  {c.tag && (
                    <span
                      className={cx(
                        'inline-flex items-center gap-4 rounded-full px-[10px] py-4 text-latin-caption-strong',
                        c.soon ? 'bg-cream-200 text-mocha-700' : 'bg-status-success-bg text-status-success',
                      )}
                    >
                      {!c.soon && <Check width={14} height={14} aria-hidden />}
                      {c.tag}
                    </span>
                  )}
                </div>
                <h3 className="text-latin-h3 md:text-web-h3">{c.title}</h3>
                <p className="text-latin-body text-text-secondary">{c.body}</p>
              </div>
            </div>
          ))}
        </div>
      </Container>
    </Section>
  );
}

/** "See it in the app": four phones with numbered captions on a dark band. */
function AppShots({ id, eyebrow, title, body, items }: { id: string; eyebrow: string; title: string; body: string; items: { icon: ReactNode; title: string; body: string }[] }) {
  return (
    <Section tone="dark">
      <Container>
        <Heading eyebrow={eyebrow} title={title} body={body} dark />
        <ol className="mt-40 grid grid-cols-2 gap-x-16 gap-y-40 md:mt-48 lg:grid-cols-4 lg:gap-24">
          {items.map((s, i) => (
            <li key={s.title} {...rv('up', i, 120)} className="group flex flex-col items-center text-center">
              <img
                src={`/img/feat-${id}-app${i + 1}.webp`}
                alt={s.title}
                width={222}
                height={468}
                loading="lazy"
                className="w-full max-w-[200px] drop-shadow-[0_16px_32px_rgba(0,0,0,0.35)] transition-transform duration-500 group-hover:-translate-y-8 lg:max-w-[222px]"
              />
              <div className="mt-24 flex items-center gap-8 text-cream-200">
                <span className="inline-flex h-[28px] w-[28px] items-center justify-center rounded-full bg-cream-50 text-latin-caption-strong text-mocha-950">{i + 1}</span>
                <span className="transition-transform duration-300 group-hover:scale-110">{s.icon}</span>
              </div>
              <h3 className="mt-12 text-latin-h3 text-cream-50 md:text-web-h3">{s.title}</h3>
              <p className="mt-8 max-w-[240px] text-latin-body text-cream-400">{s.body}</p>
            </li>
          ))}
        </ol>
      </Container>
    </Section>
  );
}

/** Use cases: the trades from GET /config, each linking to its industry page. */
export function UseCases({ t, eyebrow, title, body, trades, counts }: { t: T; eyebrow: string; title: string; body: string; trades: TradeOut[]; counts?: boolean }) {
  if (!trades.length) return null;
  return (
    <Section>
      <Container>
        <Heading eyebrow={eyebrow} title={title} body={body} />
        <div className="mt-40 grid grid-cols-2 gap-12 md:mt-48 md:gap-16 lg:grid-cols-3 xl:grid-cols-6">
          {trades.map((tr, i) => (
            <div key={tr.key} {...rv('up', i, 70)}>
              <a href={ROUTES.industry(tr.key)} className="kn-lift group flex h-full flex-col overflow-hidden rounded-xl border border-border-default bg-bg-surface">
                <div className="overflow-hidden">
                  <img src={TRADE_PHOTO[tr.key] ?? '/img/industry-hvac.webp'} alt="" width={185} height={112} loading="lazy" className="kn-zoom aspect-[185/112] w-full object-cover" />
                </div>
                <div className="flex flex-1 flex-col gap-8 p-16">
                  <h3 className="text-latin-label font-semibold text-text-primary">{tr.name}</h3>
                  <p className="text-latin-caption text-text-secondary">{t(`site.ind.${tr.key.replace(/-/g, '_')}`)}</p>
                  {counts && (
                    <span
                      className={cx(
                        'mt-4 inline-flex w-fit items-center rounded-full px-8 py-[2px] text-latin-caption-strong',
                        tr.checklists ? 'bg-status-success-bg text-status-success' : 'bg-cream-200 text-mocha-700',
                      )}
                    >
                      {tr.checklists === 1 ? t('site.ind.count_one') : tr.checklists ? t('site.ind.count', { n: tr.checklists }) : t('site.fp.build_own')}
                    </span>
                  )}
                  <span className="mt-auto inline-flex items-center gap-4 pt-8 text-latin-label-sm font-semibold text-text-primary">
                    <span className="kn-link">{t('site.fp.view_industry')}</span>
                    <ChevronRight width={14} height={14} className="kn-nudge" aria-hidden />
                  </span>
                </div>
              </a>
            </div>
          ))}
        </div>
      </Container>
    </Section>
  );
}

export function Related({ t, ids }: { t: T; ids: FeatureId[] }) {
  return (
    <Section tone="surface">
      <Container>
        <div className="flex flex-wrap items-end justify-between gap-16">
          <div className="flex flex-col gap-8">
            <p {...rv('fade')} className="text-web-eyebrow uppercase text-mocha-700">
              {t('site.fp.explore')}
            </p>
            <h2 {...rv('up')} className="text-web-m-h2 md:text-web-h2">
              {t('site.fp.related')}
            </h2>
          </div>
          <a {...rv('left', 1)} href={ROUTES.features} className="group inline-flex items-center gap-4 text-web-label font-semibold text-text-primary">
            <span className="kn-link">{t('site.fp.all')}</span>
            <ChevronRight width={16} height={16} className="kn-nudge" aria-hidden />
          </a>
        </div>
        <div className="mt-32 grid gap-24 md:grid-cols-3">
          {ids.map((id, i) => {
            const f = feature(id);
            const Icon = f.icon;
            return (
              <div key={id} {...rv('up', i)}>
                <a href={featureHref(id)} className="kn-lift group flex h-full flex-col overflow-hidden rounded-xl border border-border-default bg-bg-canvas">
                  <div className="overflow-hidden">
                    <img src={f.cover} alt="" width={382} height={216} loading="lazy" className="kn-zoom aspect-[382/216] w-full object-cover" />
                  </div>
                  <div className="flex flex-1 flex-col gap-12 p-24">
                    <div className="flex items-center gap-12">
                      <IconDot size={36}>
                        <Icon width={18} height={18} aria-hidden />
                      </IconDot>
                      <h3 className="text-latin-h3 md:text-web-h3">{t(`site.fp.${id}.name`)}</h3>
                    </div>
                    <p className="text-latin-body text-text-secondary">{t(`site.fp.${id}.card`)}</p>
                    <span className="mt-auto inline-flex items-center gap-4 text-latin-label-sm font-semibold text-text-primary">
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
  );
}

/** FAQ items k = 1..n; answers can use the numbers in [f]. */
export function faqItems(t: T, prefix: string, n: number, f: Facts) {
  const { ready, ...params } = f;
  return Array.from({ length: n }, (_, i) => i + 1)
    .filter((i) => ready || !/\{\w+\}/.test(t(`${prefix}.ans${i}`)))
    .map((i) => ({ q: t(`${prefix}.q${i}`), a: t(`${prefix}.ans${i}`, params) }));
}

/** W09–W17: one template, filled from site.fp.<id>.* and catalog.ts. */
export default function FeaturePage({
  t,
  spec,
  trades,
  plans,
  config,
  lang,
}: {
  t: T;
  spec: FeaturePageSpec;
  trades: TradeOut[];
  plans: PlansOut | null;
  config: ConfigOut | null;
  lang: Lang;
}) {
  const k = (s: string, p?: Record<string, string | number>) => t(`site.fp.${spec.id}.${s}`, p);
  const f = facts(plans, config, lang);
  const name = k('name');
  const Icon = feature(spec.id).icon;
  const [one, two, three, four] = [1, 2, 3, 4];
  return (
    <>
      <FeatureHero
        t={t}
        crumb={name}
        pill={t('site.fp.eyebrow', { name })}
        pillIcon={<Icon width={16} height={16} aria-hidden />}
        title={k('title')}
        body={k('body')}
        ticks={[t('site.fp.every_plan'), k('tick1'), k('tick2')]}
      >
        <HeroVisual
          id={spec.id}
          kind={spec.hero}
          alt={t('site.fp.alt_hero', { name })}
          chips={spec.chips.map((chip, i) => ({ chip, title: k(`chip${i + 1}`), sub: k(`chip${i + 1}_sub`) }))}
        />
      </FeatureHero>
      <Steps
        eyebrow={t('site.fp.how')}
        title={k('how_title')}
        body={k('how_body')}
        items={spec.steps.map((img, i) => ({ img, title: k(`s${i + 1}`), body: k(`s${i + 1}_b`) }))}
      />
      <Capabilities
        eyebrow={t('site.fp.caps')}
        title={k('cap_title')}
        body={k('cap_body')}
        items={spec.caps.map((C, i) => ({
          icon: <C width={20} height={20} aria-hidden />,
          title: k(`c${i + 1}`),
          body: k(`c${i + 1}_b`),
          tag: i === spec.tagAt ? k('tag') : undefined,
        }))}
      />
      {spec.app === 'shots' && spec.appIcons ? (
        <AppShots
          id={spec.id}
          eyebrow={t('site.fp.app')}
          title={k('app_title')}
          body={k('app_body')}
          items={[one, two, three, four].map((n, i) => {
            const C = spec.appIcons![i];
            return { icon: <C width={18} height={18} aria-hidden />, title: k(`p${n}`), body: k(`p${n}_b`) };
          })}
        />
      ) : spec.app === 'voice' ? (
        <ReportDemo t={t} title={k('app_title')} body={k('app_body')} />
      ) : (
        <Assistant t={t} title={k('app_title')} body={k('app_body')} questions={[k('ask1'), k('ask2'), k('ask3')]} />
      )}
      <UseCases t={t} eyebrow={t('site.fp.use')} title={k('use_title')} body={k('use_body')} trades={trades} counts={spec.checklistCounts} />
      <Related t={t} ids={spec.related} />
      <Faq t={t} title={t('site.faq.title')} body={t('site.faq.body')} items={faqItems(t, `site.fp.${spec.id}`, 4, f)} />
      <FinalCta t={t} trialDays={plans?.trial_days ?? null} title={k('cta')} />
    </>
  );
}
