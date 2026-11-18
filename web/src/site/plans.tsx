import { Check, FileText, Minus, Phone, Plus, Share2, Star, User } from 'lucide-react';
import { Fragment, useState, type ReactNode } from 'react';

import { cx } from '../components/ui';
import type { Lang, T } from '../lib/i18n';
import type { PlanOut, PlansOut } from '../lib/types';
import { LinkButton } from './Layout';
import { rv } from './motion';
import { Container, Section } from './parts';
import { money, num, ROUTES } from './site';

/** The order features are listed in, on the cards and in the table. */
const CAPTURE = ['capture', 'offline', 'ai_reports', 'report_links', 'branded_pdf'];
const APPROVALS = ['manager_approvals', 'ai_assistant', 'custom_checklists'];
const SECURITY = ['sso_audit', 'custom_integrations'];
const ORDER = [...CAPTURE, ...APPROVALS, ...SECURITY];

/** Free shows its basics; every other plan shows "Everything in <previous>" and what it adds. */
export function planBullets(plans: PlanOut[], i: number, t: T): string[] {
  const p = plans[i]!;
  if (i === 0) return ['capture', 'ai_reports', 'offline'].filter((f) => p.features.includes(f)).map((f) => t(`site.f.${f}`));
  const prev = plans[i - 1]!;
  const added = ORDER.filter((f) => p.features.includes(f) && !prev.features.includes(f)).map((f) => t(`site.f.${f}`));
  const support = p.support && p.support !== prev.support && p.support !== 'email' ? [t(`site.support_line.${p.support}`)] : [];
  return [t('site.price.everything', { plan: prev.name }), ...added, ...support];
}

function limits(p: PlanOut, t: T, lang: Lang): string {
  const techs = p.technician_limit === 1 ? t('site.price.tech_one') : t('site.price.techs', { n: num(p.technician_limit ?? 0, lang) });
  if (p.price?.amount === 0) return `${techs} · ${t('site.price.ai_reports', { n: num(p.report_limit_monthly ?? 0, lang) })}`;
  const reports = p.report_limit_monthly == null ? t('site.price.fair') : t('site.price.reports', { n: num(p.report_limit_monthly, lang) });
  return `${techs} · ${reports}`;
}

