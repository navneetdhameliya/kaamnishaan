import {
  BarChart3,
  Bell,
  BellRing,
  LifeBuoy,
  Briefcase,
  CheckCheck,
  ClipboardList,
  FileText,
  Globe,
  Home,
  Inbox,
  KeyRound,
  Languages,
  LayoutTemplate,
  Bot,
  CreditCard,
  Earth,
  Factory,
  HardDrive,
  FileCode,
  Images,
  Repeat,
  Tags,
  ListChecks,
  PenLine,
  Quote,
  Lock,
  LogOut,
  Menu,
  MessageSquareText,
  Phone,
  ScrollText,
  SlidersHorizontal,
  User,
  X,
  type LucideIcon,
} from 'lucide-react';
import { useEffect, useState, type ReactNode } from 'react';

import { api } from './lib/api';
import type { Lang, T } from './lib/i18n';
import { session } from './lib/session';
import type { StaffOut } from './lib/types';
import { cx, Initials, LangSelect, Link, navigate } from './ui';

export type NavItem = { key: string; path: string; icon: LucideIcon; ready?: boolean; hidden?: boolean };

/** The A03 side menu. Pages not built yet open a "coming soon" page. */
export const NAV: { section: string; items: NavItem[] }[] = [
  {
    section: 'overview',
    items: [
      { key: 'dashboard', path: '/', icon: Home, ready: true },
      { key: 'ai_usage', path: '/ai-usage', icon: SlidersHorizontal, ready: true },
      { key: 'analytics', path: '/analytics', icon: BarChart3, ready: true },
    ],
  },
  {
    section: 'customers',
    items: [
      { key: 'companies', path: '/companies', icon: Briefcase, ready: true },
      { key: 'users', path: '/users', icon: User, ready: true },
      { key: 'leads', path: '/leads', icon: Inbox, ready: true },
      { key: 'reviews', path: '/reviews', icon: CheckCheck, ready: true },
      { key: 'ai_calls', path: '/ai-review-calls', icon: Phone, ready: true },
      { key: 'templates', path: '/message-templates', icon: MessageSquareText, ready: true },
      { key: 'usage', path: '/usage', icon: SlidersHorizontal, ready: true },
    ],
  },
  { section: 'operations', items: [
      { key: 'jobs', path: '/jobs', icon: ClipboardList, ready: true },
      { key: 'evidence', path: '/evidence', icon: Images, ready: true },
      { key: 'reports', path: '/reports', icon: FileText, ready: true },
    ] },
  {
    section: 'ai',
    items: [
      { key: 'ai_config', path: '/ai-config', icon: Bot, ready: true },
      { key: 'prompts', path: '/prompts', icon: FileCode, ready: true },
    ],
  },
  {
    section: 'revenue',
    items: [
      { key: 'subscriptions', path: '/subscriptions', icon: Repeat, ready: true },
      { key: 'plans', path: '/plans', icon: Tags, ready: true },
      { key: 'payments', path: '/payments', icon: CreditCard, ready: true },
    ],
  },
  {
    section: 'help',
    items: [
      { key: 'support', path: '/support', icon: LifeBuoy, ready: true },
      { key: 'notifications', path: '/notifications', icon: BellRing, ready: true },
    ],
  },
  {
    section: 'content',
    items: [
      { key: 'checklists', path: '/checklist-templates', icon: ListChecks, ready: true },
      { key: 'industries', path: '/industries', icon: Factory, ready: true },
      { key: 'website_content', path: '/website-content', icon: LayoutTemplate, ready: true },
      { key: 'texts', path: '/localized-content', icon: Languages, ready: true },
      { key: 'blog', path: '/blog', icon: PenLine, ready: true },
      { key: 'testimonials', path: '/testimonials', icon: Quote, ready: true },
    ],
  },
  {
    section: 'system',
    items: [
      { key: 'audit', path: '/audit-logs', icon: ScrollText, ready: true },
      { key: 'settings', path: '/settings', icon: Globe, ready: true },
      { key: 'email', path: '/email-settings', icon: Bell, ready: true },
      { key: 'storage', path: '/storage', icon: HardDrive, ready: true },
      { key: 'localization', path: '/localization', icon: Earth, ready: true },
      { key: 'roles', path: '/roles', icon: Lock, ready: true },
    ],
  },
  // A36 opens from the name at the bottom of the menu
  { section: 'account', items: [{ key: 'profile', path: '/profile', icon: User, ready: true, hidden: true }] },
];

