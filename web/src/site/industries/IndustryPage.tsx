import {
  Camera,
  Check,
  ChevronRight,
  CircleAlert,
  Clock,
  FileText,
  Globe,
  Hash,
  Image as ImageIcon,
  Languages,
  Link2,
  ListChecks,
  Mic,
  Plus,
  Users,
  X,
  type LucideIcon,
} from 'lucide-react';
import { useEffect, useRef, useState, type CSSProperties } from 'react';

import type { Lang, T } from '../../lib/i18n';
import type { ConfigOut, PlansOut, PublicChecklistTemplate, TradeOut } from '../../lib/types';
import { HomePricing, IconDot } from '../Home';
import { LinkButton } from '../Layout';
import { rv } from '../motion';
import { Container, Faq, FinalCta, Heading, Section } from '../parts';
import { num, ROUTES, useReadyChecklists, type Load } from '../site';
import { feature, featureHref, type FeatureId } from '../features/catalog';
import { FeatureHero, HeroChip } from '../features/FeaturePage';

/** Words: site.indp.<id>.*; pictures: /img/ind-<img>-*.webp. Trade keys and names come from GET /config. */
interface IndustrySpec {
  key: string;
  id: string;
  img: string;
  pains: [LucideIcon, LucideIcon, LucideIcon];
  report: [string, string];
  features: [FeatureId, FeatureId, FeatureId, FeatureId];
}

const I = (s: string) => `/img/${s}.webp`;

export const INDUSTRIES: IndustrySpec[] = [
  { key: 'hvac', id: 'hvac', img: 'hvac', pains: [CircleAlert, Clock, Globe], report: [I('compare-before'), I('compare-after')], features: ['evidence', 'checklists', 'voice', 'reports'] },
  { key: 'roofing', id: 'roofing', img: 'roofing', pains: [CircleAlert, Clock, FileText], report: [I('ind-roofing-before'), I('ind-roofing-photo')], features: ['evidence', 'checklists', 'offline', 'reports'] },
  { key: 'solar', id: 'solar', img: 'solar', pains: [CircleAlert, FileText, ImageIcon], report: [I('ind-solar-before'), I('ind-solar-photo')], features: ['evidence', 'checklists', 'pdf', 'offline'] },
  { key: 'maintenance', id: 'maintenance', img: 'property', pains: [CircleAlert, ListChecks, Users], report: [I('ind-property-before'), I('ind-property-photo')], features: ['jobs', 'evidence', 'checklists', 'sharing'] },
  { key: 'pest-control', id: 'pest_control', img: 'pest', pains: [FileText, CircleAlert, Clock], report: [I('ind-pest-photo'), I('ind-pest-bait')], features: ['evidence', 'checklists', 'pdf', 'jobs'] },
  { key: 'cleaning', id: 'cleaning', img: 'cleaning', pains: [CircleAlert, Users, Languages], report: [I('ind-cleaning-before'), I('ind-cleaning-photo')], features: ['checklists', 'evidence', 'voice', 'jobs'] },
];

export const industryByKey = (key: string) => INDUSTRIES.find((x) => x.key === key);

const TYPE_ICON: Record<string, LucideIcon> = { yes_no: Check, pass_fail: Check, number: Hash, text: FileText, choice: ListChecks, photo: Camera, signature: FileText };

/** Hero picture: the trade photo with the checklist phone over its left edge (Figma 640 × 624). */
function HeroPicture({ spec, t, alt }: { spec: IndustrySpec; t: T; alt: string }) {
  const k = (s: string) => t(`site.indp.${spec.id}.${s}`);
  return (
    <div className="relative mx-auto aspect-[640/624] w-full max-w-[640px] lg:mx-0 lg:mt-[-32px] lg:w-[600px] lg:shrink-0" role="img" aria-label={alt}>
      <div {...rv('zoom', 0)} className="absolute bottom-0 left-[8.75%] top-0 w-[91.25%]">
        <div className="group relative h-full overflow-hidden rounded-xl">
          <img src={I(`ind-${spec.img}-photo`)} alt="" width={584} height={624} fetchPriority="high" className="kn-zoom h-full w-full object-cover" />
          <div className="pointer-events-none absolute inset-0 bg-espresso-950/[0.16]" />
        </div>
      </div>
      <div {...rv('up', 2, 160)} className="absolute left-0 top-[13.8%] w-[39%]">
        <img
          src={I(`ind-${spec.img}-phone`)}
          alt=""
          width={250}
          height={532}
          style={{ '--f': '-2s' } as CSSProperties}
          className="kn-float w-full drop-shadow-[0_16px_32px_rgba(0,0,0,0.4)]"
        />
      </div>
      <HeroChip i={0} className="left-[51.6%] top-[9%]" chip={{ icon: Check, tone: 'success' }} title={k('chip1')} sub={k('chip1_sub')} />
      <HeroChip i={1} className="left-[52%] top-[86%]" chip={{ icon: Camera, tone: 'cream' }} title={k('chip2')} sub={k('chip2_sub')} />
    </div>
  );
}

