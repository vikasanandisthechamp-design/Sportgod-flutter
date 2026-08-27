# Inovers Journal — Product Spec (decisions + rationale)

Written for the next engineer or the next session that will drop this
package into `inovers-web`. Read this before touching any file — it
explains the *why* behind the shape.

## The one-line pitch

Long-form editorial site at `inovers.io/blog` — public to read, sign-in
required to comment — publishing one well-argued piece per day on
innovation, creative thinking, education, and the AI-shaped future.

## Product decisions (and the alternatives we rejected)

### Decision 1 — Medium-like, not Quora-like

**Shape:** posts + threaded comments, one editor-controlled voice per
post.

**Rejected:** open Q&A (Quora shape), where any signed-in user can
post a question and anyone can answer.

**Why:** Q&A is a great long-term surface but a slow launch — you need
critical mass of contributors before it becomes interesting to read.
Medium-shaped launches on day 1 with three good essays and grows from
there. Q&A comes back as v2 once we have 10k engaged readers.

### Decision 2 — Provocative, not controversial

**Shape:** strong, well-argued, sometimes counter-intuitive takes.
Every claim sourced. Always civil.

**Rejected:** rage-bait / clickbait / take-down culture — even though
that traffic grows faster short-term.

**Why:** Inovers is also an accelerator writing large cheques and a
school platform selling to parents. Rage-bait audiences are exactly
the wrong audiences for both those products. The Journal is a *lead
engine* for the accelerator and Edu OS, not a standalone media brand.
Voice matters.

### Decision 3 — Daily draft, human publish

**Shape:** a cron endpoint calls Anthropic every morning to produce
one draft. Draft lands in `pending_review`. Editor reviews, clicks
publish. See `daily-research/SPEC.md`.

**Rejected:** full auto-publish.

**Why:** Google penalizes low-quality AI content (Helpful Content
Update, Sept 2023 onwards). One bad hallucinated stat kills months of
trust. Legal exposure. The bot's job is to save 90% of drafting time,
not replace the editor.

### Decision 4 — Supabase Auth, email + Google

**Shape:** existing Supabase Auth (already in the April scaffold).
Signup requires email verification. OAuth via Google as one-click.
Password login for the email-first crowd.

**Rejected:** anonymous comments, third-party embed like Disqus,
custom JWT.

**Why:** anonymous = spam, brand dilution, no way to build a
community with real names. Disqus is trackers + slow load + ugly UX.
Custom JWT is undifferentiated work.

### Decision 5 — Simple threaded comments (one reply depth)

**Shape:** top-level comment can have replies. Replies cannot have
replies. Prevents Reddit-style deep chains that no one reads.

**Rejected:** unlimited depth, or flat-only.

**Why:** unlimited depth = threads become unreadable and encourage
dogpiling. Flat-only kills conversational reply. One-deep is the
Substack default and it works.

### Decision 6 — Reactions bar, not just upvote

**Shape:** four kinds — Upvote, Insightful, Curious, Disagree. One per
user per target. Toggle to change.

**Rejected:** binary upvote only.

**Why:** "Disagree" as a first-class reaction is the trick that keeps
disagreement civil — people vent by clicking Disagree instead of
writing a nasty comment.

### Decision 7 — Role-based editorial (reader / author / editor / admin)

**Shape:** `profiles.role` enum. RLS + helper `is_blog_editor()`
enforces publish/reject. Bootstrap: run one SQL update to make the
founder an admin.

**Rejected:** flat "is_admin" boolean, or admin table separate from
profiles.

**Why:** extends existing `profiles` table without new joins. Enum is
easy to grow (`moderator`, `contributor` later).

### Decision 8 — Server-side pagination, `revalidate: 300`

**Shape:** `listPublishedPosts` returns 12 per page. Pages use ISR
with 5-min revalidation. Post detail page revalidates every 60s.

**Rejected:** infinite scroll, client-side query, force-dynamic.