/** The menu item for a path; /companies/<id> belongs to Companies. */
export const findNav = (path: string) => {
  const items = NAV.flatMap((s) => s.items.map((i) => ({ ...i, section: s.section })));
  return items.find((i) => i.path === path) ?? items.find((i) => i.path !== '/' && path.startsWith(`${i.path}/`));
};

function Sidebar({ t, path, staff, onPick }: { t: T; path: string; staff: StaffOut; onPick?: () => void }) {
  const [leaving, setLeaving] = useState(false);
  const logout = async () => {
    setLeaving(true);
    try {
      await api('/admin/auth/logout', { method: 'POST' });
    } catch {
      /* the session ends in this browser either way */
    }
    session.end();
    navigate('/login', true);
  };
  return (
    <div className="flex h-full flex-col bg-mocha-900 px-12 pb-16 pt-24">
      <Link to="/" onClick={onPick} className="px-4">
        <span className="flex items-center gap-12">
          <img src="/brand-mark-dark.svg" alt="" width={40} height={40} className="h-[40px] w-[40px] rounded-md" />
          <span className="text-[24px] font-bold leading-none text-cream-50">KaamNishaan</span>
        </span>
        <span className="mt-8 inline-block rounded-sm bg-white/10 px-[6px] text-[12px] font-semibold uppercase leading-[18px] text-mocha-300">{t('admin.role.admin')}</span>
      </Link>
      <nav aria-label={t('admin.console')} className="mt-24 flex-1 overflow-y-auto">
        {NAV.filter((s) => s.items.some((i) => !i.hidden)).map((s) => (
          <div key={s.section} className="mb-16">
            <p className="px-4 pb-4 text-[13px] font-semibold uppercase tracking-wide text-cream-400">{t(`admin.nav.${s.section}`)}</p>
            {s.items.filter((i) => !i.hidden).map((i) => {
              const on = path === i.path || (i.path !== '/' && path.startsWith(`${i.path}/`));
              const Icon = i.icon;
              return (
                <Link
                  key={i.key}
                  to={i.path}
                  onClick={onPick}
                  aria-current={on ? 'page' : undefined}
                  className={cx(
                    'group relative flex h-[40px] items-center gap-12 rounded-md px-12 text-[14px] font-semibold transition-colors',
                    on ? 'bg-white/10 text-cream-50' : 'text-cream-100 hover:bg-white/[0.06] hover:text-cream-50',
                  )}
                >
                  {on && <span aria-hidden className="absolute -left-12 top-[8px] h-[24px] w-[3px] rounded-r-full bg-cream-50" />}
                  <Icon width={18} height={18} className="shrink-0 transition-transform duration-300 group-hover:scale-110" aria-hidden />
                  <span className="truncate">{t(`admin.nav.${i.key}`)}</span>
                </Link>
              );
            })}
          </div>
        ))}
      </nav>
      <div className={cx('mt-8 flex items-center gap-12 rounded-lg p-12 transition-colors', path === '/profile' ? 'bg-white/[0.16]' : 'bg-white/[0.08]')}>
        <Link to="/profile" onClick={onPick} aria-current={path === '/profile' ? 'page' : undefined} className="group flex min-w-0 flex-1 items-center gap-12">
          <Initials name={staff.name} className="h-[40px] w-[40px] shrink-0 rounded-full bg-mocha-500 text-[14px] text-cream-50 transition-transform group-hover:scale-105" />
          <span className="min-w-0 flex-1">
            <span className="block truncate text-[14px] font-semibold text-cream-50 group-hover:underline">{staff.name}</span>
            <span className="block truncate text-[13px] text-cream-400">{t(`admin.role.${staff.role}`)}</span>
          </span>
        </Link>
        <button
          type="button"
          onClick={() => void logout()}
          disabled={leaving}
          aria-label={t('admin.logout')}
          title={t('admin.logout')}
          className="inline-flex h-[36px] w-[36px] items-center justify-center rounded-md text-cream-100 transition-colors hover:bg-white/10 hover:text-cream-50"
        >
          <LogOut width={18} height={18} aria-hidden />
        </button>
      </div>
    </div>
  );
}