function Pains({ spec, t }: { spec: IndustrySpec; t: T }) {
  const k = (s: string) => t(`site.indp.${spec.id}.${s}`);
  return (
    <Section>
      <Container>
        <Heading eyebrow={t('site.indp.pains')} title={k('pain_title')} body={k('pain_body')} />
        <div className="mt-40 grid gap-24 md:mt-48 md:grid-cols-3">
          {spec.pains.map((Icon, i) => (
            <div key={i} {...rv('up', i)}>
              <div className="kn-lift group flex h-full flex-col gap-12 rounded-xl border border-border-default bg-bg-surface p-24">
                <span className="inline-flex h-[40px] w-[40px] items-center justify-center rounded-full bg-status-warning-bg text-status-warning transition-transform duration-300 group-hover:rotate-[-8deg] group-hover:scale-110">
                  <Icon width={20} height={20} aria-hidden />
                </span>
                <h3 className="mt-4 text-latin-h3 md:text-web-h3">{k(`p${i + 1}`)}</h3>
                <p className="text-latin-body text-text-secondary">{k(`p${i + 1}_b`)}</p>
                <p className="mt-auto flex items-start gap-12 border-t border-border-default pt-16 text-latin-body text-text-primary">
                  <span className="mt-[2px] inline-flex h-[20px] w-[20px] shrink-0 items-center justify-center rounded-full bg-status-success-bg text-status-success">
                    <Check width={12} height={12} aria-hidden />
                  </span>
                  {k(`p${i + 1}_fix`)}
                </p>
              </div>
            </div>
          ))}
        </div>
      </Container>
    </Section>
  );
}

/** The full question list of one ready checklist, in a dialog. */
function Preview({ tpl, t, onClose }: { tpl: PublicChecklistTemplate; t: T; onClose: () => void }) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const d = ref.current;
    if (d && !d.open) d.showModal();
  }, []);
  return (
    <dialog
      ref={ref}
      onClose={onClose}
      onClick={(e) => e.target === ref.current && ref.current?.close()}
      aria-labelledby="tpl-title"
      className="kn-pop m-auto max-h-[85vh] w-[calc(100%-32px)] max-w-[600px] overflow-hidden rounded-xl bg-bg-surface p-0 text-text-primary shadow-lg backdrop:bg-espresso-950/60"
    >
      <div className="flex max-h-[85vh] flex-col">
        <div className="flex items-start justify-between gap-16 border-b border-border-default p-24">
          <div>
            <p className="text-web-eyebrow uppercase text-mocha-700">{t('site.indp.ready_tag')}</p>
            <h3 id="tpl-title" className="mt-4 text-web-h3">
              {tpl.name}
            </h3>
            <p className="mt-4 text-latin-caption text-text-secondary">{t('site.indp.tpl_meta', { n: tpl.question_count, l: tpl.languages.length })}</p>
          </div>
          <button
            type="button"
            onClick={() => ref.current?.close()}
            aria-label={t('site.indp.close')}
            className="inline-flex h-[40px] w-[40px] shrink-0 items-center justify-center rounded-full bg-bg-canvas transition-transform hover:rotate-90"
          >
            <X width={18} height={18} aria-hidden />
          </button>
        </div>
        <ol className="flex flex-col gap-8 overflow-y-auto p-24">
          {tpl.questions.map((q, i) => {
            const Icon = TYPE_ICON[q.type] ?? Check;
            return (
              <li key={i} className="flex items-start gap-12 rounded-md bg-bg-canvas px-12 py-[10px]">
                <span className="w-[20px] shrink-0 pt-[2px] text-right text-latin-caption-strong text-text-secondary">{i + 1}</span>
                <span className="flex-1 text-latin-body">
                  {q.text}
                  {q.unit && <span className="text-text-secondary"> ({q.unit})</span>}
                </span>
                <span className="flex shrink-0 items-center gap-4 text-text-secondary">
                  <Icon width={14} height={14} aria-label={t(`site.indp.type_${q.type}`)} />
                  {q.photo_rule !== 'none' && q.type !== 'photo' && <Camera width={14} height={14} aria-label={t('site.indp.photo_rule')} />}
                </span>
              </li>
            );
          })}
        </ol>
        <div className="flex flex-wrap items-center justify-between gap-12 border-t border-border-default p-16 md:px-24">
          <p className="text-latin-caption text-text-secondary">{t('site.indp.tpl_copy')}</p>
          <LinkButton href={ROUTES.trial} variant="primary">
            {t('site.cta.trial')}
          </LinkButton>
        </div>
      </div>
    </dialog>
  );
}

