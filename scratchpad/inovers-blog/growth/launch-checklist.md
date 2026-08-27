# Launch-Day Checklist

Go through this in order the day you flip the blog live. Nothing here
is optional.

## T-24 hours

- [ ] Apply migrations in order: `001_blog_schema.sql`, `002_blog_rls.sql`, `003_seed_posts.sql`.
- [ ] Verify RLS by hitting `blog_posts_public` from the anon SQL runner — should show 3 rows.
- [ ] Set `SUPABASE_SERVICE_ROLE_KEY`, `ANTHROPIC_API_KEY`, `CRON_SECRET`, `NEXT_PUBLIC_SITE_URL` in Vercel project → Production env.
- [ ] Set the same values in `.env.local` for local checks.
- [ ] Add `@anthropic-ai/sdk` to `package.json` dependencies. `pnpm install`.
- [ ] Append `blog.css` rules into `src/app/globals.css`.
- [ ] Merge `vercel-cron.json` into (or as) `vercel.json` at repo root.
- [ ] Sanity-run `pnpm dev` → hit `/blog`, `/blog/why-indian-schools-kill-creativity`, `/blog/tag/children`, `/blog/admin` (must redirect to /auth/login).

## T-2 hours

- [ ] Create your admin profile: sign up on `/auth/signup` with your real
      email, then in Supabase SQL Editor run:
      `update public.profiles set role='admin' where id=(select id from auth.users where email='YOU@inovers.in');`
- [ ] Verify `/blog/admin` shows an empty (or your first draft) queue.
- [ ] Trigger the cron manually to verify it works:
      `curl -H "Authorization: Bearer $CRON_SECRET" https://inovers.in/api/cron/research`
      Expect `{ok:true, draft_id:"…"}`. Open the draft in /blog/admin.
- [ ] Preview OG cards with https://opengraph.dev/ for the three seed posts.
- [ ] Confirm `sitemap.xml` and `/api/rss` return the seed posts.

## Launch (T-0)

- [ ] Post the first WhatsApp announcement to the 3 pre-agreed groups.
      Message copy is in `growth/launch-message.md` (write this before launch — one line + one link per group).
- [ ] Post the launch thread to X and LinkedIn from the founder's personal
      account, not the Inovers account (personal accounts get more organic
      reach on launch day).
- [ ] Reply-guy mode: every comment on any surface gets a reply within
      2 hours today. Set a phone alarm.

## T+24 hours

- [ ] Read every comment. Reply to every top-level.
- [ ] Look at Vercel Analytics → top 3 pages, referrers. Note surprises.
- [ ] Adjust tomorrow's post based on what today's readers actually cared
      about (this is why we don't over-schedule).

## T+7 days

- [ ] Reader digest: write a 300-word note to the mailing list summarizing
      the sharpest comments of the week + linking to the top post.
- [ ] Post-mortem with the team: what worked, what didn't, what to change.
- [ ] Commission the first guest voice for week 3.
