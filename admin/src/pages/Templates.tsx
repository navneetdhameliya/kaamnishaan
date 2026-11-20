import { AlertTriangle, Check, Info, RotateCcw, Send } from 'lucide-react';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';

import { api, ApiError } from '../lib/api';
import { LANGS, num, type Lang, type T } from '../lib/i18n';
import type { MessageTemplate, MsgChannel, TemplateKey, TemplatesOut, TemplateText } from '../lib/types';
import { cx, PageActions, Spinner, TextDialog } from '../ui';

type Draft = { text?: string; subject?: string; body?: string };
const LANG_NAMES: Record<Lang, string> = { en: 'English', hi: 'हिन्दी', gu: 'ગુજરાતી', es: 'Español', fr: 'Français' };
const PH = /\{\{\s*(\w+)\s*\}\}/g;

function fill(text: string, values: Record<string, string>): string {
  return text.replace(PH, (_, k: string) => values[k] ?? '').replace(/[ \t]+([,.])/g, '$1').trim();
}

/** SMS parts: 160 plain characters (153 each when split), or 70 (67) when it has Hindi, Gujarati or accents. */
function smsParts(text: string): { chars: number; per: number; parts: number } {
  const plain = /^[\x20-\x7E\n\r£¥èéùìòÇØøÅå]*$/.test(text);
  const chars = [...text].length;
  const one = plain ? 160 : 70;
  const many = plain ? 153 : 67;
  return { chars, per: one, parts: chars <= one ? 1 : Math.ceil(chars / many) };
}

/** Client-side copy of the server's checks (messages.problems), for instant feedback. */
function problems(tpl: MessageTemplate, channel: MsgChannel, d: Draft): Record<string, string> {
  const allowed = new Set(tpl.placeholders.filter((p) => channel === 'email' || !tpl.email_only.includes(p)));
  const fields = channel === 'email' ? (['subject', 'body'] as const) : (['text'] as const);
  const out: Record<string, string> = {};
  for (const f of fields) {
    const v = d[f] ?? '';
    if (!v.trim()) out[f] = 'required';
    else if ([...v.matchAll(PH)].some((m) => !allowed.has(m[1]))) out[f] = 'unknown_placeholder';
    else if (f === 'text' && /\bSTOP\b/.test(v)) out[f] = 'stop_added_automatically';
  }
  const main = channel === 'email' ? 'body' : 'text';
  if (!out[main] && !/\{\{\s*link\s*\}\}/.test(d[main] ?? '')) out[main] = 'needs_link';
  return out;
}

const slot = (k: TemplateKey, c: MsgChannel, l: Lang) => `${k}/${c}/${l}`;

