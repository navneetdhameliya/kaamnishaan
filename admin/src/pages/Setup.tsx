import { Check, Copy, Download, Eye, EyeOff, KeyRound, ShieldCheck } from 'lucide-react';
import QRCode from 'qrcode';
import { useEffect, useState, type FormEvent } from 'react';

import { api, ApiError } from '../lib/api';
import type { T } from '../lib/i18n';
import { session } from '../lib/session';
import type { StaffSetupInfo, StaffSetupOut } from '../lib/types';
import { Card, cx, ErrorBanner, inputCls, Link, navigate, OtpInput, primaryBtn, Spinner } from '../ui';

function useCopy(): [string | null, (key: string, text: string) => void] {
  const [done, setDone] = useState<string | null>(null);
  return [
    done,
    (key, text) => {
      void navigator.clipboard?.writeText(text).then(() => {
        setDone(key);
        window.setTimeout(() => setDone(null), 1800);
      });
    },
  ];
}

/** Setting up a staff account from a setup link: password, authenticator, then the recovery codes. */
export function Setup({ t, token }: { t: T; token: string }) {
  const [info, setInfo] = useState<StaffSetupInfo | 'bad' | null>(null);
  const [qr, setQr] = useState<string | null>(null);
  const [password, setPassword] = useState('');
  const [show, setShow] = useState(false);
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<{ text: string; field?: 'password' | 'code' } | null>(null);
  const [tries, setTries] = useState(0);
  const [done, setDone] = useState<StaffSetupOut | null>(null);
  const [copied, copy] = useCopy();

  useEffect(() => {
    if (!token) return setInfo('bad');
    api<StaffSetupInfo>(`/admin/auth/setup?token=${encodeURIComponent(token)}`, { auth: false })
      .then((i) => {
        setInfo(i);
        void QRCode.toDataURL(i.otpauth_uri, { margin: 1, width: 336, color: { dark: '#2b1d16', light: '#fffcf8' } }).then(setQr);
      })
      .catch(() => setInfo('bad'));
    // the link carries a secret: take it out of the address bar and history
    window.history.replaceState(null, '', '/setup');
  }, [token]);

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (password.length < 8 || !/[A-Za-z]/.test(password) || !/\d/.test(password)) {
      setError({ text: t('admin.setup.pw_rule'), field: 'password' });
      return setTries((n) => n + 1);
    }
    if (code.length !== 6) {
      setError({ text: t('admin.setup.err_code'), field: 'code' });
      return setTries((n) => n + 1);
    }
    setBusy(true);
    setError(null);
    try {
      setDone(await api<StaffSetupOut>('/admin/auth/setup', { method: 'POST', auth: false, body: { token, password, code } }));
    } catch (err) {
      setCode('');
      const c = err instanceof ApiError ? err.code : '';
      if (c === 'code_invalid') setError({ text: t('admin.setup.err_code'), field: 'code' });
      else if (c === 'password_weak') setError({ text: t('admin.setup.pw_rule'), field: 'password' });
      else if (c === 'too_many_tries') setError({ text: t('admin.setup.err_tries') });
      else if (c === 'link_invalid' || c === 'link_expired') setInfo('bad');
      else setError({ text: t(err instanceof ApiError && err.status === 0 ? 'admin.err.offline' : 'admin.err.generic') });
      setTries((n) => n + 1);
    } finally {
      setBusy(false);
    }
  }

  if (info === null)
    return (
      <Card wide>
        <div className="kn-shimmer h-[420px] rounded-lg bg-bg-subtle" aria-busy="true" />
      </Card>
    );
  if (info === 'bad')
    return (
      <Card>
        <h1 className="text-[28px] font-bold leading-[36px]">{t('admin.setup.title')}</h1>
        <div className="mt-20">
          <ErrorBanner>{t('admin.setup.err_link')}</ErrorBanner>
        </div>
        <Link to="/login" className={`${primaryBtn} mt-24`}>
          {t('admin.forgot.back')}
        </Link>
      </Card>
    );
  if (done) return <RecoveryCodes t={t} out={done} copied={copied} copy={copy} />;

  return (
    <Card wide>
      <h1 className="text-[28px] font-bold leading-[36px]">{t(info.is_reset ? 'admin.setup.title_reset' : 'admin.setup.title')}</h1>
      <p className="mt-8 text-latin-body text-text-secondary">{t('admin.setup.body', { name: info.name })}</p>
      <p className="mt-4 text-latin-label-sm font-semibold text-text-primary">{info.email}</p>
      <form noValidate onSubmit={(e) => void submit(e)} className="mt-24 flex flex-col gap-24">
        {error && <ErrorBanner shake={tries}>{error.text}</ErrorBanner>}
        <input type="email" value={info.email} autoComplete="username" readOnly hidden />
        <div className="flex flex-col gap-8">
          <label htmlFor="new-password" className="text-latin-label font-semibold">
            {t('admin.setup.step1')}
          </label>
          <div className="relative">
            <input
              id="new-password"
              type={show ? 'text' : 'password'}
              autoComplete="new-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              aria-invalid={error?.field === 'password' || undefined}
              aria-describedby="pw-rule"
              className={cx(inputCls, 'pr-[56px]', error?.field === 'password' && 'border-[1.5px] border-status-danger')}
            />
            <button
              type="button"
              onClick={() => setShow((v) => !v)}
              aria-label={t(show ? 'admin.login.hide_pw' : 'admin.login.show_pw')}
              className="absolute right-8 top-1/2 inline-flex h-[40px] w-[40px] -translate-y-1/2 items-center justify-center rounded-md text-text-secondary hover:bg-bg-subtle hover:text-text-primary"
            >
              {show ? <EyeOff width={20} height={20} aria-hidden /> : <Eye width={20} height={20} aria-hidden />}
            </button>
          </div>
          <p id="pw-rule" className="text-latin-caption text-text-secondary">
            {t('admin.setup.pw_rule')}
          </p>
        </div>
        <div className="flex flex-col gap-12">
          <p className="text-latin-label font-semibold">{t('admin.setup.step2')}</p>
          <div className="flex flex-col items-start gap-16 sm:flex-row sm:items-center">
            <div className="kn-pop rounded-lg border border-border-default bg-cream-50 p-8">
              {qr ? <img src={qr} alt={t('admin.setup.qr_alt')} width={168} height={168} className="h-[168px] w-[168px]" /> : <div className="kn-shimmer h-[168px] w-[168px] rounded-md bg-bg-subtle" />}
            </div>
            <div className="flex min-w-0 flex-col gap-8">
              <p className="text-latin-caption text-text-secondary">{t('admin.setup.manual')}</p>
              <code className="break-all rounded-md bg-bg-subtle px-12 py-8 font-mono text-[14px] tracking-wider text-text-primary">{info.secret.replace(/(.{4})/g, '$1 ').trim()}</code>
              <button type="button" onClick={() => copy('key', info.secret)} className="inline-flex w-fit items-center gap-8 text-latin-label-sm font-semibold text-mocha-700 hover:text-text-primary">
                {copied === 'key' ? <Check width={16} height={16} className="kn-pop" aria-hidden /> : <Copy width={16} height={16} aria-hidden />}
                <span aria-live="polite">{t(copied === 'key' ? 'admin.setup.copied' : 'admin.setup.copy')}</span>
              </button>
            </div>
          </div>
        </div>
        <div className="flex flex-col gap-8">
          <label htmlFor="setup-otp" className="text-latin-label font-semibold">
            {t('admin.setup.step3')}
          </label>
          <OtpInput value={code} onChange={setCode} t={t} invalid={error?.field === 'code'} idPrefix="setup-otp" />
        </div>
        <button type="submit" disabled={busy} className={primaryBtn}>
          {busy ? <Spinner /> : <ShieldCheck width={18} height={18} aria-hidden />}
          {t('admin.setup.submit')}
        </button>
      </form>
    </Card>
  );
}

