import Link from 'next/link';
import { cn } from '@/lib/utils';

export function TagPill({
  slug,
  label,
  active,
  size = 'md',
}: {
  slug: string;
  label?: string;
  active?: boolean;
  size?: 'sm' | 'md';
}) {
  return (
    <Link
      href={`/blog/tag/${slug}`}
      className={cn(
        'inline-flex items-center rounded-full border transition-colors',
        size === 'sm'
          ? 'px-2.5 py-0.5 text-xs'
          : 'px-3 py-1 text-sm',
        active
          ? 'border-primary bg-primary/10 text-primary'
          : 'border-border bg-muted/60 text-muted-foreground hover:border-primary/60 hover:text-foreground'
      )}
    >
      #{label ?? slug}
    </Link>
  );
}
