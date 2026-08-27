'use client';

import { useState, useTransition } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { track } from '@/lib/blog/analytics';
import { moderateComment, moderationMessage } from '@/lib/blog/moderation';

interface Props {
  postId: string;
  postSlug: string;
  parentId?: string | null;
  signedIn: boolean;
  onSubmitted?: () => void;
  compact?: boolean;
}

export function CommentForm({
  postId,
  postSlug,
  parentId = null,
  signedIn,
  onSubmitted,
  compact = false,
}: Props) {
  const [body, setBody] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const router = useRouter();

  if (!signedIn) {
    return (
      <div className="rounded-2xl border border-dashed border-border bg-muted/40 p-5 text-sm">
        <p className="font-medium text-foreground">
          Sign in to add your voice.
        </p>
        <p className="mt-1 text-muted-foreground">
          Reading is open to everyone. Commenting is signed-in only — so every
          voice on Inovers is a real, verified account.
        </p>
        <div className="mt-3 flex flex-wrap gap-2">
          <Link
            href={`/auth/login?next=/blog/${postSlug}`}
            onClick={() => track('blog_comment_signin_required', { slug: postSlug })}
            className="inline-flex h-9 items-center rounded-full bg-primary px-4 text-sm font-medium text-primary-foreground hover:opacity-90"
          >
            Sign in
          </Link>
          <Link
            href={`/auth/signup?next=/blog/${postSlug}`}
            className="inline-flex h-9 items-center rounded-full border border-border px-4 text-sm font-medium hover:bg-muted"
          >
            Create free account
          </Link>
        </div>
      </div>
    );
  }

  function submit() {
    setError(null);
    const check = moderateComment(body);
    if (!check.ok) {
      setError(moderationMessage(check.reason!));
      return;
    }
    startTransition(async () => {
      const res = await fetch('/api/comments', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ post_id: postId, parent_id: parentId, body }),
      });
      if (!res.ok) {
        const t = await res.text().catch(() => '');
        setError(t || 'Could not post — please try again.');
        return;
      }
      track('blog_comment_submit', { slug: postSlug, post_id: postId });
      setBody('');
      onSubmitted?.();
      router.refresh();
    });
  }

  return (
    <div className={compact ? '' : 'rounded-2xl border border-border bg-background p-5'}>
      <textarea
        value={body}
        onChange={(e) => setBody(e.target.value)}
        placeholder={parentId ? 'Write a reply…' : 'Share what you think — disagree, add nuance, ask a question.'}
        className="min-h-[110px] w-full resize-y rounded-xl border border-border bg-muted/40 p-3 text-sm outline-none focus:border-primary"
        maxLength={4000}
      />
      <div className="mt-3 flex items-center justify-between gap-3">
        <p className="text-xs text-muted-foreground">
          Be direct. Be civil. Attack ideas, not people.
        </p>
        <button
          type="button"
          onClick={submit}
          disabled={pending || body.trim().length < 2}
          className="inline-flex h-9 items-center rounded-full bg-primary px-4 text-sm font-medium text-primary-foreground hover:opacity-90 disabled:opacity-40"
        >
          {pending ? 'Posting…' : parentId ? 'Reply' : 'Post comment'}
        </button>
      </div>
      {error && (
        <p role="alert" className="mt-2 text-xs text-red-600">
          {error}
        </p>
      )}
    </div>
  );
}
