import { CalendarClock, Check, ChevronDown, ChevronRight, CircleAlert, FileDown, Lock, MapPin, Wrench } from 'lucide-react';
import { useState, type ReactNode } from 'react';

import { Badge, Button, Card, Initials, LanguageSelect, cx } from '../../components/ui';
import { apiUrl } from '../../lib/api';
import { clock, day, type Lang, type T } from '../../lib/i18n';
import type { PublicPhoto, PublicReport } from '../../lib/types';

export interface PageCtx {
  token: string;
  lang: Lang;
  t: T;
  report: PublicReport;
}

/** The bar at the top: company, secure-link note, language, PDF. */
export function TopBar({ ctx, onLang }: { ctx: PageCtx; onLang: (l: Lang) => void }) {
  const { report, t, lang } = ctx;
  return (
    <header className="sticky top-0 z-10 border-b border-border-default bg-bg-surface">
      <div className="mx-auto flex max-w-[1200px] items-center gap-12 px-16 py-12 md:px-32 md:py-16">
        {report.company.logo_url ? (
          <img src={report.company.logo_url} alt="" className="h-[40px] w-[40px] rounded-md object-cover" />
        ) : (
          <Initials name={report.company.name} />
        )}
        <div className="min-w-0 flex-1">
          <p className="truncate text-latin-label font-semibold">{report.company.name}</p>
          <p className="text-latin-caption text-text-secondary">{t('web.r.subtitle')}</p>
        </div>
        <span className="hidden lg:inline-flex">
          <Badge icon={<Lock width={14} height={14} />}>
            {t('web.r.secure', { date: day(report.link_expires_at, lang, { year: undefined }) })}
          </Badge>
        </span>
        <LanguageSelect lang={lang} langs={report.languages} onChange={onLang} t={t} short />
        <span className="hidden md:inline-flex">
          <PdfButton ctx={ctx} variant="secondary" />
        </span>
      </div>
    </header>
  );
}

export function PdfButton({ ctx, variant }: { ctx: PageCtx; variant: 'secondary' | 'outline-light' | 'primary' }) {
  const ready = ctx.report.pdf_ready;
  return (
    <Button
      variant={variant}
      icon={<FileDown width={18} height={18} />}
      disabled={!ready}
      onClick={() => window.open(apiUrl(`/public/reports/${ctx.token}/pdf`), '_blank', 'noopener')}
    >
      {ready ? ctx.t('web.r.download') : ctx.t('web.r.pdf_making')}
    </Button>
  );
}

/** Badges, title and the where / when / who line. */
export function TitleBlock({ ctx, compact }: { ctx: PageCtx; compact?: boolean }) {
  const { report, t, lang } = ctx;
  const when = report.completed_at ?? report.approved_at;
  return (
    <div>
      <div className="flex flex-wrap gap-8">
        {report.approved_by && (
          <Badge tone="success" icon={<Check width={14} height={14} />}>
            {t('web.r.approved_by', { name: report.approved_by })}
          </Badge>
        )}
        {report.acknowledged && (
          <Badge icon={<Check width={14} height={14} />}>{t('web.r.acknowledged_badge')}</Badge>
        )}
        <Badge>{t('web.r.report_n', { n: report.number })}</Badge>
      </div>
      <h1 className="mt-12 text-web-m-display md:text-web-display">
        {compact ? report.title : t('web.r.title', { customer: report.customer })}
      </h1>
      <ul className="mt-12 flex flex-col gap-4 text-latin-label-sm text-text-secondary md:flex-row md:flex-wrap md:gap-20">
        {compact ? (
          <li className="flex items-center gap-4">
            <MapPin width={16} height={16} aria-hidden />
            {[report.customer, report.address].filter(Boolean).join(', ')}
          </li>
        ) : null}
        {when && (
          <li className="flex items-center gap-4">
            <CalendarClock width={16} height={16} aria-hidden />
            {day(when, lang, { weekday: compact ? 'short' : undefined })} · {clock(when, lang)}
          </li>
        )}
        {!compact && report.address && (
          <li className="flex items-center gap-4">
            <MapPin width={16} height={16} aria-hidden />
            {report.address}
          </li>
        )}
        {!compact && (
          <li className="flex items-center gap-4">
            <Wrench width={16} height={16} aria-hidden />
            {report.title} · #{report.number}
          </li>
        )}
        {compact && report.technician && (
          <li className="flex items-center gap-4">
            <Initials name={report.technician} dark={false} size={22} />
            {t('web.r.technician', { name: report.technician })}
          </li>
        )}
      </ul>
    </div>
  );
}

function Photo({ p, label, className }: { p: PublicPhoto; label?: string; className?: string }) {
  return (
    <figure className={cx('relative overflow-hidden rounded-lg bg-bg-subtle', className)}>
      <img src={p.url} alt={label ?? ''} loading="lazy" className="h-full w-full object-cover" />
      {label && (
        <figcaption className="absolute left-8 top-8 rounded-sm bg-espresso-900 px-8 py-2 text-latin-caption font-bold uppercase tracking-wide text-cream-50">
          {label}
        </figcaption>
      )}
    </figure>
  );
}

export function BeforeAfter({ ctx, children }: { ctx: PageCtx; children?: ReactNode }) {
  const { report, t } = ctx;
  const pair = report.pairs[0];
  if (!pair && !children) return null;
  return (
    <Card>
      <h2 className="text-web-h3">{t('web.r.before_after')}</h2>
      {pair && (
        <div className="mt-16 grid grid-cols-2 gap-8 md:gap-12">
          <Photo p={pair.before} label={t('web.r.before')} className="aspect-[4/3]" />
          <Photo p={pair.after} label={t('web.r.after')} className="aspect-[4/3]" />
        </div>
      )}
      {children}
    </Card>
  );
}

