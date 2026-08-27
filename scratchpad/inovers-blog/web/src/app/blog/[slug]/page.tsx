import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import {
  getPublishedPost,
  getPostTags,
  listCommentsForPost,
  listPublishedPosts,
} from '@/lib/blog/queries';
import { getCurrentUser } from '@/lib/blog/auth';
import { renderMarkdown } from '@/lib/blog/mdx';
import { PostHeader } from '@/components/blog/post-header';
import { ReactionBar } from '@/components/blog/reaction-bar';
import { CommentThread } from '@/components/blog/comment-thread';

export const revalidate = 60;

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const post = await getPublishedPost(slug);
  if (!post) return { title: 'Not found — Inovers Journal' };
  const title = `${post.title} — Inovers Journal`;
  const description = post.dek ?? post.body_excerpt ?? undefined;
  return {
    title,
    description,
    alternates: { canonical: `/blog/${post.slug}` },
    openGraph: {
      title,
      description,
      type: 'article',
      publishedTime: post.publish_at ?? undefined,
      authors: post.author_name ? [post.author_name] : undefined,
      images: post.cover_image ? [{ url: post.cover_image }] : undefined,
    },
    twitter: {
      card: post.cover_image ? 'summary_large_image' : 'summary',
      title,
      description,
    },
  };
}

export default async function BlogPostPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const post = await getPublishedPost(slug);
  if (!post) notFound();

  const [tags, comments, me] = await Promise.all([
    getPostTags(post.id).then((ts) => ts.map((t) => t.slug)),
    listCommentsForPost(post.id),
    getCurrentUser(),
  ]);

  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'BlogPosting',
    headline: post.title,
    description: post.dek ?? post.body_excerpt ?? undefined,
    datePublished: post.publish_at ?? undefined,
    dateModified: post.updated_at,
    author: post.author_name
      ? { '@type': 'Person', name: post.author_name }
      : { '@type': 'Organization', name: 'Inovers Editorial' },
    publisher: {
      '@type': 'Organization',
      name: 'Inovers',
      logo: {
        '@type': 'ImageObject',
        url: 'https://inovers.in/icon.png',
      },
    },
    mainEntityOfPage: `https://inovers.in/blog/${post.slug}`,
    image: post.cover_image ? [post.cover_image] : undefined,
    keywords: tags.join(', '),
    commentCount: post.comment_count,
  };

  return (
    <article className="mx-auto max-w-3xl pb-24">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />

      <PostHeader post={post} tags={tags} />

      {post.cover_image && (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={post.cover_image}
          alt=""
          className="mt-8 rounded-2xl border border-border"
        />
      )}

      <div className="prose-inovers mt-8">
        {renderMarkdown(post.body_mdx)}
      </div>

      <ReactionBar
        postId={post.id}
        postSlug={post.slug}
        signedIn={!!me}
        totals={{ up: post.reaction_count }}
        mine={null}
      />

      <div className="my-10 rounded-2xl border border-border bg-muted/40 p-5 text-sm">
        <p className="font-medium">Take this further.</p>
        <p className="mt-1 text-muted-foreground">
          Ideas travel through people. Send this to one person who needs to
          read it — a parent, a teacher, a founder, a friend.
        </p>
        <div className="mt-3 flex flex-wrap gap-2">
          <ShareBar slug={post.slug} title={post.title} />
        </div>
      </div>

      <CommentThread
        postId={post.id}
        postSlug={post.slug}
        comments={comments}
        signedIn={!!me}
        currentUserId={me?.id ?? null}
      />

      <RelatedPosts excludeId={post.id} />
    </article>
  );
}

function ShareBar({ slug, title }: { slug: string; title: string }) {
  const url = `https://inovers.in/blog/${slug}`;
  const wa = `https://wa.me/?text=${encodeURIComponent(`${title} — ${url}`)}`;
  const x = `https://twitter.com/intent/tweet?text=${encodeURIComponent(title)}&url=${encodeURIComponent(url)}`;
  const li = `https://www.linkedin.com/sharing/share-offsite/?url=${encodeURIComponent(url)}`;
  const cn =
    'inline-flex h-9 items-center rounded-full border border-border px-4 text-sm font-medium hover:bg-muted';
  return (
    <>
      <a href={wa} target="_blank" rel="noopener noreferrer" className={cn}>WhatsApp</a>
      <a href={x} target="_blank" rel="noopener noreferrer" className={cn}>Twitter / X</a>
      <a href={li} target="_blank" rel="noopener noreferrer" className={cn}>LinkedIn</a>
      <a href={`mailto:?subject=${encodeURIComponent(title)}&body=${encodeURIComponent(url)}`} className={cn}>Email</a>
    </>
  );
}

async function RelatedPosts({ excludeId }: { excludeId: string }) {
  const { posts } = await listPublishedPosts({ page: 1 });
  const related = posts.filter((p) => p.id !== excludeId).slice(0, 3);
  if (related.length === 0) return null;
  return (
    <section className="mt-20 border-t border-border pt-10">
      <h2 className="text-lg font-semibold tracking-tight mb-4">Keep reading</h2>
      <ul className="grid gap-4 md:grid-cols-3">
        {related.map((p) => (
          <li key={p.id}>
            <Link
              href={`/blog/${p.slug}`}
              className="block rounded-xl border border-border bg-background p-4 hover:border-primary transition-colors"
            >
              <div className="text-sm font-semibold leading-snug">{p.title}</div>
              {p.dek && (
                <div className="mt-1 text-xs text-muted-foreground line-clamp-2">{p.dek}</div>
              )}
            </Link>
          </li>
        ))}
      </ul>
    </section>
  );
}
