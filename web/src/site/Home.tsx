import {
  Camera,
  Check,
  ChevronLeft,
  ChevronRight,
  Clock,
  CloudOff,
  FileText,
  Globe,
  ListChecks,
  Lock,
  MapPin,
  Mic,
  Play,
  Search,
  Sparkles,
  User,
  X,
} from 'lucide-react';
import { useState, type ReactNode } from 'react';

import { cx } from '../components/ui';
import type { Lang, T } from '../lib/i18n';
import type { PlansOut, TradeOut } from '../lib/types';
import { LinkButton } from './Layout';
import { Container, Faq, FinalCta, Heading, Section, Tick } from './parts';
import { FreeStrip, PlanGrid, PriceState } from './plans';
import { ROUTES } from './site';

type Load<D> = { kind: 'loading' } | { kind: 'ready'; data: D } | { kind: 'error' };

const TRADE_PHOTO: Record<string, string> = {
  hvac: '/img/industry-hvac.webp',
  roofing: '/img/industry-roofing.webp',
  solar: '/img/industry-solar.webp',
  maintenance: '/img/industry-property.webp',
  'pest-control': '/img/industry-pest.webp',
  cleaning: '/img/industry-cleaning.webp',
};

function Chip({ icon, tone, title, sub, className }: { icon: ReactNode; tone: string; title: string; sub?: string; className: string }) {
  return (
    <div
      className={cx(
        'absolute hidden items-center gap-12 rounded-full bg-cream-50 py-[10px] pl-12 pr-20 shadow-md sm:flex',
        className,
      )}
    >
      <span className={cx('inline-flex h-[36px] w-[36px] shrink-0 items-center justify-center rounded-full', tone)}>{icon}</span>
      <span className="flex flex-col whitespace-nowrap">
        <span className="text-latin-label-sm font-semibold text-text-primary">{title}</span>
        {sub && <span className="text-latin-caption text-text-secondary">{sub}</span>}
      </span>
    </div>
  );
}

/** W01 hero: the promise on the left, the rooftop photo with the two app screens on the right. */
function Hero({ t, trialDays }: { t: T; trialDays: number | null }) {
  return (
    <section className="relative overflow-hidden bg-espresso-950 pb-64 pt-48 md:pb-[88px] lg:min-h-[800px] lg:pt-[72px]">
      <div
        aria-hidden
        className="pointer-events-none absolute -left-[360px] top-[420px] hidden h-[720px] w-[720px] rounded-full border-[72px] border-mocha-950 lg:block"
      />
      <Container className="relative flex flex-col gap-48 lg:flex-row lg:items-start lg:justify-between lg:gap-16">
        <div className="flex flex-col items-start gap-32 lg:mt-64 lg:w-[600px] lg:shrink-0">
          <span className="inline-flex items-center gap-8 rounded-full border border-cream-100/[0.14] bg-cream-100/[0.08] px-12 py-[6px] text-latin-label-sm font-semibold text-cream-200">
            <Check width={16} height={16} aria-hidden />
            {t('site.hero.pill')}
          </span>
          <div className="flex flex-col gap-24">
            <h1 className="text-[40px] font-bold leading-[48px] tracking-[-0.015em] text-cream-50 md:text-web-display-xl">{t('site.hero.title')}</h1>
            <p className="max-w-[540px] text-latin-body-lg text-cream-400 md:text-web-body-lg">{t('site.hero.body')}</p>
          </div>
          <div className="flex w-full flex-col gap-16 sm:w-auto sm:flex-row">
            <LinkButton href={ROUTES.trial} variant="light">
              {t('site.cta.trial')}
            </LinkButton>
            <LinkButton href={ROUTES.demo} variant="outline-light" icon={<Play width={20} height={20} aria-hidden />}>
              {t('site.cta.demo')}
            </LinkButton>
          </div>
          <div className="flex flex-wrap gap-x-24 gap-y-8">
            {trialDays != null && <Tick light>{t('site.hero.trial_days', { n: trialDays })}</Tick>}
            <Tick light>{t('site.hero.no_card')}</Tick>
            <Tick light>{t('site.hero.offline')}</Tick>
          </div>
        </div>
        {/* 612 × 716 box; everything inside is placed in % so it scales down on small screens */}
        <div className="relative mx-auto aspect-[612/716] w-full max-w-[612px] lg:mx-0 lg:w-[612px]" role="img" aria-label={t('site.hero.alt')}>
          <img
            src="/img/hero-photo.webp"
            alt=""
            className="absolute left-0 top-0 h-[89.4%] w-[95.4%] rounded-xl object-cover"
            fetchPriority="high"
          />
          <div className="absolute left-0 top-0 h-[89.4%] w-[95.4%] rounded-xl bg-espresso-950/[0.16]" />
          <img src="/img/hero-phone-today.webp" alt="" className="absolute left-0 top-[27.9%] w-[39.7%] drop-shadow-[0_12px_32px_rgba(59,41,33,0.14)]" />
          <img src="/img/hero-phone-report.webp" alt="" className="absolute left-[60.1%] top-[17.9%] w-[39.7%] drop-shadow-[0_12px_32px_rgba(59,41,33,0.14)]" />
          <Chip
            className="left-[7.8%] top-[5.6%]"
            tone="bg-status-success-bg text-status-success"
            icon={<Check width={18} height={18} aria-hidden />}
            title={t('site.hero.chip_approved')}
            sub={t('site.hero.chip_approved_sub')}
          />
          <Chip
            className="left-[48.4%] top-[8.9%]"
            tone="bg-sage-100 text-sage-700"
            icon={<Globe width={18} height={18} aria-hidden />}
            title={t('site.hero.chip_langs')}
          />
          <Chip
            className="left-[26.8%] top-[84.4%]"
            tone="bg-cream-200 text-mocha-700"
            icon={<Camera width={18} height={18} aria-hidden />}
            title={t('site.hero.chip_photos')}
            sub={t('site.hero.chip_photos_sub')}
          />
        </div>
      </Container>
    </section>
  );
}

