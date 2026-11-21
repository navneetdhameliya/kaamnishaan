import { Clock, FileCheck, Send, Users } from 'lucide-react';
import { useEffect, useState } from 'react';

import { api, ApiError } from '../lib/api';
import { day, num, type Lang, type T } from '../lib/i18n';
import type { AdminAnalyticsOut, Metric, Share } from '../lib/types';
import { cx } from '../ui';
import { Panel, StatCard } from './Dashboard';

type Tone = 'up' | 'down' | 'good' | 'bad' | 'flat';

/** "+18% vs last 90 days" — up is good unless `lowerIsBetter`. */
function change(t: T, m: Metric, days: number, lang: Lang, kind: 'pct' | 'count' | 'minutes' | 'points'): { text: string; tone: Tone } {
  if (m.value == null) return { text: t(kind === 'minutes' ? 'admin.an.no_review' : 'admin.an.no_data'), tone: 'flat' };
  if (m.previous == null || (kind === 'pct' && m.previous === 0)) return { text: t('admin.an.no_before', { days }), tone: 'flat' };
  const diff = m.value - m.previous;
  if (Math.abs(diff) < 0.05) return { text: t('admin.an.same', { days }), tone: 'flat' };
  const better = kind === 'minutes' ? diff < 0 : diff > 0;
  const tone: Tone = better ? (kind === 'minutes' ? 'good' : 'up') : kind === 'minutes' ? 'bad' : 'down';
  const sign = diff > 0 ? '+' : '−';
  const abs = Math.abs(diff);
  const text =
    kind === 'pct'
      ? `${sign}${num(Math.round((abs / m.previous) * 100), lang)}%`
      : kind === 'minutes'
        ? `${sign}${minutes(t, abs, lang)}`
        : kind === 'points'
          ? t('admin.an.pts', { n: `${sign}${num(Math.round(abs), lang)}` })
          : `${sign}${num(abs, lang)}`;
  return { text: t('admin.an.vs', { change: text, days }), tone };
}

function minutes(t: T, m: number, lang: Lang): string {
  if (m < 60) return t('admin.an.min', { n: num(Math.round(m), lang) });
  if (m < 48 * 60) return t('admin.an.hours', { n: num(Math.round((m / 60) * 10) / 10, lang) });
  return t('admin.an.days', { n: num(Math.round(m / 1440), lang) });
}

function Bars({ t, lang, data }: { t: T; lang: Lang; data: AdminAnalyticsOut }) {
  const max = Math.max(1, ...data.sent_by_period.map((b) => b.count));
  const [shown, setShown] = useState(false);
  useEffect(() => {
    const id = window.requestAnimationFrame(() => setShown(true));
    return () => window.cancelAnimationFrame(id);
  }, []);
  const first = data.sent_by_period[0]?.start;
  const last = data.sent_by_period.at(-1)?.start;
  return (
    <div>
      <div role="img" aria-label={t('admin.an.chart_label', { n: num(data.sent_by_period.reduce((a, b) => a + b.count, 0), lang) })} className="flex h-[220px] items-end gap-[3px] border-b border-border-default sm:gap-4">
        {data.sent_by_period.map((b, i) => (
          <div key={b.start} className="group relative flex h-full flex-1 items-end">
            <div
              className="w-full rounded-t-sm bg-mocha-300 transition-[height,background-color] duration-700 ease-out group-hover:bg-mocha-600"
              style={{ height: shown ? `${Math.max((b.count / max) * 100, b.count ? 3 : 0.5)}%` : '0%', transitionDelay: `${Math.min(i * 15, 400)}ms` }}
            />
            <span className="pointer-events-none absolute bottom-full left-1/2 z-10 mb-4 -translate-x-1/2 whitespace-nowrap rounded-md bg-espresso-950 px-8 py-4 text-[12px] font-semibold text-cream-50 opacity-0 transition-opacity group-hover:opacity-100">
              {t(data.step === 'week' ? 'admin.an.tip_week' : 'admin.an.tip_day', { day: day(b.start, lang, { year: undefined }), n: num(b.count, lang) })}
            </span>
          </div>
        ))}
      </div>
      {first && last && (
        <p className="mt-8 flex justify-between text-[13px] text-text-secondary">
          <span>{day(first, lang, { year: undefined })}</span>
          <span>{day(last, lang)}</span>
        </p>
      )}
    </div>
  );
}

