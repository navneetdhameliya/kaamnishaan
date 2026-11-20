import { CreditCard, Lock } from 'lucide-react';
import { useEffect, useState } from 'react';

import { api, ApiError } from '../lib/api';
import type { T } from '../lib/i18n';
import type { AdminPaymentsOut } from '../lib/types';

/** A18 Payments. Online payments are set up in the testing phase; until then this says so plainly. */
export function Payments({ t }: { t: T }) {
  const [data, setData] = useState<AdminPaymentsOut | null>(null);
  const [error, setError] = useState(false);
  useEffect(() => {
    api<AdminPaymentsOut>('/admin/payments').then(setData).catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, []);
  if (error) return <p role="alert" className="rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">{t('admin.err.load')}</p>;
  if (!data) return <div aria-busy="true" className="kn-shimmer h-[320px] rounded-xl bg-bg-surface" />;
  return (
    <div className="flex flex-col gap-16">
      <div className="kn-in flex flex-col items-center rounded-xl border border-border-default bg-bg-surface px-24 py-48 text-center">
        <span className="kn-pop inline-flex h-[88px] w-[88px] items-center justify-center rounded-full bg-bg-subtle text-mocha-700">
          <CreditCard width={32} height={32} aria-hidden />
        </span>
        <h2 className="mt-16 text-[24px] font-bold">{t('admin.pm.title')}</h2>
        <p className="mt-8 max-w-[520px] text-latin-body text-text-secondary">{t('admin.pm.body', { provider: data.provider ? t(`admin.pm.provider.${data.provider}`) : '—' })}</p>
        <ul className="mt-16 flex max-w-[520px] flex-col gap-4 text-left text-[14px]">
          {(['invoices', 'methods', 'failed', 'refunds'] as const).map((k, i) => (
            <li key={k} className="kn-in flex items-start gap-8" style={{ ['--d' as string]: `${200 + i * 60}ms` }}>
              <span aria-hidden className="mt-[7px] inline-block h-[6px] w-[6px] shrink-0 rounded-full bg-mocha-700" />
              {t(`admin.pm.will.${k}`)}
            </li>
          ))}
        </ul>
      </div>
      <p className="kn-in flex items-center gap-8 text-[13px] text-text-secondary" style={{ ['--d' as string]: '300ms' }}>
        <Lock width={14} height={14} aria-hidden />
        {t('admin.pm.cards')}
      </p>
    </div>
  );
}
