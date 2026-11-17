import { ChevronDown, ChevronRight, Globe, Menu, Sparkles, X } from 'lucide-react';
import { useEffect, useRef, useState, type ReactNode } from 'react';

import { cx } from '../components/ui';
import { LANGS, type Lang, type T } from '../lib/i18n';
import type { TradeOut } from '../lib/types';
import { ROUTES } from './site';

/** A link that looks like the Figma buttons (Start free trial, Book a demo, …). */
export function LinkButton({
  href,
  children,
  variant,
  icon,
  className,
  size = 'lg',
}: {
  href: string;
  children: ReactNode;
  variant: 'light' | 'outline-light' | 'primary' | 'secondary' | 'outline';
  icon?: ReactNode;
  className?: string;
  size?: 'md' | 'lg';
}) {
  const v = {
    light: 'bg-cream-50 text-mocha-950 hover:bg-cream-100',
    'outline-light': 'border border-cream-100/30 text-cream-50 hover:bg-espresso-850',
    primary: 'bg-action-primary text-text-on-action hover:bg-action-primary-pressed',
    secondary: 'bg-action-secondary text-text-primary hover:brightness-95',
    outline: 'border-[1.5px] border-mocha-900 text-text-primary hover:bg-bg-canvas',
  }[variant];
  return (
    <a
      href={href}
      className={cx(
        'inline-flex items-center justify-center gap-8 whitespace-nowrap rounded-lg px-24 font-semibold transition focus:outline-none focus-visible:ring-2 focus-visible:ring-focus-ring',
        size === 'lg' ? 'h-[56px] text-latin-label' : 'h-[48px] px-20 text-latin-label',
        v,
        className,
      )}
    >
      {icon}
      {children}
    </a>
  );
}

export function Logo({ dark = true }: { dark?: boolean }) {
  return (
    <span className="inline-flex items-center gap-[9px]">
      <img src="/brand-mark-dark.svg" alt="" width={35} height={35} className="h-[35px] w-[35px]" />
      <span
        className={cx('text-[22px] font-bold tracking-[-0.01em]', dark ? 'text-cream-100' : 'text-text-primary')}
        style={{ fontFamily: '"Baloo 2", "Noto Sans", sans-serif' }}
      >
        KaamNishaan
      </span>
    </span>
  );
}

function AnnouncementBar({ t }: { t: T }) {
  return (
    <div className="flex items-center justify-center gap-8 bg-mocha-900 px-16 py-[8px] text-center md:py-12">
      <Sparkles width={16} height={16} className="hidden shrink-0 text-cream-400 sm:block" aria-hidden />
      <p className="text-[13px] font-semibold leading-[18px] text-cream-100 md:text-latin-label-sm">{t('site.ann.text')}</p>
      <span className="hidden h-[14px] w-px bg-cream-100/30 md:block" aria-hidden />
      <a href="/#how-it-works" className="hidden items-center gap-4 text-latin-label-sm font-semibold text-mocha-300 hover:text-cream-50 md:inline-flex">
        {t('site.ann.link')}
        <ChevronRight width={14} height={14} aria-hidden />
      </a>
    </div>
  );
}

/** A nav item that opens a small menu (Product, Industries). */
function NavMenu({ label, items }: { label: string; items: { href: string; label: string }[] }) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!open) return;
    const close = (e: MouseEvent | KeyboardEvent) => {
      if (e instanceof KeyboardEvent ? e.key === 'Escape' : !ref.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', close);
    document.addEventListener('keydown', close);
    return () => {
      document.removeEventListener('mousedown', close);
      document.removeEventListener('keydown', close);
    };
  }, [open]);
  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        aria-expanded={open}
        onClick={() => setOpen((o) => !o)}
        className="inline-flex items-center gap-4 text-web-label font-semibold text-cream-200 hover:text-cream-50"
      >
        {label}
        <ChevronDown width={16} height={16} className={cx('transition', open && 'rotate-180')} aria-hidden />
      </button>
      {open && (
        <div className="absolute left-1/2 top-[calc(100%+20px)] z-30 w-[260px] -translate-x-1/2 rounded-xl border border-border-default bg-bg-surface p-8 shadow-lg">
          {items.map((i) => (
            <a
              key={i.href + i.label}
              href={i.href}
              onClick={() => setOpen(false)}
              className="flex items-center justify-between rounded-md px-12 py-12 text-latin-label font-semibold text-text-primary hover:bg-bg-canvas"
            >
              {i.label}
              <ChevronRight width={16} height={16} className="text-text-secondary" aria-hidden />
            </a>
          ))}
        </div>
      )}
    </div>
  );
}

