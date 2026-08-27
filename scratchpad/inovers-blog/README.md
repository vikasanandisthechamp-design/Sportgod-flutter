# Inovers Journal — Drop-in Package

You are (or your session is) looking at this from `Sportgod-flutter`.
That's fine — this whole folder is *portable*. It was built here
because the standalone `inovers-web` repo was out of scope for the
session that wrote it. Below is exactly how to move it into
`inovers-web` and get the Journal live.

**Total time from empty repo state to `/blog` live: ~90 minutes.**

---

## What you're getting

A complete, opinionated blog platform built on top of the existing
Inovers Next.js + Supabase stack. Public reading, signed-in commenting,
threaded comments, reactions, reports, an editorial admin queue, an
RSS feed, a sitemap, JSON-LD, an OG-card-friendly post layout, three
launch-ready seed posts, and a daily Anthropic-powered research
bot that produces drafts (never auto-publishes).

## Read these first (in order, 15 min)

1. **`SPEC.md`** — the product decisions and their rationale. Read
   this if you're about to argue with any choice.
2. **`FILE-MAP.md`** — where every file goes.
3. **`daily-research/SPEC.md`** — how the cron works and what to check.
4. **`growth/PLAN.md`** — 90-day growth strategy so you know *why* the
   pieces are shaped this way.
5. **`growth/launch-checklist.md`** — the runbook for launch day.

## Then do this (75 min)

### 1. Move the files into `inovers-web`

From this directory:

```bash
# From the root of the inovers-web repo, with this package copied to /tmp/inovers-blog:

# Frontend
cp -r /tmp/inovers-blog/web/src/types/blog.ts        src/types/
cp -r /tmp/inovers-blog/web/src/lib/blog             src/lib/
cp -r /tmp/inovers-blog/web/src/components/blog      src/components/
cp -r /tmp/inovers-blog/web/src/app/blog             src/app/
cp    /tmp/inovers-blog/web/src/app/sitemap.ts       src/app/
mkdir -p src/app/auth
cp    /tmp/inovers-blog/web/src/app/auth/callback/route.ts   src/app/auth/callback/route.ts
cp    /tmp/inovers-blog/web/src/app/auth/login/page.tsx      src/app/auth/login/page.tsx
cp    /tmp/inovers-blog/web/src/app/auth/signup/page.tsx     src/app/auth/signup/page.tsx
mkdir -p src/app/api/comments src/app/api/reactions src/app/api/reports src/app/api/admin/publish src/app/api/cron/research src/app/api/rss
cp    /tmp/inovers-blog/web/src/app/api/comments/route.ts       src/app/api/comments/route.ts
cp    /tmp/inovers-blog/web/src/app/api/comments/[id]/route.ts  src/app/api/comments/[id]/route.ts
cp    /tmp/inovers-blog/web/src/app/api/reactions/route.ts      src/app/api/reactions/route.ts
cp    /tmp/inovers-blog/web/src/app/api/reports/route.ts        src/app/api/reports/route.ts
cp    /tmp/inovers-blog/web/src/app/api/admin/publish/route.ts  src/app/api/admin/publish/route.ts
cp    /tmp/inovers-blog/web/src/app/api/cron/research/route.ts  src/app/api/cron/research/route.ts
cp    /tmp/inovers-blog/web/src/app/api/rss/route.ts            src/app/api/rss/route.ts
```

**If any of the `/auth/*` files already exist in the current inovers-web
codebase (the current main has `feat: auth, idea wall, live feed`), KEEP the
existing ones** — the blog only needs `getCurrentUser()` to work. The
routes shipped here are a *fallback* in case none exist.

### 2. Append the CSS

Open `src/app/globals.css`. Paste the contents of
`/tmp/inovers-blog/web/src/app/blog/blog.css` at the end of the file.
This defines `.prose-inovers` (used to style post bodies).

Then delete `src/app/blog/blog.css` (it was only a carrier).

### 3. Add the dep

Open `package.json`. In `dependencies`, add:

```json
"@anthropic-ai/sdk": "^0.35.0"
```

Then:

```bash
pnpm install
```

### 4. Add the environment variables

Open `.env.local`. Add the block from `web/env.additions.example`:

```
SUPABASE_SERVICE_ROLE_KEY=eyJ...
ANTHROPIC_API_KEY=sk-ant-...
EDITOR_EMAIL=editorial@inovers.in
CRON_SECRET=<long random string>
NEXT_PUBLIC_SITE_URL=https://inovers.in
```

Fill in the real values. `SUPABASE_SERVICE_ROLE_KEY` is in Supabase →
Project Settings → API. `ANTHROPIC_API_KEY` from
console.anthropic.com. `CRON_SECRET` = generate with
`openssl rand -hex 32`.

Also add the SAME values to Vercel → Project → Settings → Environment
Variables (Production).