function Problem({ t }: { t: T }) {
  const card = (img: string, alt: string, icon: ReactNode, tone: string, title: string, body: string) => (
    <div className="flex flex-col gap-24 rounded-xl border border-border-default bg-bg-surface p-[24px]">
      <img src={img} alt={alt} width={538} height={320} loading="lazy" className="w-full rounded-lg" />
      <div className="flex gap-12">
        <span className={cx('inline-flex h-[32px] w-[32px] shrink-0 items-center justify-center rounded-full', tone)}>{icon}</span>
        <div className="flex flex-col gap-8">
          <h3 className="text-latin-h3 md:text-web-h3">{title}</h3>
          <p className="text-latin-body text-text-secondary md:text-web-body">{body}</p>
        </div>
      </div>
    </div>
  );
  return (
    <Section>
      <Container>
        <Heading title={t('site.problem.title')} body={t('site.problem.body')} />
        <div className="mt-40 grid gap-24 md:mt-48 lg:grid-cols-2">
          {card(
            '/img/problem-before.webp',
            t('site.problem.before_alt'),
            <X width={16} height={16} aria-hidden />,
            'bg-status-danger-bg text-status-danger',
            t('site.problem.before_title'),
            t('site.problem.before_body'),
          )}
          {card(
            '/img/problem-after.webp',
            t('site.problem.after_alt'),
            <Check width={16} height={16} aria-hidden />,
            'bg-status-success-bg text-status-success',
            t('site.problem.after_title'),
            t('site.problem.after_body'),
          )}
        </div>
      </Container>
    </Section>
  );
}

