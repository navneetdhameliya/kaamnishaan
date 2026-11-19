import { AlertCircle, Briefcase, CalendarDays, ChevronDown, Clock, FileText, Inbox, SlidersHorizontal, TrendingDown, TrendingUp, User, Wallet, type LucideIcon } from 'lucide-react';
import { useCallback, useEffect, useState, type ReactNode } from 'react';

import { api, ApiError } from '../lib/api';
import { clock, day, money, num, plural, type Lang, type T } from '../lib/i18n';
import type { DashboardOut, Stat } from '../lib/types';
import { cx, Initials, Link } from '../ui';

export const RANGES = [7, 30, 90] as const;
export type Range = (typeof RANGES)[number];

export function RangeSelect({ t, days, onChange }: { t: T; days: Range; onChange: (d: Range) => void }) {
  return (
    <label className="relative inline-flex h-[40px] items-center gap-8 rounded-full border border-border-default bg-bg-surface pl-12 pr-[32px] text-latin-label-sm font-semibold hover:border-mocha-500">
      <CalendarDays width={16} height={16} aria-hidden />
      <span className="sr-only">{t('admin.range.label')}</span>
      <select value={days} onChange={(e) => onChange(Number(e.target.value) as Range)} className="cursor-pointer appearance-none bg-transparent focus:outline-none">
        {RANGES.map((d) => (
          <option key={d} value={d}>
            {t(`admin.range.${d}`)}
          </option>
        ))}
      </select>
      <ChevronDown width={16} height={16} className="pointer-events-none absolute right-12" aria-hidden />
    </label>
  );
}

const stagger = (i: number) => ({ ['--d' as string]: `${i * 60}ms` });

function Panel({ title, sub, right, children, className, i = 0 }: { title: string; sub?: ReactNode; right?: ReactNode; children: ReactNode; className?: string; i?: number }) {
  return (
    <section className={cx('kn-in rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24', className)} style={stagger(i)}>
      <div className="flex flex-wrap items-start justify-between gap-12">
        <div>
          <h2 className="text-[20px] font-semibold leading-[28px]">{title}</h2>
          {sub && <p className="mt-2 text-[13px] text-text-secondary">{sub}</p>}
        </div>
        {right}
      </div>
      <div className="mt-16">{children}</div>
    </section>
  );
}

type Trend = { text: string; tone: 'up' | 'down' | 'flat' };

function StatCard({ label, icon: Icon, value, trend, i }: { label: string; icon: LucideIcon; value: string; trend: Trend; i: number }) {
  return (
    <div className="kn-in" style={stagger(i)}>
      <div className="kn-hover h-full rounded-xl border border-border-default bg-bg-surface p-20">
        <div className="flex items-start justify-between gap-8">
          <p className="text-[14px] font-semibold">{label}</p>
          <span className="inline-flex h-[32px] w-[32px] shrink-0 items-center justify-center rounded-full bg-bg-subtle">
            <Icon width={16} height={16} aria-hidden />
          </span>
        </div>
        <p className="mt-12 text-[34px] font-bold leading-[44px] tabular-nums sm:text-[40px] sm:leading-[48px]">{value}</p>
        <p className={cx('mt-8 flex items-center gap-4 text-[13px]', trend.tone === 'up' ? 'text-status-success' : trend.tone === 'down' ? 'text-status-danger' : 'text-text-secondary')}>
          {trend.tone === 'up' && <TrendingUp width={14} height={14} aria-hidden />}
          {trend.tone === 'down' && <TrendingDown width={14} height={14} aria-hidden />}
          <span>{trend.text}</span>
        </p>
      </div>
    </div>
  );
}

function growth(t: T, s: Stat, days: number, lang: Lang): Trend {
  const n = s.value - s.previous;
  return n > 0 ? { text: t('admin.dash.new_in', { n: num(n, lang), days }), tone: 'up' } : { text: t('admin.dash.none_new', { days }), tone: 'flat' };
}

