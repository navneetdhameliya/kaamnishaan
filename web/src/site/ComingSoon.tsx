import { ChevronRight } from 'lucide-react';

import type { T } from '../lib/i18n';
import { LinkButton } from './Layout';
import { Container } from './parts';
import { ROUTES } from './site';

/** Pages from the next website steps (demo, trial, log in, features, industries, legal…). */
export default function ComingSoon({ t }: { t: T }) {
  return (
    <section className="bg-bg-canvas py-[96px]">
      <Container className="flex max-w-[640px] flex-col items-center gap-16 text-center">
        <h1 className="text-web-m-h2 md:text-web-h2">{t('site.soon.title')}</h1>
        <p className="text-latin-body-lg text-text-secondary">{t('site.soon.body')}</p>
        <div className="mt-16 flex flex-wrap justify-center gap-16">
          <LinkButton href={ROUTES.home} variant="primary" size="md">
            {t('site.soon.home')}
          </LinkButton>
          <LinkButton href={ROUTES.pricing} variant="secondary" size="md" icon={<ChevronRight width={18} height={18} aria-hidden />}>
            {t('site.nav.pricing')}
          </LinkButton>
        </div>
      </Container>
    </section>
  );
}