**Why:** SEO. Pagination is crawlable. ISR keeps latency < 100ms
warm. New drafts don't need instant visibility.

### Decision 9 — Zero external client-side deps for the reader

**Shape:** the reader path (`/blog`, `/blog/[slug]`) loads only the
site fonts + a tiny bit of client JS for the reaction bar. Comment
form loads on interaction.

**Rejected:** analytics scripts, tracker embeds, "sign in" popups on
scroll, live chat widgets.

**Why:** speed. Speed is a feature. Blog readers close a page that
takes >3s to become interactive. Ads / trackers / widgets are what
kill blogs.

### Decision 10 — Progressive: launch with 3, grow to 100

**Shape:** 3 seed posts hand-written now. 1/day via the research bot
+ editor thereafter. Deep dives once/month.

**Rejected:** big launch (30 posts on day 1) OR trickle launch (1 post,
"see if anyone reads").

**Why:** 3 posts is enough for the reader to feel "there's a body of
work here" without having to read 30. And the editor stays sane.

## Data model (see `supabase/001_blog_schema.sql`)

```
profiles ─┬─▶ blog_posts   ◀── blog_post_tags ─▶ blog_tags
          │        │
          │        ├─▶ blog_comments (self-parenting, 1 deep)
          │        │        │
          │        │        └─▶ blog_reactions (fk: comment_id)
          │        └─▶ blog_reactions (fk: post_id)
          │
          └─▶ blog_reports (fk: post_id OR comment_id, XOR)
```

Triggers keep `comment_count`, `reaction_count`, `report_count`
denormalized so reads are one row.

## Route map

| Route                          | Purpose                     | Auth        | Cache        |
|--------------------------------|-----------------------------|-------------|--------------|
| `/blog`                        | List (paginated, filterable)| public read | ISR 300s     |
| `/blog/[slug]`                 | Post detail + comments      | public read | ISR 60s      |
| `/blog/tag/[tag]`              | Tag filter                  | public read | ISR 300s     |
| `/blog/admin`                  | Editorial queue             | editor+     | dynamic      |
| `/blog/admin/[id]`             | Draft preview + publish     | editor+     | dynamic      |
| `/api/comments`                | POST comment                | signed-in   | -            |
| `/api/comments/[id]`           | PATCH / DELETE              | own or editor| -           |
| `/api/reactions`               | POST reaction (toggle)      | signed-in   | -            |
| `/api/reports`                 | POST flag                   | signed-in   | -            |
| `/api/admin/publish`           | POST publish/archive        | editor+     | -            |
| `/api/cron/research`           | Daily draft generator       | cron secret | -            |
| `/api/rss`                     | RSS feed                    | public read | 600s         |
| `/sitemap.xml`                 | Sitemap                     | public read | 600s         |
| `/auth/login`                  | Email + Google              | public      | dynamic      |
| `/auth/signup`                 | Email + name                | public      | dynamic      |
| `/auth/callback`               | OAuth exchange              | -           | dynamic      |

## What this package deliberately does NOT include (yet)

- **Rich text WYSIWYG editor.** Editors write MDX directly for now.
  Add `@uiw/react-md-editor` in v2 if the editor asks.
- **Image upload.** Cover images are URL-strings. Wire Supabase Storage
  in v2.
- **Newsletter service integration.** `/api/newsletter` is a placeholder
  form; hook it to Resend / Buttondown / MailerSend when picked.
- **Search.** For now, `?q=` does a title `ilike` filter. Move to
  Supabase FTS or Meilisearch when the archive > 100 posts.
- **Live comment updates.** No websockets. `router.refresh()` after post.
  Add Supabase Realtime later if desired.
- **Newsletter double opt-in / unsubscribe UI.** Add with the newsletter
  service.
- **RTL / multi-language.** English only for launch.
- **Comment editing UI.** The API supports it; the client widget is v2.

Any of these can ship in a follow-up sprint without touching the
schema or the core routes.
