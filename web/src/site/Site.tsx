import ComingSoon from './ComingSoon';
import Home from './Home';
import { SiteLayout } from './Layout';
import Pricing from './Pricing';
import { useConfig, useLang, usePlans } from './site';

/** The marketing website: / (W01), /pricing (W02); every other path shows "coming soon" for now. */
export default function Site({ path }: { path: string }) {
  const { lang, t, setLang } = useLang();
  const [plans, retryPlans] = usePlans(lang);
  const config = useConfig(lang);
  const trades = config.kind === 'ready' ? config.data.trades : [];
  const page = path.replace(/\/+$/, '') || '/';
  return (
    <SiteLayout t={t} lang={lang} setLang={setLang} trades={trades}>
      {page === '/' ? (
        <Home t={t} lang={lang} plans={plans} retryPlans={retryPlans} trades={trades} />
      ) : page === '/pricing' ? (
        <Pricing t={t} lang={lang} plans={plans} retryPlans={retryPlans} />
      ) : (
        <ComingSoon t={t} />
      )}
    </SiteLayout>
  );
}
