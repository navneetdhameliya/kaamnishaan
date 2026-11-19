import { useEffect, useMemo, useState } from 'react';

import { rememberLang, startLang, translator, type Lang } from './lib/i18n';
import { session } from './lib/session';
import type { StaffSession } from './lib/types';
import { Dashboard, RangeSelect, RANGES, type Range } from './pages/Dashboard';
import { Forgot, Login } from './pages/Login';
import { Setup } from './pages/Setup';
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
  return (
    <Shell
      t={t}
      lang={lang}
      onLang={setLang}
      path={path}
      staff={sess.staff}
      crumb={t(`admin.nav.${nav.section}`)}
      title={name}
      actions={nav.key === 'dashboard' ? <RangeSelect t={t} days={days} onChange={setDays} /> : undefined}
    >
      {nav.ready ? <Dashboard t={t} lang={lang} days={days} /> : <Soon t={t} name={name} />}
    </Shell>
  );
}

function setTitle(title: string) {
  document.title = `${title} · KaamNishaan Admin`;
}
