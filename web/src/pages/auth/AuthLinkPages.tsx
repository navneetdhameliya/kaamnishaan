import { CircleAlert, Clock, KeyRound, MailCheck } from 'lucide-react';
import { useEffect, useState, type FormEvent, type ReactNode } from 'react';

import { Button, Card, LanguageSelect } from '../../components/ui';
import { api, ApiError } from '../../lib/api';
import { rememberLang, startLang, translator, type Lang, type T } from '../../lib/i18n';
import { useRevealOnScroll } from '../../site/motion';

/** The token in ?token=… from the email link. */
const linkToken = () => new URLSearchParams(window.location.search).get('token') ?? '';

function Shell({ t, lang, onLang, children }: { t: T; lang: Lang; onLang: (l: Lang) => void; children: ReactNode }) {
  return (
    <div className="min-h-screen">
      <header className="border-b border-border-default bg-bg-surface">
        <div className="mx-auto flex max-w-[1200px] items-center gap-12 px-16 py-12 md:px-32">
          <span className="inline-flex h-[40px] w-[40px] items-center justify-center rounded-md bg-mocha-900 text-latin-label font-bold text-cream-50">
            K
          </span>
          <p className="flex-1 text-latin-label font-semibold">KaamNishaan</p>
          <LanguageSelect lang={lang} onChange={onLang} t={t} short />
        </div>
      </header>
      <main className="px-16 pb-48">
        <Card className="mx-auto mt-48 max-w-[460px]">{children}</Card>
      </main>
    </div>
  );
}

function useLang(): [Lang, (l: Lang) => void, T] {
  const [lang, setLang] = useState<Lang>(startLang);
  useRevealOnScroll();
  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);
  return [
    lang,
    (l) => {
      rememberLang(l);
      setLang(l);
    },
    translator(lang),
  ];
}

function Notice({ icon, tone, title, body }: { icon: ReactNode; tone: 'success' | 'warning'; title: string; body: string }) {
  return (
    <div className="text-center">
      <span
        className={
          tone === 'success'
            ? 'kn-pop mx-auto inline-flex h-[72px] w-[72px] items-center justify-center rounded-full bg-status-success-bg text-status-success'
            : 'kn-pop mx-auto inline-flex h-[72px] w-[72px] items-center justify-center rounded-full bg-status-warning-bg text-status-warning'
        }
      >
        {icon}
      </span>
      <h1 className="mt-16 text-web-m-h2">{title}</h1>
      <p className="mt-8 text-latin-body text-text-secondary">{body}</p>
    </div>
  );
}

function linkProblem(t: T, err: unknown) {
  const expired = err instanceof ApiError && err.code === 'link_expired';
  return (
    <Notice
      icon={expired ? <Clock width={28} height={28} /> : <CircleAlert width={28} height={28} />}
      tone="warning"
      title={expired ? t('web.auth.link_expired') : t('web.auth.link_bad')}
      body={expired ? t('web.auth.link_expired_body') : t('web.auth.link_bad_body')}
    />
  );
}

/** /verify-email?token=… — the link in "Confirm your email". Confirms at once. */
export function VerifyEmailPage() {
  const [lang, setLang, t] = useLang();
  const [state, setState] = useState<'working' | 'done' | unknown>('working');
  useEffect(() => {
    api('/auth/email/verify', { method: 'POST', body: { token: linkToken() } })
      .then(() => setState('done'))
      .catch((e: unknown) => setState(e));
  }, []);
  return (
    <Shell t={t} lang={lang} onLang={setLang}>
      {state === 'working' ? (
        <p className="py-24 text-center text-latin-body text-text-secondary">{t('web.auth.verify_working')}</p>
      ) : state === 'done' ? (
        <Notice icon={<MailCheck width={28} height={28} />} tone="success" title={t('web.auth.verified')} body={t('web.auth.verified_body')} />
      ) : (
        linkProblem(t, state)
      )}
    </Shell>
  );
}

/** /reset-password?token=… — the link in "Reset your password". */
export function ResetPasswordPage() {
  const [lang, setLang, t] = useLang();
  const [min, setMin] = useState(8);
  const [password, setPassword] = useState('');
  const [again, setAgain] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState<boolean | unknown>(false);

  useEffect(() => {
    api<{ password_min_length?: number }>('/config')
      .then((c) => c.password_min_length && setMin(c.password_min_length))
      .catch(() => undefined);
  }, []);

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (password.length < min) return setError(t('web.auth.too_short', { n: min }));
    if (password !== again) return setError(t('web.auth.mismatch'));
    setBusy(true);
    setError(null);
    try {
      await api('/auth/password/reset', { method: 'POST', body: { token: linkToken(), password } });
      setDone(true);
    } catch (err) {
      if (err instanceof ApiError && err.status === 410) setDone(err);
      else setError(err instanceof ApiError ? err.message : String(err));
    } finally {
      setBusy(false);
    }
  }

  const field = 'mt-4 w-full rounded-lg border border-border-strong bg-bg-surface px-12 py-12 text-latin-body outline-none focus:border-text-primary';
  return (
    <Shell t={t} lang={lang} onLang={setLang}>
      {done === true ? (
        <Notice icon={<KeyRound width={28} height={28} />} tone="success" title={t('web.auth.reset_done')} body={t('web.auth.reset_done_body')} />
      ) : done ? (
        linkProblem(t, done)
      ) : (
        <form onSubmit={submit} className="flex flex-col gap-16">
          <div>
            <h1 className="text-web-m-h2">{t('web.auth.reset_title')}</h1>
            <p className="mt-8 text-latin-body text-text-secondary">{t('web.auth.reset_body', { n: min })}</p>
          </div>
          <label className="text-latin-label-sm font-semibold">
            {t('web.auth.new_password')}
            <input type="password" autoComplete="new-password" value={password} onChange={(e) => setPassword(e.target.value)} className={field} />
          </label>
          <label className="text-latin-label-sm font-semibold">
            {t('web.auth.again')}
            <input type="password" autoComplete="new-password" value={again} onChange={(e) => setAgain(e.target.value)} className={field} />
          </label>
          {error && <p className="text-latin-label-sm font-semibold text-status-danger">{error}</p>}
          <Button type="submit" full disabled={busy || !password || !again}>
            {t('web.auth.save')}
          </Button>
        </form>
      )}
    </Shell>
  );
}
