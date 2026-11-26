import { AlertCircle, Briefcase, ChevronLeft, Clock, FileText, Globe, Link2, Lock, MapPin, Pencil, Power, ScrollText, SlidersHorizontal, Timer, User } from 'lucide-react';
import { useCallback, useEffect, useState, type ReactNode } from 'react';

import { api, ApiError } from '../lib/api';
import { ago, day, money, num, plural, region, type Lang, type T } from '../lib/i18n';
import { session } from '../lib/session';
import type { CompanyDetail as Detail, OwnerInvite, PlanInfo } from '../lib/types';
import { cx, Initials, Link, ReasonDialog, Spinner } from '../ui';
import { InvitePanel } from './CompanyForm';
import { StatusBadge } from './badges';

const stagger = (i: number) => ({ ['--d' as string]: `${i * 60}ms` });

function price(p: PlanInfo, currency: string, lang: Lang): string | null {
  const v = p.prices[currency] ?? p.prices.INR ?? p.prices.USD;
  const cur = p.prices[currency] !== undefined ? currency : p.prices.INR !== undefined ? 'INR' : 'USD';
  return v === undefined ? null : money(v, cur, lang);
}

function Stat({ label, icon: Icon, value, sub, tone, i }: { label: string; icon: typeof User; value: string; sub: string; tone?: 'warn'; i: number }) {
  return (
    <div className="kn-in" style={stagger(i)}>
      <div className="kn-hover h-full rounded-xl border border-border-default bg-bg-surface p-20">
        <div className="flex items-start justify-between gap-8">
          <p className="text-[14px] font-semibold">{label}</p>
          <span className="inline-flex h-[32px] w-[32px] shrink-0 items-center justify-center rounded-full bg-bg-subtle">
            <Icon width={16} height={16} aria-hidden />
          </span>
        </div>
        <p className="mt-12 text-[30px] font-bold leading-[40px] tabular-nums sm:text-[34px]">{value}</p>
        <p className={cx('mt-4 text-[13px]', tone === 'warn' ? 'font-semibold text-status-warning' : 'text-text-secondary')}>{sub}</p>
      </div>
    </div>
  );
}

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-16 py-8">
      <dt className="shrink-0 text-[13px] text-text-secondary">{label}</dt>
      <dd className="text-right text-[14px] font-semibold">{children}</dd>
    </div>
  );
}

function minutes(m: number, t: T, lang: Lang): string {
  return m < 90 ? t('admin.co.minutes', { n: num(Math.round(m), lang) }) : t('admin.co.hours', { n: num(Math.round(m / 6) / 10, lang) });
}

