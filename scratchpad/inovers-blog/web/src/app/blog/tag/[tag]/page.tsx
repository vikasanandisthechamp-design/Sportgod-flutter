import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { listPublishedPosts, listAllTags } from '@/lib/blog/queries';
import { PostCard } from '@/components/blog/post-card';

export const revalidate = 300;

export async function generateMetadata({
  params,
}: {
  params: Promise<{ tag: string }>;
}): Promise<Metadata> {
  const { tag } = await params;
  const tags = await listAllTags();
  const t = tags.find((x) => x.slug === tag);
  if (!t) return { title: 'Not found — Inovers Journal' };
  const title = `${t.label} — Inovers Journal`;
  return {
    title,
    description:
      t.description ?? `Posts on ${t.label} at Inovers.`,
    alternates: { canonical: `/blog/tag/${t.slug}` },
  };
}

export default async function TagPage({
  params,
  searchParams,
}: {
  params: Promise<{ tag: string }>;
  searchParams: Promise<{ page?: string }>;
}) {
  const { tag } = await params;
  const sp = await searchParams;
  const page = Math.max(1, Number(sp.page ?? '1') || 1);

  const tags = await listAllTags();
  const t = tags.find((x) => x.slug === tag);
  if (!t) notFound();

  const { posts, hasMore } = await listPublishedPosts({ page, tag });

  return (
    <main className="pb-24">
      <header className="mt-8">
        <h1 className="text-3xl font-bold tracking-tight">#{t.label}</h1>
        {t.description && (
          <p className="mt-2 text-muted-foreground max-w-2xl">{t.description}</p>
        )}
      </header>

      <section className="mt-8">
        {posts.length === 0 ? (
          <div className="rounded-2xl border border-dashed border-border p-10 text-center text-sm text-muted-foreground">
            Nothing tagged {t.label} yet.
          </div>
        ) : (
          <div className="grid gap-5 md:grid-cols-2">
            {posts.map((p) => (
              <PostCard key={p.id} post={p} />
            ))}
          </div>
        )}
      </section>

      {hasMore && (
        <div className="mt-8 text-right">
          <a
            href={`/blog/tag/${tag}?page=${page + 1}`}
            className="inline-flex h-9 items-center rounded-full border border-border px-4 text-sm hover:bg-muted"
          >
            Older →
          </a>
        </div>
      )}
    </main>
  );
}
