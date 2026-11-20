import { Camera, CheckCircle2, ChevronLeft, ExternalLink, FileText, MapPin, Mic, Zap } from 'lucide-react';
import { useCallback, useEffect, useState, type ReactNode } from 'react';

import { api, ApiError } from '../lib/api';
import { clock, day, num, type Lang, type T } from '../lib/i18n';
import type { AdminJobDetail, AdminTimelineItem } from '../lib/types';
import { cx, Link } from '../ui';
import { JobStatusPill } from './Jobs';

const at = (iso: string, lang: Lang) => `${day(iso, lang, { year: undefined })}, ${clock(iso, lang)}`;
const mapUrl = (lat: number, lng: number) => `https://www.google.com/maps?q=${lat},${lng}`;

function Card({ title, children, i, className }: { title?: string; children: ReactNode; i: number; className?: string }) {
  return (
    <section className={cx('kn-in rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24', className)} style={{ ['--d' as string]: `${i * 80}ms` }}>
      {title && <h2 className="mb-12 text-[20px] font-semibold leading-[28px]">{title}</h2>}
      {children}
    </section>
  );
}

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex flex-wrap items-baseline justify-between gap-x-16 gap-y-2 py-8">
      <dt className="text-latin-body text-text-secondary">{label}</dt>
      <dd className="min-w-0 text-right text-[14px] font-semibold">{children}</dd>
    </div>
  );
}

/** One line of the timeline, in plain words. */
function line(e: AdminTimelineItem, t: T): string {
  const who = e.actor ?? t('admin.jb.someone');
  switch (e.type) {
    case 'created': return t(e.data.quick_job ? 'admin.jb.tl.created_quick' : 'admin.jb.tl.created', { who });
    case 'assigned': return t('admin.jb.tl.assigned', { name: e.data.technician ?? '—' });
    case 'unassigned': return t('admin.jb.tl.unassigned', { who });
    case 'started': return t('admin.jb.tl.started', { who });
    case 'edited': return t('admin.jb.tl.edited', { who });
    case 'cancelled': return e.data.reason ? t('admin.jb.tl.cancelled_why', { who, why: e.data.reason }) : t('admin.jb.tl.cancelled', { who });
    case 'photos': return t(`admin.jb.tl.photos_${e.data.stage}`, { n: e.data.count ?? 0 });
    case 'voice': return t('admin.jb.tl.voice', { n: e.data.count ?? 0 });
    case 'report_submitted': return t('admin.jb.tl.submitted', { who });
    case 'changes_requested': return t('admin.jb.tl.changes', { who });
    case 'approved': return t('admin.jb.tl.approved', { who });
    case 'shared': return t('admin.jb.tl.shared');
    case 'acknowledged': return t('admin.jb.tl.acknowledged', { who });
    default: return e.type;
  }
}

const dot = (type: string) =>
  ['photos', 'voice', 'approved', 'acknowledged'].includes(type) ? 'bg-status-success' : type === 'cancelled' || type === 'changes_requested' ? 'bg-status-danger' : 'bg-mocha-700';