/** A39 Message templates, from GET /admin/message-templates. */
export function Templates({ t, lang }: { t: T; lang: Lang }) {
  const [data, setData] = useState<TemplatesOut | null>(null);
  const [error, setError] = useState(false);
  const [key, setKey] = useState<TemplateKey>('report_review');
  const [channel, setChannel] = useState<MsgChannel>('sms');
  const [language, setLanguage] = useState<Lang>(LANGS.includes(lang) ? lang : 'en');
  const [drafts, setDrafts] = useState<Record<string, Draft>>({});
  const [busy, setBusy] = useState<string | null>(null);
  const [note, setNote] = useState<{ ok: boolean; text: string } | null>(null);
  const [serverErr, setServerErr] = useState<Record<string, string>>({});
  const [testing, setTesting] = useState(false);
  const ref = useRef<HTMLTextAreaElement>(null);

  const load = useCallback(() => {
    setError(false);
    api<TemplatesOut>('/admin/message-templates')
      .then(setData)
      .catch((e) => !(e instanceof ApiError && e.status === 401) && setError(true));
  }, []);
  useEffect(load, [load]);

  const tpl = data?.templates.find((x) => x.key === key);
  const saved: TemplateText | undefined = tpl?.texts.find((x) => x.channel === channel && x.language === language);
  const id = slot(key, channel, language);
  const draft: Draft = drafts[id] ?? (saved ? { text: saved.text ?? undefined, subject: saved.subject ?? undefined, body: saved.body ?? undefined } : {});
  const dirty = !!drafts[id] && (['text', 'subject', 'body'] as const).some((f) => (drafts[id][f] ?? null) !== (saved?.[f] ?? null));
  const errs = useMemo(() => (tpl ? problems(tpl, channel, draft) : {}), [tpl, channel, draft]);
  const shownErrs = { ...errs, ...serverErr };

  if (error && !data)
    return (
      <div className="kn-in mx-auto mt-48 max-w-[480px] rounded-xl border border-border-default bg-bg-surface p-24 text-center">
        <p className="text-latin-body text-text-secondary">{t('admin.err.load')}</p>
        <button type="button" onClick={load} className="kn-btn mt-16 inline-flex h-[44px] items-center rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action">
          {t('admin.retry')}
        </button>
      </div>
    );
  if (!data || !tpl || !saved)
    return (
      <div aria-busy="true" className="grid gap-16 lg:grid-cols-[320px_1fr]">
        <div className="kn-shimmer h-[320px] rounded-xl bg-bg-surface" />
        <div className="kn-shimmer h-[520px] rounded-xl bg-bg-surface" />
      </div>
    );

  const can = data.can_act;
  const pick = (k: TemplateKey) => {
    const next = data.templates.find((x) => x.key === k)!;
    setKey(k);
    if (!next.channels.includes(channel)) setChannel(next.channels[0]);
    setNote(null);
    setServerErr({});
  };
  const edit = (patch: Draft) => {
    setNote(null);
    setServerErr({});
    setDrafts((d) => ({ ...d, [id]: { ...draft, ...patch } }));
  };
  const insert = (ph: string) => {
    const token = `{{${ph}}}`;
    const el = ref.current;
    const field = channel === 'email' ? 'body' : 'text';
    const cur = draft[field] ?? '';
    const at = el && document.activeElement === el ? el.selectionStart : cur.length;
    edit({ [field]: cur.slice(0, at) + token + cur.slice(at) });
    window.setTimeout(() => {
      el?.focus();
      el?.setSelectionRange(at + token.length, at + token.length);
    }, 0);
  };
  const replace = (out: MessageTemplate, msg: string) => {
    setData({ ...data, templates: data.templates.map((x) => (x.key === out.key ? out : x)) });
    setDrafts((d) => {
      const n = { ...d };
      delete n[id];
      return n;
    });
    setNote({ ok: true, text: msg });
  };
  const call = async (what: string, fn: () => Promise<MessageTemplate>, msg: string) => {
    setBusy(what);
    setNote(null);
    try {
      replace(await fn(), msg);
    } catch (e) {
      if (e instanceof ApiError && e.status === 422) setServerErr(e.fields);
      setNote({ ok: false, text: e instanceof ApiError && e.status === 422 ? t('admin.mt.fix') : t('admin.err.generic') });
    } finally {
      setBusy(null);
    }
  };
  const path = `/admin/message-templates/${key}/${channel}/${language}`;
  const publish = () =>
    call('publish', () => api<MessageTemplate>(path, { method: 'PUT', body: channel === 'email' ? { subject: draft.subject, body: draft.body } : { text: draft.text } }), t('admin.mt.published'));

  const preview = channel === 'email' ? null : `${fill(draft.text ?? '', tpl.sample)} ${data.stop[language]}`;
  const count = preview && channel === 'sms' ? smsParts(preview) : null;
  const live = channel === 'sms' ? data.sms_live : channel === 'whatsapp' ? data.whatsapp_live : data.email_live;
  const errText = (f: string) => shownErrs[f] && t(`admin.mt.e.${shownErrs[f]}`);
  const inputCls = (f: string) => cx('mt-8 w-full rounded-lg border bg-bg-surface px-16 py-12 text-latin-body hover:border-mocha-500 focus:outline-none focus:ring-2 focus:ring-focus-ring disabled:opacity-70', shownErrs[f] ? 'border-status-danger' : 'border-border-strong');
  const statusOf = (l: Lang) => tpl.texts.find((x) => x.channel === channel && x.language === l)!;

  return (
    <div className="grid grid-cols-1 items-start gap-16 lg:grid-cols-[320px_minmax(0,1fr)]">
      {can && (
        <PageActions>
          <button type="button" onClick={() => setTesting(true)} disabled={Object.keys(errs).length > 0} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-50">
            <Send width={16} height={16} aria-hidden />
            <span className="hidden sm:inline">{t('admin.mt.test')}</span>
          </button>
          <button type="button" onClick={publish} disabled={!dirty || busy !== null || Object.keys(errs).length > 0} className="kn-btn inline-flex h-[40px] items-center gap-8 rounded-lg bg-action-primary px-16 text-latin-label-sm font-semibold text-text-on-action disabled:opacity-50">
            {busy === 'publish' ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
            {t('admin.mt.publish')}
          </button>
        </PageActions>
      )}

      <nav aria-label={t('admin.nav.templates')} className="kn-in overflow-hidden rounded-xl border border-border-default bg-bg-surface">
        <ul>
          {data.templates.map((x, i) => (
            <li key={x.key} className={cx(i > 0 && 'border-t border-border-default')}>
              <button type="button" onClick={() => pick(x.key)} aria-current={x.key === key ? 'true' : undefined} className={cx('flex w-full flex-col gap-2 px-16 py-12 text-left transition-colors', x.key === key ? 'bg-bg-subtle' : 'hover:bg-cream-100')}>
                <span className="text-latin-label-sm font-semibold">{t(`admin.mt.t.${x.key}`)}</span>
                <span className="text-[13px] text-text-secondary">{x.channels.map((c) => t(`admin.mt.ch.${c}`)).join(' · ')}</span>
                {x.texts.some((y) => !y.checked) && <span className="text-[12px] font-semibold text-status-warning">{t('admin.mt.some_review')}</span>}
              </button>
            </li>
          ))}
        </ul>
        <p className="border-t border-border-default px-16 py-12 text-[13px] text-text-secondary">{t('admin.mt.list_note')}</p>
      </nav>

      <section key={key} className="kn-in min-w-0 rounded-xl border border-border-default bg-bg-surface p-20 sm:p-24" style={{ ['--d' as string]: '80ms' }}>
        <div className="flex flex-wrap items-center justify-between gap-12">
          <h2 className="text-[22px] font-semibold leading-[30px]">{t(`admin.mt.t.${key}`)}</h2>
          {saved.checked ? (
            <span className="rounded-full bg-status-success-bg px-[10px] py-[3px] text-[13px] font-semibold text-status-success">{t(saved.edited ? 'admin.mt.st.edited' : 'admin.mt.st.checked')}</span>
          ) : (
            <span className="rounded-full bg-status-warning-bg px-[10px] py-[3px] text-[13px] font-semibold text-status-warning">{t('admin.mt.st.review')}</span>
          )}
        </div>
        <p className="mt-4 text-[13px] text-text-secondary">{t(`admin.mt.when.${key}`)}</p>

        <div className="mt-16 flex min-w-0 flex-wrap gap-12">
          <div role="tablist" aria-label={t('admin.mt.channel')} className="inline-flex rounded-lg bg-bg-subtle p-4">
            {tpl.channels.map((c) => (
              <button key={c} role="tab" type="button" aria-selected={c === channel} onClick={() => { setChannel(c); setServerErr({}); setNote(null); }} className={cx('h-[36px] rounded-md px-16 text-latin-label-sm font-semibold transition-colors', c === channel ? 'bg-bg-surface shadow-sm' : 'text-text-secondary hover:text-text-primary')}>
                {t(`admin.mt.ch.${c}`)}
              </button>
            ))}
          </div>
          <div role="tablist" aria-label={t('admin.mt.language')} className="-mx-4 flex min-w-0 max-w-full overflow-x-auto px-4">
            <div className="inline-flex rounded-lg bg-bg-subtle p-4">
              {LANGS.map((l) => (
                <button key={l} role="tab" type="button" lang={l} aria-selected={l === language} onClick={() => { setLanguage(l); setServerErr({}); setNote(null); }} className={cx('relative h-[36px] shrink-0 rounded-md px-12 text-latin-label-sm font-semibold transition-colors', l === language ? 'bg-bg-surface shadow-sm' : 'text-text-secondary hover:text-text-primary')}>
                  {LANG_NAMES[l]}
                  {drafts[slot(key, channel, l)] && <span aria-label={t('admin.mt.unsaved')} className="absolute right-[4px] top-[6px] h-[6px] w-[6px] rounded-full bg-status-warning" />}
                </button>
              ))}
            </div>
          </div>
        </div>

        {channel !== 'email' && (
          <p className="mt-16 flex items-start gap-8 rounded-lg bg-status-warning-bg px-12 py-8 text-[13px] text-status-warning">
            <AlertTriangle width={16} height={16} className="mt-[1px] shrink-0" aria-hidden />
            {t(channel === 'sms' ? 'admin.mt.dlt' : 'admin.mt.meta')}
          </p>
        )}
        {!live && (
          <p className="mt-8 flex items-start gap-8 text-[13px] text-text-secondary">
            <Info width={16} height={16} className="mt-[1px] shrink-0" aria-hidden />
            {t(`admin.mt.not_live.${channel}`)}
          </p>
        )}

        {channel === 'email' && (
          <>
            <label htmlFor="mt-subject" className="mt-16 block text-latin-label-sm font-semibold">
              {t('admin.mt.subject')}
            </label>
            <input id="mt-subject" value={draft.subject ?? ''} disabled={!can} maxLength={150} onChange={(e) => edit({ subject: e.target.value })} aria-invalid={!!shownErrs.subject} className={cx(inputCls('subject'), 'h-[48px] py-0')} />
            {errText('subject') && <p className="mt-4 text-[13px] font-semibold text-status-danger">{errText('subject')}</p>}
          </>
        )}
        <label htmlFor="mt-text" className="mt-16 block text-latin-label-sm font-semibold">
          {t('admin.mt.message')}
        </label>
        <textarea
          id="mt-text"
          ref={ref}
          lang={language}
          value={(channel === 'email' ? draft.body : draft.text) ?? ''}
          disabled={!can}
          rows={channel === 'email' ? 8 : 3}
          maxLength={channel === 'email' ? 3000 : 600}
          onChange={(e) => edit(channel === 'email' ? { body: e.target.value } : { text: e.target.value })}
          aria-invalid={!!shownErrs[channel === 'email' ? 'body' : 'text']}
          className={inputCls(channel === 'email' ? 'body' : 'text')}
        />
        {errText(channel === 'email' ? 'body' : 'text') && <p className="mt-4 text-[13px] font-semibold text-status-danger">{errText(channel === 'email' ? 'body' : 'text')}</p>}
        <p className="mt-4 text-[13px] text-text-secondary">
          {count
            ? t(count.parts === 1 ? 'admin.mt.count_one' : 'admin.mt.count', { n: num(count.chars, lang), max: num(count.per, lang), parts: num(count.parts, lang) })
            : channel === 'whatsapp'
              ? t('admin.mt.count_wa', { n: num([...(preview ?? '')].length, lang) })
              : t('admin.mt.email_note')}
        </p>

        {can && (
          <div className="mt-12 flex flex-wrap gap-8">
            {tpl.placeholders
              .filter((p) => channel === 'email' || !tpl.email_only.includes(p))
              .map((p) => (
                <button key={p} type="button" onClick={() => insert(p)} title={t('admin.mt.insert')} className="kn-btn rounded-md bg-bg-subtle px-8 py-4 font-mono text-[13px] font-semibold hover:bg-cream-300">
                  {`{{${p}}}`}
                </button>
              ))}
          </div>
        )}

        <div className="mt-16 rounded-lg bg-bg-subtle p-16">
          <p className="text-[13px] font-semibold text-text-secondary">{t('admin.mt.preview', { company: tpl.sample.company, customer: tpl.sample.customer })}</p>
          {channel === 'email' ? (
            <>
              <p className="mt-8 break-words text-latin-label-sm font-semibold" lang={language}>
                {fill(draft.subject ?? '', tpl.sample)}
              </p>
              <p className="mt-8 whitespace-pre-line break-words text-latin-body" lang={language}>
                {fill(draft.body ?? '', tpl.sample)}
              </p>
            </>
          ) : (
            <p className="mt-8 break-words text-latin-body" lang={language}>
              {preview}
            </p>
          )}
        </div>

        <ul className="mt-16 flex flex-wrap gap-8" aria-label={t('admin.mt.languages')}>
          {LANGS.map((l) => {
            const s = statusOf(l);
            return (
              <li key={l} className={cx('rounded-full px-[10px] py-[3px] text-[13px] font-semibold', s.checked ? 'bg-status-success-bg text-status-success' : 'bg-status-warning-bg text-status-warning')}>
                {t(s.checked ? 'admin.mt.lang_ok' : 'admin.mt.lang_review', { lang: t(`lang.${l}`) })}
              </li>
            );
          })}
        </ul>

        {note && (
          <p role={note.ok ? 'status' : 'alert'} className={cx('kn-pop mt-16 rounded-lg px-12 py-8 text-latin-label-sm font-semibold', note.ok ? 'bg-status-success-bg text-status-success' : 'bg-status-danger-bg text-status-danger')}>
            {note.text}
          </p>
        )}

        {can && (saved.edited || !saved.checked || dirty) && (
          <div className="mt-16 flex flex-wrap gap-12 border-t border-border-default pt-16">
            {dirty && (
              <button type="button" onClick={() => setDrafts((d) => { const n = { ...d }; delete n[id]; return n; })} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300">
                {t('admin.mt.discard')}
              </button>
            )}
            {!saved.checked && !dirty && (
              <button type="button" disabled={busy !== null} onClick={() => call('check', () => api<MessageTemplate>(`${path}/check`, { method: 'POST' }), t('admin.mt.checked_done'))} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-60">
                {busy === 'check' ? <Spinner /> : <Check width={16} height={16} aria-hidden />}
                {t('admin.mt.mark_checked')}
              </button>
            )}
            {saved.edited && !dirty && (
              <button type="button" disabled={busy !== null} onClick={() => call('reset', () => api<MessageTemplate>(path, { method: 'DELETE' }), t('admin.mt.reset_done'))} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg bg-bg-subtle px-16 text-latin-label-sm font-semibold hover:bg-cream-300 disabled:opacity-60">
                {busy === 'reset' ? <Spinner /> : <RotateCcw width={16} height={16} aria-hidden />}
                {t('admin.mt.reset')}
              </button>
            )}
          </div>
        )}
      </section>

      {testing && (
        <TextDialog
          t={t}
          title={t('admin.mt.test_title')}
          body={t(live ? 'admin.mt.test_body' : `admin.mt.not_live.${channel}`)}
          label={t(channel === 'email' ? 'admin.mt.test_email' : 'admin.mt.test_phone')}
          type={channel === 'email' ? 'email' : 'tel'}
          min={5}
          max={200}
          confirm={t('admin.mt.test_go')}
          onClose={() => setTesting(false)}
          onConfirm={async (to) => {
            try {
              const r = await api<{ sent: boolean; to: string }>('/admin/message-templates/test', { method: 'POST', body: { template: key, channel, language, to, ...(dirty ? draft : {}) } });
              setTesting(false);
              setNote({ ok: true, text: t(r.sent ? 'admin.mt.test_sent' : 'admin.mt.test_logged', { to: r.to }) });
              return null;
            } catch (e) {
              return e instanceof ApiError && e.fields?.to ? t('admin.mt.test_bad_to') : t('admin.err.generic');
            }
          }}
        />
      )}
    </div>
  );
}