function change(t: T, s: Stat, days: number, lang: Lang): Trend {
  if (!s.previous) return { text: t('admin.dash.vs_none', { days }), tone: 'flat' };
  const pct = Math.round(((s.value - s.previous) / s.previous) * 100);
  const text = t('admin.dash.vs', { change: `${pct > 0 ? '+' : ''}${num(pct, lang)}%`, days });
  return { text, tone: pct > 0 ? 'up' : pct < 0 ? 'down' : 'flat' };
}

const usd = (v: number, lang: Lang) => money(Math.round(v * 100), 'USD', lang, v > 0 && v < 100 ? 2 : 0);

function Chart({ t, lang, data }: { t: T; lang: Lang; data: DashboardOut }) {
  const rows = data.reports_per_day;
  const max = Math.max(1, ...rows.map((r) => r.approved + r.ai_drafts));
  const empty = rows.every((r) => !r.approved && !r.ai_drafts);
  const ticks = [0, 0.25, 0.5, 0.75, 1].map((f) => Math.min(rows.length - 1, Math.round(f * (rows.length - 1))));
  return (
    <div>
      <div className="relative h-[200px] sm:h-[240px]">
        {[0, 1, 2, 3].map((g) => (
          <span key={g} aria-hidden className="absolute inset-x-0 border-t border-border-default" style={{ top: `${(g / 4) * 100}%` }} />
        ))}
        <span aria-hidden className="absolute inset-x-0 bottom-0 border-t border-border-strong" />
        <ul className={cx('relative flex h-full items-end', rows.length > 45 ? 'gap-[2px]' : 'gap-[3px] sm:gap-[6px]')}>
          {rows.map((r, i) => {
            const total = r.approved + r.ai_drafts;
            const label = t('admin.dash.bar', { date: day(`${r.day}T12:00:00`, lang, { year: undefined }), approved: num(r.approved, lang), drafts: num(r.ai_drafts, lang) });
            return (
              <li key={r.day} className="group relative flex h-full flex-1 flex-col justify-end" aria-label={label} tabIndex={0}>
                <span aria-hidden className="absolute inset-x-[-2px] inset-y-0 rounded-sm bg-bg-subtle opacity-0 transition-opacity group-hover:opacity-100 group-focus:opacity-100" />
                <span className="kn-grow relative flex flex-col justify-end overflow-hidden rounded-t-[3px]" style={{ height: `${(total / max) * 100}%`, ['--d' as string]: `${Math.min(i * 12, 600)}ms` }}>
                  <span className="bg-mocha-300" style={{ height: total ? `${(r.ai_drafts / total) * 100}%` : 0 }} />
                  <span className="bg-espresso-950" style={{ height: total ? `${(r.approved / total) * 100}%` : 0 }} />
                </span>
                <span role="tooltip" className="pointer-events-none absolute bottom-full left-1/2 z-10 mb-8 hidden w-max max-w-[220px] -translate-x-1/2 rounded-md bg-espresso-950 px-8 py-4 text-[12px] text-cream-50 shadow-md group-hover:block group-focus:block">
                  {label}
                </span>
              </li>
            );
          })}
        </ul>
        {empty && <p className="absolute inset-0 flex items-center justify-center text-latin-label-sm text-text-secondary">{t('admin.dash.no_reports')}</p>}
      </div>
      <div className="relative mt-12 h-[18px] text-[13px] text-text-secondary">
        {[...new Set(ticks)].map((ix, n) => (
          <span key={ix} className={cx('absolute', n === 0 ? 'left-0' : n === 4 ? 'right-0' : '-translate-x-1/2', n !== 0 && n !== 4 && 'hidden sm:inline')} style={n !== 0 && n !== 4 ? { left: `${((ix + 0.5) / rows.length) * 100}%` } : undefined}>
            {day(`${rows[ix].day}T12:00:00`, lang, { year: undefined })}
          </span>
        ))}
      </div>
    </div>
  );
}

