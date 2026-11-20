import { AlertCircle, Check, ChevronLeft, Download, X } from 'lucide-react';
import { useCallback, useEffect, useState, type ReactNode } from 'react';

import { api, ApiError } from '../lib/api';
import { clock, day, num, type Lang, type T } from '../lib/i18n';
import type { AdminReportDetail } from '../lib/types';
import { cx, Link, PageActions } from '../ui';
import { ReportStatusPill } from './Reports';

const at = (iso: string, lang: Lang) => `${day(iso, lang, { year: undefined })}, ${clock(iso, lang)}`;

function Card({ title, children, i, className }: { title?: string; children: ReactNode; i: number; className?: string }) {
  return (
    <section className={cx('kn-in rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24', className)} style={{ ['--d' as string]: `${i * 80}ms` }}>
      {title && <h2 className="mb-12 text-[20px] font-semibold leading-[28px]">{title}</h2>}
      {children}
    </section>
  );
}

function Check1({ ok, children }: { ok: boolean; children: ReactNode }) {
  return (
    <li className="flex items-start gap-8 py-4 text-[14px] font-semibold">
      {ok ? <Check width={16} height={16} aria-hidden className="mt-[2px] shrink-0 text-status-success" /> : <AlertCircle width={16} height={16} aria-hidden className="mt-[2px] shrink-0 text-status-warning" />}
      <span className="min-w-0 break-words">{children}</span>
    </li>
  );
}

