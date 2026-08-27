import { notFound, redirect } from 'next/navigation';
import { getCurrentUser, isEditor } from '@/lib/blog/auth';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import type { BlogPost } from '@/types/blog';
import { renderMarkdown } from '@/lib/blog/mdx';

export const dynamic = 'force-dynamic';

export default async function DraftReviewPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const me = await getCurrentUser();
  if (!me) redirect('/auth/login?next=/blog/admin');
  if (!isEditor(me)) redirect('/blog');

  const { id } = await params;
  const supabase = await getSupabaseServerClient();
  if (!supabase) notFound();

  const { data } = await supabase
    .from('blog_posts')
    .select('*')
    .eq('id', id)
    .maybeSingle();
  const post = (data as BlogPost | null) ?? null;
  if (!post) notFound();

  return (
    <main className="pb-24">
      <div className="mt-6 rounded-2xl border border-dashed border-border bg-muted/30 p-4 text-xs text-muted-foreground">
        Draft preview — this is not live. Status:{' '}
        <span className="font-medium text-foreground">{post.status}</span>
      </div>

      <article className="mx-auto mt-6 max-w-3xl">
        <header className="pt-4">
          <h1 className="text-3xl md:text-4xl font-bold tracking-tight leading-tight">
            {post.title || <em>(untitled)</em>}
          </h1>
          {post.dek && (
            <p className="mt-3 text-lg text-muted-foreground">{post.dek}</p>
          )}
        </header>

        {post.source_note && (
          <p className="mt-4 text-xs text-muted-foreground">
            Source: {post.source_note}
          </p>
        )}

        <div className="prose-inovers mt-8">
          {renderMarkdown(post.body_mdx || '')}
        </div>

        <form
          action="/api/admin/publish"
          method="post"
          className="mt-10 flex flex-wrap items-center gap-3 border-t border-border pt-6"
        >
          <input type="hidden" name="id" value={post.id} />
          <button
            type="submit"
            name="action"
            value="publish"
            className="inline-flex h-10 items-center rounded-full bg-primary px-5 text-sm font-semibold text-primary-foreground hover:opacity-90"
          >
            Publish now
          </button>
          <button
            type="submit"
            name="action"
            value="pending_review"
            className="inline-flex h-10 items-center rounded-full border border-border px-5 text-sm font-medium hover:bg-muted"
          >
            Mark for later
          </button>
          <button
            type="submit"
            name="action"
            value="archive"
            className="inline-flex h-10 items-center rounded-full border border-border px-5 text-sm font-medium hover:bg-muted"
          >
            Archive
          </button>
        </form>
      </article>
    </main>
  );
}