function HowItWorks({ t }: { t: T }) {
  const steps = [
    { img: '/img/step-photos.webp', title: t('site.how.s1_title'), body: t('site.how.s1_body') },
    { img: '/img/step-voice.webp', title: t('site.how.s2_title'), body: t('site.how.s2_body') },
    { img: '/img/step-report.webp', title: t('site.how.s3_title'), body: t('site.how.s3_body') },
  ];
  return (
    <Section id="how-it-works" tone="dark">
      <Container>
        <Heading title={t('site.how.title')} body={t('site.how.body')} dark />
        <ol className="mt-40 grid gap-40 md:mt-48 md:grid-cols-3 md:gap-24">
          {steps.map((s, i) => (
            <li key={s.title} className="flex flex-col gap-24">
              <img src={s.img} alt="" width={384} height={360} loading="lazy" className="w-full rounded-xl" />
              <div className="flex gap-16">
                <span className="inline-flex h-[32px] w-[32px] shrink-0 items-center justify-center rounded-full bg-cream-200 text-web-label font-semibold text-mocha-950">
                  {i + 1}
                </span>
                <div className="flex flex-col gap-8">
                  <h3 className="text-web-h3 text-cream-50">{s.title}</h3>
                  <p className="text-web-body text-cream-400">{s.body}</p>
                </div>
              </div>
            </li>
          ))}
        </ol>
      </Container>
    </Section>
  );
}

function IconDot({ children, tone = 'bg-cream-200 text-mocha-700', size = 48 }: { children: ReactNode; tone?: string; size?: number }) {
  return (
    <span style={{ width: size, height: size }} className={cx('inline-flex shrink-0 items-center justify-center rounded-full', tone)}>
      {children}
    </span>
  );
}

function Features({ t }: { t: T }) {
  const small = [
    { icon: <Mic width={22} height={22} />, title: t('site.feat.voice_title'), body: t('site.feat.voice_body') },
    { icon: <ListChecks width={22} height={22} />, title: t('site.feat.checklists_title'), body: t('site.feat.checklists_body') },
    { icon: <FileText width={22} height={22} />, title: t('site.feat.pdf_title'), body: t('site.feat.pdf_body') },
    { icon: <CloudOff width={22} height={22} />, title: t('site.feat.offline_title'), body: t('site.feat.offline_body') },
  ];
  return (
    <Section id="features">
      <Container>
        <Heading title={t('site.feat.title')} body={t('site.feat.body')} className="max-w-[960px]" />
        <div className="mt-40 grid gap-24 md:mt-48 lg:grid-cols-[2fr_1fr]">
          <div id="ai-reports" className="flex scroll-mt-16 flex-col gap-32 rounded-xl border border-border-default bg-bg-surface p-24 md:flex-row md:items-center md:p-32">
            <div className="flex flex-1 flex-col items-start gap-16">
              <IconDot tone="bg-sage-100 text-sage-700">
                <Sparkles width={24} height={24} aria-hidden />
              </IconDot>
              <h3 className="text-web-h3">{t('site.feat.reports_title')}</h3>
              <p className="text-web-body text-text-secondary">{t('site.feat.reports_body')}</p>
              <div className="flex flex-wrap gap-8">
                <span className="inline-flex items-center gap-[6px] rounded-full bg-status-success-bg px-[10px] py-4 text-latin-caption-strong text-status-success">
                  <Check width={14} height={14} aria-hidden />
                  {t('site.feat.reports_tag1')}
                </span>
                <span className="inline-flex items-center gap-[6px] rounded-full bg-cream-200 px-[10px] py-4 text-latin-caption-strong text-mocha-700">
                  <User width={14} height={14} aria-hidden />
                  {t('site.feat.reports_tag2')}
                </span>
              </div>
            </div>
            <img
              src="/img/feature-report.webp"
              alt={t('site.feat.reports_alt')}
              loading="lazy"
              className="aspect-square w-full rounded-lg object-cover md:w-[340px]"
            />
          </div>
          <div className="flex flex-col gap-16 rounded-xl border border-border-default bg-bg-surface p-24 md:p-32">
            <img src="/img/feature-camera.webp" alt={t('site.feat.capture_alt')} loading="lazy" className="h-[180px] w-full rounded-lg object-cover" />
            <div className="flex items-center gap-12">
              <IconDot size={40}>
                <Camera width={20} height={20} aria-hidden />
              </IconDot>
              <h3 className="text-web-h3">{t('site.feat.capture_title')}</h3>
            </div>
            <p className="text-web-body text-text-secondary">{t('site.feat.capture_body')}</p>
          </div>
        </div>
        <div className="mt-24 grid gap-24 sm:grid-cols-2 lg:grid-cols-4">
          {small.map((f) => (
            <div key={f.title} className="flex flex-col items-start gap-16 rounded-xl border border-border-default bg-bg-surface p-24 md:p-32">
              <IconDot>{f.icon}</IconDot>
              <h3 className="text-web-h3">{f.title}</h3>
              <p className="text-web-body text-text-secondary">{f.body}</p>
            </div>
          ))}
        </div>
      </Container>
    </Section>
  );
}

