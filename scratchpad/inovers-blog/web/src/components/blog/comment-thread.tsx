'use client';

import { useState } from 'react';
import { MessageSquare, Flag } from 'lucide-react';
import type { BlogComment } from '@/types/blog';
import { CommentForm } from './comment-form';
import { track } from '@/lib/blog/analytics';

interface Props {
  postId: string;
  postSlug: string;
  comments: BlogComment[];
  signedIn: boolean;
  currentUserId?: string | null;
}

export function CommentThread({
  postId,
  postSlug,
  comments,
  signedIn,
  currentUserId = null,
}: Props) {
  return (
    <section aria-labelledby="comments-heading" className="mt-16">
      <div className="mb-6 flex items-center justify-between">
        <h2 id="comments-heading" className="text-xl font-semibold tracking-tight">
          {comments.length === 0
            ? 'Be the first to comment'
            : `${countAll(comments)} ${countAll(comments) === 1 ? 'comment' : 'comments'}`}
        </h2>
      </div>

      <CommentForm postId={postId} postSlug={postSlug} signedIn={signedIn} />

      <ol className="mt-8 space-y-6">
        {comments.map((c) => (
          <CommentItem
            key={c.id}
            comment={c}
            postId={postId}
            postSlug={postSlug}
            signedIn={signedIn}
            currentUserId={currentUserId}
          />
        ))}
      </ol>
    </section>
  );
}

function countAll(list: BlogComment[]): number {
  return list.reduce((n, c) => n + 1 + (c.replies?.length ?? 0), 0);
}

function CommentItem({
  comment,
  postId,
  postSlug,
  signedIn,
  currentUserId,
  depth = 0,
}: {
  comment: BlogComment;
  postId: string;
  postSlug: string;
  signedIn: boolean;
  currentUserId: string | null;
  depth?: number;
}) {
  const [replying, setReplying] = useState(false);
  const [reporting, setReporting] = useState(false);
  const isMine = currentUserId && currentUserId === comment.author_id;
  const authorName = comment.author?.name ?? 'Anonymous';

  return (
    <li className={depth === 0 ? '' : 'ml-6 md:ml-10 border-l border-border pl-4 md:pl-6'}>
      <div className="rounded-2xl border border-border bg-background p-4">
        <header className="flex items-center gap-3 text-sm">
          <div className="h-8 w-8 rounded-full bg-primary/10 text-primary flex items-center justify-center text-xs font-semibold">
            {authorName.slice(0, 1).toUpperCase()}
          </div>
          <div className="flex-1 min-w-0">
            <div className="font-medium truncate">{authorName}</div>
            <div className="text-xs text-muted-foreground">
              {new Date(comment.created_at).toLocaleString('en-IN', {
                day: 'numeric',
                month: 'short',
                hour: 'numeric',
                minute: '2-digit',
              })}
              {comment.edited_at ? ' · edited' : ''}
            </div>
          </div>
        </header>

        <p className="mt-3 whitespace-pre-wrap text-[15px] leading-relaxed text-foreground/90">
          {comment.body}
        </p>

        <footer className="mt-3 flex items-center gap-4 text-xs text-muted-foreground">
          {depth === 0 && (
            <button
              type="button"
              onClick={() => setReplying((v) => !v)}
              className="inline-flex items-center gap-1 hover:text-foreground"
            >
              <MessageSquare className="h-3.5 w-3.5" /> Reply
            </button>
          )}
          {signedIn && !isMine && (
            <button
              type="button"
              onClick={() => {
                if (reporting) return;
                setReporting(true);
                fetch('/api/reports', {
                  method: 'POST',
                  headers: { 'content-type': 'application/json' },
                  body: JSON.stringify({ comment_id: comment.id, reason: 'other' }),
                }).finally(() => {
                  track('blog_reaction_add', { extra: { kind: 'report' } });
                });
              }}
              className="inline-flex items-center gap-1 hover:text-red-600 disabled:opacity-40"
              disabled={reporting}
            >
              <Flag className="h-3.5 w-3.5" />
              {reporting ? 'Reported' : 'Report'}
            </button>
          )}
        </footer>
      </div>

      {replying && (
        <div className="mt-3">
          <CommentForm
            postId={postId}
            postSlug={postSlug}
            parentId={comment.id}
            signedIn={signedIn}
            compact
            onSubmitted={() => setReplying(false)}
          />
        </div>
      )}

      {comment.replies && comment.replies.length > 0 && (
        <ol className="mt-4 space-y-4">
          {comment.replies.map((r) => (
            <CommentItem
              key={r.id}
              comment={r}
              postId={postId}
              postSlug={postSlug}
              signedIn={signedIn}
              currentUserId={currentUserId}
              depth={depth + 1}
            />
          ))}
        </ol>
      )}
    </li>
  );
}