/** One plan card (W01 Pricing, W02 Plans). */
function PlanCard({
  plans,
  i,
  t,
  lang,
  annual,
  showAnnualLine,
}: {
  plans: PlanOut[];
  i: number;
  t: T;
  lang: Lang;
  annual: boolean;
  showAnnualLine: boolean;
}) {
  const p = plans[i]!;
  const dark = p.most_popular;
  const free = p.price?.amount === 0;
  const custom = p.price == null;
  const yearly = annual && p.annual_price != null;
  const cta = free
    ? { href: ROUTES.trial, label: t('site.price.start_free'), variant: 'secondary' as const }
    : custom
      ? { href: ROUTES.contact, label: t('site.price.contact'), variant: 'secondary' as const }
      : { href: ROUTES.trial, label: t('site.nav.trial'), variant: dark ? ('light' as const) : ('primary' as const) };
  return (
    <article
      className={cx(
        'kn-lift group relative flex h-full flex-col rounded-xl p-24',
        dark ? 'bg-mocha-900 text-cream-50 shadow-lg' : 'border border-border-default bg-bg-surface hover:border-mocha-300',
      )}
    >
      {p.most_popular && (
        <span className="kn-glow absolute left-24 top-[-13px] rounded-full bg-sage-500 px-12 py-4 text-web-eyebrow uppercase text-mocha-950">
          {t('site.price.popular')}
        </span>
      )}
      <h3 className={cx('mt-8 text-web-h3', dark ? 'text-cream-50' : 'text-text-primary')}>{p.name}</h3>
      <div className="mt-12 flex items-baseline gap-8">
        {custom ? (
          <span className="text-[40px] font-bold leading-[48px]">{t('site.price.custom')}</span>
        ) : (
          <>
            <span key={yearly ? 'y' : 'm'} className="kn-pop text-web-display">
              {money(yearly ? p.annual_price! : p.price!, lang)}
            </span>
            <span className={cx('text-latin-body', dark ? 'text-cream-400' : 'text-text-secondary')}>
              {free ? t('site.price.forever') : yearly ? t('site.price.year') : t('site.price.month')}
            </span>
          </>
        )}
      </div>
      <div className="mt-8 flex flex-col gap-4">
        {custom ? (
          <>
            <p className="text-latin-caption-strong text-mocha-700">{t('site.price.large')}</p>
            <p className="text-latin-caption text-text-secondary">{t('site.price.annual_contract')}</p>
          </>
        ) : (
          <>
            <p className={cx('text-latin-caption-strong', dark ? 'text-cream-200' : 'text-mocha-700')}>{limits(p, t, lang)}</p>
            {p.monthly_credits != null && (
              <p className={cx('inline-flex items-center gap-4 text-[12px] font-semibold leading-[16px]', dark ? 'text-cream-400' : 'text-text-secondary')}>
                <Star width={12} height={12} className="fill-amber-600 text-amber-600" aria-hidden />
                {t('site.price.credits', { n: num(p.monthly_credits, lang) })}
              </p>
            )}
            {free && <p className="text-latin-caption text-text-secondary">{t('site.price.no_card')}</p>}
            {showAnnualLine && !free && p.annual_price && (
              <p className={cx('text-latin-caption', dark ? 'text-cream-400' : 'text-text-secondary')}>
                {yearly
                  ? t('site.pp.two_free')
                  : t('site.price.or_year', { price: money(p.annual_price, lang) })}
              </p>
            )}
          </>
        )}
      </div>
      <hr className={cx('my-20 border-t', dark ? 'border-cream-100/[0.14]' : 'border-border-default')} />
      <ul className="flex flex-1 flex-col gap-12">
        {planBullets(plans, i, t).map((b) => (
          <li key={b} className="flex gap-12 text-latin-body">
            <Check
              width={18}
              height={18}
              className={cx('mt-[3px] shrink-0 transition-transform duration-300 group-hover:scale-125', dark ? 'text-sage-500' : 'text-status-success')}
              aria-hidden
            />
            {b}
          </li>
        ))}
      </ul>
      <LinkButton href={cta.href} variant={cta.variant} size="md" className="mt-24 w-full">
        {cta.label}
      </LinkButton>
    </article>
  );
}

export function PlanGrid({
  data,
  t,
  lang,
  codes,
  annual = false,
  showAnnualLine = false,
}: {
  data: PlansOut;
  t: T;
  lang: Lang;
  codes?: string[];
  annual?: boolean;
  showAnnualLine?: boolean;
}) {
  const shown = data.plans.map((p, i) => ({ p, i })).filter(({ p }) => !codes || codes.includes(p.code));
  return (
    <div
      className={cx(
        'grid gap-16 sm:grid-cols-2',
        shown.length >= 5 ? 'lg:grid-cols-3 xl:grid-cols-5 xl:gap-[14px]' : 'lg:grid-cols-4',
      )}
    >
      {shown.map(({ p, i }, n) => (
        <div key={p.code} {...rv('up', n)}>
          <PlanCard plans={data.plans} i={i} t={t} lang={lang} annual={annual} showAnnualLine={showAnnualLine} />
        </div>
      ))}
    </div>
  );
}

/** "Free forever for 1 technician" strip under the home pricing cards. */
export function FreeStrip({ plan, t }: { plan: PlanOut; t: T }) {
  return (
    <div {...rv('up')} className="mt-32">
    <div className="group flex flex-col gap-16 rounded-xl border border-dashed border-border-strong p-20 transition-colors duration-300 hover:border-solid hover:border-status-success hover:bg-bg-surface sm:flex-row sm:items-center sm:justify-between md:px-24">
      <div className="flex items-center gap-16">
        <span className="inline-flex h-[44px] w-[44px] shrink-0 items-center justify-center rounded-full bg-status-success-bg text-status-success transition-transform duration-500 group-hover:rotate-[360deg]">
          <User width={20} height={20} aria-hidden />
        </span>
        <div>
          <p className="text-web-h3">{t('site.price.free_title')}</p>
          <p className="text-latin-body text-text-secondary">{t('site.price.free_body', { n: plan.report_limit_monthly ?? 0 })}</p>
        </div>
      </div>
      <LinkButton href={ROUTES.trial} variant="outline" size="md">
        {t('site.price.start_free')}
      </LinkButton>
    </div>
    </div>
  );
}

