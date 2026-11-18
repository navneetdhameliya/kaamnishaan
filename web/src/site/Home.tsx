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
import { useEffect, useState, type ReactNode } from 'react';

import { cx } from '../components/ui';
import type { Lang, T } from '../lib/i18n';
import type { PlansOut, TradeOut } from '../lib/types';
import { LinkButton } from './Layout';
import { CountUp, reducedMotion, rv, useInView } from './motion';
import { Container, Faq, FinalCta, Heading, Section, Tick } from './parts';
import { FreeStrip, PlanGrid, PriceState } from './plans';
import { ROUTES } from './site';

type Load<D> = { kind: 'loading' } | { kind: 'ready'; data: D } | { kind: 'error' };

export const TRADE_PHOTO: Record<string, string> = {
  hvac: '/img/industry-hvac.webp',
  roofing: '/img/industry-roofing.webp',
  solar: '/img/industry-solar.webp',
  maintenance: '/img/industry-property.webp',
  'pest-control': '/img/industry-pest.webp',
  cleaning: '/img/industry-cleaning.webp',
};

function Chip({
  icon,
  tone,
  title,
  sub,
  className,
  i = 0,
}: {
  icon: ReactNode;
  tone: string;
  title: string;
  sub?: string;
  className: string;
  i?: number;
}) {
  return (
    <div {...rv('zoom', 4 + i, 140)} className={cx('absolute hidden sm:block', className)}>
      <div
        style={{ '--f': `${i * -2}s` } as React.CSSProperties}
        className="kn-float flex items-center gap-12 rounded-full bg-cream-50 py-[10px] pl-12 pr-20 shadow-md transition-transform duration-300 hover:scale-105"
      >
      <span className={cx('inline-flex h-[36px] w-[36px] shrink-0 items-center justify-center rounded-full', tone)}>{icon}</span>
      <span className="flex flex-col whitespace-nowrap">
        <span className="text-latin-label-sm font-semibold text-text-primary">{title}</span>
        {sub && <span className="text-latin-caption text-text-secondary">{sub}</span>}
      </span>
      </div>
    </div>
  );
}