### 5. Add the Vercel cron

Create or merge `vercel.json` at the repo root with the `crons` block
from `daily-research/vercel-cron.json`:

```json
{
  "crons": [
    { "path": "/api/cron/research", "schedule": "0 6 * * *" }
  ]
}
```

### 6. Run the Supabase migrations

In Supabase → SQL Editor, paste and run in this order:

1. `supabase/001_blog_schema.sql`
2. `supabase/002_blog_rls.sql`
3. `supabase/003_seed_posts.sql`

Each is idempotent — safe to re-run.

### 7. Bootstrap the admin

- Deploy the site (or run `pnpm dev`).
- Go to `/auth/signup` and create your account with your real email.
- Verify the email.
- In Supabase → SQL Editor:

```sql
update public.profiles
set role='admin'
where id = (select id from auth.users where email='YOUR_EMAIL_HERE');
```

- Refresh `/blog/admin` — you should see the editorial queue (empty until the cron runs).

### 8. Update the site nav

In `src/components/site-header.tsx`, add a Journal link:

```tsx
<Link href="/blog" className="hover:text-primary transition-colors">
  Journal
</Link>
```

In `src/components/site-footer.tsx`, under the "Platform" column, add:

```tsx
<li><Link href="/blog" className="hover:text-foreground">Journal</Link></li>
<li><Link href="/comment-policy" className="hover:text-foreground">Comment Policy</Link></li>
```

Also create a simple `src/app/comment-policy/page.tsx` that renders
`growth/moderation-policy.md`. (One-line React MDX component or a
paste-into-JSX is fine.)

### 9. Smoke test

- `/blog` → shows 3 seed posts.
- `/blog/why-indian-schools-kill-creativity` → renders, comment form
  shows "Sign in to comment" for logged-out users.
- Log in → comment form shows a textarea.
- Post a comment → appears in the thread.
- Click a reaction → count updates.
- `/blog/tag/education` → shows the two education-tagged posts.
- `/blog/admin` → editorial queue loads (empty is fine).
- `/api/rss` → returns XML with the 3 posts.
- `/sitemap.xml` → returns XML with blog URLs.

### 10. Trigger the cron manually (optional but recommended)

Verify the research bot works before waiting for the first scheduled run:

```bash
curl -H "Authorization: Bearer $CRON_SECRET" https://inovers.in/api/cron/research
```

Expect `{"ok":true,"draft_id":"…","slug":"…"}`. Then open `/blog/admin`
and you'll see the new draft in the queue.

### 11. Launch

Follow `growth/launch-checklist.md`.

---

## What lives WHERE at runtime (mental model)

- **Reader path:** entirely public, cached. No JS on the critical path
  beyond the Next.js runtime.
- **Auth path:** Supabase Auth. Cookies set by `/auth/callback` (OAuth)
  or the client SDK (email+password).
- **Comment path:** client-side `fetch('/api/comments', ...)` → server
  validates → RLS enforces `author_id = auth.uid()`. Then
  `router.refresh()` re-fetches the thread.
- **Admin path:** server-rendered, dynamic, redirects to `/auth/login` if
  the user isn't an editor.
- **Cron path:** Vercel calls `/api/cron/research` with a bearer token.
  Endpoint uses `SUPABASE_SERVICE_ROLE_KEY` to insert as service role
  (bypasses RLS), stores the draft with `status='pending_review'`,
  and returns.

## What is deliberately missing from this package

Everything called out in **`SPEC.md` → "What this package does NOT
include (yet)"**. Read that section before adding "the editor asked
for X."

## When something goes wrong

- **`/blog` is 500:** check that `blog_posts_public` view exists
  (`\d public.blog_posts_public` in psql). If not, `001_blog_schema.sql`
  didn't finish — re-run.
- **Comment API returns 401:** user isn't signed in, or the Supabase
  cookie isn't being forwarded. Check `getSupabaseServerClient` returns
  non-null and the request has cookies.
- **`/blog/admin` redirects to `/blog` even though you signed in:** your
  role isn't editor/admin. Re-run the SQL bootstrap step above.
- **Cron returns 401:** `Authorization` header doesn't match
  `CRON_SECRET`. Vercel sends it automatically; if you're testing
  manually, use `-H "Authorization: Bearer $CRON_SECRET"`.
- **Model returns unparseable JSON:** the endpoint returns 502 with the
  first 400 chars of the raw output — check the payload, adjust the
  prompt, redeploy.

## The final word

The point of this package isn't the code. The code is straightforward.
The point is the *editorial discipline* it encodes: humans publish,
bots draft, comments require real accounts, we take positions but
don't rage-bait, and every quarter we cut whatever isn't landing.

If you follow that discipline, this platform will grow. If you paste
it live and start doing "engagement hacks," it won't.

Good luck. Ship the first post today.
