'use client';

import { useOptimistic, useTransition } from 'react';
import { ArrowUp, Sparkles, HelpCircle, MessageCircleQuestion } from 'lucide-react';
import type { ReactionKind } from '@/types/blog';
import { track } from '@/lib/blog/analytics';
import { cn } from '@/lib/utils';

const KINDS: { kind: ReactionKind; label: string; Icon: React.ComponentType<{ className?: string }> }[] = [
  { kind: 'up',          label: 'Upvote',      Icon: ArrowUp },
  { kind: 'insightful',  label: 'Insightful',  Icon: Sparkles },
  { kind: 'curious',     label: 'Curious',     Icon: HelpCircle },
  { kind: 'disagree',    label: 'Disagree',    Icon: MessageCircleQuestion },
];

interface Props {
  postId: string;
  postSlug: string;
  signedIn: boolean;
  totals: Partial<Record<ReactionKind, number>>;
  mine: ReactionKind | null;
}

export function ReactionBar({ postId, postSlug, signedIn, totals, mine }: Props) {
  const [state, apply] = useOptimistic(
    { totals, mine },
    (s, kind: ReactionKind) => {
      const next = { ...s, totals: { ...s.totals } };
      if (s.mine === kind) {
        next.totals[kind] = Math.max((next.totals[kind] ?? 0) - 1, 0);
        next.mine = null;
      } else {
        if (s.mine) next.totals[s.mine] = Math.max((next.totals[s.mine] ?? 0) - 1, 0);
        next.totals[kind] = (next.totals[kind] ?? 0) + 1;
        next.mine = kind;
      }
      return next;
    }
  );
  const [pending, startTransition] = useTransition();

  function react(kind: ReactionKind) {
    if (!signedIn) {
      window.location.href = `/auth/login?next=/blog/${postSlug}`;
      return;
    }
    startTransition(async () => {
      apply(kind);
      track('blog_reaction_add', { slug: postSlug, post_id: postId, reaction: kind });
      await fetch('/api/reactions', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ post_id: postId, kind }),
      }).catch(() => {});
    });
  }

  return (
    <div className="my-8 flex flex-wrap items-center gap-2">
      {KINDS.map(({ kind, label, Icon }) => {
        const on = state.mine === kind;
        const n = state.totals[kind] ?? 0;
        return (
          <button
            key={kind}
            type="button"
            onClick={() => react(kind)}
            disabled={pending}
            aria-pressed={on}
            className={cn(
              'inline-flex items-center gap-1.5 rounded-full border px-3.5 py-1.5 text-sm transition-colors',
              on
                ? 'border-primary bg-primary/10 text-primary'
                : 'border-border bg-background text-muted-foreground hover:text-foreground hover:border-primary/60'
            )}
          >
            <Icon className="h-4 w-4" />
            <span className="font-medium">{label}</span>
            <span className="tabular-nums">{n}</span>
          </button>
        );
      })}
    </div>
  );
}