/** W01 hero: the promise on the left, the rooftop photo with the two app screens on the right. */
function Hero({ t, trialDays }: { t: T; trialDays: number | null }) {
  return (
    <section className="relative overflow-hidden bg-espresso-950 pb-64 pt-48 md:pb-[88px] lg:min-h-[800px] lg:pt-[72px]">
      <div
        aria-hidden
        className="pointer-events-none absolute -left-[360px] top-[420px] hidden h-[720px] w-[720px] animate-[spin_80s_linear_infinite] rounded-full border-[72px] border-mocha-950 border-t-transparent lg:block"
      />
      <Container className="relative flex flex-col gap-48 lg:flex-row lg:items-start lg:justify-between lg:gap-16">
        <div className="flex flex-col items-start gap-32 lg:mt-64 lg:w-[600px] lg:shrink-0">
          <span {...rv('up', 0)} className="inline-flex items-center gap-8 rounded-full border border-cream-100/[0.14] bg-cream-100/[0.08] px-12 py-[6px] text-latin-label-sm font-semibold text-cream-200">
            <Check width={16} height={16} aria-hidden />
            {t('site.hero.pill')}
          </span>
          <div className="flex flex-col gap-24">
            <h1 {...rv('up', 1, 120)} className="text-[40px] font-bold leading-[48px] tracking-[-0.015em] text-cream-50 md:text-web-display-xl">{t('site.hero.title')}</h1>
            <p {...rv('up', 2, 120)} className="max-w-[540px] text-latin-body-lg text-cream-400 md:text-web-body-lg">
              {t('site.hero.body')}
            </p>
          </div>
          <div {...rv('up', 3, 120)} className="flex w-full flex-col gap-16 sm:w-auto sm:flex-row">
            <LinkButton href={ROUTES.trial} variant="light">
              {t('site.cta.trial')}
            </LinkButton>
            <LinkButton href={ROUTES.demo} variant="outline-light" icon={<Play width={20} height={20} aria-hidden />}>
              {t('site.cta.demo')}
            </LinkButton>
          </div>
          <div {...rv('up', 4, 120)} className="flex flex-wrap gap-x-24 gap-y-8">
            {trialDays != null && <Tick light>{t('site.hero.trial_days', { n: trialDays })}</Tick>}
            <Tick light>{t('site.hero.no_card')}</Tick>
            <Tick light>{t('site.hero.offline')}</Tick>
          </div>
        </div>
        {/* 612 × 716 box; everything inside is placed in % so it scales down on small screens */}
        <div className="relative mx-auto aspect-[612/716] w-full max-w-[612px] lg:mx-0 lg:w-[612px]" role="img" aria-label={t('site.hero.alt')}>
          <div {...rv('zoom', 1)} className="group absolute left-0 top-0 h-[89.4%] w-[95.4%] overflow-hidden rounded-xl">
            <img src="/img/hero-photo.webp" alt="" className="kn-zoom h-full w-full object-cover" fetchPriority="high" />
            <div className="absolute inset-0 bg-espresso-950/[0.16]" />
          </div>
          <div {...rv('up', 2, 160)} className="absolute left-0 top-[27.9%] w-[39.7%]">
            <img
              src="/img/hero-phone-today.webp"
              alt=""
              style={{ '--f': '-1.5s' } as React.CSSProperties}
              className="kn-float w-full drop-shadow-[0_12px_32px_rgba(59,41,33,0.14)]"
            />
          </div>
          <div {...rv('up', 3, 160)} className="absolute left-[60.1%] top-[17.9%] w-[39.7%]">
            <img src="/img/hero-phone-report.webp" alt="" className="kn-float w-full drop-shadow-[0_12px_32px_rgba(59,41,33,0.14)]" />
          </div>
          <Chip
            i={0}
            className="left-[7.8%] top-[5.6%]"
            tone="bg-status-success-bg text-status-success"
            icon={<Check width={18} height={18} aria-hidden />}
            title={t('site.hero.chip_approved')}
            sub={t('site.hero.chip_approved_sub')}
          />
          <Chip
            i={1}
            className="left-[48.4%] top-[8.9%]"
            tone="bg-sage-100 text-sage-700"
            icon={<Globe width={18} height={18} aria-hidden />}
            title={t('site.hero.chip_langs')}
          />
          <Chip
            i={2}
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
  const card = (img: string, alt: string, icon: ReactNode, tone: string, title: string, body: string, i: number) => (
    <div {...rv(i ? 'right' : 'left', i)}>
    <div className="kn-lift group flex h-full flex-col gap-24 rounded-xl border border-border-default bg-bg-surface p-[24px]">
      <div className="overflow-hidden rounded-lg">
        <img src={img} alt={alt} width={538} height={320} loading="lazy" className="kn-zoom w-full" />
      </div>
      <div className="flex gap-12">
        <span className={cx('inline-flex h-[32px] w-[32px] shrink-0 items-center justify-center rounded-full transition-transform duration-300 group-hover:scale-110', tone)}>
          {icon}
        </span>
        <div className="flex flex-col gap-8">
          <h3 className="text-latin-h3 md:text-web-h3">{title}</h3>
          <p className="text-latin-body text-text-secondary md:text-web-body">{body}</p>
        </div>
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
            0,
          )}
          {card(
            '/img/problem-after.webp',
            t('site.problem.after_alt'),
            <Check width={16} height={16} aria-hidden />,
            'bg-status-success-bg text-status-success',
            t('site.problem.after_title'),
            t('site.problem.after_body'),
            1,
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
            <li key={s.title} {...rv('up', i, 150)}>
              <div className="group flex flex-col gap-24">
              <div className="overflow-hidden rounded-xl">
                <img src={s.img} alt="" width={384} height={360} loading="lazy" className="w-full transition-transform duration-700 ease-[cubic-bezier(.22,1,.36,1)] group-hover:-translate-y-8 group-hover:scale-[1.04]" />
              </div>
              <div className="flex gap-16">
                <span className="inline-flex h-[32px] w-[32px] shrink-0 items-center justify-center rounded-full bg-cream-200 text-web-label font-semibold text-mocha-950 transition-all duration-300 group-hover:scale-110 group-hover:bg-sage-500">
                  {i + 1}
                </span>
                <div className="flex flex-col gap-8">
                  <h3 className="text-web-h3 text-cream-50">{s.title}</h3>
                  <p className="text-web-body text-cream-400">{s.body}</p>
                </div>
              </div>
              </div>
            </li>
          ))}
        </ol>
      </Container>
    </Section>
  );
}

