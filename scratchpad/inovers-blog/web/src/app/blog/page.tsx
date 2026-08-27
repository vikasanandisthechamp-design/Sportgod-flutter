import type { Metadata } from 'next';
import Link from 'next/link';
import { listPublishedPosts } from '@/lib/blog/queries';
import { PostCard } from '@/components/blog/post-card';

export const metadata: Metadata = {
  title: 'Inovers Journal — Ideas that build the future',
  description:
    'Long-form writing on innovation, creative thinking, education and the AI-shaped world. Open to read; sign in to comment.',
  alternates: { canonical: '/blog' },
  openGraph: {
    title: 'Inovers Journal',
    description:
      'Ideas that build the future. Read openly, comment as a member.',
    type: 'website',
  },
};

// Revalidate every 5 minutes — new drafts don't need to appear instantly.
export const revalidate = 300;

export default async function BlogIndexPage({
  searchParams,
}: {
  searchParams: Promise<{ page?: string; q?: string }>;
}) {
  const sp = await searchParams;
  const page = Math.max(1, Number(sp.page ?? '1') || 1);
  const q = (sp.q ?? '').toString();

  const { posts, hasMore } = await listPublishedPosts({ page, q });

  return (
    <main className="pb-24">
      <section className="mt-8 md:mt-12">
        {posts.length === 0 ? (
          <EmptyState q={q} />
        ) : (
          <div className="grid gap-5 md:grid-cols-2">
            {posts.map((p, i) => (
              <PostCard key={p.id} post={p} featured={i === 0 && page === 1 && !q} />
            ))}
          </div>
        )}
      </section>

      <nav
        className="mt-10 flex items-center justify-between text-sm"
        aria-label="Pagination"
      >
        {page > 1 ? (
          <Link
            href={`/blog?page=${page - 1}${q ? `&q=${encodeURIComponent(q)}` : ''}`}
            className="inline-flex h-9 items-center rounded-full border border-border px-4 hover:bg-muted"
          >
            ← Newer
          </Link>
        ) : (
          <span />
        )}
        {hasMore && (
          <Link
            href={`/blog?page=${page + 1}${q ? `&q=${encodeURIComponent(q)}` : ''}`}
            className="inline-flex h-9 items-center rounded-full border border-border px-4 hover:bg-muted ml-auto"
          >
            Older →
          </Link>
        )}
      </nav>

      <section
        id="subscribe"
        className="mt-24 rounded-3xl border border-border bg-muted/40 p-8 md:p-12 text-center"
      >
        <h2 className="text-2xl md:text-3xl font-bold tracking-tight">
          Get one good idea a week.
        </h2>
        <p className="mt-2 text-muted-foreground">
          No auto-published slop. One human-reviewed piece worth your time.
        </p>
        <form
          action="/api/newsletter"
          method="post"
          className="mt-6 flex flex-col sm:flex-row items-center gap-3 justify-center"
        >
          <input
            type="email"
            name="email"
            required
            placeholder="you@example.com"
            className="h-11 w-full sm:w-80 rounded-full border border-border bg-background px-4 text-sm focus:border-primary outline-none"
          />
          <button
            type="submit"
            className="inline-flex h-11 items-center rounded-full bg-primary px-5 text-sm font-semibold text-primary-foreground hover:opacity-90"
          >
            Subscribe
          </button>
        </form>
        <p className="mt-3 text-xs text-muted-foreground">
          Free. Weekly. Unsubscribe with one click. Never sold, never shared.
        </p>
      </section>
    </main>
  );
}

function EmptyState({ q }: { q: string }) {
  return (
    <div className="rounded-2xl border border-dashed border-border p-10 text-center">
      <p className="text-lg font-semibold">
        {q ? `No posts match "${q}".` : 'No posts yet.'}
      </p>
      <p className="mt-2 text-sm text-muted-foreground">
        Come back tomorrow — the editorial team publishes at least one piece a day.
      </p>
    </div>
  );
}