const PLAN_BARS = ['bg-taupe-500', 'bg-mocha-300', 'bg-espresso-950', 'bg-mocha-700', 'bg-sage-500'];
const AVATARS = ['bg-mocha-500', 'bg-sage-500', 'bg-mocha-700', 'bg-mocha-300'];

function PlanMix({ t, lang, data }: { t: T; lang: Lang; data: DashboardOut }) {
  const total = data.plan_mix.reduce((a, p) => a + p.companies, 0);
  return (
    <>
      <p className="-mt-8 text-[13px] text-text-secondary">{plural(t, 'admin.dash.n_companies', total, { n: num(total, lang) })}</p>
      <ul className="mt-16 flex flex-col gap-16">
        {data.plan_mix.map((p, i) => {
          const price = p.prices.INR ?? p.prices.USD;
          const cur = p.prices.INR !== undefined ? 'INR' : 'USD';
          return (
            <li key={p.code}>
              <div className="flex items-baseline justify-between gap-8">
                <span className="text-[14px] font-semibold">
                  {p.name}
                  {price !== undefined && <span className="font-semibold"> · {money(price, cur, lang)}</span>}
                </span>
                <span className="shrink-0 text-[13px] text-text-secondary">{plural(t, 'admin.dash.n_companies', p.companies, { n: num(p.companies, lang) })}</span>
              </div>
              <div className="mt-8 h-[8px] overflow-hidden rounded-full bg-bg-subtle">
                <div className={cx('kn-fill h-full rounded-full', PLAN_BARS[i % PLAN_BARS.length])} style={{ width: `${total ? (p.companies / total) * 100 : 0}%`, ['--d' as string]: `${200 + i * 80}ms` }} />
              </div>
            </li>
          );
        })}
      </ul>
    </>
  );
}

function Attention({ t, lang, data }: { t: T; lang: Lang; data: DashboardOut }) {
  if (!data.attention.length) return <p className="text-latin-label-sm text-text-secondary">{t('admin.dash.all_clear')}</p>;
  const look = {
    near_limit: { bg: 'bg-status-warning-bg', fg: 'text-status-warning', icon: AlertCircle },
    past_due: { bg: 'bg-status-danger-bg', fg: 'text-status-danger', icon: AlertCircle },
    trial_ending: { bg: 'bg-bg-subtle', fg: 'text-text-primary', icon: Clock },
    new_leads: { bg: 'bg-status-info-bg', fg: 'text-status-info', icon: Inbox },
  } as const;
  return (
    <ul className="flex flex-col gap-12">
      {data.attention.map((a, i) => {
        const l = look[a.kind];
        const Icon = l.icon;
        const n = num(a.count, lang);
        const title = {
          near_limit: plural(t, 'admin.dash.near_limit', a.count, { n }),
          past_due: plural(t, 'admin.dash.past_due', a.count, { n }),
          trial_ending: plural(t, 'admin.dash.trials', a.count, { n }),
          new_leads: plural(t, 'admin.dash.leads', a.count, { n }),
        }[a.kind];
        const detail =
          a.kind === 'near_limit'
            ? t('admin.dash.of', { name: a.example ?? '', used: num(a.used ?? 0, lang), limit: num(a.limit ?? 0, lang) })
            : a.kind === 'trial_ending'
              ? t('admin.dash.trials_detail', { name: a.example ?? '' })
              : a.kind === 'new_leads'
                ? t('admin.dash.latest', { name: a.example ?? '' })
                : a.example;
        return (
          <li key={a.kind} className={cx('kn-in flex items-start gap-12 rounded-lg px-12 py-12', l.bg)} style={stagger(i + 2)}>
            <Icon width={18} height={18} className={cx('mt-[2px] shrink-0', l.fg)} aria-hidden />
            <div className="min-w-0">
              <p className="text-[14px] font-semibold">
                {a.kind === 'new_leads' ? (
                  <Link to="/leads" className="kn-link">
                    {title}
                  </Link>
                ) : a.kind === 'past_due' ? (
                  <Link to="/companies?status=past_due" className="kn-link">
                    {title}
                  </Link>
                ) : a.kind === 'trial_ending' ? (
                  <Link to="/companies?status=trial" className="kn-link">
                    {title}
                  </Link>
                ) : (
                  title
                )}
              </p>
              {detail && <p className="mt-2 text-[13px] text-text-secondary">{detail}</p>}
            </div>
          </li>
        );
      })}
    </ul>
  );
}