export function PriceState({ kind, t, retry }: { kind: 'loading' | 'error'; t: T; retry: () => void }) {
  if (kind === 'loading')
    return (
      <div className="grid gap-16 sm:grid-cols-2 lg:grid-cols-4" aria-busy="true" aria-label={t('site.price.loading')}>
        {[0, 1, 2, 3].map((i) => (
          <div key={i} className="kn-shimmer h-[420px] rounded-xl" />
        ))}
      </div>
    );
  return (
    <div className="rounded-xl border border-border-default bg-bg-surface p-24 text-center">
      <p className="text-latin-body text-text-secondary">{t('site.price.error')}</p>
      <button type="button" onClick={retry} className="kn-link mt-12 text-web-label font-semibold text-text-primary">
        {t('site.price.retry')}
      </button>
    </div>
  );
}

/** W02 "Follow-up credits": what each message costs and the top-up pack. */
export function CreditsCard({ data, t, lang }: { data: PlansOut; t: T; lang: Lang }) {
  const r = data.credit_rules;
  const cost = (n: number) => (n === 0 ? t('site.cr.free') : n === 1 ? t('site.cr.one') : t('site.cr.many', { n: num(n, lang) }));
  const pack = data.credit_packs[0];
  const items: { icon: ReactNode; big: string; small: string }[] = [
    { icon: <Share2 width={18} height={18} />, big: cost(r.sms), small: t('site.cr.sms') },
    { icon: <Phone width={18} height={18} />, big: cost(r.ai_call), small: t('site.cr.call') },
    { icon: <FileText width={18} height={18} />, big: cost(r.email), small: t('site.cr.email') },
    ...(pack ? [{ icon: <Plus width={18} height={18} />, big: money(pack.price, lang), small: t('site.cr.pack', { n: num(pack.credits, lang) }) }] : []),
  ];
  return (
    <div {...rv('up')} className="mt-40 flex flex-col gap-24 rounded-xl border border-border-default bg-bg-surface p-24 md:p-32 lg:flex-row lg:items-center lg:justify-between">
      <div className="lg:max-w-[400px]">
        <h3 className="text-web-h3">{t('site.cr.title')}</h3>
        <p className="mt-8 text-latin-body text-text-secondary md:text-web-body">{t('site.cr.body')}</p>
      </div>
      <ul className="grid grid-cols-2 gap-12 sm:grid-cols-4 lg:w-[560px]">
        {items.map((it) => (
          <li key={it.small} className="kn-lift group flex flex-col gap-4 rounded-lg bg-bg-canvas p-16">
            <span className="inline-block text-mocha-700 transition-transform duration-300 group-hover:-rotate-12 group-hover:scale-125" aria-hidden>
              {it.icon}
            </span>
            <span className="text-[20px] font-semibold leading-[28px]">{it.big}</span>
            <span className="text-latin-caption text-text-secondary">{it.small}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

/** W02 "Compare every feature". */
export function Comparison({ data, t, lang }: { data: PlansOut; t: T; lang: Lang }) {
  const plans = data.plans;
  const head = (p: PlanOut) =>
    p.price == null ? t('site.price.custom') : p.price.amount === 0 ? money(p.price, lang) : t('site.cmp.per_mo', { price: money(p.price, lang) });
  const value = (p: PlanOut, row: string): ReactNode => {
    if (row === 'technicians') return p.technician_limit == null ? t('site.price.custom') : num(p.technician_limit, lang);
    if (row === 'reports')
      return p.report_limit_monthly != null ? num(p.report_limit_monthly, lang) : p.price == null ? t('site.price.custom') : t('site.cmp.fair');
    if (row === 'support') return p.support ? t(`site.support.${p.support}`) : '—';
    return p.features.includes(row) ? (
      <Check width={18} height={18} className="mx-auto text-status-success" aria-label={t('site.cmp.yes')} />
    ) : (
      <Minus width={16} height={16} className="mx-auto text-taupe-400" aria-label={t('site.cmp.no')} />
    );
  };
  const groups: { title: string; rows: { key: string; label: string }[] }[] = [
    {
      title: t('site.cmp.g_team'),
      rows: [
        { key: 'technicians', label: t('site.cmp.technicians') },
        { key: 'reports', label: t('site.cmp.reports') },
      ],
    },
    { title: t('site.cmp.g_capture'), rows: CAPTURE.map((k) => ({ key: k, label: t(`site.f.${k}`) })) },
    { title: t('site.cmp.g_approvals'), rows: APPROVALS.map((k) => ({ key: k, label: t(`site.f.${k}`) })) },
    {
      title: t('site.cmp.g_security'),
      rows: [...SECURITY.map((k) => ({ key: k, label: t(`site.f.${k}`) })), { key: 'support', label: t('site.cmp.support') }],
    },
  ];
  const pop = (p: PlanOut) => p.most_popular;
  return (
    <Section tone="surface" id="compare">
      <Container>
        <div className="mx-auto mb-40 flex max-w-[760px] flex-col gap-16 text-center md:mb-48">
          <h2 {...rv('up')} className="text-web-m-h2 md:text-web-h2">{t('site.cmp.title')}</h2>
          <p {...rv('up', 1)} className="text-latin-body-lg text-text-secondary md:text-web-body-lg">{t('site.cmp.body')}</p>
        </div>
        <div {...rv('up', 2)} className="overflow-x-auto rounded-xl border border-border-default">
          <table className="w-full min-w-[760px] border-collapse bg-bg-surface text-left">
            <thead>
              <tr>
                <th scope="col" className="sticky left-0 z-10 w-[260px] bg-bg-surface p-16">
                  <span className="sr-only">{t('site.cmp.feature')}</span>
                </th>
                {plans.map((p) => (
                  <th
                    key={p.code}
                    scope="col"
                    className={cx('px-8 py-20 text-center', pop(p) ? 'bg-mocha-900 text-cream-50' : 'text-text-primary')}
                  >
                    <span className="block text-web-label font-semibold">{p.name}</span>
                    <span className={cx('block text-latin-caption font-normal', pop(p) ? 'text-cream-400' : 'text-text-secondary')}>{head(p)}</span>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {groups.map((g) => (
                <Fragment key={g.title}>
                  <tr className="border-t border-border-default bg-bg-canvas">
                    <th colSpan={plans.length + 1} scope="colgroup" className="px-16 py-12 text-web-eyebrow uppercase text-mocha-700">
                      {g.title}
                    </th>
                  </tr>
                  {g.rows.map((r) => (
                    <tr key={r.key} className="kn-row border-t border-border-default">
                      <th scope="row" className="sticky left-0 z-10 bg-bg-surface px-16 py-12 text-latin-body font-normal">
                        {r.label}
                      </th>
                      {plans.map((p) => (
                        <td
                          key={p.code}
                          className={cx('px-8 py-12 text-center text-latin-label-sm font-semibold', pop(p) && 'bg-cream-200/50')}
                        >
                          {value(p, r.key)}
                        </td>
                      ))}
                    </tr>
                  ))}
                </Fragment>
              ))}
            </tbody>
          </table>
        </div>
      </Container>
    </Section>
  );
}

/** Monthly / Annual switch on W02. */
export function BillingSwitch({ annual, onChange, t }: { annual: boolean; onChange: (a: boolean) => void; t: T }) {
  const opt = (on: boolean, label: ReactNode, value: boolean) => (
    <button
      type="button"
      role="radio"
      aria-checked={on}
      onClick={() => onChange(value)}
      className={cx(
        'inline-flex h-[40px] items-center gap-8 rounded-full px-20 text-web-label font-semibold transition-all duration-300 active:scale-95',
        on ? 'bg-cream-50 text-mocha-950 shadow-md' : 'text-cream-200 hover:bg-cream-100/[0.08] hover:text-cream-50',
      )}
    >
      {label}
    </button>
  );
  return (
    <div role="radiogroup" className="inline-flex rounded-full border border-cream-100/[0.14] bg-cream-100/[0.06] p-4">
      {opt(!annual, t('site.pp.monthly'), false)}
      {opt(
        annual,
        <>
          {t('site.pp.annual')}
          <span className="kn-glow rounded-full bg-sage-500 px-8 py-2 text-[12px] leading-[16px] text-mocha-950">{t('site.pp.two_free')}</span>
        </>,
        true,
      )}
    </div>
  );
}

export function useAnnual() {
  return useState(false);
}