function RecoveryCodes({ t, out, copied, copy }: { t: T; out: StaffSetupOut; copied: string | null; copy: (k: string, text: string) => void }) {
  const [saved, setSaved] = useState(false);
  const text = out.recovery_codes.join('\n');
  const download = () => {
    const blob = new Blob([`KaamNishaan admin recovery codes for ${out.staff.email}\n\n${text}\n`], { type: 'text/plain' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'kaamnishaan-admin-recovery-codes.txt';
    a.click();
    URL.revokeObjectURL(a.href);
  };
  return (
    <Card wide>
      <span className="kn-pop inline-flex h-[48px] w-[48px] items-center justify-center rounded-full bg-status-success-bg text-status-success">
        <KeyRound width={22} height={22} aria-hidden />
      </span>
      <h1 className="mt-16 text-[28px] font-bold leading-[36px]">{t('admin.setup.codes_title')}</h1>
      <p className="mt-8 text-latin-body text-text-secondary">{t('admin.setup.codes_body')}</p>
      <ul className="mt-20 grid grid-cols-2 gap-8 rounded-lg bg-bg-subtle p-16">
        {out.recovery_codes.map((c, i) => (
          <li key={c} className="kn-in rounded-md bg-bg-surface px-12 py-8 text-center font-mono text-[15px] tracking-wider" style={{ ['--d' as string]: `${i * 50}ms` }}>
            {c}
          </li>
        ))}
      </ul>
      <div className="mt-16 flex flex-wrap gap-12">
        <button type="button" onClick={() => copy('codes', text)} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg border border-border-strong bg-bg-surface px-16 text-latin-label-sm font-semibold hover:border-mocha-500">
          {copied === 'codes' ? <Check width={16} height={16} className="kn-pop" aria-hidden /> : <Copy width={16} height={16} aria-hidden />}
          <span aria-live="polite">{t(copied === 'codes' ? 'admin.setup.copied' : 'admin.setup.codes_copy')}</span>
        </button>
        <button type="button" onClick={download} className="kn-btn inline-flex h-[44px] items-center gap-8 rounded-lg border border-border-strong bg-bg-surface px-16 text-latin-label-sm font-semibold hover:border-mocha-500">
          <Download width={16} height={16} aria-hidden />
          {t('admin.setup.codes_download')}
        </button>
      </div>
      <label className="mt-24 flex cursor-pointer items-center gap-12 text-latin-label font-semibold">
        <input type="checkbox" checked={saved} onChange={(e) => setSaved(e.target.checked)} className="h-[20px] w-[20px] accent-[#2b1d16]" />
        {t('admin.setup.codes_saved')}
      </label>
      <button
        type="button"
        disabled={!saved}
        onClick={() => {
          // the recovery codes are not kept anywhere in the browser
          session.set({ access_token: out.access_token, refresh_token: out.refresh_token, expires_in: out.expires_in, session_ends_at: out.session_ends_at, staff: out.staff });
          navigate('/', true);
        }}
        className={`${primaryBtn} mt-20`}
      >
        {t('admin.setup.continue')}
      </button>
    </Card>
  );
}
