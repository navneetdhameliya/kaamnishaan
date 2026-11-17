import { FileText } from 'lucide-react';
import { useState } from 'react';

import type { Lang, T } from '../lib/i18n';
import type { PlansOut } from '../lib/types';
import { Container, Faq, FinalCta, Section, Tick } from './parts';
import { rv } from './motion';
import { BillingSwitch, Comparison, CreditsCard, PlanGrid, PriceState } from './plans';

type Load<D> = { kind: 'loading' } | { kind: 'ready'; data: D } | { kind: 'error' };

/** W02 Pricing: every plan from GET /plans, monthly or annual, the credits and the full comparison. */
export default function Pricing({ t, lang, plans, retryPlans }: { t: T; lang: Lang; plans: Load<PlansOut>; retryPlans: () => void }) {
  const [annual, setAnnual] = useState(false);
  const data = plans.kind === 'ready' ? plans.data : null;
  const pro = data?.plans.find((p) => p.most_popular)?.name ?? '';
  return (
    <>
      <section className="relative overflow-hidden bg-espresso-950 py-48 md:py-64">
        <div
          aria-hidden
          className="pointer-events-none absolute -right-[160px] -top-[200px] hidden h-[560px] w-[560px] animate-[spin_70s_linear_infinite] rounded-full border-[56px] border-mocha-950 border-b-transparent md:block"
        />
        <Container className="relative flex flex-col items-center gap-24 text-center">
          <span {...rv('down')} className="inline-flex items-center gap-8 rounded-full border border-cream-100/[0.14] bg-cream-100/[0.06] px-12 py-[6px] text-web-eyebrow uppercase text-cream-200">
            <FileText width={14} height={14} aria-hidden />
            {t('site.pp.eyebrow')}
          </span>
          <h1 {...rv('up', 1)} className="text-web-m-display text-cream-50 md:text-web-display">
            {t('site.pp.title')}
          </h1>
          {data && (
            <p {...rv('up', 2)} className="max-w-[640px] text-latin-body-lg text-cream-400 md:text-web-body-lg">
              {t('site.pp.body', { currency: data.currency, plan: pro, n: data.trial_days })}
            </p>
          )}
          <div {...rv('zoom', 3)}>
            <BillingSwitch annual={annual} onChange={setAnnual} t={t} />
          </div>
        </Container>
      </section>
      <Section className="!pt-48 md:!pt-64">
        <Container>
          {data ? (
            <>
              <PlanGrid data={data} t={t} lang={lang} annual={annual} showAnnualLine />
              <div {...rv('up')} className="mt-32 flex flex-wrap justify-center gap-x-32 gap-y-8">
                <Tick>{t('site.pp.n1', { currency: data.currency })}</Tick>
                <Tick>{t('site.pp.n2')}</Tick>
                <Tick>{t('site.pp.n3', { n: data.trial_days, plan: pro })}</Tick>
                <Tick>{t('site.pp.n4')}</Tick>
              </div>
              <CreditsCard data={data} t={t} lang={lang} />
            </>
          ) : (
            <PriceState kind={plans.kind === 'error' ? 'error' : 'loading'} t={t} retry={retryPlans} />
          )}
        </Container>
      </Section>
      {data && <Comparison data={data} t={t} lang={lang} />}
      <Faq
        t={t}
        title={t('site.pfaq.title')}
        body={t('site.pfaq.body')}
        items={[1, 2, 3, 4, 5]
          .filter((i) => i !== 1 || data != null)
          .map((i) => ({ q: t(`site.pfaq.q${i}`, { n: data?.trial_days ?? '' }), a: t(`site.pfaq.a${i}`) }))}
      />
      <FinalCta t={t} trialDays={data?.trial_days ?? null} />
    </>
  );
}
