import Link from 'next/link';
import { MessageSquare, ArrowUp, Clock } from 'lucide-react';
import type { BlogPostPublic } from '@/types/blog';
import { TagPill } from './tag-pill';

export function PostCard({
  post,
  featured = false,
}: {
  post: BlogPostPublic;
  featured?: boolean;
}) {
  return (
    <article
      className={
        featured
          ? 'group relative overflow-hidden rounded-3xl border border-border bg-background p-6 md:p-8 hover:border-primary transition-colors md:col-span-2'
          : 'group relative overflow-hidden rounded-2xl border border-border bg-background p-6 hover:border-primary transition-colors'
      }
    >
      {post.tags.length > 0 && (
        <div className="mb-3 flex flex-wrap gap-1.5">
          {post.tags.slice(0, 3).map((t) => (
            <TagPill key={t} slug={t} size="sm" />
          ))}
        </div>
      )}
      <Link href={`/blog/${post.slug}`} className="block">
        <h2
          className={
            featured
              ? 'text-2xl md:text-3xl font-bold tracking-tight leading-tight group-hover:text-primary transition-colors'
              : 'text-xl font-semibold tracking-tight leading-snug group-hover:text-primary transition-colors'
          }
        >
          {post.title}
        </h2>
        {post.dek && (
          <p className="mt-2 text-sm md:text-base text-muted-foreground leading-relaxed line-clamp-3">
            {post.dek}
          </p>
        )}
      </Link>

      <div className="mt-5 flex items-center justify-between text-xs text-muted-foreground">
        <div className="flex items-center gap-2">
          <span className="font-medium text-foreground/80">
            {post.author_name ?? 'Inovers Editorial'}
          </span>
          <span aria-hidden>·</span>
          <time dateTime={post.publish_at}>
            {new Date(post.publish_at).toLocaleDateString('en-IN', {
              day: 'numeric',
              month: 'short',
              year: 'numeric',
            })}
          </time>
        </div>
        <div className="flex items-center gap-3">
          {post.reading_time && (
            <span className="inline-flex items-center gap-1">
              <Clock className="h-3.5 w-3.5" />
              {post.reading_time} min
            </span>
          )}
          <span className="inline-flex items-center gap-1">
            <ArrowUp className="h-3.5 w-3.5" />
            {post.reaction_count}
          </span>
          <span className="inline-flex items-center gap-1">
            <MessageSquare className="h-3.5 w-3.5" />
            {post.comment_count}
          </span>
        </div>
      </div>
    </article>
  );
}
