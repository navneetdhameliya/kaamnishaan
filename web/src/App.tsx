import en from '../../shared/i18n/en.json';
import ReportPage from './pages/report/ReportPage';

/** The website's pages. The customer report page (W27, W29) is at /r/{token}; the rest comes in later steps. */
export default function App() {
  const report = window.location.pathname.match(/^\/r\/([^/]+)\/?$/);
  if (report) return <ReportPage token={decodeURIComponent(report[1]!)} />;
  return <Home />;
}

/** Step 0 placeholder for the home page (W01 comes in a later step). */
function Home() {
  return (
    <main className="mx-auto max-w-[1200px] px-16 py-64 md:px-32">
      <p className="text-web-eyebrow uppercase text-text-secondary">Proof of work for field teams</p>
      <h1 className="mt-16 text-web-m-display md:text-web-display-xl">Every Job Deserves Proof.</h1>
      <p className="mt-24 max-w-2xl text-web-body-lg text-text-secondary">{en['app.tagline']}</p>
      <div className="mt-40 flex gap-12">
        <a className="rounded-lg bg-action-primary px-24 py-16 text-web-label text-text-on-action shadow-md" href="#">
          Start free trial
        </a>
        <a className="rounded-lg border border-border-strong px-24 py-16 text-web-label" href="#">
          Book a demo
        </a>
      </div>
    </main>
  );
}
