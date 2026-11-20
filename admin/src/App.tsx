import { useCallback, useEffect, useMemo, useState } from 'react';

import { rememberLang, startLang, translator, useTextsVersion, type Lang } from './lib/i18n';
import { session } from './lib/session';
import type { StaffSession } from './lib/types';
import { AuditLogs } from './pages/AuditLogs';
import { ChecklistEditor } from './pages/ChecklistEditor';
import { ChecklistTemplates } from './pages/ChecklistTemplates';
import { Companies } from './pages/Companies';
import { CompanyDetail } from './pages/CompanyDetail';
import { Credits } from './pages/Credits';
import { PlatformSettings } from './pages/PlatformSettings';
import { EmailSettings } from './pages/EmailSettings';
import { Roles } from './pages/Roles';
import { ExportJobs, Jobs } from './pages/Jobs';
import { JobDetail } from './pages/JobDetail';
import { Evidence } from './pages/Evidence';
import { ExportReports, Reports } from './pages/Reports';
import { ReportDetail } from './pages/ReportDetail';
import { ExportSubscriptions, Subscriptions } from './pages/Subscriptions';
import { Plans } from './pages/Plans';
import { Payments } from './pages/Payments';
import { AiConfig } from './pages/AiConfig';
import { Prompts } from './pages/Prompts';
import { Industries } from './pages/Industries';
import { CompanyForm } from './pages/CompanyForm';
import { Dashboard, RangeSelect, RANGES, type Range } from './pages/Dashboard';
import { AiCalls } from './pages/AiCalls';
import { AiUsage } from './pages/AiUsage';
import { ExportReviews, Reviews } from './pages/Reviews';
import { Templates } from './pages/Templates';
import { Leads } from './pages/Leads';
import { Blog, NewPost } from './pages/Blog';
import { BlogEditor } from './pages/BlogEditor';
import { Notifications } from './pages/Notifications';
import { Testimonials } from './pages/Testimonials';
import { Texts } from './pages/Texts';
import { WebsiteContent } from './pages/WebsiteContent';
import { ExportSupport, Support } from './pages/Support';
import { Forgot, Login } from './pages/Login';
import { Setup } from './pages/Setup';
import { UserDetail } from './pages/UserDetail';
import { Users } from './pages/Users';
import { findNav, Shell, Soon } from './Shell';
import { navigate, SplitLayout, useLocation } from './ui';

const PUBLIC = ['/login', '/forgot-password', '/setup'];