function LangPicker({ lang, setLang, t, label }: { lang: Lang; setLang: (l: Lang) => void; t: T; label: 'code' | 'name' }) {
  return (
    <label className="relative inline-flex cursor-pointer items-center gap-[6px] text-web-label font-semibold text-cream-200 hover:text-cream-50">
      <Globe width={18} height={18} aria-hidden />
      {label === 'code' ? lang.toUpperCase() : t(`web.lang.${lang}`)}
      <ChevronDown width={16} height={16} aria-hidden />
      <select
        aria-label="Language"
        value={lang}
        onChange={(e) => setLang(e.target.value as Lang)}
        className="absolute inset-0 cursor-pointer opacity-0"
      >
        {LANGS.map((l) => (
          <option key={l} value={l}>
            {t(`web.lang.${l}`)}
          </option>
        ))}
      </select>
    </label>
  );
}

function productItems(t: T) {
  return [
    { href: '/#how-it-works', label: t('site.menu.how') },
    { href: '/#features', label: t('site.menu.features') },
    { href: '/#ai-reports', label: t('site.menu.reports') },
    { href: '/#before-after', label: t('site.menu.compare') },
    { href: '/#assistant', label: t('site.menu.assistant') },
  ];
}

function Nav({ t, lang, setLang, trades }: { t: T; lang: Lang; setLang: (l: Lang) => void; trades: TradeOut[] }) {
  const [drawer, setDrawer] = useState(false);
  const industries = trades.map((tr) => ({ href: ROUTES.industry(tr.key), label: tr.name }));
  useEffect(() => {
    document.body.style.overflow = drawer ? 'hidden' : '';
  }, [drawer]);
  return (
    <header className="relative z-20 border-b border-cream-100/[0.08] bg-espresso-950">
      <div className="mx-auto flex h-[64px] max-w-[1200px] items-center justify-between px-16 md:h-[89px] md:px-32 xl:px-0">
        <a href={ROUTES.home} aria-label={t('site.nav.home')}>
          <Logo />
        </a>
        <nav className="hidden items-center gap-32 lg:flex">
          <NavMenu label={t('site.nav.product')} items={productItems(t)} />
          <NavMenu label={t('site.nav.industries')} items={industries} />
          <a href={ROUTES.pricing} className="text-web-label font-semibold text-cream-200 hover:text-cream-50">
            {t('site.nav.pricing')}
          </a>
          <a href={ROUTES.demo} className="text-web-label font-semibold text-cream-200 hover:text-cream-50">
            {t('site.nav.demo')}
          </a>
        </nav>
        <div className="hidden items-center gap-24 lg:flex">
          <LangPicker lang={lang} setLang={setLang} t={t} label="code" />
          <a href={ROUTES.login} className="text-web-label font-semibold text-cream-50 hover:underline">
            {t('site.nav.login')}
          </a>
          <LinkButton href={ROUTES.trial} variant="light" size="md">
            {t('site.nav.trial')}
          </LinkButton>
        </div>
        <button
          type="button"
          onClick={() => setDrawer(true)}
          aria-label={t('site.nav.menu')}
          className="inline-flex h-[44px] w-[44px] items-center justify-center rounded-full text-cream-50 hover:bg-espresso-850 lg:hidden"
        >
          <Menu width={24} height={24} />
        </button>
      </div>
      {drawer && (
        <div className="fixed inset-0 z-40 flex flex-col overflow-y-auto bg-espresso-950 lg:hidden" role="dialog" aria-modal="true">
          <div className="flex h-[64px] items-center justify-between px-16 md:h-[89px] md:px-32">
            <Logo />
            <button
              type="button"
              onClick={() => setDrawer(false)}
              aria-label={t('site.nav.close')}
              className="inline-flex h-[44px] w-[44px] items-center justify-center rounded-full text-cream-50 hover:bg-espresso-850"
            >
              <X width={24} height={24} />
            </button>
          </div>
          <div className="flex flex-1 flex-col gap-24 px-16 pb-32 pt-16 md:px-32">
            {[
              { title: t('site.nav.product'), items: productItems(t) },
              { title: t('site.nav.industries'), items: industries },
            ].map((g) => (
              <div key={g.title}>
                <p className="mb-8 text-web-eyebrow uppercase text-cream-400">{g.title}</p>
                {g.items.map((i) => (
                  <a
                    key={i.href + i.label}
                    href={i.href}
                    onClick={() => setDrawer(false)}
                    className="flex items-center justify-between border-b border-cream-100/[0.08] py-12 text-latin-body font-semibold text-cream-50"
                  >
                    {i.label}
                    <ChevronRight width={18} height={18} className="text-cream-400" aria-hidden />
                  </a>
                ))}
              </div>
            ))}
            <div className="flex flex-col">
              <a href={ROUTES.pricing} className="border-b border-cream-100/[0.08] py-12 text-latin-body font-semibold text-cream-50">
                {t('site.nav.pricing')}
              </a>
              <a href={ROUTES.demo} className="border-b border-cream-100/[0.08] py-12 text-latin-body font-semibold text-cream-50">
                {t('site.nav.demo')}
              </a>
              <a href={ROUTES.login} className="border-b border-cream-100/[0.08] py-12 text-latin-body font-semibold text-cream-50">
                {t('site.nav.login')}
              </a>
            </div>
            <LangPicker lang={lang} setLang={setLang} t={t} label="name" />
            <LinkButton href={ROUTES.trial} variant="light" className="mt-auto w-full">
              {t('site.nav.trial')}
            </LinkButton>
          </div>
        </div>
      )}
    </header>
  );
}

