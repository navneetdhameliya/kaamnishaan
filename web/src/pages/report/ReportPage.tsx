import { Check } from 'lucide-react';
import { useCallback, useEffect, useState } from 'react';

import { Badge, Initials, LanguageSelect } from '../../components/ui';
import { api, ApiError } from '../../lib/api';
import { isLang, rememberLang, startLang, translator, type Lang } from '../../lib/i18n';
import type { PublicReport } from '../../lib/types';
import { Acknowledge, LinkProblem } from './actions';
import { AllPhotos, BeforeAfter, Checklist, Footer, PdfButton, TechnicianCard, TitleBlock, TopBar, WorkAndAdvice, type PageCtx } from './parts';
import { RatingCard } from './RatingCard';
import { useRevealOnScroll } from '../../site/motion';

type State =
  | { kind: 'loading' }
  | { kind: 'ready'; report: PublicReport }
  | { kind: 'problem'; problem: 'expired' | 'revoked' | 'not_found' | 'error'; company: string | null };

/**
 * The page the customer opens from the SMS, WhatsApp or email (no login; the token is the key).
 * W27 shows the whole report; with ?rate=1 (the review request) it is W29: a short report and "Rate this job".
 */
export default function ReportPage({ token }: { token: string }) {
  const [lang, setLang] = useState<Lang>(startLang);
  const [state, setState] = useState<State>({ kind: 'loading' });
  const rate = new URLSearchParams(window.location.search).get('rate') === '1';
  const t = translator(lang);
  useRevealOnScroll();

  const load = useCallback(
    async (l: Lang) => {
      try {
        const report = await api<PublicReport>(`/public/reports/${encodeURIComponent(token)}?lang=${l}`);
        setState({ kind: 'ready', report });
      } catch (err) {
        if (err instanceof ApiError && (err.code === 'link_expired' || err.code === 'link_revoked')) {
          setState({
            kind: 'problem',
            problem: err.code === 'link_expired' ? 'expired' : 'revoked',
            company: typeof err.details.company === 'string' ? err.details.company : null,
          });
        } else {
          setState({ kind: 'problem', problem: err instanceof ApiError && err.status === 404 ? 'not_found' : 'error', company: null });
        }
      }
    },
    [token],
  );

  useEffect(() => {
    void load(lang);
  }, [load, lang]);

  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);

  function changeLang(l: Lang) {
    if (!isLang(l)) return;
    rememberLang(l);
    setLang(l);
  }

  if (state.kind === 'loading') {
    return (
      <main className="mx-auto max-w-[1000px] px-16 py-48 md:px-32" aria-busy>
        <div className="kn-shimmer h-[32px] w-2/3 rounded-lg" />
        <div className="kn-shimmer mt-24 h-[240px] rounded-xl" />
        <div className="kn-shimmer mt-16 h-[120px] rounded-xl" />
        <p className="sr-only">{t('web.r.loading')}</p>
      </main>
    );
  }

  if (state.kind === 'problem') {
    return (
      <div className="min-h-screen">
        <header className="border-b border-border-default bg-bg-surface">
          <div className="mx-auto flex max-w-[1200px] items-center gap-12 px-16 py-12 md:px-32 md:py-16">
            {state.company && <Initials name={state.company} />}
            <div className="min-w-0 flex-1">
              {state.company && <p className="truncate text-latin-label font-semibold">{state.company}</p>}
              <p className="text-latin-caption text-text-secondary">{t('web.r.subtitle')}</p>
            </div>
            <LanguageSelect lang={lang} onChange={changeLang} t={t} short />
          </div>
        </header>
        <main className="px-16 pb-48">
          <LinkProblem kind={state.problem} company={state.company} token={token} t={t} />
        </main>
      </div>
    );
  }

  const report = state.report;
  const ctx: PageCtx = { token, lang, t, report };
  const setReport = (r: PublicReport) => setState({ kind: 'ready', report: r });

  if (rate && report.review) {
    const total = report.checklists.reduce((n, c) => n + c.items.length, 0);
    const ok = report.checklists.reduce((n, c) => n + c.items.filter((i) => i.passed !== false).length, 0);
    return (
      <div className="min-h-screen">
        <TopBar ctx={ctx} onLang={changeLang} />
        <main className="mx-auto grid max-w-[1200px] gap-16 px-16 py-24 md:px-32 md:py-40 lg:grid-cols-[1fr_400px] lg:gap-24">
          <div className="lg:col-span-2">
            <TitleBlock ctx={ctx} compact />
          </div>
          <div className="flex flex-col gap-16">
            <BeforeAfter ctx={ctx}>
              {(report.summary || report.work_done.length > 0) && (
                <>
                  <h3 className="mt-20 text-latin-label font-semibold">{t('web.r.work_done')}</h3>
                  <p className="mt-8 text-latin-body">{report.summary ?? report.work_done.join(' ')}</p>
                </>
              )}
              <div className="mt-16 flex flex-wrap gap-8">
                {total > 0 && (
                  <Badge icon={<Check width={14} height={14} />}>{t('web.r.checklist_n', { a: ok, b: total })}</Badge>
                )}
                {report.photos.length > 0 && (
                  <Badge icon={<Check width={14} height={14} />}>{t('web.r.photos_stamped', { n: report.photos.length })}</Badge>
                )}
              </div>
            </BeforeAfter>
            <div className="md:hidden">
              <PdfButton ctx={ctx} variant="secondary" />
            </div>
          </div>
          <div className="lg:sticky lg:top-[96px] lg:self-start">
            <RatingCard ctx={ctx} review={report.review} />
          </div>
        </main>
        <Footer t={t} />
      </div>
    );
  }

  return (
    <div className="min-h-screen">
      <TopBar ctx={ctx} onLang={changeLang} />
      <main className="mx-auto flex max-w-[960px] flex-col gap-16 px-16 py-24 md:px-32 md:py-40">
        <TitleBlock ctx={ctx} />
        <TechnicianCard ctx={ctx} />
        <BeforeAfter ctx={ctx} />
        <AllPhotos ctx={ctx} />
        <Checklist ctx={ctx} />
        <WorkAndAdvice ctx={ctx} />
        <Acknowledge ctx={ctx} onDone={(a) => setReport({ ...report, acknowledged: a })} />
      </main>
      <Footer t={t} />
    </div>
  );
}