function TopCompanies({ t, lang, data }: { t: T; lang: Lang; data: DashboardOut }) {
  if (!data.top_companies.length) return <p className="text-latin-label-sm text-text-secondary">{t('admin.dash.no_reports')}</p>;
  return (
    <ul className="divide-y divide-border-default">
      {data.top_companies.map((c, i) => (
        <li key={c.id} className="kn-row -mx-8 flex items-center gap-12 rounded-md px-8 py-12">
          <Initials name={c.name} className={cx('h-[36px] w-[36px] rounded-md text-[13px] text-cream-50', AVATARS[i % AVATARS.length])} />
          <div className="min-w-0 flex-1">
            <p className="truncate text-[14px] font-semibold">{c.name}</p>
            <p className="truncate text-[13px] text-text-secondary">{[c.trade, c.plan].filter(Boolean).join(' · ')}</p>
          </div>
          <p className="shrink-0 text-[14px] font-semibold tabular-nums">{plural(t, 'admin.dash.n_reports', c.reports, { n: num(c.reports, lang) })}</p>
        </li>
      ))}
    </ul>
  );
}

function when(iso: string, t: T, lang: Lang): string {
  const d = new Date(iso);
  const today = new Date();
  const yesterday = new Date();
  yesterday.setDate(today.getDate() - 1);
  if (d.toDateString() === today.toDateString()) return clock(iso, lang);
  if (d.toDateString() === yesterday.toDateString()) return t('admin.yesterday');
  return day(iso, lang, { year: undefined });
}

function Activity({ t, lang, data }: { t: T; lang: Lang; data: DashboardOut }) {
  if (!data.activity.length) return <p className="text-latin-label-sm text-text-secondary">{t('admin.dash.no_activity')}</p>;
  const tag = { company_created: 'signup', lead_demo: 'website', lead_contact: 'website', lead_newsletter: 'website', staff_joined: 'staff' } as const;
  return (
    <ul className="flex flex-col gap-16">
      {data.activity.map((a, i) => (
        <li key={`${a.kind}-${a.at}-${i}`} className="kn-in flex gap-12" style={stagger(i + 2)}>
          <span aria-hidden className="mt-[8px] h-[6px] w-[6px] shrink-0 rounded-full bg-espresso-950" />
          <div className="min-w-0">
            <p className="break-words text-[14px] font-semibold">{t(`admin.act.${a.kind}`, { title: a.title })}</p>
            <p className="mt-2 text-[13px] text-text-secondary">
              {when(a.at, t, lang)} · {t(`admin.tag.${tag[a.kind]}`)}
            </p>
          </div>
        </li>
      ))}
    </ul>
  );
}

function Skeleton() {
  return (
    <div aria-busy="true" className="flex flex-col gap-24">
      <div className="grid gap-16 sm:grid-cols-2 xl:grid-cols-5">
        {[0, 1, 2, 3, 4].map((i) => (
          <div key={i} className="kn-shimmer h-[148px] rounded-xl bg-bg-surface" />
        ))}
      </div>
      <div className="grid gap-24 xl:grid-cols-3">
        <div className="kn-shimmer h-[360px] rounded-xl bg-bg-surface xl:col-span-2" />
        <div className="kn-shimmer h-[360px] rounded-xl bg-bg-surface" />
      </div>
    </div>
  );
}