function Footer({ t, lang, setLang, trades }: { t: T; lang: Lang; setLang: (l: Lang) => void; trades: TradeOut[] }) {
  const groups = [
    {
      title: t('site.foot.product'),
      links: [
        { href: '/#features', label: t('site.foot.features') },
        { href: ROUTES.pricing, label: t('site.nav.pricing') },
        { href: '/#features', label: t('site.foot.offline') },
        { href: ROUTES.demo, label: t('site.nav.demo') },
      ],
    },
    { title: t('site.foot.industries'), links: trades.slice(0, 4).map((tr) => ({ href: ROUTES.industry(tr.key), label: tr.name })) },
    {
      title: t('site.foot.company'),
      links: [
        { href: ROUTES.about, label: t('site.foot.about') },
        { href: ROUTES.contact, label: t('site.foot.contact') },
        { href: ROUTES.blog, label: t('site.foot.blog') },
      ],
    },
    {
      title: t('site.foot.legal'),
      links: [
        { href: ROUTES.privacy, label: t('site.foot.privacy') },
        { href: ROUTES.terms, label: t('site.foot.terms') },
      ],
    },
  ];
  return (
    <footer className="bg-espresso-950 text-cream-200">
      <div className="mx-auto max-w-[1200px] px-16 pb-32 pt-48 md:px-32 md:pt-64 xl:px-0">
        <div className="flex flex-col gap-40 lg:flex-row lg:justify-between">
          <div className="flex flex-col items-start gap-16 lg:w-[360px]">
            <Logo />
            <p className="text-web-body-lg text-cream-100">{t('site.foot.tagline')}</p>
            <span className="inline-flex rounded-full border border-cream-100/[0.14] bg-cream-100/[0.06] px-16 py-8">
              <LangPicker lang={lang} setLang={setLang} t={t} label="name" />
            </span>
          </div>
          <div className="grid grid-cols-2 gap-x-24 gap-y-32 sm:grid-cols-4 lg:w-[752px]">
            {groups.map((g) => (
              <div key={g.title}>
                <p className="mb-16 text-web-eyebrow uppercase text-cream-400">{g.title}</p>
                <ul className="flex flex-col gap-12">
                  {g.links.map((l) => (
                    <li key={l.label}>
                      <a href={l.href} className="text-web-body text-cream-200 hover:text-cream-50">
                        {l.label}
                      </a>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        </div>
        <div className="mt-40 flex flex-col gap-8 border-t border-cream-100/[0.08] pt-24 text-latin-caption text-cream-400 sm:flex-row sm:justify-between md:mt-64">
          <p>{t('site.foot.rights', { year: new Date().getFullYear() })}</p>
          <p>{t('site.foot.made')}</p>
        </div>
      </div>
    </footer>
  );
}

/** Announcement bar, nav and footer around every marketing page. */
export function SiteLayout({
  t,
  lang,
  setLang,
  trades,
  announcement = true,
  children,
}: {
  t: T;
  lang: Lang;
  setLang: (l: Lang) => void;
  trades: TradeOut[];
  announcement?: boolean;
  children: ReactNode;
}) {
  return (
    <div className="min-h-screen bg-bg-canvas">
      {announcement && <AnnouncementBar t={t} />}
      <Nav t={t} lang={lang} setLang={setLang} trades={trades} />
      <main>{children}</main>
      <Footer t={t} lang={lang} setLang={setLang} trades={trades} />
    </div>
  );
}
