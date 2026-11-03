const NAV = ['Dashboard', 'AI usage & cost', 'Companies', 'Users', 'Reviews & ratings', 'Usage & credits', 'Audit logs'];

/** Step 0 placeholder: admin shell using shared tokens. Real screens come in Step 3. */
export default function App() {
  return (
    <div className="flex min-h-screen">
      <aside className="w-[256px] shrink-0 bg-mocha-900 px-16 py-24">
        <div className="px-12 text-latin-h3 text-cream-50">KaamNishaan</div>
        <nav className="mt-32 space-y-4">
          {NAV.map((n, i) => (
            <a
              key={n}
              href="#"
              className={`block rounded-md px-12 py-12 text-latin-label-sm ${i === 0 ? 'bg-white/10 text-cream-50' : 'text-cream-100'}`}
            >
              {n}
            </a>
          ))}
        </nav>
      </aside>
      <main className="flex-1 p-32">
        <h1 className="text-latin-h1">Dashboard</h1>
        <p className="mt-8 text-latin-body text-text-secondary">Admin panel skeleton — screens are built in Step 3.</p>
      </main>
    </div>
  );
}
