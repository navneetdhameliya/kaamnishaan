import { ChevronLeft, Eye, EyeOff, Lock } from 'lucide-react';
import { useState, type FormEvent } from 'react';

import { api, ApiError } from '../lib/api';
import { clock, type Lang, type T } from '../lib/i18n';
import { session } from '../lib/session';
import type { StaffSession } from '../lib/types';
import { Card, ErrorBanner, inputCls, Link, navigate, OtpInput, primaryBtn, Spinner } from '../ui';

/** A01 Admin log in: email, password and the authenticator code (or a recovery code). */
export function Login({ t, lang }: { t: T; lang: Lang }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [show, setShow] = useState(false);
  const [code, setCode] = useState('');
  const [recovery, setRecovery] = useState('');
  const [useRecovery, setUseRecovery] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(() => (session.takeEnded() ? t('admin.session_ended') : null));
  const [tries, setTries] = useState(0);

  async function submit(e: FormEvent) {
    e.preventDefault();
    const second = useRecovery ? recovery.trim() : code;
    if (!email.trim() || !password || (useRecovery ? !second : second.length !== 6)) {
      setError(t(useRecovery ? 'admin.login.err_fill_recovery' : 'admin.login.err_fill'));
      setTries((n) => n + 1);
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const s = await api<StaffSession>('/admin/auth/login', {
        method: 'POST',
        auth: false,
        body: { email: email.trim(), password, ...(useRecovery ? { recovery_code: second } : { code: second }) },
      });
      session.set(s);
      navigate('/', true);
    } catch (err) {
      setCode('');
      setRecovery('');
      if (err instanceof ApiError && err.code === 'login_invalid') {
        const left = Number(err.details.attempts_left ?? 0);
        setError(left === 1 ? t('admin.login.err_invalid_one') : t('admin.login.err_invalid', { n: left }));
      } else if (err instanceof ApiError && err.code === 'account_locked') {
        const until = String(err.details.locked_until ?? '');
        setError(t('admin.login.err_locked', { time: until ? clock(until, lang) : '15 min' }));
      } else if (err instanceof ApiError && err.status === 0) setError(t('admin.err.offline'));
      else setError(t('admin.err.generic'));
      setTries((n) => n + 1);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card>
      <h1 className="text-[28px] font-bold leading-[36px] sm:text-[32px] sm:leading-[40px]">{t('admin.login.title')}</h1>
      <p className="mt-8 text-latin-body text-text-secondary">{t('admin.login.body')}</p>
      <form noValidate onSubmit={(e) => void submit(e)} className="mt-24 flex flex-col gap-20">
        {error && <ErrorBanner shake={tries}>{error}</ErrorBanner>}
        <div className="flex flex-col gap-8">
          <label htmlFor="email" className="text-latin-label font-semibold">
            {t('admin.login.email')}
          </label>
          <input id="email" type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="name@kaamnishaan.com" className={inputCls} />
        </div>
        <div className="flex flex-col gap-8">
          <label htmlFor="password" className="text-latin-label font-semibold">
            {t('admin.login.password')}
          </label>
          <div className="relative">
            <input id="password" type={show ? 'text' : 'password'} autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} className={`${inputCls} pr-[56px]`} />
            <button
              type="button"
              onClick={() => setShow((v) => !v)}
              aria-label={t(show ? 'admin.login.hide_pw' : 'admin.login.show_pw')}
              className="absolute right-8 top-1/2 inline-flex h-[40px] w-[40px] -translate-y-1/2 items-center justify-center rounded-md text-text-secondary hover:bg-bg-subtle hover:text-text-primary"
            >
              {show ? <EyeOff width={20} height={20} aria-hidden /> : <Eye width={20} height={20} aria-hidden />}
            </button>
          </div>
        </div>
        {useRecovery ? (
          <div key="recovery" className="kn-in flex flex-col gap-8">
            <label htmlFor="recovery" className="text-latin-label font-semibold">
              {t('admin.login.recovery')}
            </label>
            <input id="recovery" autoComplete="off" spellCheck={false} value={recovery} onChange={(e) => setRecovery(e.target.value)} placeholder="7f3a-91c0" className={`${inputCls} font-mono tracking-wider`} />
            <p className="text-latin-caption text-text-secondary">{t('admin.login.recovery_hint')}</p>
          </div>
        ) : (
          <div key="code" className="kn-in flex flex-col gap-8">
            <label htmlFor="otp" className="text-latin-label font-semibold">
              {t('admin.login.code')}
            </label>
            <OtpInput value={code} onChange={setCode} t={t} />
          </div>
        )}
        <button type="submit" disabled={busy} className={primaryBtn}>
          {busy ? <Spinner /> : <Lock width={18} height={18} aria-hidden />}
          {t('admin.login.submit')}
        </button>
        <div className="flex flex-wrap items-center justify-between gap-12">
          <Link to="/forgot-password" className="kn-link text-latin-label-sm font-semibold text-mocha-700">
            {t('admin.login.forgot')}
          </Link>
          <button
            type="button"
            onClick={() => {
              setUseRecovery((v) => !v);
              setError(null);
            }}
            className="kn-link text-latin-label-sm font-semibold text-mocha-700"
          >
            {t(useRecovery ? 'admin.login.use_code' : 'admin.login.use_recovery')}
          </button>
        </div>
      </form>
    </Card>
  );
}

/** A02 Forgot password. There is no email service yet (D-96), so the page says how to get a new setup link. */
export function Forgot({ t }: { t: T }) {
  return (
    <Card>
      <Link to="/login" className="group inline-flex items-center gap-4 text-latin-label-sm font-semibold text-text-secondary hover:text-text-primary">
        <ChevronLeft width={16} height={16} className="transition-transform group-hover:-translate-x-[3px]" aria-hidden />
        {t('admin.forgot.back')}
      </Link>
      <h1 className="mt-20 text-[28px] font-bold leading-[36px] sm:text-[32px] sm:leading-[40px]">{t('admin.forgot.title')}</h1>
      <p className="mt-12 text-latin-body text-text-secondary">{t('admin.forgot.body')}</p>
      <p className="mt-20 rounded-lg bg-bg-subtle px-16 py-12 text-latin-caption text-text-secondary">{t('admin.forgot.only_super')}</p>
      <Link to="/login" className={`${primaryBtn} mt-24`}>
        {t('admin.forgot.back')}
      </Link>
    </Card>
  );
}
