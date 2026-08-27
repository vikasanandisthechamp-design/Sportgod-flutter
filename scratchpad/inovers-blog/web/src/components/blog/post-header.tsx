import { Clock } from 'lucide-react';
import type { BlogPost } from '@/types/blog';
import { TagPill } from './tag-pill';

export function PostHeader({
  post,
  tags,
}: {
  post: BlogPost;
  tags: string[];
}) {
  return (
    <header className="pt-10 md:pt-16">
      {tags.length > 0 && (
        <div className="mb-4 flex flex-wrap gap-1.5">
          {tags.map((t) => (
            <TagPill key={t} slug={t} size="sm" />
          ))}
        </div>
      )}
      <h1 className="text-3xl md:text-5xl font-bold tracking-tight leading-[1.1]">
        {post.title}
      </h1>
      {post.dek && (
        <p className="mt-4 text-lg md:text-xl text-muted-foreground leading-relaxed">
          {post.dek}
        </p>
      )}
      <div className="mt-6 flex items-center gap-3 text-sm text-muted-foreground">
        <div className="h-9 w-9 rounded-full bg-primary/10 text-primary flex items-center justify-center font-semibold">
          {(post.author_name ?? 'I').slice(0, 1).toUpperCase()}
        </div>
        <div>
          <div className="font-medium text-foreground">
            {post.author_name ?? 'Inovers Editorial'}
          </div>
          <div className="flex items-center gap-2 text-xs">
            {post.publish_at && (
              <time dateTime={post.publish_at}>
                {new Date(post.publish_at).toLocaleDateString('en-IN', {
                  day: 'numeric',
                  month: 'long',
                  year: 'numeric',
                })}
              </time>
            )}
            {post.reading_time && (
              <>
                <span aria-hidden>·</span>
                <span className="inline-flex items-center gap-1">
                  <Clock className="h-3.5 w-3.5" />
                  {post.reading_time} min read
                </span>
              </>
            )}
          </div>
        </div>
      </div>
    </header>
  );
}