function Industries({ t, trades }: { t: T; trades: TradeOut[] }) {
  return (
    <Section id="industries" tone="surface">
      <Container>
        <Heading title={t('site.ind.title')} body={t('site.ind.body')} />
        <div className="mt-40 grid gap-24 sm:grid-cols-2 md:mt-48 lg:grid-cols-3">
          {trades.map((tr) => (
            <a
              key={tr.key}
              href={ROUTES.industry(tr.key)}
              className="group relative block h-[300px] overflow-hidden rounded-xl md:h-[340px]"
            >
              <img
                src={TRADE_PHOTO[tr.key] ?? '/img/industry-hvac.webp'}
                alt=""
                loading="lazy"
                className="absolute inset-0 h-full w-full object-cover transition duration-300 group-hover:scale-[1.03]"
              />
              <span className="absolute inset-0 bg-gradient-to-b from-[rgba(43,28,23,0)] from-[35%] to-[rgba(43,28,23,0.92)]" />
              {tr.checklists > 0 && (
                <span className="absolute left-16 top-16 inline-flex items-center gap-[6px] rounded-full bg-bg-surface px-12 py-[6px] text-latin-label-sm font-semibold text-text-primary">
                  <ListChecks width={14} height={14} aria-hidden />
                  {tr.checklists === 1 ? t('site.ind.count_one') : t('site.ind.count', { n: tr.checklists })}
                </span>
              )}
              <span className="absolute bottom-20 left-20 right-[76px] flex flex-col gap-[6px]">
                <span className="text-web-h3 text-cream-50">{tr.name}</span>
                <span className="text-web-label font-semibold text-cream-100">{t(`site.ind.${tr.key.replace(/-/g, '_')}`)}</span>
                <span className="inline-flex items-center gap-[6px] text-web-label font-semibold text-mocha-300">
                  {t('site.ind.learn')}
                  <ChevronRight width={16} height={16} aria-hidden />
                </span>
              </span>
              <span className="absolute bottom-20 right-20 inline-flex h-[44px] w-[44px] items-center justify-center rounded-full bg-bg-surface text-text-primary">
                <ChevronRight width={20} height={20} aria-hidden />
              </span>
            </a>
          ))}
        </div>
      </Container>
    </Section>
  );
}

/** Drag (or use the arrow keys on) the line to compare the two photos. */
function BeforeAfter({ t }: { t: T }) {
  const [pos, setPos] = useState(50);
  return (
    <Section id="before-after">
      <Container>
        <Heading title={t('site.compare.title')} body={t('site.compare.body')} className="max-w-[840px]" />
        <div className="relative mt-40 aspect-[4/3] w-full select-none overflow-hidden rounded-xl md:mt-48 md:aspect-[1200/560]">
          <img src="/img/compare-after.webp" alt={t('site.compare.after_alt')} loading="lazy" className="absolute inset-0 h-full w-full object-cover" />
          <div className="absolute inset-0" style={{ clipPath: `inset(0 ${100 - pos}% 0 0)` }}>
            <img src="/img/compare-before.webp" alt={t('site.compare.before_alt')} loading="lazy" className="absolute inset-0 h-full w-full object-cover" />
          </div>
          <div className="pointer-events-none absolute inset-y-0 w-[4px] -translate-x-1/2 bg-cream-50" style={{ left: `${pos}%` }} />
          <div
            className="pointer-events-none absolute top-1/2 inline-flex h-[64px] w-[64px] -translate-x-1/2 -translate-y-1/2 items-center justify-center gap-4 rounded-full bg-cream-50 text-text-primary shadow-lg"
            style={{ left: `${pos}%` }}
          >
            <ChevronLeft width={20} height={20} aria-hidden />
            <ChevronRight width={20} height={20} aria-hidden />
          </div>
          <span className="absolute left-24 top-24 rounded-full bg-espresso-950/[0.72] px-12 py-[6px] text-web-eyebrow uppercase text-cream-50">
            {t('site.compare.before')}
          </span>
          <span className="absolute right-24 top-24 rounded-full bg-espresso-950/[0.72] px-12 py-[6px] text-web-eyebrow uppercase text-cream-50">
            {t('site.compare.after')}
          </span>
          <input
            type="range"
            min={0}
            max={100}
            value={pos}
            onChange={(e) => setPos(Number(e.target.value))}
            aria-label={t('site.compare.handle')}
            className="absolute inset-0 h-full w-full cursor-ew-resize opacity-0"
          />
        </div>
        <div className="mt-24 flex flex-wrap justify-center gap-x-24 gap-y-8 text-latin-label-sm font-semibold text-text-secondary md:mt-48">
          <span className="inline-flex items-center gap-8">
            <MapPin width={18} height={18} aria-hidden />
            {t('site.compare.where')}
          </span>
          <span className="inline-flex items-center gap-8">
            <Clock width={18} height={18} aria-hidden />
            {t('site.compare.when')}
          </span>
          <span className="inline-flex items-center gap-8">
            <User width={18} height={18} aria-hidden />
            {t('site.compare.who')}
          </span>
        </div>
      </Container>
    </Section>
  );
}