const ANSWER_TYPES: [LucideIcon, string][] = [
  [Check, 'type_yes_no'],
  [Check, 'type_pass_fail'],
  [Hash, 'type_number'],
  [FileText, 'type_text'],
  [Camera, 'type_photo'],
];

function ReadyChecklists({ spec, trade, t, lang }: { spec: IndustrySpec; trade: TradeOut | undefined; t: T; lang: Lang }) {
  const [data, retry] = useReadyChecklists(spec.key, lang);
  const [open, setOpen] = useState<PublicChecklistTemplate | null>(null);
  const name = trade?.name ?? '';
  const items = data.kind === 'ready' ? data.data.items : [];
  return (
    <Section tone="surface" id="checklists">
      <Container>
        <Heading
          eyebrow={t('site.indp.ready_eyebrow')}
          title={t('site.indp.ready_title', { trade: name })}
          body={t('site.indp.ready_body')}
          align="left"
          className="max-w-[640px]"
        />
        {data.kind === 'loading' ? (
          <div className="mt-40 grid gap-24 md:grid-cols-2 lg:grid-cols-3" aria-busy="true">
            {[0, 1, 2].map((i) => (
              <div key={i} className="kn-shimmer h-[260px] rounded-xl bg-bg-canvas" />
            ))}
          </div>
        ) : data.kind === 'error' ? (
          <p className="mt-40 text-latin-body text-text-secondary">
            {t('site.err.generic')}{' '}
            <button type="button" onClick={retry} className="font-semibold text-text-primary underline">
              {t('site.indp.retry')}
            </button>
          </p>
        ) : items.length ? (
          <div className={`mt-40 grid gap-24 md:mt-48 md:grid-cols-2 ${items.length === 4 ? 'xl:grid-cols-4' : 'lg:grid-cols-3'}`}>
            {items.map((tpl, i) => {
              const more = tpl.question_count - Math.min(3, tpl.questions.length);
              return (
                <div key={tpl.key ?? tpl.name} {...rv('up', i % 3)}>
                  <div className="kn-lift group flex h-full flex-col gap-16 rounded-xl border border-border-default bg-bg-canvas p-24">
                    <div className="flex items-center justify-between gap-8">
                      <span className="inline-flex h-[40px] w-[40px] items-center justify-center rounded-full bg-bg-surface text-mocha-700 transition-transform duration-300 group-hover:scale-110">
                        <ListChecks width={20} height={20} aria-hidden />
                      </span>
                      <span className="rounded-full bg-sage-100 px-[10px] py-4 text-latin-caption-strong text-sage-700">{t('site.indp.ready_tag')}</span>
                    </div>
                    <div>
                      <h3 className="text-latin-h3 md:text-web-h3">{tpl.name}</h3>
                      <p className="mt-4 text-latin-caption text-text-secondary">
                        {t('site.indp.tpl_meta', { n: num(tpl.question_count, lang), l: num(tpl.languages.length, lang) })}
                        {tpl.photo_questions > 0 && ` · ${t('site.indp.tpl_photos')}`}
                      </p>
                    </div>
                    <ul className="flex flex-col gap-8 rounded-md bg-bg-surface p-12">
                      {tpl.questions.slice(0, 3).map((q, n) => (
                        <li key={n} className="flex items-start gap-8 text-latin-label-sm text-text-primary">
                          <Check width={14} height={14} className="mt-[3px] shrink-0 text-status-success" aria-hidden />
                          {q.text}
                        </li>
                      ))}
                      {more > 0 && <li className="pl-[22px] text-latin-caption text-text-secondary">{t('site.indp.more', { n: num(more, lang) })}</li>}
                    </ul>
                    <button
                      type="button"
                      onClick={() => setOpen(tpl)}
                      className="mt-auto inline-flex w-fit items-center gap-4 text-latin-label-sm font-semibold text-text-primary"
                    >
                      <span className="kn-link">{t('site.indp.preview')}</span>
                      <ChevronRight width={14} height={14} className="kn-nudge" aria-hidden />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <div {...rv('up')} className="mt-40 md:mt-48">
            <div className="flex flex-col gap-24 rounded-xl border border-dashed border-border-strong bg-bg-canvas p-24 md:flex-row md:items-center md:justify-between md:p-32">
              <div className="flex max-w-[560px] flex-col gap-8">
                <span className="inline-flex h-[44px] w-[44px] items-center justify-center rounded-full bg-bg-surface text-mocha-700">
                  <Plus width={20} height={20} aria-hidden />
                </span>
                <h3 className="mt-8 text-latin-h3 md:text-web-h3">{t('site.indp.none_title', { trade: name })}</h3>
                <p className="text-latin-body text-text-secondary">{t('site.indp.none_body')}</p>
                <ul className="mt-8 flex flex-wrap gap-8">
                  {ANSWER_TYPES.map(([Icon, key]) => (
                    <li key={key} className="inline-flex items-center gap-[6px] rounded-full bg-bg-surface px-12 py-[6px] text-latin-caption-strong text-text-primary">
                      <Icon width={14} height={14} aria-hidden />
                      {t(`site.indp.${key}`)}
                    </li>
                  ))}
                </ul>
              </div>
              <div className="flex shrink-0 flex-col gap-12 sm:flex-row md:flex-col">
                <LinkButton href={ROUTES.trial} variant="primary">
                  {t('site.cta.trial')}
                </LinkButton>
                <LinkButton href={featureHref('checklists')} variant="outline">
                  {t('site.indp.how_checklists')}
                </LinkButton>
              </div>
            </div>
          </div>
        )}
      </Container>
      {open && <Preview tpl={open} t={t} onClose={() => setOpen(null)} />}
    </Section>
  );
}

function SampleReport({ spec, t, config }: { spec: IndustrySpec; t: T; config: ConfigOut | null }) {
  const k = (s: string) => t(`site.indp.${spec.id}.${s}`);
  const bullets = [k('r_b1'), k('r_b2'), t('site.indp.r_b3'), t('site.indp.r_b4')];
  const labels = spec.id === 'pest_control' ? [k('r_photo1'), k('r_photo2')] : [t('site.indp.before'), t('site.indp.after')];
  return (
    <Section>
      <Container className="flex flex-col gap-40 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex flex-col gap-24 lg:w-[564px]">
          <Heading eyebrow={t('site.indp.sample')} title={t('site.indp.sample_title')} body={k('r_body')} align="left" className="max-w-none" />
          <ul className="flex flex-col gap-12">
            {bullets.map((b, i) => (
              <li key={b} {...rv('left', i + 2, 70)} className="flex items-start gap-12 text-latin-body text-text-primary">
                <span className="mt-[2px] inline-flex h-[20px] w-[20px] shrink-0 items-center justify-center rounded-full bg-status-success-bg text-status-success">
                  <Check width={12} height={12} aria-hidden />
                </span>
                {b}
              </li>
            ))}
          </ul>
        </div>
        <div {...rv('right', 1)} className="w-full lg:w-[540px]">
          <div className="kn-lift relative rounded-xl border border-border-default bg-bg-surface p-24 shadow-md md:p-[28px]">
            <span className="absolute -top-12 left-24 rounded-full bg-mocha-900 px-12 py-4 text-latin-caption-strong text-cream-50">{t('site.indp.sample_label')}</span>
            <div className="flex items-center justify-between gap-8">
              <span className="flex items-center gap-8 text-latin-label-sm font-semibold">
                <span className="inline-flex h-[28px] w-[28px] items-center justify-center rounded-md bg-mocha-900 text-cream-50">
                  <FileText width={14} height={14} aria-hidden />
                </span>
                {k('r_company')}
              </span>
              <span className="inline-flex items-center gap-4 rounded-full bg-status-success-bg px-[10px] py-4 text-latin-caption-strong text-status-success">
                <Check width={12} height={12} aria-hidden />
                {t('site.indp.approved')}
              </span>
            </div>
            <h3 className="mt-16 text-[20px] font-semibold leading-[28px] md:text-web-h3">{k('r_title')}</h3>
            <p className="mt-4 text-latin-caption text-text-secondary">{k('r_meta')}</p>
            <div className="mt-16 grid grid-cols-2 gap-8">
              {spec.report.map((src, i) => (
                <figure key={src} className="group relative overflow-hidden rounded-md">
                  <img src={src} alt={labels[i]} width={238} height={128} loading="lazy" className="kn-zoom aspect-[238/128] w-full object-cover" />
                  <figcaption className="absolute left-8 top-8 rounded-sm bg-espresso-950/70 px-8 py-[2px] text-latin-caption-strong text-cream-50">{labels[i]}</figcaption>
                </figure>
              ))}
            </div>
            <p className="mt-16 text-latin-label-sm font-semibold">{t('site.indp.work_done')}</p>
            <p className="mt-4 text-latin-body text-text-secondary">{k('r_work')}</p>
            <div className="mt-16 flex flex-wrap gap-8">
              <span className="inline-flex items-center gap-4 rounded-full bg-status-success-bg px-[10px] py-4 text-latin-caption-strong text-status-success">
                <ListChecks width={12} height={12} aria-hidden />
                {k('r_checks')}
              </span>
              {config && (
                <span className="inline-flex items-center gap-4 rounded-full bg-cream-200 px-[10px] py-4 text-latin-caption-strong text-mocha-700">
                  <Globe width={12} height={12} aria-hidden />
                  {t('site.indp.written_in', { lang: config.languages.find((l) => l.code === 'en')?.native_name ?? 'English' })}
                </span>
              )}
              <span className="inline-flex items-center gap-4 rounded-full bg-sage-100 px-[10px] py-4 text-latin-caption-strong text-sage-700">
                <Link2 width={12} height={12} aria-hidden />
                {t('site.indp.linked')}
              </span>
            </div>
          </div>
        </div>
      </Container>
    </Section>
  );
}

function Flow({ spec, t }: { spec: IndustrySpec; t: T }) {
  const k = (s: string) => t(`site.indp.${spec.id}.${s}`);
  const steps: { icon: LucideIcon; title: string; body: string }[] = [
    { icon: Camera, title: t('site.indp.f1'), body: k('f1_b') },
    { icon: ListChecks, title: k('f2'), body: t('site.indp.f2_b') },
    { icon: Mic, title: t('site.indp.f3'), body: t('site.indp.f3_b') },
    { icon: FileText, title: t('site.indp.f4'), body: t('site.indp.f4_b') },
  ];
  return (
    <Section tone="dark">
      <Container>
        <Heading eyebrow={t('site.indp.flow_eyebrow')} title={k('flow_title')} body={t('site.indp.flow_body')} dark />
        <ol className="mt-40 grid grid-cols-2 gap-x-16 gap-y-40 md:mt-48 lg:grid-cols-4 lg:gap-24">
          {steps.map((s, i) => (
            <li key={i} {...rv('up', i, 120)} className="group flex flex-col items-center text-center">
              <img
                src={I(`ind-${spec.img}-flow${i + 1}`)}
                alt={s.title}
                width={222}
                height={468}
                loading="lazy"
                className="w-full max-w-[200px] drop-shadow-[0_16px_32px_rgba(0,0,0,0.35)] transition-transform duration-500 group-hover:-translate-y-8 lg:max-w-[222px]"
              />
              <div className="mt-24 flex items-center gap-8 text-cream-200">
                <span className="inline-flex h-[28px] w-[28px] items-center justify-center rounded-full bg-cream-50 text-latin-caption-strong text-mocha-950">{i + 1}</span>
                <s.icon width={18} height={18} className="transition-transform duration-300 group-hover:scale-110" aria-hidden />
              </div>
              <h3 className="mt-12 text-latin-h3 text-cream-50 md:text-web-h3">{s.title}</h3>
              <p className="mt-8 max-w-[260px] text-latin-body text-cream-400">{s.body}</p>
            </li>
          ))}
        </ol>
      </Container>
    </Section>
  );
}

function Features({ spec, t }: { spec: IndustrySpec; t: T }) {
  const k = (s: string) => t(`site.indp.${spec.id}.${s}`);
  return (
    <Section tone="surface">
      <Container>
        <div className="flex flex-wrap items-end justify-between gap-16">
          <div className="flex flex-col gap-8">
            <p {...rv('fade')} className="text-web-eyebrow uppercase text-mocha-700">
              {k('feat_eyebrow')}
            </p>
            <h2 {...rv('up')} className="text-web-m-h2 md:text-web-h2">
              {k('feat_title')}
            </h2>
          </div>
          <a {...rv('left', 1)} href={ROUTES.features} className="group inline-flex items-center gap-4 text-web-label font-semibold text-text-primary">
            <span className="kn-link">{t('site.fp.all')}</span>
            <ChevronRight width={16} height={16} className="kn-nudge" aria-hidden />
          </a>
        </div>
        <div className="mt-32 grid gap-16 sm:grid-cols-2 lg:grid-cols-4 lg:gap-24">
          {spec.features.map((id, i) => {
            const Icon = feature(id).icon;
            return (
              <div key={id} {...rv('up', i)}>
                <a href={featureHref(id)} className="kn-lift group flex h-full flex-col gap-12 rounded-xl border border-border-default bg-bg-canvas p-24 hover:border-mocha-300">
                  <IconDot size={40}>
                    <Icon width={20} height={20} aria-hidden />
                  </IconDot>
                  <h3 className="mt-4 text-latin-h3 md:text-web-h3">{t(`site.fp.${id}.name`)}</h3>
                  <p className="text-latin-body text-text-secondary">{t(`site.fp.${id}.card`)}</p>
                  <span className="mt-auto inline-flex items-center gap-4 pt-4 text-latin-label-sm font-semibold text-text-primary">
                    <span className="kn-link">{t('site.fp.learn')}</span>
                    <ChevronRight width={14} height={14} className="kn-nudge" aria-hidden />
                  </span>
                </a>
              </div>
            );
          })}
        </div>
      </Container>
    </Section>
  );
}

/** W18–W23: one page per trade. Checklists come live from GET /public/checklist-templates. */
export default function IndustryPage({
  t,
  lang,
  spec,
  config,
  plans,
  retryPlans,
}: {
  t: T;
  lang: Lang;
  spec: IndustrySpec;
  config: ConfigOut | null;
  plans: Load<PlansOut>;
  retryPlans: () => void;
}) {
  const k = (s: string) => t(`site.indp.${spec.id}.${s}`);
  const trade = config?.trades.find((x) => x.key === spec.key);
  const name = trade?.name ?? '';
  const ready = trade?.checklists ?? 0;
  const ticks = [
    ...(trade ? [ready === 1 ? t('site.indp.ready_one') : ready ? t('site.indp.ready_n', { n: num(ready, lang) }) : t('site.fp.build_own')] : []),
    k('tick'),
    ...(config ? [t('site.fp.ov.langs', { n: num(config.languages.length, lang) })] : []),
  ];
  const faq = [
    { q: k('q1'), a: k('ans1') },
    { q: t('site.indp.q2'), a: t('site.indp.ans2') },
    { q: t('site.indp.q3'), a: t('site.indp.ans3') },
    { q: t('site.indp.q4'), a: t('site.indp.ans4') },
  ];
  return (
    <>
      <FeatureHero
        t={t}
        root={{ href: '/#industries', label: t('site.indp.crumb') }}
        crumb={name}
        pill={t('site.indp.pill', { trade: name })}
        pillIcon={<ListChecks width={16} height={16} aria-hidden />}
        title={k('title')}
        body={k('body')}
        ticks={ticks}
      >
        <HeroPicture spec={spec} t={t} alt={t('site.indp.alt', { trade: name })} />
      </FeatureHero>
      <Pains spec={spec} t={t} />
      <ReadyChecklists spec={spec} trade={trade} t={t} lang={lang} />
      <SampleReport spec={spec} t={t} config={config} />
      <Flow spec={spec} t={t} />
      <Features spec={spec} t={t} />
      <HomePricing t={t} lang={lang} plans={plans} retry={retryPlans} title={k('price_title')} />
      <Faq t={t} title={t('site.faq.title')} body={t('site.faq.body')} items={faq} />
      <FinalCta t={t} trialDays={plans.kind === 'ready' ? plans.data.trial_days : null} title={k('cta')} />
    </>
  );
}

