import { Bell } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';

import { api } from './lib/api';
import type { Lang, T } from './lib/i18n';
import type { DashboardOut } from './lib/types';
import { Attention } from './pages/Dashboard';

/** Top bar bell (A04): the dashboard's "Needs attention", from any page; checked again on each page. */
export function TopAlerts({ t, lang, path }: { t: T; lang: Lang; path: string }) {
  const [rows, setRows] = useState<DashboardOut['attention'] | null>(null);
  const [open, setOpen] = useState(false);
  const box = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let live = true;
    api<DashboardOut['attention']>('/admin/alerts')
      .then((r) => live && setRows(r))
      .catch(() => live && setRows(null));
    setOpen(false);
    return () => {
      live = false;
    };
  }, [path]);

  useEffect(() => {
    const close = (e: MouseEvent) => {
      if (box.current && !box.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', close);
    return () => document.removeEventListener('mousedown', close);
  }, []);

  if (rows === null) return null;
  const n = rows.length;
  return (
    <div ref={box} className="relative">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-label={t('admin.alerts.title')}
        aria-expanded={open}
        className="relative inline-flex h-[40px] w-[40px] items-center justify-center rounded-md transition hover:-translate-y-[1px] hover:bg-bg-subtle"
      >
        <Bell width={20} height={20} aria-hidden />
        {n > 0 && (
          <span className="kn-pop absolute right-[4px] top-[4px] inline-flex h-[18px] min-w-[18px] items-center justify-center rounded-full bg-status-danger px-4 text-[11px] font-bold text-white">
            {n}
          </span>
        )}
      </button>
      {open && (
        <div className="kn-in absolute right-0 top-[48px] z-40 w-[340px] max-w-[90vw] rounded-lg border border-border-default bg-bg-surface p-12 shadow-lg">
          <p className="mb-8 text-[14px] font-semibold">{t('admin.alerts.title')}</p>
          <Attention t={t} lang={lang} rows={rows} />
        </div>
      )}
    </div>
  );
}
