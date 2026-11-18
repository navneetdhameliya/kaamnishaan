import BookDemo from './BookDemo';
import ComingSoon from './ComingSoon';
import Contact from './Contact';
import { featureBySlug, page as featurePage } from './features/catalog';
import FeaturePage from './features/FeaturePage';
import Overview from './features/Overview';
import Reviews from './features/Reviews';
import Home from './Home';
import { SiteLayout } from './Layout';
import Login from './Login';
import { PageLoader, useRevealOnScroll } from './motion';
import Pricing from './Pricing';
import { ROUTES, useConfig, useLang, usePlans } from './site';
import StartTrial from './StartTrial';

/**
 * The marketing website: / (W01), /pricing (W02), /start-trial (W04), /login (W28), /book-demo (W03), /contact (W05),
 * /features (W08) and /features/<slug> (W09–W17, W31); other paths show "coming soon".
 */
export default function Site({ path }: { path: string }) {
  const { lang, t, setLang } = useLang();
  const [plans, retryPlans] = usePlans(lang);
  const config = useConfig(lang);
  const cfg = config.kind === 'ready' ? config.data : null;
  const trades = cfg?.trades ?? [];
  const planData = plans.kind === 'ready' ? plans.data : null;
  const page = path.replace(/\/+$/, '') || '/';
  useRevealOnScroll();
  const feat = page.startsWith(`${ROUTES.features}/`) ? featureBySlug(page.slice(ROUTES.features.length + 1)) : undefined;
  const spec = feat ? featurePage(feat.id) : undefined;
  const firstDataIn = config.kind !== 'loading' && plans.kind !== 'loading';
  return (
    <>
    <PageLoader ready={firstDataIn} />
    <SiteLayout t={t} lang={lang} setLang={setLang} trades={trades} announcement={page !== ROUTES.login}>
      {page === ROUTES.home ? (
        <Home t={t} lang={lang} plans={plans} retryPlans={retryPlans} trades={trades} />
      ) : page === ROUTES.pricing ? (
        <Pricing t={t} lang={lang} plans={plans} retryPlans={retryPlans} />
      ) : page === ROUTES.trial ? (
        <StartTrial t={t} lang={lang} plans={planData} config={cfg} />
      ) : page === ROUTES.demo ? (
        <BookDemo t={t} lang={lang} plans={planData} config={cfg} />
      ) : page === ROUTES.contact ? (
        <Contact t={t} lang={lang} config={cfg} />
      ) : page === ROUTES.features ? (
        <Overview t={t} lang={lang} plans={planData} config={cfg} />
      ) : feat?.id === 'reviews' ? (
        <Reviews t={t} lang={lang} plans={planData} config={cfg} />
      ) : spec ? (
        <FeaturePage key={spec.id} t={t} lang={lang} spec={spec} trades={trades} plans={planData} config={cfg} />
      ) : page === ROUTES.login ? (
        <Login t={t} lang={lang} config={cfg} />
      ) : (
        <ComingSoon t={t} />
      )}
    </SiteLayout>
    </>
  );
}
