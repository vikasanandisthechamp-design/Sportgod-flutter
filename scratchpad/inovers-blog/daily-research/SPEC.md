# Daily Research + Draft Workflow

## What this is

An automated pipeline that produces ONE well-researched blog draft every day
at 06:00 UTC (11:30 IST), lands it in the editorial queue, and emails the
editor. Nothing goes live until a human clicks Publish.

## Why not full auto-publish

1. **Google penalizes low-quality auto-published AI content.** Rankings tank
   fast. Killing SEO for the sake of throughput is a bad trade.
2. **Hallucinations.** Even a great model gets 5–10% of factual claims wrong.
   Published under Inovers's byline, one bad hallucination = weeks of
   trust-rebuilding.
3. **Legal.** Defamation, misattribution, plagiarism — the platform is on
   the hook the moment it publishes.
4. **Voice.** A brand voice needs one hand at the tiller.

The bot's job is to save the editor 90% of the drafting time. The editor
still owns publish.

## Pipeline

```
                             ┌──────────────────────────┐
Vercel Cron (daily 06:00 UTC)│                          │
      │                      │                          │
      ▼                      │                          │
GET /api/cron/research ─────▶│  Anthropic API (Sonnet)  │
      │  (bearer CRON_SECRET)│  drafts one article      │
      │                      │  with citations          │
      ▼                      └──────────────────────────┘
Draft inserted as
status='pending_review',
research_json stored,
tagged automatically
      │
      ▼
Editor gets email + sees it in /blog/admin
      │
      ▼
Editor reviews, edits, clicks Publish → status='published'
```

## Vercel Cron config

Add to `vercel.json` in the project root:

```json
{
  "crons": [
    {
      "path": "/api/cron/research",
      "schedule": "0 6 * * *"
    }
  ]
}
```

Vercel automatically sends `Authorization: Bearer $CRON_SECRET`. Set
`CRON_SECRET` in Vercel project settings AND in `.env.local`.

## Editorial checklist (put this on a Post-it)

Before pressing Publish, the editor confirms:

1. **Every stat, quote, and claim has a source that says exactly that.**
   Open each link. If any source doesn't back the claim, delete the claim
   or rewrite it.
2. **No proper name (person, org, book title) is misspelled or fabricated.**
3. **The dek is a promise the piece keeps.** Rewrite dek if the article
   drifted during editing.
4. **Voice matches Inovers's editorial line** (see `growth/editorial-voice.md`).
5. **Tone is provocative but civil.** No cheap shots, no rage bait.
6. **Cover image** (if used) is either original, licensed, or Unsplash CC0.

## Rotation across topics

The prompt intentionally lets the model choose a topic from the universe.
To ensure balance across time, wire a topic-history table later — for now,
if the model repeats a topic within 4 days, the editor rewrites the
brief in the queue.

## Manual override

Editors can also click "New draft" in the admin (once we build it) to seed
a specific topic. Or `psql` an insert directly. The path is deliberately
low-tech so the human always wins.

## Failure modes and what to do

| Failure                          | What the endpoint does           | What the editor does |
|----------------------------------|----------------------------------|----------------------|
| Anthropic API down               | Returns 502, no draft inserted   | Skip that day; write manually |
| Model returns unparseable JSON   | Returns 502 with `raw` preview   | Check API status; retry manually |
| DB insert fails (RLS/schema)     | Returns 500                      | Read logs; usually a schema mismatch |
| Duplicate slug                   | Auto-suffixed                    | Nothing |
| Confidence = "low"               | Draft still inserted             | Editor is extra careful before publish |

## Growth: from 1 post/day to 3

After 30 days of clean output, wire two more crons at different hours
targeting different tag clusters (education vs. tech innovation vs. AI).
Total volume ≠ audience. Quality does. Do not increase frequency until
average time-on-page > 3 minutes.
