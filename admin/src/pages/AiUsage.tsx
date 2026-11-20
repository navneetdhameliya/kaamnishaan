import { Check, FileText, Info, Mic, Sparkles } from 'lucide-react';
import { useCallback, useEffect, useState } from 'react';

import { api, ApiError } from '../lib/api';
import { day, num, type Lang, type T } from '../lib/i18n';
import type { AiTask, AiUsageOut } from '../lib/types';
import { cx, Link } from '../ui';
import { Panel, StatCard, stagger, type Range, type Trend } from './Dashboard';

/** Bar colours per task, in stacking order (bottom first), as in Figma A20. */
const TASKS: { key: AiTask; color: string }[] = [
  { key: 'report_draft', color: 'bg-espresso-950' },
  { key: 'transcription', color: 'bg-mocha-300' },
  { key: 'assistant', color: 'bg-sage-500' },
  { key: 'translation', color: 'bg-taupe-400' },
];

/** Dollars with as many decimals as small AI costs need: $412 · $41.20 · $0.068. */
function usd(v: number, lang: Lang): string {
  const d = v === 0 || v >= 100 ? 0 : v >= 1 || v >= 0.1 ? 2 : 3;
  return num(v, lang, { style: 'currency', currency: 'USD', minimumFractionDigits: d, maximumFractionDigits: d });
}

const pct = (v: number, lang: Lang) => num(v, lang, { style: 'percent', maximumFractionDigits: 1 });

