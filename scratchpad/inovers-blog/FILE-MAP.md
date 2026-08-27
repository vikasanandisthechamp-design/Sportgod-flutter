# File Map — where every file in this package goes in `inovers-web`

Paths on the LEFT are inside this package. Paths on the RIGHT are
where they land in the `inovers-web` repo. Most files are new; a few
have integration notes.

## Supabase migrations (run in Supabase SQL Editor, in order)

| Source                            | Destination                          | Notes |
|-----------------------------------|--------------------------------------|-------|
| `supabase/001_blog_schema.sql`    | Run as-is                            | Extends existing `profiles` |
| `supabase/002_blog_rls.sql`       | Run after 001                        | Enables RLS on all blog tables |
| `supabase/003_seed_posts.sql`     | Run after 002                        | Idempotent — safe re-run |

## Frontend (Next.js)

| Source                                                                          | Destination                                                     |
|---------------------------------------------------------------------------------|-----------------------------------------------------------------|
| `web/src/types/blog.ts`                                                         | `src/types/blog.ts` (new)                                       |
| `web/src/lib/blog/auth.ts`                                                      | `src/lib/blog/auth.ts` (new)                                    |
| `web/src/lib/blog/queries.ts`                                                   | `src/lib/blog/queries.ts` (new)                                 |
| `web/src/lib/blog/mdx.ts`                                                       | `src/lib/blog/mdx.ts` (new)                                     |
| `web/src/lib/blog/slug.ts`                                                      | `src/lib/blog/slug.ts` (new)                                    |
| `web/src/lib/blog/analytics.ts`                                                 | `src/lib/blog/analytics.ts` (new)                               |
| `web/src/lib/blog/moderation.ts`                                                | `src/lib/blog/moderation.ts` (new)                              |
| `web/src/components/blog/*.tsx`                                                 | `src/components/blog/*.tsx` (new dir)                           |
| `web/src/app/blog/layout.tsx`                                                   | `src/app/blog/layout.tsx` (new)                                 |
| `web/src/app/blog/page.tsx`                                                     | `src/app/blog/page.tsx` (new)                                   |
| `web/src/app/blog/[slug]/page.tsx`                                              | `src/app/blog/[slug]/page.tsx` (new)                            |
| `web/src/app/blog/tag/[tag]/page.tsx`                                           | `src/app/blog/tag/[tag]/page.tsx` (new)                         |
| `web/src/app/blog/admin/page.tsx`                                               | `src/app/blog/admin/page.tsx` (new)                             |
| `web/src/app/blog/admin/[id]/page.tsx`                                          | `src/app/blog/admin/[id]/page.tsx` (new)                        |
| `web/src/app/blog/blog.css`                                                     | APPEND its rules into `src/app/globals.css`                     |
| `web/src/app/api/comments/route.ts`                                             | `src/app/api/comments/route.ts` (new)                           |
| `web/src/app/api/comments/[id]/route.ts`                                        | `src/app/api/comments/[id]/route.ts` (new)                      |
| `web/src/app/api/reactions/route.ts`                                            | `src/app/api/reactions/route.ts` (new)                          |
| `web/src/app/api/reports/route.ts`                                              | `src/app/api/reports/route.ts` (new)                            |
| `web/src/app/api/admin/publish/route.ts`                                        | `src/app/api/admin/publish/route.ts` (new)                      |
| `web/src/app/api/cron/research/route.ts`                                        | `src/app/api/cron/research/route.ts` (new)                      |
| `web/src/app/api/rss/route.ts`                                                  | `src/app/api/rss/route.ts` (new)                                |
| `web/src/app/sitemap.ts`                                                        | `src/app/sitemap.ts` (new — if you already have one, merge)     |
| `web/src/app/auth/login/page.tsx`                                               | `src/app/auth/login/page.tsx` (create if missing)               |
| `web/src/app/auth/signup/page.tsx`                                              | `src/app/auth/signup/page.tsx` (create if missing)              |
| `web/src/app/auth/callback/route.ts`                                            | `src/app/auth/callback/route.ts` (create if missing)            |

If the current `inovers-web` already has `/auth/login`, `/auth/signup`,
or `/auth/callback`, KEEP them — they'll be shaped to the rest of the
site. Only the blog wiring needs the flow to exist.

## Content (published via 003_seed_posts.sql)

| Source                                                          | Purpose |
|-----------------------------------------------------------------|---------|
| `web/content/seed/why-indian-schools-kill-creativity.mdx`       | Reference copy of seed post 1 |
| `web/content/seed/ai-is-not-the-enemy.mdx`                      | Reference copy of seed post 2 |
| `web/content/seed/the-12-year-old-rd-project.mdx`               | Reference copy of seed post 3 |

The MDX files are for humans (and future rewrites). The DB rows are
what actually render.

## Environment / config

| Source                        | Destination                                                        |
|-------------------------------|--------------------------------------------------------------------|
| `web/env.additions.example`   | Append to `.env.local.example`; set real values in `.env.local`    |
| `web/package.additions.json`  | Merge `add_dependencies` into `package.json`, then `pnpm install`  |
| `daily-research/vercel-cron.json` | Merge `crons` block into `vercel.json` at repo root            |

## Docs (no runtime effect — keep for team)

| Source                                         | Notes |
|------------------------------------------------|-------|
| `SPEC.md`                                      | Product decisions + rationale |
| `FILE-MAP.md`                                  | This file |
| `README.md`                                    | Handoff for whoever runs the drop-in |
| `daily-research/SPEC.md`                       | How the cron works, what to check |
| `daily-research/prompt-template.md`            | The canonical prompt |
| `growth/PLAN.md`                               | 90-day growth plan |
| `growth/keyword-targets.csv`                   | SEO targets |
| `growth/editorial-calendar-90d.md`             | Cadence + rotation |
| `growth/moderation-policy.md`                  | Public comment policy — publish at `/comment-policy` |
| `growth/launch-checklist.md`                   | Day-0 runbook |

## Site nav additions (edit these two existing files)

- `src/components/site-header.tsx` — add `<Link href="/blog">Journal</Link>` between Ideas and Manifesto.
- `src/components/site-footer.tsx` — under "Platform", add a link to `/blog` and one to `/comment-policy`.

Those two edits are the only *modifications* to files that already
exist. Everything else is additive.