function ReportDemo({ t }: { t: T }) {
  return (
    <Section tone="dark">
      <Container>
        <Heading title={t('site.demo.title')} body={t('site.demo.body')} dark className="max-w-[880px]" />
        <div className="mt-40 flex flex-col items-center gap-24 md:mt-48 lg:flex-row lg:justify-between lg:gap-0">
          <img src="/img/demo-voice.webp" alt={t('site.demo.voice_alt')} width={500} height={344} loading="lazy" className="w-full max-w-[500px] rounded-xl lg:w-[41.7%]" />
          <div className="flex flex-col items-center gap-12 lg:w-[112px]">
            <span className="inline-flex h-[64px] w-[64px] items-center justify-center rounded-full bg-sage-500 text-mocha-950">
              <Sparkles width={26} height={26} aria-hidden />
            </span>
            <span className="max-w-[112px] text-center text-latin-label-sm font-semibold text-cream-200">{t('site.demo.step')}</span>
          </div>
          <img src="/img/demo-report-card.webp" alt={t('site.demo.report_alt')} width={540} height={434} loading="lazy" className="w-full max-w-[540px] rounded-xl lg:w-[45%]" />
        </div>
      </Container>
    </Section>
  );
}

function Assistant({ t }: { t: T }) {
  return (
    <Section id="assistant">
      <Container className="flex flex-col gap-40 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex flex-col gap-32 lg:w-[480px]">
          <Heading title={t('site.ask.title')} body={t('site.ask.body')} align="left" />
          <ul className="flex flex-col gap-16">
            {[t('site.ask.q1'), t('site.ask.q2'), t('site.ask.q3')].map((q) => (
              <li key={q} className="flex items-center gap-12 text-latin-body">
                <IconDot size={32} tone="bg-sage-100 text-sage-700">
                  <Search width={16} height={16} aria-hidden />
                </IconDot>
                {q}
              </li>
            ))}
          </ul>
        </div>
        <img src="/img/demo-assistant.webp" alt={t('site.ask.alt')} width={656} height={668} loading="lazy" className="w-full max-w-[624px]" />
      </Container>
    </Section>
  );
}

