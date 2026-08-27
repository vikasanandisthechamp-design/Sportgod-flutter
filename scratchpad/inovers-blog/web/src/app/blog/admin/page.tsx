import Link from 'next/link';
import { redirect } from 'next/navigation';
import { getCurrentUser, isEditor } from '@/lib/blog/auth';
import { listDraftsForReview } from '@/lib/blog/queries';

export const dynamic = 'force-dynamic';

export default async function BlogAdminPage() {
  const me = await getCurrentUser();
  if (!me) redirect('/auth/login?next=/blog/admin');
  if (!isEditor(me)) redirect('/blog');

  const drafts = await listDraftsForReview();

  return (
    <main className="pb-24">
      <header className="mt-8">
        <h1 className="text-3xl font-bold tracking-tight">Editorial queue</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          Review each draft. Publish, edit, or discard. Nothing goes live until
          you press publish.
        </p>
      </header>

      <section className="mt-8 space-y-4">
        {drafts.length === 0 ? (
          <div className="rounded-2xl border border-dashed border-border p-10 text-center text-sm text-muted-foreground">
            No drafts waiting. The daily research bot runs at 06:00 UTC.
          </div>
        ) : (
          drafts.map((d) => (
            <article
              key={d.id}
              className="rounded-2xl border border-border bg-background p-5"
            >
              <div className="flex items-start justify-between gap-4">
                <div className="min-w-0">
                  <div className="flex items-center gap-2 text-xs text-muted-foreground">
                    <span className="rounded-full border border-border bg-muted px-2 py-0.5">
                      {d.status}
                    </span>
                    <span>
                      updated{' '}
                      {new Date(d.updated_at).toLocaleString('en-IN', {
                        day: 'numeric',
                        month: 'short',
                        hour: 'numeric',
                        minute: '2-digit',
                      })}
                    </span>
                    {d.source_note && (
                      <span className="truncate">· {d.source_note}</span>
                    )}
                  </div>
                  <h2 className="mt-2 text-lg font-semibold leading-snug">
                    {d.title || <em className="text-muted-foreground">(untitled)</em>}
                  </h2>
                  {d.dek && (
                    <p className="mt-1 text-sm text-muted-foreground line-clamp-2">
                      {d.dek}
                    </p>
                  )}
                </div>
                <div className="flex flex-col gap-2 shrink-0">
                  <Link
                    href={`/blog/admin/${d.id}`}
                    className="inline-flex h-9 items-center rounded-full bg-primary px-4 text-sm font-medium text-primary-foreground hover:opacity-90"
                  >
                    Review
                  </Link>
                  <form action="/api/admin/publish" method="post">
                    <input type="hidden" name="id" value={d.id} />
                    <input type="hidden" name="action" value="publish" />
                    <button
                      type="submit"
                      className="inline-flex h-9 items-center rounded-full border border-border px-4 text-sm font-medium hover:bg-muted"
                    >
                      Quick publish
                    </button>
                  </form>
                </div>
              </div>
            </article>
          ))
        )}
      </section>
    </main>
  );
}