/** A03 frame: side menu, top bar (breadcrumb, title, page actions, language) and the page. */
export function Shell({ t, lang, onLang, path, staff, crumb, title, actions, children }: { t: T; lang: Lang; onLang: (l: Lang) => void; path: string; staff: StaffOut; crumb: string; title: string; actions?: ReactNode; children: ReactNode }) {
  const [open, setOpen] = useState(false);
  useEffect(() => {
    document.title = `${title} · KaamNishaan Admin`;
  }, [title]);
  useEffect(() => {
    if (!open) return;
    const close = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false);
    window.addEventListener('keydown', close);
    return () => window.removeEventListener('keydown', close);
  }, [open]);
  return (
    <div className="min-h-screen bg-bg-canvas lg:pl-[256px]">
      <aside className="fixed inset-y-0 left-0 hidden w-[256px] lg:block">
        <Sidebar t={t} path={path} staff={staff} />
      </aside>
      {open && (
        <div className="fixed inset-0 z-40 lg:hidden">
          <button type="button" aria-label={t('admin.nav.close')} onClick={() => setOpen(false)} className="absolute inset-0 bg-espresso-950/50" />
          <div className="kn-drawer absolute inset-y-0 left-0 w-[280px] max-w-[85vw]">
            <Sidebar t={t} path={path} staff={staff} onPick={() => setOpen(false)} />
            <button type="button" onClick={() => setOpen(false)} aria-label={t('admin.nav.close')} className="absolute right-8 top-16 inline-flex h-[40px] w-[40px] items-center justify-center rounded-md text-cream-50 hover:bg-white/10">
              <X width={20} height={20} aria-hidden />
            </button>
          </div>
        </div>
      )}
      <header className="sticky top-0 z-30 border-b border-border-default bg-bg-canvas/90 backdrop-blur">
        <div className="flex min-h-[72px] flex-wrap items-center gap-x-16 gap-y-8 px-16 py-12 sm:px-32">
          <button type="button" onClick={() => setOpen(true)} aria-label={t('admin.nav.open')} className="-ml-8 inline-flex h-[40px] w-[40px] items-center justify-center rounded-md hover:bg-bg-subtle lg:hidden">
            <Menu width={22} height={22} aria-hidden />
          </button>
          <div className="mr-auto min-w-0">
            <p className="text-[13px] text-text-secondary">{crumb}</p>
            <h1 className="truncate text-[24px] font-bold leading-[30px]">{title}</h1>
          </div>
          <div className="flex flex-wrap items-center gap-12">
            {actions}
            {/* pages that keep their own state put their buttons here (see PageActions) */}
            <div id="kn-page-actions" className="contents" />
            <LangSelect t={t} lang={lang} onChange={onLang} />
          </div>
        </div>
      </header>
      {staff.recovery_codes_left <= 2 && (
        <p role="note" className="mx-16 mt-16 flex items-start gap-12 rounded-lg bg-status-warning-bg px-16 py-12 text-latin-label-sm text-status-warning sm:mx-32">
          <KeyRound width={18} height={18} className="mt-[2px] shrink-0" aria-hidden />
          {t('admin.recovery_low', { n: staff.recovery_codes_left })}
        </p>
      )}
      <main className="px-16 py-24 sm:px-32">{children}</main>
    </div>
  );
}

export function Soon({ t, name }: { t: T; name: string }) {
  return (
    <div className="kn-in mx-auto mt-48 flex max-w-[480px] flex-col items-center rounded-xl border border-border-default bg-bg-surface px-24 py-48 text-center">
      <span className="kn-float inline-flex h-[56px] w-[56px] items-center justify-center rounded-full bg-bg-subtle text-mocha-700">
        <FileText width={24} height={24} aria-hidden />
      </span>
      <h2 className="mt-16 text-latin-h3">{t('admin.soon.title', { page: name })}</h2>
      <p className="mt-8 text-latin-body text-text-secondary">{t('admin.soon.body')}</p>
      <Link to="/" className="kn-btn mt-24 inline-flex h-[44px] items-center rounded-lg bg-action-primary px-20 text-latin-label-sm font-semibold text-text-on-action hover:bg-action-primary-pressed">
        {t('admin.soon.back')}
      </Link>
    </div>
  );
}