function Benefits({ t }: { t: T }) {
  const stats = [1, 2, 3, 4].map((i) => ({ v: t(`site.why.s${i}`), l: t(`site.why.s${i}_l`) }));
  const items = [
    { icon: <Lock width={20} height={20} />, title: t('site.why.b1'), body: t('site.why.b1_body') },
    { icon: <Check width={20} height={20} />, title: t('site.why.b2'), body: t('site.why.b2_body') },
    { icon: <Clock width={20} height={20} />, title: t('site.why.b3'), body: t('site.why.b3_body') },
    { icon: <FileText width={20} height={20} />, title: t('site.why.b4'), body: t('site.why.b4_body') },
  ];
  return (
    <Section tone="surface">
      <Container>
        <Heading title={t('site.why.title')} body={t('site.why.body')} />
        <div className="mt-40 grid grid-cols-2 gap-y-32 rounded-xl bg-mocha-900 px-16 py-32 md:mt-48 lg:grid-cols-4 lg:py-40">
          {stats.map((s, i) => (
            <div key={s.l} className={cx('flex flex-col items-center gap-4 px-8 text-center', i > 0 && 'lg:border-l lg:border-cream-100/[0.14]')}>
              <span className="whitespace-nowrap text-[26px] font-bold leading-[34px] text-cream-50 sm:text-[32px] sm:leading-[40px] lg:text-[40px] lg:leading-[48px] xl:text-web-display">{s.v}</span>
              <span className="text-latin-caption text-cream-400 md:text-web-body">{s.l}</span>
            </div>
          ))}
        </div>
        <div className="mt-48 grid gap-32 sm:grid-cols-2 lg:grid-cols-4">
          {items.map((b) => (
            <div key={b.title} className="flex flex-col items-start gap-12">
              <IconDot size={48}>{b.icon}</IconDot>
              <h3 className="text-web-h3">{b.title}</h3>
              <p className="text-web-body text-text-secondary">{b.body}</p>
            </div>
          ))}
        </div>
      </Container>
    </Section>
  );
}

function HomePricing({ t, lang, plans, retry }: { t: T; lang: Lang; plans: Load<PlansOut>; retry: () => void }) {
  const ready = plans.kind === 'ready' ? plans.data : null;
  const pro = ready?.plans.find((p) => p.most_popular);
  const free = ready?.plans.find((p) => p.price?.amount === 0);
  return (
    <Section id="pricing" tone="surface" className="border-t-0">
      <Container>
        <Heading
          title={t('site.price.title')}
          body={ready ? t('site.price.body', { currency: ready.currency, plan: pro?.name ?? '', n: ready.trial_days }) : undefined}
        />
        <div className="mt-40 md:mt-48">
          {ready ? (
            <>
              <PlanGrid data={ready} t={t} lang={lang} codes={ready.plans.filter((p) => p !== free).map((p) => p.code)} />
              {free && <FreeStrip plan={free} t={t} />}
              <p className="mt-24 text-center">
                <a href={ROUTES.pricing} className="inline-flex items-center gap-4 text-web-label font-semibold text-text-primary hover:underline">
                  {t('site.price.see_all')}
                  <ChevronRight width={16} height={16} aria-hidden />
                </a>
              </p>
            </>
          ) : (
            <PriceState kind={plans.kind === 'error' ? 'error' : 'loading'} t={t} retry={retry} />
          )}
        </div>
      </Container>
    </Section>
  );
}

/** W01 Home. Prices, the trial length and the trades come from the API; the words from shared/i18n. */
export default function Home({
  t,
  lang,
  plans,
  retryPlans,
  trades,
}: {
  t: T;
  lang: Lang;
  plans: Load<PlansOut>;
  retryPlans: () => void;
  trades: TradeOut[];
}) {
  const trialDays = plans.kind === 'ready' ? plans.data.trial_days : null;
  const pro = plans.kind === 'ready' ? (plans.data.plans.find((p) => p.most_popular)?.name ?? '') : '';
  return (
    <>
      <Hero t={t} trialDays={trialDays} />
      <Problem t={t} />
      <HowItWorks t={t} />
      <Features t={t} />
      {trades.length > 0 && <Industries t={t} trades={trades} />}
      <BeforeAfter t={t} />
      <ReportDemo t={t} />
      <Assistant t={t} />
      <Benefits t={t} />
      <HomePricing t={t} lang={lang} plans={plans} retry={retryPlans} />
      <Faq
        t={t}
        title={t('site.faq.title')}
        body={t('site.faq.body')}
        items={[1, 2, 3, 4, 5]
          .filter((i) => i !== 4 || trialDays != null)
          .map((i) => ({
          q: t(`site.faq.q${i}`),
          a: t(`site.faq.a${i}`, { plan: pro, n: trialDays ?? '' }),
        }))}
      />
      <FinalCta t={t} trialDays={trialDays} />
    </>
  );
}