/** Admin panel (Step 4a): log in, setup links, the dashboard and the side menu. */
export default function App() {
  const [lang, setLang] = useState<Lang>(startLang);
  const texts = useTextsVersion();
  const t = useMemo(() => translator(lang), [lang, texts]);
  const { path, search } = useLocation();
  const [sess, setSess] = useState<StaffSession | null>(session.get);
  const [days, setDays] = useState<Range>(() => {
    const d = Number(search.get('days'));
    return (RANGES as readonly number[]).includes(d) ? (d as Range) : 30;
  });

  // the name a detail page reports, kept with the path it belongs to so a new page never shows the old one
  const [named, setNamed] = useState<{ path: string; name: string }>({ path: '', name: '' });
  const onName = useCallback((n: string) => setNamed({ path: location.pathname, name: n }), []);
  const pageName = named.path === path ? named.name : '';
  useEffect(() => session.subscribe(setSess), []);
  useEffect(() => {
    document.documentElement.lang = lang;
    rememberLang(lang);
  }, [lang]);

  const isPublic = PUBLIC.includes(path);
  const nav = findNav(path);
  useEffect(() => {
    if (!sess && !isPublic) navigate('/login', true);
    else if (sess && path === '/login') navigate('/', true);
    else if (sess && !isPublic && !nav) navigate('/', true);
  }, [sess, isPublic, path, nav]);

  if (isPublic || !sess) {
    if (!isPublic) return null;
    setTitle(t(path === '/setup' ? 'admin.setup.title' : path === '/forgot-password' ? 'admin.forgot.title' : 'admin.login.title'));
    return (
      <SplitLayout t={t} lang={lang} onLang={setLang}>
        {path === '/setup' ? <Setup t={t} token={search.get('token') ?? ''} /> : path === '/forgot-password' ? <Forgot t={t} /> : <Login t={t} lang={lang} />}
      </SplitLayout>
    );
  }
  if (!nav) return null;

  const name = t(`admin.nav.${nav.key}`);
  const sub = path.startsWith(`${nav.path}/`) ? path.slice(nav.path.length + 1) : null;
  const companyId = nav.key === 'companies' ? sub : null;
  const userId = nav.key === 'users' ? sub : null;
  let page;
  if (!nav.ready) page = <Soon t={t} name={name} />;
  else if (nav.key === 'dashboard') page = <Dashboard t={t} lang={lang} days={days} />;
  else if (nav.key === 'ai_usage') page = <AiUsage t={t} lang={lang} days={days} />;
  else if (nav.key === 'ai_calls') page = <AiCalls key="ai-calls" t={t} lang={lang} />;
  else if (nav.key === 'jobs') page = sub ? <JobDetail key={sub} t={t} lang={lang} id={sub} onName={onName} /> : <Jobs key="jobs" t={t} lang={lang} />;
  else if (nav.key === 'ai_config') page = <AiConfig key="ai_config" t={t} lang={lang} />;
  else if (nav.key === 'prompts') page = <Prompts key="prompts" t={t} lang={lang} />;
  else if (nav.key === 'industries') page = <Industries key="industries" t={t} lang={lang} />;
  else if (nav.key === 'subscriptions') page = <Subscriptions key="subscriptions" t={t} lang={lang} />;
  else if (nav.key === 'plans') page = <Plans key="plans" t={t} lang={lang} />;
  else if (nav.key === 'payments') page = <Payments key="payments" t={t} />;
  else if (nav.key === 'reports') page = sub ? <ReportDetail key={sub} t={t} lang={lang} id={sub} onName={onName} /> : <Reports key="reports" t={t} lang={lang} />;
  else if (nav.key === 'evidence') page = <Evidence key="evidence" t={t} lang={lang} />;
  else if (nav.key === 'roles') page = <Roles key="roles" t={t} lang={lang} />;
  else if (nav.key === 'email') page = <EmailSettings key="email" t={t} />;
  else if (nav.key === 'settings') page = <PlatformSettings key="settings" t={t} />;
  else if (nav.key === 'usage') page = <Credits key="credits" t={t} lang={lang} />;
  else if (nav.key === 'templates') page = <Templates key="templates" t={t} lang={lang} />;
  else if (nav.key === 'reviews') page = <Reviews key="reviews" t={t} lang={lang} canAct={sess.staff.role !== 'support'} />;
  else if (companyId === 'new') page = <CompanyForm key="new" t={t} lang={lang} id={null} onName={onName} />;
  else if (companyId?.endsWith('/edit')) page = <CompanyForm key={companyId} t={t} lang={lang} id={companyId.slice(0, -5)} onName={onName} />;
  else if (companyId) page = <CompanyDetail key={companyId} t={t} lang={lang} id={companyId} onName={onName} />;
  else if (nav.key === 'companies') page = <Companies key={path} t={t} lang={lang} />;
  else if (nav.key === 'checklists') page = sub ? <ChecklistEditor key={sub} t={t} lang={lang} id={sub} onName={onName} /> : <ChecklistTemplates key="cl" t={t} lang={lang} />;
  else if (nav.key === 'audit') page = <AuditLogs key="audit" t={t} lang={lang} />;
  else if (nav.key === 'leads') page = <Leads key="leads" t={t} lang={lang} id={sub} />;
  else if (nav.key === 'support') page = <Support key="support" t={t} lang={lang} id={sub} />;
  else if (nav.key === 'blog') page = sub ? <BlogEditor key={sub} t={t} lang={lang} id={sub} onName={onName} /> : <Blog key="blog" t={t} lang={lang} />;
  else if (nav.key === 'testimonials') page = <Testimonials key="testimonials" t={t} lang={lang} />;
  else if (nav.key === 'website_content') page = <WebsiteContent key="wc" t={t} lang={lang} page={sub} />;
  else if (nav.key === 'texts') page = <Texts key="texts" t={t} lang={lang} />;
  else if (nav.key === 'notifications') page = <Notifications key="notifications" t={t} lang={lang} />;
  else if (userId) page = <UserDetail key={userId} t={t} lang={lang} id={userId} onName={onName} />;
  else page = <Users key={path} t={t} lang={lang} />;
  return (
    <Shell
      t={t}
      lang={lang}
      onLang={setLang}
      path={path}
      staff={sess.staff}
      crumb={sub && nav.key !== 'leads' && nav.key !== 'support' && nav.key !== 'website_content' ? `${t(`admin.nav.${nav.section}`)} / ${name}` : t(`admin.nav.${nav.section}`)}
      title={sub && nav.key !== 'leads' && nav.key !== 'support' && nav.key !== 'website_content' ? pageName || name : name}
      actions={nav.key === 'dashboard' || nav.key === 'ai_usage' ? <RangeSelect t={t} days={days} onChange={setDays} /> : nav.key === 'reviews' ? <ExportReviews t={t} /> : nav.key === 'jobs' && !sub ? <ExportJobs t={t} /> : nav.key === 'reports' && !sub ? <ExportReports t={t} /> : nav.key === 'subscriptions' ? <ExportSubscriptions t={t} lang={lang} /> : nav.key === 'support' ? <ExportSupport t={t} /> : nav.key === 'blog' && !sub ? <NewPost t={t} /> : undefined}
    >
      {page}
    </Shell>
  );
}

function setTitle(title: string) {
  document.title = `${title} · KaamNishaan Admin`;
}
