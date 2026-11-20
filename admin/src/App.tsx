import { useCallback, useEffect, useMemo, useState } from 'react';

import { rememberLang, startLang, translator, type Lang } from './lib/i18n';
import { session } from './lib/session';
import type { StaffSession } from './lib/types';
import { AuditLogs } from './pages/AuditLogs';
import { ChecklistEditor } from './pages/ChecklistEditor';
import { ChecklistTemplates } from './pages/ChecklistTemplates';
import { Companies } from './pages/Companies';
import { CompanyDetail } from './pages/CompanyDetail';
import { CompanyForm } from './pages/CompanyForm';
import { Dashboard, RangeSelect, RANGES, type Range } from './pages/Dashboard';
import { AiCalls } from './pages/AiCalls';
import { AiUsage } from './pages/AiUsage';
import { ExportReviews, Reviews } from './pages/Reviews';
import { Leads } from './pages/Leads';
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
  const t = useMemo(() => translator(lang), [lang]);
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
  else if (nav.key === 'reviews') page = <Reviews key="reviews" t={t} lang={lang} canAct={sess.staff.role !== 'support'} />;
  else if (companyId === 'new') page = <CompanyForm key="new" t={t} lang={lang} id={null} onName={onName} />;
  else if (companyId?.endsWith('/edit')) page = <CompanyForm key={companyId} t={t} lang={lang} id={companyId.slice(0, -5)} onName={onName} />;
  else if (companyId) page = <CompanyDetail key={companyId} t={t} lang={lang} id={companyId} onName={onName} />;
  else if (nav.key === 'companies') page = <Companies key={path} t={t} lang={lang} />;
  else if (nav.key === 'checklists') page = sub ? <ChecklistEditor key={sub} t={t} lang={lang} id={sub} onName={onName} /> : <ChecklistTemplates key="cl" t={t} lang={lang} />;
  else if (nav.key === 'audit') page = <AuditLogs key="audit" t={t} lang={lang} />;
  else if (nav.key === 'leads') page = <Leads key="leads" t={t} lang={lang} id={sub} />;
  else if (userId) page = <UserDetail key={userId} t={t} lang={lang} id={userId} onName={onName} />;
  else page = <Users key={path} t={t} lang={lang} />;
  return (
    <Shell
      t={t}
      lang={lang}
      onLang={setLang}
      path={path}
      staff={sess.staff}
      crumb={sub && nav.key !== 'leads' ? `${t(`admin.nav.${nav.section}`)} / ${name}` : t(`admin.nav.${nav.section}`)}
      title={sub && nav.key !== 'leads' ? pageName || name : name}
      actions={nav.key === 'dashboard' || nav.key === 'ai_usage' ? <RangeSelect t={t} days={days} onChange={setDays} /> : nav.key === 'reviews' ? <ExportReviews t={t} /> : undefined}
    >
      {page}
    </Shell>
  );
}

function setTitle(title: string) {
  document.title = `${title} · KaamNishaan Admin`;
}
