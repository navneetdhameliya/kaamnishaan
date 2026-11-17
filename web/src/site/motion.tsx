import { useEffect, useRef, useState, type CSSProperties } from 'react';

import { Logo } from './Layout';

type Kind = 'up' | 'down' | 'left' | 'right' | 'zoom' | 'fade';

/** Props that make an element fade in when it scrolls into view; [i] staggers siblings by [step] ms. */
export function rv(kind: Kind = 'up', i = 0, step = 90): { 'data-reveal': Kind; style: CSSProperties } {
  return { 'data-reveal': kind, style: { '--d': `${Math.min(i * step, 600)}ms` } as CSSProperties };
}

export const reducedMotion = () => typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

/** Watches the page for [data-reveal] elements (also ones that appear later) and shows each once. */
export function useRevealOnScroll() {
  useEffect(() => {
    const show = (el: Element) => el.classList.add('is-in');
    if (!('IntersectionObserver' in window) || reducedMotion()) {
      const all = () => document.querySelectorAll('[data-reveal]:not(.is-in)').forEach(show);
      all();
      const mo = new MutationObserver(all);
      mo.observe(document.body, { childList: true, subtree: true });
      return () => mo.disconnect();
    }
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) {
            show(e.target);
            io.unobserve(e.target);
          }
        }
      },
      { threshold: 0.12, rootMargin: '0px 0px -6% 0px' },
    );
    const watched = new WeakSet<Element>();
    const scan = () =>
      document.querySelectorAll('[data-reveal]:not(.is-in)').forEach((el) => {
        if (!watched.has(el)) {
          watched.add(el);
          io.observe(el);
        }
      });
    scan();
    const mo = new MutationObserver(scan);
    mo.observe(document.body, { childList: true, subtree: true });
    return () => {
      mo.disconnect();
      io.disconnect();
    };
  }, []);
}

/** True when the element has scrolled into view (once). */
export function useInView<T extends Element>(threshold = 0.4) {
  const ref = useRef<T>(null);
  const [seen, setSeen] = useState(false);
  useEffect(() => {
    const el = ref.current;
    if (!el || seen) return;
    if (!('IntersectionObserver' in window)) return setSeen(true);
    const io = new IntersectionObserver(
      ([e]) => {
        if (e?.isIntersecting) {
          setSeen(true);
          io.disconnect();
        }
      },
      { threshold },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [seen, threshold]);
  return [ref, seen] as const;
}

/** "15 min" counts up from 0 (and "0 typing" counts down from 10) when it scrolls into view. */
export function CountUp({ text, className }: { text: string; className?: string }) {
  const m = text.match(/^(\D*)(\d+)(.*)$/s);
  const [ref, seen] = useInView<HTMLSpanElement>(0.6);
  const target = m ? Number(m[2]) : 0;
  const from = target === 0 ? 10 : 0;
  const [n, setN] = useState(from);
  useEffect(() => {
    if (!m || !seen) return;
    if (reducedMotion()) return setN(target);
    let raf = 0;
    const start = performance.now();
    const tick = (now: number) => {
      const p = Math.min(1, (now - start) / 1200);
      const eased = 1 - Math.pow(1 - p, 3);
      setN(Math.round(from + (target - from) * eased));
      if (p < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [seen, target]);
  if (!m) return <span className={className}>{text}</span>;
  return (
    <span ref={ref} className={className} aria-label={text}>
      <span aria-hidden>
        {m[1]}
        {n}
        {m[3]}
      </span>
    </span>
  );
}

/** How far down the page the reader is, 0–1, and whether they have left the top. */
export function useScroll() {
  const [state, setState] = useState({ progress: 0, scrolled: false });
  useEffect(() => {
    let raf = 0;
    const read = () => {
      raf = 0;
      const max = document.documentElement.scrollHeight - window.innerHeight;
      setState({ progress: max > 0 ? Math.min(1, window.scrollY / max) : 0, scrolled: window.scrollY > 8 });
    };
    const on = () => {
      if (!raf) raf = requestAnimationFrame(read);
    };
    read();
    window.addEventListener('scroll', on, { passive: true });
    window.addEventListener('resize', on);
    return () => {
      window.removeEventListener('scroll', on);
      window.removeEventListener('resize', on);
      if (raf) cancelAnimationFrame(raf);
    };
  }, []);
  return state;
}

/** The brand loader shown while the site's first data (plans, config) arrives; never longer than 2.5 s. */
export function PageLoader({ ready }: { ready: boolean }) {
  const [timeUp, setTimeUp] = useState(false);
  // shown once per visit; moving between pages after that doesn't flash it again
  const [gone, setGone] = useState(() => {
    try {
      return window.sessionStorage.getItem('kn.loaded') === '1';
    } catch {
      return false;
    }
  });
  useEffect(() => {
    const id = window.setTimeout(() => setTimeUp(true), 2500);
    return () => window.clearTimeout(id);
  }, []);
  const done = ready || timeUp;
  useEffect(() => {
    if (!done) return;
    try {
      window.sessionStorage.setItem('kn.loaded', '1');
    } catch {
      /* storage may be blocked */
    }
    const id = window.setTimeout(() => setGone(true), 600);
    return () => window.clearTimeout(id);
  }, [done]);
  if (gone) return null;
  return (
    <div
      aria-hidden={done}
      role="status"
      className={`kn-loader fixed inset-0 z-50 flex flex-col items-center justify-center gap-24 bg-espresso-950 ${done ? 'is-done' : ''}`}
    >
      <span className="relative inline-flex h-[88px] w-[88px] items-center justify-center">
        <span className="kn-loader-ring absolute inset-0 rounded-full border-2 border-sage-500" />
        <img src="/brand-mark-dark.svg" alt="" width={64} height={64} className="kn-loader-mark h-[64px] w-[64px]" />
      </span>
      <Logo />
      <span className="relative h-[3px] w-[160px] overflow-hidden rounded-full bg-cream-100/[0.12]">
        <span className="kn-loader-bar absolute inset-y-0 left-0 w-[40%] rounded-full bg-sage-500" />
      </span>
    </div>
  );
}

/** A small spinner for buttons that are working. */
export function Spinner({ size = 18 }: { size?: number }) {
  return (
    <span
      aria-hidden
      style={{ width: size, height: size }}
      className="kn-spin inline-block rounded-full border-2 border-current border-r-transparent"
    />
  );
}