export function TechnicianCard({ ctx }: { ctx: PageCtx }) {
  const { report, t } = ctx;
  if (!report.technician) return null;
  const translated = report.language !== ctx.lang;
  return (
    <Card className="flex flex-col gap-12 md:flex-row md:items-center">
      <div className="flex flex-1 items-center gap-12">
        <Initials name={report.technician} dark={false} size={44} />
        <div>
          <p className="text-latin-label font-semibold">{report.technician}</p>
          <p className="text-latin-caption text-text-secondary">{t('web.r.tech_line', { company: report.company.name })}</p>
        </div>
      </div>
      {translated && (
        <Badge>{t('web.r.translated', { language: t(`web.lang.${report.language}`) })}</Badge>
      )}
    </Card>
  );
}

export function AllPhotos({ ctx }: { ctx: PageCtx }) {
  const { report, t } = ctx;
  if (report.photos.length === 0) return null;
  return (
    <Card>
      <div className="flex items-baseline justify-between">
        <h2 className="text-web-h3">{t('web.r.all_photos')}</h2>
        <span className="text-latin-caption text-text-secondary">{t('web.r.n_photos', { n: report.photos.length })}</span>
      </div>
      <div className="mt-16 flex snap-x gap-8 overflow-x-auto pb-4 md:grid md:grid-cols-4 md:overflow-visible">
        {report.photos.map((p) => (
          <a key={p.id} href={p.url} target="_blank" rel="noopener" className="w-[45%] shrink-0 snap-start md:w-auto">
            <Photo p={{ ...p, url: p.thumb_url ?? p.url }} className="aspect-[4/3]" />
          </a>
        ))}
      </div>
    </Card>
  );
}

export function Checklist({ ctx }: { ctx: PageCtx }) {
  const { report, t } = ctx;
  const [all, setAll] = useState(false);
  const items = report.checklists.flatMap((c) => c.items);
  if (items.length === 0) return null;
  const passed = items.filter((i) => i.passed !== false);
  const notes = items.filter((i) => i.passed === false);

  return (
    <Card>
      <div className="flex flex-wrap items-center justify-between gap-8">
        <h2 className="text-web-h3">{t('web.r.checklist')}</h2>
        <div className="flex gap-8">
          <Badge tone="success" icon={<Check width={14} height={14} />}>
            {t('web.r.passed', { n: passed.length })}
          </Badge>
          {notes.length > 0 && (
            <Badge tone="warning" icon={<CircleAlert width={14} height={14} />}>
              {notes.length === 1 ? t('web.r.one_note') : t('web.r.notes', { n: notes.length })}
            </Badge>
          )}
        </div>
      </div>
      <ul className="mt-16 grid gap-12 md:grid-cols-2 md:gap-x-32">
        {passed.map((i, n) => (
          <li key={n} className={cx('items-start gap-8 text-latin-body', n >= 5 && !all ? 'hidden md:flex' : 'flex')}>
            <Check width={18} height={18} className="mt-2 shrink-0 text-status-success" aria-hidden />
            <span>
              {i.question}
              {i.answer && !/^(yes|pass|ok)$/i.test(i.answer) ? <span className="text-text-secondary"> · {i.answer}</span> : null}
            </span>
          </li>
        ))}
      </ul>
      {!all && passed.length > 5 && (
        <button
          type="button"
          onClick={() => setAll(true)}
          className="mt-12 inline-flex items-center gap-4 text-latin-label-sm font-semibold text-text-secondary md:hidden"
        >
          {t('web.r.show_all', { n: passed.length })}
          <ChevronDown width={16} height={16} />
        </button>
      )}
      {notes.map((i, n) => (
        <div key={n} className="mt-16 flex gap-8 rounded-lg bg-status-warning-bg p-12">
          <CircleAlert width={18} height={18} className="mt-2 shrink-0 text-status-warning" aria-hidden />
          <div>
            <p className="text-latin-label-sm font-semibold">{i.question}</p>
            <p className="text-latin-caption text-text-secondary">{i.answer}</p>
          </div>
        </div>
      ))}
    </Card>
  );
}

export function WorkAndAdvice({ ctx }: { ctx: PageCtx }) {
  const { report, t } = ctx;
  return (
    <Card className="grid gap-24 md:grid-cols-2 md:gap-32">
      <div>
        <h2 className="text-web-h3">{t('web.r.work_done')}</h2>
        {report.summary && <p className="mt-12 text-latin-body text-text-secondary">{report.summary}</p>}
        {report.work_done.length > 0 && (
          <ul className="mt-8 list-disc pl-20 text-latin-body text-text-secondary">
            {report.work_done.map((w, i) => (
              <li key={i}>{w}</li>
            ))}
          </ul>
        )}
      </div>
      {report.advice.length > 0 && (
        <div>
          <h2 className="text-web-h3">{t('web.r.advice')}</h2>
          <ul className="mt-12 flex flex-col gap-8">
            {report.advice.map((a, i) => (
              <li key={i} className="flex gap-8 text-latin-body">
                <ChevronRight width={18} height={18} className="mt-2 shrink-0" aria-hidden />
                {a}
              </li>
            ))}
          </ul>
        </div>
      )}
    </Card>
  );
}

export function Footer({ t }: { t: T }) {
  return (
    <footer className="mt-48 border-t border-border-default py-24 text-center text-latin-caption text-text-secondary">
      {t('web.r.powered')} · <a href="/privacy" className="underline-offset-4 hover:underline">{t('web.r.privacy')}</a>
    </footer>
  );
}