function ShareList({ items, total, label, empty }: { items: Share[]; total: number; label: (s: Share) => string; empty: string }) {
  if (!total) return <p className="py-24 text-center text-[13px] text-text-secondary">{empty}</p>;
  return (
    <ul className="flex flex-col gap-12">
      {items.map((s, i) => {
        const pct = Math.round((s.count / total) * 100);
        return (
          <li key={s.key} className="kn-in" style={{ ['--d' as string]: `${i * 60}ms` }}>
            <p className="flex justify-between text-[14px]">
              <span className="font-semibold">{label(s)}</span>
              <span className="tabular-nums text-text-secondary">{pct}%</span>
            </p>
            <div className="mt-4 h-[8px] overflow-hidden rounded-full bg-cream-200">
              <div className="kn-fill h-full rounded-full bg-status-success" style={{ width: `${pct}%` }} />
            </div>
          </li>
        );
      })}
    </ul>
  );
}

/** A30 Analytics: how companies use KaamNishaan, compared with the period before. */
export function Analytics({ t, lang, days }: { t: T; lang: Lang; days: number }) {
  const [data, setData] = useState<AdminAnalyticsOut | null>(null);
  const [error, setError] = useState(false);
  useEffect(() => {
    setData(null);
    setError(false);
    api<AdminAnalyticsOut>(`/admin/analytics?days=${days}&locale=${lang}`).then(setData).catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, [days, lang]);

  if (error) return <p role="alert" className="rounded-lg bg-status-danger-bg px-16 py-12 text-latin-label-sm font-semibold text-status-danger">{t('admin.err.load')}</p>;
  if (!data)
    return (
      <div aria-busy="true" className="grid gap-16 sm:grid-cols-2 xl:grid-cols-4">
        {[0, 1, 2, 3].map((i) => <div key={i} className="kn-shimmer h-[140px] rounded-xl bg-bg-subtle" />)}
        <div className="kn-shimmer h-[320px] rounded-xl bg-bg-subtle sm:col-span-2 xl:col-span-4" />
      </div>
    );
  const indTotal = data.reports_by_industry.reduce((a, b) => a + b.count, 0);
  return (
    <div className="flex flex-col gap-16">
      <div className="grid gap-16 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard i={0} icon={Send} label={t('admin.an.sent')} value={num(data.reports_sent.value ?? 0, lang)} trend={change(t, data.reports_sent, days, lang, 'pct')} />
        <StatCard i={1} icon={Clock} label={t('admin.an.review')} value={data.review_minutes.value == null ? '—' : minutes(t, data.review_minutes.value, lang)} trend={change(t, data.review_minutes, days, lang, 'minutes')} />
        <StatCard i={2} icon={FileCheck} label={t('admin.an.first')} value={data.first_time.value == null ? '—' : `${num(Math.round(data.first_time.value), lang)}%`} trend={change(t, data.first_time, days, lang, 'points')} />
        <StatCard i={3} icon={Users} label={t('admin.an.active')} value={num(data.active_technicians.value ?? 0, lang)} trend={change(t, data.active_technicians, days, lang, 'count')} />
      </div>
      <div className="grid items-start gap-16 xl:grid-cols-[1fr_400px]">
        <Panel i={4} title={t(data.step === 'week' ? 'admin.an.per_week' : 'admin.an.per_day')} sub={t('admin.an.per_sub')}>
          <Bars t={t} lang={lang} data={data} />
        </Panel>
        <div className="flex flex-col gap-16">
          <Panel i={5} title={t('admin.an.voice')} sub={t('admin.an.voice_sub', { n: num(data.voice_total, lang) })}>
            <ShareList items={data.voice_languages} total={data.voice_total} label={(s) => (s.key === 'other' ? t('admin.an.other') : t(`lang.${s.key}`))} empty={t('admin.an.voice_none')} />
          </Panel>
          <Panel i={6} title={t('admin.an.by_industry')}>
            <ShareList items={data.reports_by_industry.slice(0, 6)} total={indTotal} label={(s) => s.label ?? t('admin.an.no_industry')} empty={t('admin.an.sent_none')} />
          </Panel>
        </div>
      </div>
      <p className={cx('text-[13px] text-text-secondary')}>{t('admin.an.note')}</p>
    </div>
  );
}