/** A03 Dashboard, from GET /admin/dashboard. */
export function Dashboard({ t, lang, days }: { t: T; lang: Lang; days: Range }) {
  const [data, setData] = useState<DashboardOut | null>(null);
  const [error, setError] = useState(false);
  const load = useCallback(() => {
    setError(false);
    api<DashboardOut>(`/admin/dashboard?days=${days}&locale=${lang}`)
      .then(setData)
      .catch((e) => {
        if (!(e instanceof ApiError && e.status === 401)) setError(true);
      });
  }, [days, lang]);
  useEffect(load, [load]);

  if (error)
    return (
      <div className="kn-in mx-auto mt-48 max-w-[480px] rounded-xl border border-border-default bg-bg-surface p-24 text-center">
        <p className="text-latin-body text-text-secondary">{t('admin.err.load')}</p>
        <button type="button" onClick={load} className="kn-btn mt-16 inline-flex h-[44px] items-center rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action">
          {t('admin.retry')}
        </button>
      </div>
    );
  if (!data) return <Skeleton />;

  const revenue = data.monthly_revenue;
  return (
    <div key={`${data.days}-${lang}`} className="flex flex-col gap-24">
      <div className="grid gap-16 sm:grid-cols-2 xl:grid-cols-5">
        <StatCard i={0} label={t('admin.dash.companies')} icon={Briefcase} value={num(data.active_companies.value, lang)} trend={growth(t, data.active_companies, data.days, lang)} />
        <StatCard i={1} label={t('admin.dash.technicians')} icon={User} value={num(data.technicians.value, lang)} trend={growth(t, data.technicians, data.days, lang)} />
        <StatCard i={2} label={t('admin.dash.reports')} icon={FileText} value={num(data.reports_sent.value, lang)} trend={change(t, data.reports_sent, data.days, lang)} />
        <StatCard
          i={3}
          label={t('admin.dash.revenue')}
          icon={Wallet}
          value={revenue.length ? revenue.map((m) => money(m.amount_minor, m.currency, lang)).join(' + ') : money(0, 'INR', lang)}
          trend={{ text: t(revenue.length ? 'admin.dash.revenue_note' : 'admin.dash.revenue_none'), tone: 'flat' }}
        />
        <StatCard
          i={4}
          label={t('admin.dash.ai_cost')}
          icon={SlidersHorizontal}
          value={usd(data.ai_cost_usd.value, lang)}
          trend={data.ai_cost_per_report_usd !== null ? { text: t('admin.dash.per_report', { cost: usd(data.ai_cost_per_report_usd, lang) }), tone: 'flat' } : change(t, data.ai_cost_usd, data.days, lang)}
        />
      </div>
      <div className="grid gap-24 xl:grid-cols-3">
        <Panel
          i={5}
          className="xl:col-span-2"
          title={t('admin.dash.per_day')}
          sub={t('admin.dash.per_day_body')}
          right={
            <div className="flex items-center gap-16 text-[13px] text-text-secondary">
              <span className="inline-flex items-center gap-[6px]">
                <span aria-hidden className="h-[10px] w-[10px] rounded-sm bg-espresso-950" />
                {t('admin.dash.approved')}
              </span>
              <span className="inline-flex items-center gap-[6px]">
                <span aria-hidden className="h-[10px] w-[10px] rounded-sm bg-mocha-300" />
                {t('admin.dash.drafts')}
              </span>
            </div>
          }
        >
          <Chart t={t} lang={lang} data={data} />
        </Panel>
        <Panel i={6} title={t('admin.dash.plan_mix')}>
          <PlanMix t={t} lang={lang} data={data} />
        </Panel>
      </div>
      <div className="grid gap-24 lg:grid-cols-2 xl:grid-cols-3">
        <Panel i={7} title={t('admin.dash.attention')}>
          <Attention t={t} lang={lang} data={data} />
        </Panel>
        <Panel i={8} title={t('admin.dash.top')}>
          <TopCompanies t={t} lang={lang} data={data} />
        </Panel>
        <Panel i={9} title={t('admin.dash.activity')}>
          <Activity t={t} lang={lang} data={data} />
        </Panel>
      </div>
    </div>
  );
}