function CostChart({ t, lang, data }: { t: T; lang: Lang; data: AiUsageOut }) {
  const rows = data.per_day;
  const totals = rows.map((r) => TASKS.reduce((a, k) => a + r[k.key], 0));
  const max = Math.max(...totals, 0) || 1;
  const empty = totals.every((v) => !v);
  const ticks = [0, 0.25, 0.5, 0.75, 1].map((f) => Math.min(rows.length - 1, Math.round(f * (rows.length - 1))));
  return (
    <div>
      <div className="relative h-[200px] sm:h-[220px]">
        {[0, 1, 2, 3].map((g) => (
          <span key={g} aria-hidden className="absolute inset-x-0 border-t border-border-default" style={{ top: `${(g / 4) * 100}%` }} />
        ))}
        <span aria-hidden className="absolute inset-x-0 bottom-0 border-t border-border-strong" />
        <ul className={cx('relative flex h-full items-end', rows.length > 45 ? 'gap-[2px]' : 'gap-[3px] sm:gap-[6px]')}>
          {rows.map((r, i) => {
            const date = day(`${r.day}T12:00:00`, lang, { year: undefined });
            const parts = TASKS.filter((k) => r[k.key] > 0).map((k) => `${t(`admin.ai.task.${k.key}`)} ${usd(r[k.key], lang)}`);
            const label = `${date} · ${usd(totals[i], lang)}${parts.length ? ` (${parts.join(', ')})` : ''}`;
            return (
              <li key={r.day} className="group relative flex h-full flex-1 flex-col justify-end" aria-label={label} tabIndex={0}>
                <span aria-hidden className="absolute inset-x-[-2px] inset-y-0 rounded-sm bg-bg-subtle opacity-0 transition-opacity group-hover:opacity-100 group-focus:opacity-100" />
                <span className="kn-grow relative flex flex-col-reverse overflow-hidden rounded-t-[3px]" style={{ height: `${(totals[i] / max) * 100}%`, ['--d' as string]: `${Math.min(i * 12, 600)}ms` }}>
                  {TASKS.map((k) => (
                    <span key={k.key} className={k.color} style={{ height: totals[i] ? `${(r[k.key] / totals[i]) * 100}%` : 0 }} />
                  ))}
                </span>
                <span role="tooltip" className="pointer-events-none absolute bottom-full left-1/2 z-10 mb-8 hidden w-max max-w-[240px] -translate-x-1/2 rounded-md bg-espresso-950 px-8 py-4 text-[12px] text-cream-50 shadow-md group-hover:block group-focus:block">
                  {label}
                </span>
              </li>
            );
          })}
        </ul>
        {empty && <p className="absolute inset-0 flex items-center justify-center text-latin-label-sm text-text-secondary">{t('admin.ai.no_use')}</p>}
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

function ByCompany({ t, lang, data }: { t: T; lang: Lang; data: AiUsageOut }) {
  const rows = [
    ...data.companies.map((c) => ({ key: c.id, name: c.name, cost: c.cost_usd, to: `/companies/${c.id}` })),
    ...(data.others_cost_usd > 0 ? [{ key: 'others', name: t('admin.ai.others', { n: num(data.others_count, lang) }), cost: data.others_cost_usd, to: null }] : []),
  ];
  if (!rows.length) return <p className="text-latin-label-sm text-text-secondary">{t('admin.ai.no_use')}</p>;
  const total = data.total_cost_usd || 1;
  return (
    <ul className="flex flex-col gap-16">
      {rows.map((r, i) => (
        <li key={r.key} className="kn-in" style={stagger(i + 6)}>
          <div className="flex items-baseline justify-between gap-12 text-[14px] font-semibold">
            {r.to ? (
              <Link to={r.to} className="kn-link min-w-0 truncate">
                {r.name}
              </Link>
            ) : (
              <span className="min-w-0 truncate">{r.name}</span>
            )}
            <span className="shrink-0 tabular-nums">{usd(r.cost, lang)}</span>
          </div>
          <div className="mt-8 h-[8px] overflow-hidden rounded-full bg-bg-subtle">
            <div className="kn-fill h-full rounded-full bg-espresso-950" style={{ width: `${Math.min(100, (r.cost / total) * 100)}%`, ['--d' as string]: `${200 + i * 80}ms` }} />
          </div>
        </li>
      ))}
    </ul>
  );
}

function Models({ t, lang, data }: { t: T; lang: Lang; data: AiUsageOut }) {
  if (!data.models.length) return <p className="text-latin-label-sm text-text-secondary">{t('admin.ai.no_use')}</p>;
  const th = 'px-16 py-[10px] text-left text-[13px] font-semibold text-text-secondary';
  const td = 'px-16 py-[10px] text-latin-body';
  return (
    <div className="-mx-4 overflow-x-auto px-4">
      <table className="w-full min-w-[640px] border-separate border-spacing-0">
        <thead>
          <tr className="bg-bg-subtle">
            <th scope="col" className={cx(th, 'rounded-l-lg')}>{t('admin.ai.col_task')}</th>
            <th scope="col" className={th}>{t('admin.ai.col_model')}</th>
            <th scope="col" className={th}>{t('admin.ai.col_calls', { days: data.days })}</th>
            <th scope="col" className={th}>{t('admin.ai.col_avg')}</th>
            <th scope="col" className={cx(th, 'rounded-r-lg')}>{t('admin.ai.col_errors')}</th>
          </tr>
        </thead>
        <tbody>
          {data.models.map((m, i) => (
            <tr key={`${m.task}-${m.model}`} className="kn-in kn-row" style={stagger(i + 8)}>
              <td className={td}>{t(`admin.ai.task.${m.task}`)}</td>
              <td className={cx(td, 'break-all')}>{m.model}</td>
              <td className={cx(td, 'tabular-nums')}>{num(m.calls, lang)}</td>
              <td className={cx(td, 'tabular-nums')}>{m.avg_cost_usd === null ? '—' : m.per_minute ? t('admin.ai.per_min', { cost: usd(m.avg_cost_usd, lang) }) : usd(m.avg_cost_usd, lang)}</td>
              <td className={cx(td, 'tabular-nums', m.error_rate !== null && m.error_rate >= 0.05 && 'font-semibold text-status-danger')}>{m.error_rate === null ? '—' : pct(m.error_rate, lang)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function Skeleton() {
  return (
    <div aria-busy="true" className="flex flex-col gap-16">
      <div className="grid gap-16 sm:grid-cols-2 xl:grid-cols-4">
        {[0, 1, 2, 3].map((i) => (
          <div key={i} className="kn-shimmer h-[148px] rounded-xl bg-bg-surface" />
        ))}
      </div>
      <div className="grid gap-16 xl:grid-cols-[1fr_380px]">
        <div className="kn-shimmer h-[340px] rounded-xl bg-bg-surface" />
        <div className="kn-shimmer h-[340px] rounded-xl bg-bg-surface" />
      </div>
      <div className="kn-shimmer h-[200px] rounded-xl bg-bg-surface" />
    </div>
  );
}

/** A20 AI usage and cost, from GET /admin/ai-usage. */
export function AiUsage({ t, lang, days }: { t: T; lang: Lang; days: Range }) {
  const [data, setData] = useState<AiUsageOut | null>(null);
  const [error, setError] = useState(false);
  const load = useCallback(() => {
    setError(false);
    api<AiUsageOut>(`/admin/ai-usage?days=${days}`)
      .then(setData)
      .catch((e) => {
        if (!(e instanceof ApiError && e.status === 401)) setError(true);
      });
  }, [days]);
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

  const target = data.target_per_report_usd;
  const perReport: Trend =
    data.cost_per_report_usd === null
      ? { text: t('admin.ai.no_drafts'), tone: 'flat' }
      : target === null
        ? { text: t('admin.ai.per_report_how'), tone: 'flat' }
        : data.cost_per_report_usd > target
          ? { text: t('admin.ai.over_target', { cost: usd(target, lang) }), tone: 'bad' }
          : { text: t('admin.ai.target', { cost: usd(target, lang) }), tone: 'flat' };
  return (
    <div key={`${data.days}-${lang}`} className="flex flex-col gap-16">
      {!data.configured && (
        <div role="status" className="kn-in flex items-start gap-12 rounded-xl bg-status-info-bg px-16 py-12 text-status-info">
          <Info width={18} height={18} className="mt-[2px] shrink-0" aria-hidden />
          <p className="text-latin-label-sm">
            <span className="font-semibold">{t('admin.ai.off_title')}</span> {t('admin.ai.off_body')}
          </p>
        </div>
      )}
      <div className="grid gap-16 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          i={0}
          label={t('admin.ai.total')}
          icon={Sparkles}
          value={usd(data.total_cost_usd, lang)}
          trend={{ text: data.budget_usd ? t('admin.ai.last_days_budget', { days: data.days, budget: usd(data.budget_usd, lang) }) : t('admin.ai.last_days', { days: data.days }), tone: 'flat' }}
        />
        <StatCard i={1} label={t('admin.ai.per_report')} icon={FileText} value={data.cost_per_report_usd === null ? '—' : usd(data.cost_per_report_usd, lang)} trend={perReport} />
        <StatCard
          i={2}
          label={t('admin.ai.drafted')}
          icon={Check}
          value={num(data.reports_drafted, lang)}
          trend={{ text: data.draft_success === null ? t('admin.ai.no_drafts') : t('admin.ai.success', { pct: pct(data.draft_success, lang) }), tone: data.draft_success !== null && data.draft_success < 0.95 ? 'bad' : 'flat' }}
        />
        <StatCard i={3} label={t('admin.ai.voice')} icon={Mic} value={num(data.voice_minutes, lang, { maximumFractionDigits: 1 })} trend={{ text: t('admin.ai.task.transcription'), tone: 'flat' }} />
      </div>
      <div className="grid gap-16 xl:grid-cols-[minmax(0,1fr)_380px]">
        <Panel
          i={4}
          title={t('admin.ai.per_day')}
          sub={t('admin.ai.estimate')}
          right={
            <ul className="flex flex-wrap items-center gap-x-12 gap-y-4 text-[13px] text-text-secondary">
              {TASKS.map((k) => (
                <li key={k.key} className="inline-flex items-center gap-[6px]">
                  <span aria-hidden className={cx('h-[10px] w-[10px] rounded-[3px]', k.color)} />
                  {t(`admin.ai.task.${k.key}`)}
                </li>
              ))}
            </ul>
          }
        >
          <CostChart t={t} lang={lang} data={data} />
        </Panel>
        <Panel i={5} title={t('admin.ai.by_company')}>
          <ByCompany t={t} lang={lang} data={data} />
        </Panel>
      </div>
      <Panel i={7} title={t('admin.ai.models')}>
        <Models t={t} lang={lang} data={data} />
      </Panel>
    </div>
  );
}