/** A15 Report details, read-only: the text and photos, what the AI checks found, who changed it, customer links. */
export function ReportDetail({ t, lang, id, onName }: { t: T; lang: Lang; id: string; onName: (n: string) => void }) {
  const [d, setD] = useState<AdminReportDetail | null>(null);
  const [error, setError] = useState<'missing' | 'load' | null>(null);
  const load = useCallback(() => {
    setError(null);
    api<AdminReportDetail>(`/admin/reports/${id}`)
      .then((x) => {
        setD(x);
        onName(`#${x.number} · ${x.job.customer}`);
      })
      .catch((e) => {
        if (e instanceof ApiError && (e.status === 404 || e.status === 422)) setError('missing');
        else if (!(e instanceof ApiError && e.status === 401)) setError('load');
      });
  }, [id, onName]);
  useEffect(load, [load]);

  const back = (
    <Link to="/reports" className="group inline-flex w-fit items-center gap-4 text-latin-label-sm font-semibold text-text-secondary hover:text-text-primary">
      <ChevronLeft width={16} height={16} className="transition-transform group-hover:-translate-x-[3px]" aria-hidden />
      {t('admin.rp.back')}
    </Link>
  );
  if (error)
    return (
      <div className="flex flex-col gap-16">
        {back}
        <div className="kn-in mx-auto mt-24 max-w-[480px] rounded-xl border border-border-default bg-bg-surface p-24 text-center">
          <p className="text-latin-body text-text-secondary">{t(error === 'missing' ? 'admin.rp.not_found' : 'admin.err.load')}</p>
          {error === 'load' && <button type="button" onClick={load} className="kn-btn mt-16 inline-flex h-[44px] items-center rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action">{t('admin.retry')}</button>}
        </div>
      </div>
    );
  if (!d)
    return (
      <div aria-busy="true" className="flex flex-col gap-16">
        {back}
        <div className="grid gap-16 lg:grid-cols-[minmax(0,1.6fr)_minmax(0,1fr)]">
          <div className="kn-shimmer h-[420px] rounded-xl bg-bg-surface" />
          <div className="kn-shimmer h-[240px] rounded-xl bg-bg-surface" />
        </div>
      </div>
    );

  const unsupported = d.flags.filter((f) => f.kind === 'unsupported_claim');
  const others = d.flags.filter((f) => f.kind !== 'unsupported_claim');
  const checked = d.status !== 'generating' && d.status !== 'generation_failed';
  const origin = d.drafted_by ? t(`admin.rp.by.${d.drafted_by}`) : null;
  const sections = (['summary', 'work_done', 'advice'] as const).filter((k) => d[k]);

  return (
    <div className="flex flex-col gap-16">
      {d.pdf_url && (
        <PageActions>
          <a href={d.pdf_url} target="_blank" rel="noreferrer" className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300">
            <Download width={16} height={16} aria-hidden />
            {t('admin.rp.pdf')}
          </a>
        </PageActions>
      )}
      {back}
      <div className="grid gap-16 lg:grid-cols-[minmax(0,1.6fr)_minmax(0,1fr)]">
        <Card i={0}>
          <div className="flex flex-wrap items-center gap-8">
            {origin && <span className="rounded-full bg-bg-subtle px-[10px] py-[3px] text-[13px] font-semibold text-mocha-700">{d.edited_by.length ? t('admin.rp.edited', { by: origin, who: d.edited_by.join(', ') }) : origin}</span>}
            <ReportStatusPill t={t} status={d.status} />
            <span className="text-[13px] text-text-secondary">{t(`lang.${d.language}`)}</span>
          </div>
          <h2 className="mt-12 break-words text-[28px] font-bold leading-[36px]">{d.job.customer}</h2>
          <p className="mt-4 text-[14px] text-text-secondary">
            <Link to={`/jobs/${d.job.id}`} className="font-semibold hover:underline">{`${d.job.title} · #${d.job.number}`}</Link>
            {' · '}
            <Link to={`/companies/${d.company.value}`} className="hover:underline">{d.company.label}</Link>
            {d.technician && ` · ${d.technician}`}
          </p>
          {d.photos.length > 0 && (
            <div className="mt-16 grid grid-cols-2 gap-8 sm:grid-cols-3">
              {d.photos.map((p, i) => (
                <a key={i} href={p.url} target="_blank" rel="noreferrer" className="group relative block aspect-[4/3] overflow-hidden rounded-lg bg-bg-subtle">
                  <img src={p.url} alt={t(`admin.ev.stage.${p.stage}`)} loading="lazy" className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-[1.04]" />
                  <span className="absolute left-8 top-8 rounded-full bg-bg-surface px-8 py-[2px] text-[12px] font-semibold">{t(`admin.ev.stage.${p.stage}`)}</span>
                </a>
              ))}
            </div>
          )}
          {d.error && <p className="mt-16 rounded-lg bg-status-danger-bg p-12 text-[14px] text-status-danger">{d.error}</p>}
          {sections.length === 0 && !d.error && <p className="mt-16 text-latin-body text-text-secondary">{t('admin.rp.no_text')}</p>}
          {sections.map((k) => (
            <div key={k} className="mt-16">
              <h3 className="text-[16px] font-semibold">{t(`admin.rp.sec.${k}`)}</h3>
              <p className="mt-4 whitespace-pre-line break-words text-latin-body">{d[k]}</p>
            </div>
          ))}
        </Card>

        <div className="flex flex-col gap-16">
          <Card i={1} title={t('admin.rp.ai_checks')}>
            {!checked ? (
              <p className="text-[14px] text-text-secondary">{t('admin.rp.not_checked')}</p>
            ) : (
              <ul>
                {d.sentences > 0 && <Check1 ok={d.sentences_linked === d.sentences}>{d.sentences_linked === d.sentences ? t('admin.rp.all_linked') : t('admin.rp.linked', { n: num(d.sentences_linked, lang), total: num(d.sentences, lang) })}</Check1>}
                {d.checks_passed + d.checks_failed > 0 && <Check1 ok={d.checks_failed === 0}>{t('admin.rp.checklist', { n: num(d.checks_passed, lang), total: num(d.checks_passed + d.checks_failed, lang) })}</Check1>}
                {others.map((f, i) => <Check1 key={i} ok={false}>{f.text}</Check1>)}
                <Check1 ok={unsupported.length === 0}>{unsupported.length === 0 ? t('admin.rp.no_invented') : t('admin.rp.invented', { n: num(unsupported.length, lang) })}</Check1>
                {unsupported.map((f, i) => <li key={i} className="ml-24 break-words text-[13px] text-text-secondary">“{f.text}”</li>)}
              </ul>
            )}
            {d.drafted_by === 'ai' && (
              <p className="mt-12 text-[13px] text-text-secondary">
                {t('admin.rp.prompt', { v: d.ai_prompt_version ?? '—', tokens: num(d.ai_tokens, lang), cost: num(d.ai_cost_usd, lang, { style: 'currency', currency: 'USD', maximumFractionDigits: 2 }) })}
              </p>
            )}
          </Card>

          <Card i={2} title={t('admin.rp.steps')}>
            <ol className="flex flex-col gap-8 text-[14px]">
              {([
                [d.created_at, t('admin.rp.st.created'), null],
                [d.submitted_at, t('admin.rp.st.submitted'), d.submitted_by],
                ...d.changes.map((c) => [c.at, t('admin.rp.st.changes', { why: c.reasons.map((r) => t(`admin.rp.reason.${r}`)).join(', ') }), c.by] as const),
                [d.approved_at, t('admin.rp.st.approved'), d.approved_by],
                [d.shared_at, t('admin.rp.st.shared'), null],
                [d.acknowledged_at, t('admin.rp.st.acknowledged'), d.acknowledged_name],
              ] as const)
                .filter(([when]) => when)
                .sort((a, b) => (a[0] as string).localeCompare(b[0] as string))
                .map(([when, what, who], i) => (
                  <li key={i} className="flex flex-wrap justify-between gap-x-12">
                    <span className="font-semibold">{what}{who ? <span className="font-normal text-text-secondary"> · {who}</span> : null}</span>
                    <span className="text-[13px] tabular-nums text-text-secondary">{at(when as string, lang)}</span>
                  </li>
                ))}
            </ol>
          </Card>

          <Card i={3} title={t('admin.rp.links')}>
            {d.links.length === 0 ? (
              <p className="text-[14px] text-text-secondary">{t('admin.rp.no_links')}</p>
            ) : (
              <ul className="flex flex-col divide-y divide-border-default text-[14px]">
                {d.links.map((l, i) => (
                  <li key={i} className="py-8">
                    <p className="flex flex-wrap items-center justify-between gap-8">
                      <span className="font-semibold">{t(`admin.rp.ch.${l.channel}`)}{l.recipient && <span className="font-normal text-text-secondary"> · {l.recipient}</span>}</span>
                      {l.revoked ? <span className="inline-flex items-center gap-4 text-[13px] text-status-danger"><X width={12} height={12} aria-hidden />{t('admin.rp.revoked')}</span> : <span className="text-[13px] text-text-secondary">{t('admin.rp.until', { when: day(l.expires_at, lang) })}</span>}
                    </p>
                    <p className="text-[13px] text-text-secondary">{l.opens ? t('admin.rp.opens', { n: num(l.opens, lang), when: l.last_opened_at ? at(l.last_opened_at, lang) : '—' }) : t('admin.rp.not_opened')}</p>
                  </li>
                ))}
              </ul>
            )}
          </Card>
        </div>
      </div>
    </div>
  );
}