/** A05 Company details (overview), from GET /admin/companies/{id}. Read only for now. */
export function CompanyDetail({ t, lang, id, onName }: { t: T; lang: Lang; id: string; onName: (name: string) => void }) {
  const [d, setD] = useState<Detail | null>(null);
  const [error, setError] = useState<'missing' | 'load' | null>(null);
  const [dialog, setDialog] = useState<'suspend' | 'reactivate' | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [invite, setInvite] = useState<OwnerInvite | null>(null);
  const [linkBusy, setLinkBusy] = useState(false);
  const canChange = session.get()?.staff.role !== 'support';
  const act = async (kind: 'suspend' | 'reactivate', reason: string): Promise<string | null> => {
    try {
      setD(await api<Detail>(`/admin/companies/${id}/${kind}?locale=${lang}`, { method: 'POST', body: { reason } }));
      setDialog(null);
      setNotice(t(kind === 'suspend' ? 'admin.cf.done_suspend' : 'admin.cf.done_reactivate'));
      return null;
    } catch (e) {
      return e instanceof ApiError && e.status === 403 ? t('admin.cf.not_allowed') : t('admin.err.generic');
    }
  };
  const newLink = async () => {
    setLinkBusy(true);
    try {
      const out = await api<OwnerInvite>(`/admin/companies/${id}/owner-invite?locale=${lang}`, { method: 'POST' });
      setInvite(out);
      setD(out.company);
    } catch {
      setNotice(t('admin.err.generic'));
    } finally {
      setLinkBusy(false);
    }
  };
  const load = useCallback(() => {
    setError(null);
    api<Detail>(`/admin/companies/${id}?locale=${lang}`)
      .then((x) => {
        setD(x);
        onName(x.name);
      })
      .catch((e) => {
        if (e instanceof ApiError && (e.status === 404 || e.status === 422)) setError('missing');
        else if (!(e instanceof ApiError && e.status === 401)) setError('load');
      });
  }, [id, lang, onName]);
  useEffect(load, [load]);

  const back = (
    <div className="flex flex-wrap items-center justify-between gap-12">
      <Link to="/companies" className="group inline-flex w-fit items-center gap-4 text-latin-label-sm font-semibold text-text-secondary hover:text-text-primary">
        <ChevronLeft width={16} height={16} className="transition-transform group-hover:-translate-x-[3px]" aria-hidden />
        {t('admin.co.back')}
      </Link>
      <div className="flex flex-wrap items-center gap-12">
        <Link to={`/audit-logs?company=${id}&days=90`} className="kn-link inline-flex items-center gap-[6px] text-latin-label-sm font-semibold text-mocha-700">
          <ScrollText width={16} height={16} aria-hidden />
          {t('admin.au.audit_link')}
        </Link>
        {canChange && d && (
          <>
            <Link to={`/companies/${id}/edit`} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300">
              <Pencil width={16} height={16} aria-hidden />
              {t('admin.cf.edit')}
            </Link>
            {d.status === 'suspended' ? (
              <button type="button" onClick={() => setDialog('reactivate')} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed">
                <Power width={16} height={16} aria-hidden />
                {t('admin.cf.reactivate')}
              </button>
            ) : (
              <button type="button" onClick={() => setDialog('suspend')} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-status-danger px-16 text-latin-label-sm font-semibold text-cream-50 hover:brightness-95">
                <Lock width={16} height={16} aria-hidden />
                {t('admin.cf.suspend')}
              </button>
            )}
          </>
        )}
      </div>
    </div>
  );
  if (error)
    return (
      <div className="flex flex-col gap-16">
        {back}
        <div className="kn-in mx-auto mt-24 max-w-[480px] rounded-xl border border-border-default bg-bg-surface p-24 text-center">
          <p className="text-latin-body text-text-secondary">{t(error === 'missing' ? 'admin.co.not_found' : 'admin.err.load')}</p>
          {error === 'load' && (
            <button type="button" onClick={load} className="kn-btn mt-16 inline-flex h-[44px] items-center rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action">
              {t('admin.retry')}
            </button>
          )}
        </div>
      </div>
    );
  if (!d)
    return (
      <div aria-busy="true" className="flex flex-col gap-24">
        <div className="kn-shimmer h-[140px] rounded-xl bg-bg-surface" />
        <div className="grid gap-16 sm:grid-cols-2 xl:grid-cols-4">
          {[0, 1, 2, 3].map((i) => (
            <div key={i} className="kn-shimmer h-[132px] rounded-xl bg-bg-surface" />
          ))}
        </div>
      </div>
    );

  const plan = d.plan;
  const planPrice = price(plan, d.currency, lang);
  const seatsFull = plan.technician_limit !== null && d.technicians >= plan.technician_limit;
  const overReports = plan.report_limit_monthly !== null && d.reports_this_cycle > plan.report_limit_monthly;
  const health = { good: 'text-status-success', quiet: 'text-status-warning', at_risk: 'text-status-danger' }[d.health];
  const upgradePrice = d.upgrade_to ? price(d.upgrade_to, d.currency, lang) : null;

  return (
    <div className="flex flex-col gap-24">
      {back}
      {notice && (
        <p role="status" className="kn-pop -my-8 rounded-lg bg-status-success-bg px-16 py-12 text-latin-label-sm font-semibold text-status-success">
          {notice}
        </p>
      )}
      {(d.purge_at || d.purged_at) && (
        <p role="note" className="flex items-start gap-12 rounded-lg bg-status-warning-bg px-16 py-12 text-latin-label-sm font-semibold text-status-warning">
          <Lock width={18} height={18} className="mt-[2px] shrink-0" aria-hidden />
          {d.purged_at
            ? t('admin.cf.purged_banner', { date: day(d.purged_at, lang) })
            : t('admin.cf.purge_banner', { closed: day(d.closed_at ?? '', lang), date: day(d.purge_at ?? '', lang) })}
        </p>
      )}
      {d.status === 'suspended' && (
        <p role="note" className="flex items-start gap-12 rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">
          <Lock width={18} height={18} className="mt-[2px] shrink-0" aria-hidden />
          {t('admin.cf.suspended_banner', { date: d.suspended_at ? day(d.suspended_at, lang) : '', reason: d.suspend_reason ?? '' })}
        </p>
      )}
      {invite ? (
        <InvitePanel t={t} invite={invite} />
      ) : (
        d.owner_pending && (
          <div className="flex flex-col gap-12 rounded-lg bg-status-info-bg px-16 py-12 sm:flex-row sm:items-center sm:justify-between">
            <p className="text-latin-label-sm font-semibold text-status-info">{t('admin.cf.owner_pending', { name: d.owner_name ?? '', phone: d.owner_phone ?? '' })}</p>
            {canChange && (
              <button type="button" disabled={linkBusy} onClick={() => void newLink()} className="kn-btn inline-flex h-[40px] shrink-0 items-center gap-8 rounded-lg bg-bg-surface px-16 text-latin-label-sm font-semibold hover:bg-cream-100">
                {linkBusy ? <Spinner /> : <Link2 width={16} height={16} aria-hidden />}
                {t('admin.cf.new_link')}
              </button>
            )}
          </div>
        )
      )}
      {/* header */}
      <section className="kn-in flex flex-col gap-24 rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24 lg:flex-row lg:items-center">
        <div className="flex min-w-0 flex-1 gap-16 sm:gap-20">
          <Initials name={d.name} className="h-[64px] w-[64px] rounded-lg bg-espresso-950 text-[22px] text-cream-50 sm:h-[80px] sm:w-[80px] sm:text-[26px]" />
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-x-12 gap-y-8">
              <h2 className="text-[26px] font-bold leading-[34px] sm:text-[32px] sm:leading-[40px]">{d.name}</h2>
              <StatusBadge t={t} badge={d.badge} daysLeft={d.trial_ends_at ? Math.max(0, Math.ceil((new Date(d.trial_ends_at).getTime() - Date.now()) / 864e5)) : null} />
              <span className="rounded-full bg-bg-subtle px-[10px] py-[3px] text-[13px] font-semibold text-mocha-700">
                {plan.name}
                {planPrice && ` · ${t('admin.co.per_month', { price: planPrice })}`}
              </span>
            </div>
            <ul className="mt-8 flex flex-wrap gap-x-20 gap-y-4 text-[13px] text-text-secondary">
              {d.industry && (
                <li className="inline-flex items-center gap-[6px]">
                  <Briefcase width={14} height={14} aria-hidden />
                  {d.industry}
                </li>
              )}
              <li className="inline-flex items-center gap-[6px]">
                <MapPin width={14} height={14} aria-hidden />
                {region(d.country, lang)}
              </li>
              {d.owner_name && (
                <li className="inline-flex items-center gap-[6px]">
                  <User width={14} height={14} aria-hidden />
                  {t('admin.co.owner', { name: d.owner_name })}
                </li>
              )}
              <li className="inline-flex items-center gap-[6px]">
                <Clock width={14} height={14} aria-hidden />
                {t('admin.co.since', { date: day(d.created_at, lang) })}
              </li>
            </ul>
            {(d.owner_email || d.owner_phone) && (
              <p className="mt-4 flex flex-wrap items-center gap-x-8 text-[13px] text-text-secondary">
                <Globe width={14} height={14} aria-hidden />
                {d.owner_email && (
                  <a href={`mailto:${d.owner_email}`} className="kn-link break-all">
                    {d.owner_email}
                  </a>
                )}
                {d.owner_email && d.owner_phone && <span aria-hidden>·</span>}
                {d.owner_phone && (
                  <a href={`tel:${d.owner_phone}`} className="kn-link">
                    {d.owner_phone}
                  </a>
                )}
              </p>
            )}
          </div>
        </div>
        <dl className="grid grid-cols-3 gap-16 border-t border-border-default pt-16 lg:border-l lg:border-t-0 lg:pl-24 lg:pt-0">
          <div title={t('admin.co.h_rule')}>
            <dt className="text-[13px] text-text-secondary">{t('admin.co.health')}</dt>
            <dd className={cx('mt-4 text-[18px] font-semibold', health)}>{t(`admin.co.h.${d.health}`)}</dd>
          </div>
          <div>
            <dt className="text-[13px] text-text-secondary">{t('admin.co.jobs_month')}</dt>
            <dd className="mt-4 text-[18px] font-semibold tabular-nums">{num(d.jobs_this_cycle, lang)}</dd>
          </div>
          <div>
            <dt className="text-[13px] text-text-secondary">{t('admin.co.last_active')}</dt>
            <dd className="mt-4 text-[18px] font-semibold">{d.last_active_at ? ago(d.last_active_at, lang) : t('admin.co.never')}</dd>
          </div>
        </dl>
      </section>

      {/* four numbers */}
      <div className="grid gap-16 sm:grid-cols-2 xl:grid-cols-4">
        <Stat
          i={1}
          label={t('admin.co.c_techs')}
          icon={User}
          value={plan.technician_limit !== null ? t('admin.co.techs_of', { n: num(d.technicians, lang), limit: num(plan.technician_limit, lang) }) : num(d.technicians, lang)}
          sub={
            plan.technician_limit === null
              ? t('admin.co.no_seat_limit')
              : seatsFull
                ? d.upgrade_to
                  ? t('admin.co.seats_full_suggest', { plan: d.upgrade_to.name })
                  : t('admin.co.seats_full')
                : plural(t, 'admin.co.seats_free', plan.technician_limit - d.technicians, { n: num(plan.technician_limit - d.technicians, lang) })
          }
          tone={seatsFull ? 'warn' : undefined}
        />
        <Stat
          i={2}
          label={t('admin.co.reports_month')}
          icon={FileText}
          value={plan.report_limit_monthly !== null ? t('admin.co.techs_of', { n: num(d.reports_this_cycle, lang), limit: num(plan.report_limit_monthly, lang) }) : num(d.reports_this_cycle, lang)}
          sub={
            plan.report_limit_monthly === null
              ? t('admin.co.fair_use')
              : overReports
                ? t('admin.co.over_plan')
                : t('admin.co.reports_left', { n: num(Math.max(0, plan.report_limit_monthly - d.reports_this_cycle), lang) })
          }
          tone={overReports ? 'warn' : undefined}
        />
        <Stat
          i={3}
          label={t('admin.co.approval')}
          icon={Timer}
          value={d.approval_minutes_median !== null ? minutes(d.approval_minutes_median, t, lang) : '—'}
          sub={d.approval_minutes_median !== null ? t('admin.co.approval_sub') : t('admin.co.no_approvals')}
        />
        <Stat
          i={4}
          label={t('admin.co.ai_cost')}
          icon={SlidersHorizontal}
          value={money(Math.round(d.ai_cost_30d_usd * 100), 'USD', lang, 2)}
          sub={d.ai_cost_per_report_usd !== null ? t('admin.dash.per_report', { cost: money(Math.round(d.ai_cost_per_report_usd * 100), 'USD', lang, 2) }) : t('admin.co.no_ai')}
        />
      </div>

      <div className="grid gap-24 xl:grid-cols-[1fr_380px]">
        {/* team */}
        <section className="kn-in rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24" style={stagger(5)}>
          <div className="flex items-baseline justify-between gap-12">
            <h2 className="text-[20px] font-semibold">{t('admin.co.team')}</h2>
            <p className="flex items-baseline gap-12 text-[13px] text-text-secondary">
              {plural(t, 'admin.co.people', d.members, { n: num(d.members, lang) })}
              <Link to={`/users?company=${d.id}`} className="kn-link text-[14px] font-semibold text-mocha-700">
                {t('admin.co.view_all')}
              </Link>
            </p>
          </div>
          {d.team.length ? (
            <ul className="mt-12 divide-y divide-border-default">
              {d.team.map((m) => (
                <li key={m.id} className="kn-row -mx-8 flex items-center gap-12 rounded-md px-8 py-12">
                  <Initials name={m.name ?? '?'} className="h-[36px] w-[36px] rounded-full bg-cream-300 text-[13px] text-mocha-700" />
                  <div className="min-w-0 flex-1">
                    <Link to={`/users/${m.id}`} className="kn-link block truncate text-[14px] font-semibold">
                      {m.name ?? '—'}
                    </Link>
                    <p className="truncate text-[13px] text-text-secondary">
                      {t(`admin.co.role.${m.role}`)} · {t(`admin.co.login.${m.login}`)} · {t(`lang.${m.language}`)}
                    </p>
                  </div>
                  <p className="shrink-0 text-right text-[13px] text-text-secondary">
                    {m.status === 'invited' ? t('admin.co.invited') : m.last_seen_at ? t('admin.co.active_when', { when: ago(m.last_seen_at, lang) }) : t('admin.co.never')}
                  </p>
                </li>
              ))}
            </ul>
          ) : (
            <p className="mt-12 text-latin-label-sm text-text-secondary">{t('admin.co.no_team')}</p>
          )}
        </section>

        {/* subscription */}
        <section className="kn-in rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24" style={stagger(6)}>
          <h2 className="text-[20px] font-semibold">{t('admin.co.sub')}</h2>
          <dl className="mt-8">
            <Row label={t('admin.co.sub_plan')}>
              {plan.name}
              {planPrice && ` · ${t('admin.co.per_month', { price: planPrice })}`}
            </Row>
            <Row label={t('admin.co.sub_status')}>{d.status === 'trial' && d.trial_ends_at ? t('admin.co.sub_trial_ends', { date: day(d.trial_ends_at, lang) }) : t(`admin.co.st.${d.status}`)}</Row>
            <Row label={t('admin.co.sub_billing')}>{t('admin.co.sub_no_payments')}</Row>
            <Row label={t('admin.co.sub_month')}>
              {day(d.cycle_start, lang, { year: undefined })} – {day(new Date(new Date(d.cycle_end).getTime() - 1).toISOString(), lang, { year: undefined })}
            </Row>
            <Row label={t('admin.co.sub_usage')}>
              {t('admin.co.usage_line', {
                reports: plan.report_limit_monthly !== null ? t('admin.co.techs_of', { n: num(d.reports_this_cycle, lang), limit: num(plan.report_limit_monthly, lang) }) : num(d.reports_this_cycle, lang),
                seats: plan.technician_limit !== null ? t('admin.co.techs_of', { n: num(d.technicians, lang), limit: num(plan.technician_limit, lang) }) : num(d.technicians, lang),
              })}
            </Row>
          </dl>
          {(overReports || seatsFull) && (
            <p className="mt-12 flex items-start gap-8 rounded-lg bg-status-warning-bg px-12 py-12 text-[13px] font-semibold text-status-warning">
              <AlertCircle width={16} height={16} className="mt-[1px] shrink-0" aria-hidden />
              {d.upgrade_to ? t('admin.co.suggest', { plan: d.upgrade_to.name, price: upgradePrice ? t('admin.co.per_month', { price: upgradePrice }) : '' }) : t('admin.co.top_plan')}
            </p>
          )}
        </section>
      </div>
      {dialog && (
        <ReasonDialog
          t={t}
          title={t(dialog === 'suspend' ? 'admin.cf.confirm_suspend' : 'admin.cf.confirm_reactivate', { name: d.name })}
          body={t(dialog === 'suspend' ? 'admin.cf.suspend_body' : 'admin.cf.confirm_reactivate_body')}
          confirm={t(dialog === 'suspend' ? 'admin.cf.suspend' : 'admin.cf.reactivate')}
          danger={dialog === 'suspend'}
          onClose={() => setDialog(null)}
          onConfirm={(r) => act(dialog, r)}
        />
      )}
    </div>
  );
}
