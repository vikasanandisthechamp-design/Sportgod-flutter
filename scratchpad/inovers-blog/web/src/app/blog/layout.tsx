import Link from 'next/link';
import { listAllTags } from '@/lib/blog/queries';
import { TagPill } from '@/components/blog/tag-pill';

export default async function BlogLayout({ children }: { children: React.ReactNode }) {
  const tags = await listAllTags();
  return (
    <div className="container-page">
      <nav className="pt-6 md:pt-10">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <Link href="/blog" className="text-2xl font-bold tracking-tight">
            Inovers <span className="text-primary">Journal</span>
          </Link>
          <Link
            href="/blog#subscribe"
            className="inline-flex h-9 items-center rounded-full border border-border px-4 text-sm font-medium hover:bg-muted"
          >
            Subscribe
          </Link>
        </div>
        <p className="mt-2 max-w-2xl text-sm text-muted-foreground">
          Long-form thinking on innovation, education, creative thinking, and
          the future we are actually building — read openly, comment as a member.
        </p>
        <div className="mt-4 flex flex-wrap gap-1.5">
          {tags.map((t) => (
            <TagPill key={t.slug} slug={t.slug} label={t.label} size="sm" />
          ))}
        </div>
      </nav>
      {children}
    </div>
  );
}
