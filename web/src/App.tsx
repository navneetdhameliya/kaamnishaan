import { ResetPasswordPage, VerifyEmailPage } from './pages/auth/AuthLinkPages';
import ReportPage from './pages/report/ReportPage';
import { useTextsVersion } from './lib/i18n';
import './lib/texts';
import Site from './site/Site';

/** The customer report page (W27, W29) at /r/{token}, the email link pages, and the marketing site. */
export default function App() {
  useTextsVersion(); // draw again with texts changed in the admin panel (A24, A25)
  const report = window.location.pathname.match(/^\/r\/([^/]+)\/?$/);
  if (report) return <ReportPage token={decodeURIComponent(report[1]!)} />;
  // the links in "Confirm your email" and "Reset your password"
  if (window.location.pathname === '/verify-email') return <VerifyEmailPage />;
  if (window.location.pathname === '/reset-password') return <ResetPasswordPage />;
  return <Site path={window.location.pathname} />;
}
