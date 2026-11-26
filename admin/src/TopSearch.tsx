import { Briefcase, Search, User } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';

import { api } from './lib/api';
import type { T } from './lib/i18n';
import type { CompanyList, UserList } from './lib/types';
import { navigate } from './ui';

type Hit = { key: string; kind: 'company' | 'user'; title: string; sub: string; to: string };

/** Top bar search (A04): companies and people by name, phone or email, five of each; Enter opens the first. */
export function TopSearch({ t }: { t: T }) {
  const [q, setQ] = useState('');
  const [hits, setHits] = useState<Hit[] | null>(null);
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(0);
  const box = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const words = q.trim();
    if (words.length < 2) {
      setHits(null);
      return;
    }
    let live = true;
    const timer = setTimeout(async () => {
      const enc = encodeURIComponent(words);
      const [cos, us] = await Promise.all([
        api<CompanyList>(`/admin/companies?q=${enc}&page_size=5`).catch(() => null),
        api<UserList>(`/admin/users?q=${enc}&page_size=5`).catch(() => null),
      ]);
      if (!live) return;
      setActive(0);
      setHits([
        ...(cos?.items ?? []).map((c) => ({
          key: `c${c.id}`,
          kind: 'company' as const,
          title: c.name,
          sub: [c.owner_name, c.country].filter(Boolean).join(' · '),
          to: `/companies/${c.id}`,
        })),
        ...(us?.items ?? []).map((u) => ({
          key: `u${u.membership_id}`,
          kind: 'user' as const,
          title: u.name || t('admin.us.no_name'),
          sub: [u.phone ?? u.email, u.company].filter(Boolean).join(' · '),
          to: `/users/${u.user_id}`,
        })),
      ]);
    }, 250);
    return () => {
      live = false;
      clearTimeout(timer);
    };
  }, [q, t]);

  useEffect(() => {
    const close = (e: MouseEvent) => {
      if (box.current && !box.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', close);
    return () => document.removeEventListener('mousedown', close);
  }, []);

  function go(h: Hit) {
    setOpen(false);
    setQ('');
    navigate(h.to);
  }

  return (
    <div ref={box} className="relative w-full sm:w-[320px]">
      <label className="flex h-[40px] items-center gap-8 rounded-md border border-border-default bg-bg-surface px-12 transition-colors focus-within:border-action-primary">
        <Search width={18} height={18} className="shrink-0 text-text-secondary" aria-hidden />
        <input
          value={q}
          onChange={(e) => {
            setQ(e.target.value);
            setOpen(true);
          }}
          onFocus={() => setOpen(true)}
          onKeyDown={(e) => {
            if (!hits?.length) return;
            if (e.key === 'ArrowDown') setActive((a) => Math.min(a + 1, hits.length - 1));
            else if (e.key === 'ArrowUp') setActive((a) => Math.max(a - 1, 0));
            else if (e.key === 'Enter') go(hits[active]);
            else if (e.key === 'Escape') setOpen(false);
            else return;
            e.preventDefault();
          }}
          placeholder={t('admin.search.hint')}
          aria-label={t('admin.search.hint')}
          className="min-w-0 flex-1 bg-transparent text-[14px] outline-none"
        />
      </label>
      {open && hits && (
        <div className="kn-in absolute left-0 right-0 top-[44px] z-40 max-h-[360px] overflow-auto rounded-lg border border-border-default bg-bg-surface py-4 shadow-lg">
          {hits.length === 0 ? (
            <p className="px-12 py-12 text-[13px] text-text-secondary">{t('admin.search.none')}</p>
          ) : (
            hits.map((h, i) => (
              <button
                key={h.key}
                type="button"
                onMouseEnter={() => setActive(i)}
                onClick={() => go(h)}
                className={`flex w-full items-center gap-12 px-12 py-8 text-left transition-colors ${i === active ? 'bg-cream-100' : ''}`}
              >
                {h.kind === 'company' ? (
                  <Briefcase width={16} height={16} className="shrink-0 text-text-secondary" aria-hidden />
                ) : (
                  <User width={16} height={16} className="shrink-0 text-text-secondary" aria-hidden />
                )}
                <span className="min-w-0">
                  <span className="block truncate text-[14px] font-semibold">{h.title}</span>
                  {h.sub && <span className="block truncate text-[12px] text-text-secondary">{h.sub}</span>}
                </span>
              </button>
            ))
          )}
        </div>
      )}
    </div>
  );
}
