import { Check, CircleAlert, Clock, MessageSquareWarning, Share, ShieldOff } from 'lucide-react';
import { useState, type FormEvent } from 'react';

import { Button, Card } from '../../components/ui';
import { api, ApiError } from '../../lib/api';
import { day, type T } from '../../lib/i18n';
import type { NewLinkOut, PublicReport } from '../../lib/types';
import { PdfButton, type PageCtx } from './parts';

/** W27 "Happy with the work?" → name → acknowledged. */
export function Acknowledge({ ctx, onDone }: { ctx: PageCtx; onDone: (a: PublicReport['acknowledged']) => void }) {
  const { report, t, lang } = ctx;
  const [open, setOpen] = useState(false);
  const [name, setName] = useState('');
  const [org, setOrg] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (report.acknowledged) {
    const a = report.acknowledged;
    return (
      <section className="rounded-xl border border-status-success bg-status-success-bg p-24 md:p-32">
        <span className="inline-flex h-[44px] w-[44px] items-center justify-center rounded-full bg-status-success text-cream-50">
          <Check width={22} height={22} />
        </span>
        <h2 className="mt-16 text-web-h2">{t('web.r.thanks_ack')}</h2>
        <p className="mt-8 text-latin-body text-text-secondary">
          {t('web.r.ack_line', { name: a.name, date: day(a.at, lang), company: report.company.name })}
        </p>
        <div className="mt-20">
          <PdfButton ctx={ctx} variant="primary" />
        </div>
      </section>
    );
  }

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    setBusy(true);
    setError(null);
    try {
      const a = await api<NonNullable<PublicReport['acknowledged']>>(`/public/reports/${ctx.token}/acknowledge`, {
        method: 'POST',
        body: { name: name.trim(), organisation: org.trim() || null },
      });
      onDone(a);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t('web.r.error'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="rounded-xl bg-espresso-900 p-24 text-center text-cream-50 md:p-40">
      <h2 className="text-web-m-h2 md:text-web-h2">{t('web.r.happy')}</h2>
      <p className="mx-auto mt-8 max-w-[560px] text-latin-body text-cream-400">
        {t('web.r.happy_body', { company: report.company.name })}
      </p>
      {open ? (
        <form onSubmit={submit} className="mx-auto mt-20 flex max-w-[420px] flex-col gap-12 text-left">
          <label className="text-latin-label-sm font-semibold">
            {t('web.r.your_name')}
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              maxLength={120}
              autoFocus
              className="mt-4 w-full rounded-lg border border-espresso-700 bg-espresso-850 px-12 py-12 text-latin-body text-cream-50 outline-none focus:border-cream-400"
            />
          </label>
          <label className="text-latin-label-sm font-semibold">
            {t('web.r.your_org')}
            <input
              value={org}
              onChange={(e) => setOrg(e.target.value)}
              maxLength={160}
              className="mt-4 w-full rounded-lg border border-espresso-700 bg-espresso-850 px-12 py-12 text-latin-body text-cream-50 outline-none focus:border-cream-400"
            />
          </label>
          {error && <p className="text-latin-label-sm text-red-50">{error}</p>}
          <Button variant="light" type="submit" disabled={busy || !name.trim()} icon={<Check width={18} height={18} />}>
            {t('web.r.confirm')}
          </Button>
        </form>
      ) : (
        <div className="mt-20 flex flex-col justify-center gap-12 md:flex-row">
          <Button variant="light" onClick={() => setOpen(true)} icon={<Check width={18} height={18} />}>
            {t('web.r.acknowledge')}
          </Button>
          <PdfButton ctx={ctx} variant="outline-light" />
        </div>
      )}
    </section>
  );
}

/** W27 / W29 link expired, turned off, or not found. */
export function LinkProblem({
  kind,
  company,
  token,
  t,
}: {
  kind: 'expired' | 'revoked' | 'not_found' | 'error';
  company: string | null;
  token: string;
  t: T;
}) {
  const [sent, setSent] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const icon =
    kind === 'expired' ? <Clock width={28} height={28} /> : kind === 'revoked' ? <ShieldOff width={28} height={28} /> : <MessageSquareWarning width={28} height={28} />;
  const title =
    kind === 'expired' ? t('web.r.expired_title') : kind === 'revoked' ? t('web.r.revoked_title') : kind === 'not_found' ? t('web.r.not_found_title') : t('web.r.error');

  async function newLink() {
    setBusy(true);
    try {
      const r = await api<NewLinkOut>(`/public/reports/${token}/request-link`, { method: 'POST' });
      setSent(r.sent_to ? t('web.r.new_link_sent', { to: r.sent_to }) : t('web.r.new_link_told', { company: company ?? '' }));
    } catch (err) {
      setSent(err instanceof ApiError ? err.message : t('web.r.error'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card className="mx-auto mt-48 max-w-[520px] text-center">
      <span className="mx-auto inline-flex h-[80px] w-[80px] items-center justify-center rounded-full bg-status-warning-bg text-status-warning">
        {icon}
      </span>
      <h1 className="mt-16 text-web-m-h2 md:text-web-h2">{title}</h1>
      {kind === 'expired' && <p className="mt-8 text-latin-body text-text-secondary">{t('web.r.expired_body')}</p>}
      {kind === 'revoked' && <p className="mt-8 text-latin-body text-text-secondary">{t('web.r.revoked_body', { company: company ?? '' })}</p>}
      {kind === 'expired' && (
        <div className="mt-20 flex flex-col gap-12">
          {sent ? (
            <p className="rounded-lg bg-status-success-bg p-12 text-latin-label-sm text-status-success">{sent}</p>
          ) : (
            <Button full onClick={newLink} disabled={busy} icon={<Share width={18} height={18} />}>
              {t('web.r.new_link')}
            </Button>
          )}
        </div>
      )}
      {kind === 'error' && (
        <div className="mt-20">
          <Button full onClick={() => window.location.reload()}>{t('web.r.try_again')}</Button>
        </div>
      )}
      {(kind === 'expired' || kind === 'not_found') && (
        <p className="mt-16 flex gap-8 rounded-lg bg-action-secondary p-12 text-left text-latin-caption text-text-secondary">
          <CircleAlert width={16} height={16} className="mt-2 shrink-0" aria-hidden />
          {t('web.r.broken')}
        </p>
      )}
    </Card>
  );
}

