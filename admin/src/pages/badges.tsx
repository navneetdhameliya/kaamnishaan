import { AlertCircle, Ban, Check, Clock, PauseCircle } from 'lucide-react';

import { plural, type T } from '../lib/i18n';
import type { CompanyBadge } from '../lib/types';
import { cx } from '../ui';

const LOOK: Record<CompanyBadge, { cls: string; icon: typeof Check }> = {
  active: { cls: 'bg-status-success-bg text-status-success', icon: Check },
  near_limit: { cls: 'bg-status-warning-bg text-status-warning', icon: AlertCircle },
  past_due: { cls: 'bg-status-danger-bg text-status-danger', icon: AlertCircle },
  trial: { cls: 'bg-bg-subtle text-mocha-700', icon: Clock },
  suspended: { cls: 'bg-cream-200 text-taupe-550', icon: PauseCircle },
  cancelled: { cls: 'bg-cream-200 text-taupe-550', icon: Ban },
};

/** Company status pill: Active, Near limit, Past due, Trial · 9 days left, Suspended, Cancelled. */
export function StatusBadge({ t, badge, daysLeft, size = 'sm' }: { t: T; badge: CompanyBadge; daysLeft?: number | null; size?: 'sm' | 'md' }) {
  const l = LOOK[badge];
  const Icon = l.icon;
  const text =
    badge === 'trial' && daysLeft !== null && daysLeft !== undefined
      ? daysLeft === 0
        ? t('admin.co.trial_ended')
        : plural(t, 'admin.co.trial_left', daysLeft)
      : t(`admin.co.st.${badge}`);
  return (
    <span className={cx('inline-flex w-fit items-center gap-4 whitespace-nowrap rounded-full font-semibold', size === 'md' ? 'px-12 py-4 text-[14px]' : 'px-[10px] py-[3px] text-[13px]', l.cls)}>
      <Icon width={14} height={14} aria-hidden />
      {text}
    </span>
  );
}
