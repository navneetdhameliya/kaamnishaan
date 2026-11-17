import { Check, Lock, Send, Share } from 'lucide-react';
import { useState, type ReactNode } from 'react';

import { Button, Initials, Stars, TagChip, cx } from '../../components/ui';
import { api, ApiError } from '../../lib/api';
import type { PublicReviewState, RatedOut, ReviewIn } from '../../lib/types';
import type { PageCtx } from './parts';

const LOW = 2;

/** W29 Rate this job: stars for the service and the technician, tags, words, then thanks. */
export function RatingCard({ ctx, review }: { ctx: PageCtx; review: PublicReviewState }) {
  const { t, report } = ctx;
  const company = report.company.name;
  const [rating, setRating] = useState(0);
  const [techRating, setTechRating] = useState(0);
  const [tags, setTags] = useState<string[]>([]);
  const [comment, setComment] = useState('');
  const [publicOk, setPublicOk] = useState(true);
  const [callMe, setCallMe] = useState(false);
  const [missing, setMissing] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<{ sent: ReviewIn; out: RatedOut } | null>(null);
  const [stopped, setStopped] = useState(false);

  const low = rating > 0 && rating <= LOW;
  const bad = rating > 0 && rating <= 3;
  const tagList = bad ? review.negative_tags : review.positive_tags;
  const tech = review.technician;

  function pick(n: number) {
    setRating(n);
    setMissing(false);
    if (!techRating || techRating === rating) setTechRating(n);
    // the other kind of tags no longer fits
    setTags((ts) => ts.filter((x) => (n <= 3 ? review.negative_tags : review.positive_tags).includes(x)));
  }

  function toggle(tag: string) {
    setTags((ts) => (ts.includes(tag) ? ts.filter((x) => x !== tag) : [...ts, tag]));
  }

  async function send() {
    if (!rating) {
      setMissing(true);
      return;
    }
    const body: ReviewIn = {
      rating,
      technician_rating: tech && techRating ? techRating : null,
      tags,
      comment: comment.trim() || null,
      name: null,
      public_allowed: !bad && publicOk,
      wants_call_back: low && callMe,
    };
    setBusy(true);
    setError(null);
    try {
      const out = await api<RatedOut>(`/public/reports/${ctx.token}/review`, { method: 'POST', body });
      setDone({ sent: body, out });
    } catch (err) {
      setError(err instanceof ApiError ? err.message : t('web.r.error'));
    } finally {
      setBusy(false);
    }
  }

  async function stop() {
    try {
      await api(`/public/reports/${ctx.token}/review/stop`, { method: 'POST' });
      setStopped(true);
    } catch {
      setError(t('web.r.error'));
    }
  }

  const shell = (border: string, children: ReactNode) => (
    <section className={cx('rounded-xl border-2 bg-bg-surface p-20 md:p-24', border)}>{children}</section>
  );

  if (stopped) return shell('border-border-default', <p className="text-latin-body">{t('web.rate.stopped')}</p>);

  if (review.rated && !done) {
    return shell('border-border-default', <p className="text-latin-body">{t('web.rate.already')}</p>);
  }

  if (done) {
    const s = done.sent;
    return shell(
      'border-text-primary',
      <>
        <span className="inline-flex h-[48px] w-[48px] items-center justify-center rounded-full bg-status-success-bg text-status-success">
          <Check width={24} height={24} />
        </span>
        <h2 className="mt-16 text-web-h3">{t('web.rate.thanks_plain')}</h2>
        <p className="mt-8 text-latin-body text-text-secondary">{t('web.rate.sent_body', { company })}</p>
        <div className="mt-16 rounded-lg bg-action-secondary p-16">
          <div className="flex items-center gap-8">
            <Stars value={s.rating} size={16} />
            <span className="text-latin-label-sm font-semibold">{t(`web.rate.s${s.rating}`)}</span>
          </div>
          {s.comment && <p className="mt-8 text-latin-body">“{s.comment}”</p>}
          {s.tags.length > 0 && (
            <div className="mt-8 flex flex-wrap gap-4">
              {s.tags.map((x) => (
                <span key={x} className="rounded-full bg-bg-surface px-8 py-2 text-latin-caption font-semibold">
                  {t(`tag.${x}`)}
                </span>
              ))}
            </div>
          )}
        </div>
        {done.out.google_review_url && (
          <div className="mt-16 rounded-lg border border-border-default p-16">
            <p className="text-latin-label font-semibold">{t('web.rate.google_title')}</p>
            <p className="mt-4 text-latin-body text-text-secondary">{t('web.rate.google_body', { company })}</p>
            <a
              href={done.out.google_review_url}
              target="_blank"
              rel="noopener"
              className="mt-12 inline-flex min-h-[48px] w-full items-center justify-center gap-8 rounded-lg bg-action-secondary text-web-label font-semibold"
            >
              <Share width={18} height={18} />
              {t('web.rate.google')}
            </a>
          </div>
        )}
      </>,
    );
  }

  return shell(
    low || missing ? 'border-status-danger' : 'border-text-primary',
    <>
      <h2 className="text-web-h3">{t('web.rate.title')}</h2>
      <p className="mt-8 text-latin-body text-text-secondary">{t('web.rate.intro', { company })}</p>

      <p className="mt-16 text-latin-label font-semibold">{t('web.rate.service')}</p>
      <div className="mt-8 flex items-center gap-12">
        <Stars value={rating} size={30} onPick={pick} label={t('web.rate.service')} />
        {rating > 0 && (
          <span className={cx('text-latin-label font-semibold', low && 'text-status-danger')}>{t(`web.rate.s${rating}`)}</span>
        )}
      </div>
      {missing && <p className="mt-4 text-latin-label-sm font-semibold text-status-danger">{t('web.rate.missing')}</p>}

      {tech && (
        <div className="mt-16 flex items-center gap-12">
          <Initials name={tech} dark={false} size={36} />
          <div>
            <p className="text-latin-label-sm font-semibold">{t('web.rate.tech', { name: tech })}</p>
            <Stars value={techRating} size={18} onPick={setTechRating} label={t('web.rate.tech', { name: tech })} />
          </div>
        </div>
      )}

      {rating > 0 && (
        <>
          <p className="mt-16 text-latin-label font-semibold">{bad ? t('web.rate.went_wrong') : t('web.rate.went_well')}</p>
          <div className="mt-8 flex flex-wrap gap-8">
            {tagList.map((x) => (
              <TagChip key={x} label={t(`tag.${x}`)} on={tags.includes(x)} onClick={() => toggle(x)} danger={bad} />
            ))}
          </div>
        </>
      )}

      <label className="mt-16 block text-latin-label-sm font-semibold">
        {t('web.rate.more')}
        <textarea
          value={comment}
          onChange={(e) => setComment(e.target.value)}
          maxLength={1000}
          rows={3}
          className="mt-8 w-full rounded-lg border border-border-strong bg-bg-surface p-12 text-latin-body font-normal outline-none focus:border-text-primary"
        />
      </label>

      {low ? (
        <button
          type="button"
          role="switch"
          aria-checked={callMe}
          onClick={() => setCallMe(!callMe)}
          className="mt-16 flex w-full items-center gap-12 rounded-lg bg-status-danger-bg p-12 text-left"
        >
          <span className="flex-1">
            <span className="block text-latin-label-sm font-semibold">{t('web.rate.call_me')}</span>
            <span className="block text-latin-caption text-text-secondary">{t('web.rate.call_me_sub')}</span>
          </span>
          <span className={cx('relative h-[28px] w-[48px] shrink-0 rounded-full transition', callMe ? 'bg-action-primary' : 'bg-taupe-400')}>
            <span className={cx('absolute top-[3px] h-[22px] w-[22px] rounded-full bg-bg-surface transition-all', callMe ? 'left-[23px]' : 'left-[3px]')} />
          </span>
        </button>
      ) : (
        !bad && (
          <label className="mt-16 flex cursor-pointer items-start gap-12">
            <input type="checkbox" checked={publicOk} onChange={(e) => setPublicOk(e.target.checked)} className="mt-2 h-[22px] w-[22px] shrink-0 accent-mocha-900" />
            <span className="text-latin-label-sm font-semibold">{t('web.rate.public', { company })}</span>
          </label>
        )
      )}

      {error && <p className="mt-12 text-latin-label-sm font-semibold text-status-danger">{error}</p>}
      <div className="mt-16">
        <Button full onClick={send} disabled={busy} icon={bad ? <Send width={18} height={18} /> : <Check width={18} height={18} />}>
          {bad ? t('web.rate.send_feedback') : t('web.rate.send')}
        </Button>
      </div>
      <p className="mt-12 flex gap-4 text-latin-caption text-text-secondary">
        <Lock width={14} height={14} className="mt-2 shrink-0" aria-hidden />
        {t('web.rate.private', { company })}
      </p>
      <button type="button" onClick={stop} className="mt-8 text-latin-caption text-text-secondary underline underline-offset-4">
        {t('web.rate.stop')}
      </button>
    </>,
  );
}