/** A12 Job details, read-only: what the job is, where it was started, proof so far, the report, the timeline. */
export function JobDetail({ t, lang, id, onName }: { t: T; lang: Lang; id: string; onName: (n: string) => void }) {
  const [d, setD] = useState<AdminJobDetail | null>(null);
  const [error, setError] = useState<'missing' | 'load' | null>(null);

  const load = useCallback(() => {
    setError(null);
    api<AdminJobDetail>(`/admin/jobs/${id}?locale=${lang}`)
      .then((x) => {
        setD(x);
        onName(`${x.customer} · #${x.number}`);
      })
      .catch((e) => {
        if (e instanceof ApiError && (e.status === 404 || e.status === 422)) setError('missing');
        else if (!(e instanceof ApiError && e.status === 401)) setError('load');
      });
  }, [id, lang, onName]);
  useEffect(load, [load]);

  const back = (
    <Link to="/jobs" className="group inline-flex w-fit items-center gap-4 text-latin-label-sm font-semibold text-text-secondary hover:text-text-primary">
      <ChevronLeft width={16} height={16} className="transition-transform group-hover:-translate-x-[3px]" aria-hidden />
      {t('admin.jb.back')}
    </Link>
  );
  if (error)
    return (
      <div className="flex flex-col gap-16">
        {back}
        <div className="kn-in mx-auto mt-24 max-w-[480px] rounded-xl border border-border-default bg-bg-surface p-24 text-center">
          <p className="text-latin-body text-text-secondary">{t(error === 'missing' ? 'admin.jb.not_found' : 'admin.err.load')}</p>
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
      <div aria-busy="true" className="flex flex-col gap-16">
        {back}
        <div className="grid gap-16 lg:grid-cols-[minmax(0,1.5fr)_minmax(0,1fr)]">
          <div className="kn-shimmer h-[300px] rounded-xl bg-bg-surface" />
          <div className="kn-shimmer h-[300px] rounded-xl bg-bg-surface" />
        </div>
        <div className="kn-shimmer h-[220px] rounded-xl bg-bg-surface" />
      </div>
    );

  const p = d.place;
  const r = d.report;
  const photosLine = (['before', 'during', 'after'] as const).map((s) => t(`admin.jb.ph.${s}`, { n: num(d.photos[s], lang) })).join(' · ');

  return (
    <div className="flex flex-col gap-16">
      {back}
      <div className="grid gap-16 lg:grid-cols-[minmax(0,1.5fr)_minmax(0,1fr)]">
        <Card i={0}>
          <div className="flex flex-wrap items-center gap-8">
            <JobStatusPill t={t} status={d.status} />
            {d.is_quick_job && (
              <span className="inline-flex items-center gap-4 rounded-full bg-status-warning-bg px-[10px] py-[3px] text-[13px] font-semibold text-status-warning">
                <Zap width={12} height={12} aria-hidden />
                {t('admin.jb.quick')}
              </span>
            )}
            <span className="text-[14px] font-semibold text-text-secondary">
              <Link to={`/companies/${d.company.value}`} className="hover:underline">{d.company.label}</Link>
              {d.industry && ` · ${d.industry}`}
            </span>
          </div>
          <h2 className="mt-12 break-words text-[24px] font-bold leading-[32px]">{d.title}</h2>
          {d.description && <p className="mt-4 whitespace-pre-line break-words text-latin-body text-text-secondary">{d.description}</p>}
          <dl className="mt-8">
            <Row label={t('admin.jb.customer')}>{[d.customer, d.contact].filter(Boolean).join(' · ')}</Row>
            <Row label={t('admin.jb.address')}>{p.address ?? '—'}</Row>
            <Row label={t('admin.jb.technician')}>{d.technician ?? t('admin.jb.nobody')}</Row>
            <Row label={t('admin.jb.scheduled')}>
              {d.scheduled_at ? at(d.scheduled_at, lang) : t('admin.jb.not_scheduled')}
              {d.duration_min ? <span className="font-normal text-text-secondary"> · {t('admin.jb.minutes', { n: num(d.duration_min, lang) })}</span> : null}
            </Row>
            <Row label={t('admin.jb.checklist')}>
              {d.checklists.length ? d.checklists.map((c) => t('admin.jb.cl_line', { name: c.name, done: num(c.answered, lang), total: num(c.total, lang) })).join(', ') : t('admin.jb.no_checklist')}
            </Row>
            {d.completed_at && <Row label={t('admin.jb.completed')}>{at(d.completed_at, lang)}</Row>}
            {d.cancel_reason && <Row label={t('admin.jb.cancel_reason')}>{d.cancel_reason}</Row>}
          </dl>
        </Card>

        <div className="flex flex-col gap-16">
          <Card i={1} title={t('admin.jb.where')}>
            <div className="flex items-start gap-12">
              <span className="inline-flex h-[40px] w-[40px] shrink-0 items-center justify-center rounded-full bg-bg-subtle text-mocha-700"><MapPin width={18} height={18} aria-hidden /></span>
              <div className="min-w-0 text-[14px]">
                <p className="break-words font-semibold">{p.address ?? t('admin.jb.no_address')}</p>
                <p className="mt-4 text-text-secondary">
                  {!p.started_at
                    ? t('admin.jb.not_started')
                    : p.start_lat === null
                    ? t('admin.jb.no_start_gps')
                    : p.start_distance_m === null
                      ? t('admin.jb.started_gps')
                      : t(p.start_distance_m <= 300 ? 'admin.jb.started_near' : 'admin.jb.started_far', { m: num(p.start_distance_m, lang) })}
                </p>
              </div>
            </div>
            <div className="mt-12 flex flex-wrap gap-8">
              {p.site_lat !== null && p.site_lng !== null && (
                <a href={mapUrl(p.site_lat, p.site_lng)} target="_blank" rel="noreferrer" className="kn-btn inline-flex h-[36px] items-center gap-8 rounded-lg border border-border-default px-12 text-[13px] font-semibold hover:border-mocha-500">
                  <ExternalLink width={14} height={14} aria-hidden />
                  {t('admin.jb.map_site')}
                </a>
              )}
              {p.start_lat !== null && p.start_lng !== null && (
                <a href={mapUrl(p.start_lat, p.start_lng)} target="_blank" rel="noreferrer" className="kn-btn inline-flex h-[36px] items-center gap-8 rounded-lg border border-border-default px-12 text-[13px] font-semibold hover:border-mocha-500">
                  <ExternalLink width={14} height={14} aria-hidden />
                  {t('admin.jb.map_start')}
                </a>
              )}
            </div>
          </Card>

          <Card i={2} title={t('admin.jb.proof')}>
            <div className="flex items-center gap-12">
              <p className="text-[32px] font-bold leading-[40px] tabular-nums">{num(d.proof.done, lang)}<span className="text-[20px] text-text-secondary">/{num(d.proof.total, lang)}</span></p>
              <div className="h-[8px] flex-1 overflow-hidden rounded-full bg-bg-subtle">
                <div className="h-full rounded-full bg-status-success transition-[width] duration-700" style={{ width: `${(d.proof.done / Math.max(1, d.proof.total)) * 100}%` }} />
              </div>
            </div>
            <p className="mt-8 flex items-center gap-8 text-[14px]"><Camera width={14} height={14} aria-hidden className="text-text-secondary" />{photosLine}</p>
            <p className="mt-4 flex items-center gap-8 text-[14px]"><Mic width={14} height={14} aria-hidden className="text-text-secondary" />{t('admin.jb.ph.voice', { n: num(d.photos.voice_notes, lang) })}</p>
            {d.photos.before + d.photos.during + d.photos.after > 0 && (
              <Link to={`/evidence?job=${d.id}`} className="mt-12 inline-flex items-center gap-4 text-[14px] font-semibold underline-offset-2 hover:underline">
                {t('admin.jb.see_photos')}
              </Link>
            )}
          </Card>
        </div>
      </div>

      <Card i={3} title={t('admin.jb.report')}>
        {!r ? (
          <p className="text-latin-body text-text-secondary">{t('admin.jb.no_report')}</p>
        ) : (
          <div className="flex flex-wrap items-center gap-x-24 gap-y-8 text-[14px]">
            <span className="inline-flex items-center gap-8 font-semibold"><FileText width={16} height={16} aria-hidden />#{r.number}</span>
            <span className="rounded-full bg-bg-subtle px-[10px] py-[3px] text-[13px] font-semibold text-mocha-700">{t(`admin.jb.rs.${r.status}`)}</span>
            {r.change_requests > 0 && <span className="text-status-danger">{t('admin.jb.changes_n', { n: num(r.change_requests, lang) })}</span>}
            {r.shared_at && <span className="text-text-secondary">{t('admin.jb.opened_n', { n: num(r.open_count, lang) })}</span>}
            {r.acknowledged_at && <span className="inline-flex items-center gap-4 text-status-success"><CheckCircle2 width={14} height={14} aria-hidden />{t('admin.jb.acked')}</span>}
          </div>
        )}
      </Card>

      <Card i={4} title={t('admin.jb.timeline')}>
        <ol className="flex flex-col">
          {d.timeline.map((e, i) => (
            <li key={i} className="kn-in flex flex-wrap items-baseline justify-between gap-x-16 gap-y-2 py-8" style={{ ['--d' as string]: `${320 + Math.min(i * 40, 400)}ms` }}>
              <span className="flex min-w-0 items-baseline gap-12 text-[14px] font-semibold">
                <span aria-hidden className={cx('relative top-[-1px] inline-block h-[10px] w-[10px] shrink-0 rounded-full', dot(e.type))} />
                <span className="break-words">{line(e, t)}</span>
              </span>
              <span className="whitespace-nowrap text-[13px] tabular-nums text-text-secondary">
                {at(e.at, lang)}
                {e.until && `–${clock(e.until, lang)}`}
              </span>
            </li>
          ))}
        </ol>
      </Card>
    </div>
  );
}