export function IconDot({ children, tone = 'bg-cream-200 text-mocha-700', size = 48 }: { children: ReactNode; tone?: string; size?: number }) {
  return (
    <span
      style={{ width: size, height: size }}
      className={cx(
        'inline-flex shrink-0 items-center justify-center rounded-full transition-transform duration-500 ease-[cubic-bezier(.34,1.56,.64,1)] group-hover:-rotate-6 group-hover:scale-110',
        tone,
      )}
    >
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
          <div id="ai-reports" className="scroll-mt-[96px]" {...rv('left')}>
          <div className="kn-lift group flex h-full flex-col gap-32 rounded-xl border border-border-default bg-bg-surface p-24 md:flex-row md:items-center md:p-32">
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
            <div className="overflow-hidden rounded-lg md:w-[340px] md:shrink-0">
              <img src="/img/feature-report.webp" alt={t('site.feat.reports_alt')} loading="lazy" className="kn-zoom aspect-square w-full object-cover" />
            </div>
          </div>
          </div>
          <div {...rv('right', 1)}>
          <div className="kn-lift group flex h-full flex-col gap-16 rounded-xl border border-border-default bg-bg-surface p-24 md:p-32">
            <div className="overflow-hidden rounded-lg">
              <img src="/img/feature-camera.webp" alt={t('site.feat.capture_alt')} loading="lazy" className="kn-zoom h-[180px] w-full object-cover" />
            </div>
            <div className="flex items-center gap-12">
              <IconDot size={40}>
                <Camera width={20} height={20} aria-hidden />
              </IconDot>
              <h3 className="text-web-h3">{t('site.feat.capture_title')}</h3>
            </div>
            <p className="text-web-body text-text-secondary">{t('site.feat.capture_body')}</p>
          </div>
          </div>
        </div>
        <div className="mt-24 grid gap-24 sm:grid-cols-2 lg:grid-cols-4">
          {small.map((f, i) => (
            <div key={f.title} {...rv('up', i)}>
              <div className="kn-lift group flex h-full flex-col items-start gap-16 rounded-xl border border-border-default bg-bg-surface p-24 hover:border-mocha-300 md:p-32">
                <IconDot>{f.icon}</IconDot>
                <h3 className="text-web-h3">{f.title}</h3>
                <p className="text-web-body text-text-secondary">{f.body}</p>
              </div>
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
          {trades.map((tr, i) => (
            <div key={tr.key} {...rv('zoom', i)}>
            <a
              href={ROUTES.industry(tr.key)}
              className="kn-lift group relative block h-[300px] overflow-hidden rounded-xl md:h-[340px]"
            >
              <img
                src={TRADE_PHOTO[tr.key] ?? '/img/industry-hvac.webp'}
                alt=""
                loading="lazy"
                className="kn-zoom absolute inset-0 h-full w-full object-cover"
              />
              <span className="absolute inset-0 bg-gradient-to-b from-[rgba(43,28,23,0)] from-[35%] to-[rgba(43,28,23,0.92)] transition-opacity duration-500 group-hover:opacity-90" />
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
                  <ChevronRight width={16} height={16} className="kn-nudge" aria-hidden />
                </span>
              </span>
              <span className="absolute bottom-20 right-20 inline-flex h-[44px] w-[44px] items-center justify-center rounded-full bg-bg-surface text-text-primary transition-all duration-300 group-hover:scale-110 group-hover:bg-sage-500">
                <ChevronRight width={20} height={20} className="transition-transform duration-300 group-hover:-rotate-45" aria-hidden />
              </span>
            </a>
            </div>
          ))}
        </div>
      </Container>
    </Section>
  );
}

/** Drag (or use the arrow keys on) the line to compare the two photos. */
function BeforeAfter({ t }: { t: T }) {
  const [pos, setPos] = useState(50);
  const [touched, setTouched] = useState(false);
  const [ref, seen] = useInView<HTMLDivElement>(0.5);
  // the first time the photos come into view, the line sweeps once to show it can be dragged
  useEffect(() => {
    if (!seen || touched || reducedMotion()) return;
    let raf = 0;
    const start = performance.now();
    const tick = (now: number) => {
      const p = Math.min(1, (now - start) / 2200);
      setPos(50 + Math.sin(p * Math.PI * 2) * 22 * (1 - p));
      if (p < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [seen]);
  return (
    <Section id="before-after">
      <Container>
        <Heading title={t('site.compare.title')} body={t('site.compare.body')} className="max-w-[840px]" />
        <div {...rv('zoom')} className="mt-40 md:mt-48">
        <div ref={ref} className="group relative aspect-[4/3] w-full select-none overflow-hidden rounded-xl md:aspect-[1200/560]">
          <img src="/img/compare-after.webp" alt={t('site.compare.after_alt')} loading="lazy" className="absolute inset-0 h-full w-full object-cover" />
          <div className="absolute inset-0" style={{ clipPath: `inset(0 ${100 - pos}% 0 0)` }}>
            <img src="/img/compare-before.webp" alt={t('site.compare.before_alt')} loading="lazy" className="absolute inset-0 h-full w-full object-cover" />
          </div>
          <div className="pointer-events-none absolute inset-y-0 w-[4px] -translate-x-1/2 bg-cream-50" style={{ left: `${pos}%` }} />
          <div
            className="pointer-events-none absolute top-1/2 inline-flex h-[64px] w-[64px] -translate-x-1/2 -translate-y-1/2 items-center justify-center gap-4 rounded-full bg-cream-50 text-text-primary shadow-lg transition-transform duration-300 group-hover:scale-110 group-active:scale-95"
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
            onChange={(e) => {
              setTouched(true);
              setPos(Number(e.target.value));
            }}
            aria-label={t('site.compare.handle')}
            className="absolute inset-0 h-full w-full cursor-ew-resize opacity-0"
          />
        </div>
        </div>
        <div {...rv('up', 1)} className="mt-24 flex flex-wrap justify-center gap-x-24 gap-y-8 text-latin-label-sm font-semibold text-text-secondary md:mt-48">
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

export function ReportDemo({ t, title, body }: { t: T; title?: string; body?: string }) {
  return (
    <Section tone="dark">
      <Container>
        <Heading title={title ?? t('site.demo.title')} body={body ?? t('site.demo.body')} dark className="max-w-[880px]" />
        <div className="mt-40 flex flex-col items-center gap-24 md:mt-48 lg:flex-row lg:justify-between lg:gap-0">
          <div {...rv('left')} className="w-full max-w-[500px] lg:w-[41.7%]">
            <img src="/img/demo-voice.webp" alt={t('site.demo.voice_alt')} width={500} height={344} loading="lazy" className="w-full rounded-xl transition-transform duration-500 hover:-translate-y-4 hover:rotate-[-1deg]" />
          </div>
          <div {...rv('zoom', 2, 200)} className="flex flex-col items-center gap-12 lg:w-[112px]">
            <span className="kn-glow inline-flex h-[64px] w-[64px] items-center justify-center rounded-full bg-sage-500 text-mocha-950">
              <Sparkles width={26} height={26} className="animate-pulse" aria-hidden />
            </span>
            <span className="max-w-[112px] text-center text-latin-label-sm font-semibold text-cream-200">{t('site.demo.step')}</span>
          </div>
          <div {...rv('right', 4, 200)} className="w-full max-w-[540px] lg:w-[45%]">
            <img src="/img/demo-report-card.webp" alt={t('site.demo.report_alt')} width={540} height={434} loading="lazy" className="w-full rounded-xl transition-transform duration-500 hover:-translate-y-4 hover:rotate-[1deg]" />
          </div>
        </div>
      </Container>
    </Section>
  );
}

export function Assistant({ t, title, body, questions }: { t: T; title?: string; body?: string; questions?: string[] }) {
  return (
    <Section id="assistant">
      <Container className="flex flex-col gap-40 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex flex-col gap-32 lg:w-[480px]">
          <Heading title={title ?? t('site.ask.title')} body={body ?? t('site.ask.body')} align="left" />
          <ul className="flex flex-col gap-16">
            {(questions ?? [t('site.ask.q1'), t('site.ask.q2'), t('site.ask.q3')]).map((q, i) => (
              <li key={q} {...rv('left', i + 2)}>
                <span className="group flex cursor-default items-center gap-12 rounded-full py-4 pr-12 text-latin-body transition-colors hover:bg-sage-100/60">
                  <IconDot size={32} tone="bg-sage-100 text-sage-700">
                    <Search width={16} height={16} aria-hidden />
                  </IconDot>
                  <span className="transition-transform duration-300 group-hover:translate-x-4">{q}</span>
                </span>
              </li>
            ))}
          </ul>
        </div>
        <div {...rv('right', 1)} className="w-full max-w-[624px]">
          <img src="/img/demo-assistant.webp" alt={t('site.ask.alt')} width={656} height={668} loading="lazy" className="w-full transition-transform duration-700 hover:-translate-y-8" />
        </div>
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
        <div {...rv('zoom')} className="mt-40 grid grid-cols-2 gap-y-32 rounded-xl bg-mocha-900 px-16 py-32 md:mt-48 lg:grid-cols-4 lg:py-40">
          {stats.map((s, i) => (
            <div key={s.l} className={cx('group flex flex-col items-center gap-4 px-8 text-center', i > 0 && 'lg:border-l lg:border-cream-100/[0.14]')}>
              <CountUp
                text={s.v}
                className="whitespace-nowrap text-[26px] font-bold leading-[34px] text-cream-50 transition-transform duration-300 group-hover:scale-110 sm:text-[32px] sm:leading-[40px] lg:text-[40px] lg:leading-[48px] xl:text-web-display"
              />
              <span className="text-latin-caption text-cream-400 md:text-web-body">{s.l}</span>
            </div>
          ))}
        </div>
        <div className="mt-48 grid gap-32 sm:grid-cols-2 lg:grid-cols-4">
          {items.map((b, i) => (
            <div key={b.title} {...rv('up', i)}>
              <div className="group flex flex-col items-start gap-12">
                <IconDot size={48}>{b.icon}</IconDot>
                <h3 className="text-web-h3">{b.title}</h3>
                <p className="text-web-body text-text-secondary">{b.body}</p>
              </div>
            </div>
          ))}
        </div>
      </Container>
    </Section>
  );
}

export function HomePricing({ t, lang, plans, retry, title }: { t: T; lang: Lang; plans: Load<PlansOut>; retry: () => void; title?: string }) {
  const ready = plans.kind === 'ready' ? plans.data : null;
  const pro = ready?.plans.find((p) => p.most_popular);
  const free = ready?.plans.find((p) => p.price?.amount === 0);
  return (
    <Section id="pricing" tone="surface" className="border-t-0">
      <Container>
        <Heading
          eyebrow={title ? t('site.nav.pricing') : undefined}
          title={title ?? t('site.price.title')}
          body={ready ? t('site.price.body', { currency: ready.currency, plan: pro?.name ?? '', n: ready.trial_days }) : undefined}
        />
        <div className="mt-40 md:mt-48">
          {ready ? (
            <>
              <PlanGrid data={ready} t={t} lang={lang} codes={ready.plans.filter((p) => p !== free).map((p) => p.code)} />
              {free && <FreeStrip plan={free} t={t} />}
              <p {...rv('up')} className="mt-24 text-center">
                <a href={ROUTES.pricing} className="group inline-flex items-center gap-4 text-web-label font-semibold text-text-primary">
                  <span className="kn-link">{t('site.price.see_all')}</span>
                  <ChevronRight width={16} height={16} className="kn-nudge" aria-hidden />
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
