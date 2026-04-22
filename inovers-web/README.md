# Inovers

**Bharat's community-powered innovation ecosystem.** Ideas. Collaboration. Execution.

This is the landing site + MVP foundation. Built on a strict free-tier stack:

| Layer | Service | Tier |
|---|---|---|
| App hosting | Vercel | Hobby (free) |
| Database + Auth + Storage | Supabase | Free (500 MB, 50K MAU) |
| Code hosting | GitHub | Free |
| Domain (optional) | Cloudflare + Hostinger | Existing |

---

## Stack

- **Next.js 16** (App Router) with TypeScript
- **Tailwind CSS v4**
- **Supabase** (`@supabase/ssr`, `@supabase/supabase-js`)
- **Zod** for form validation
- **lucide-react** for icons
- pnpm for package management

---

## Local setup

```bash
pnpm install
cp .env.local.example .env.local
# Fill in NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY
pnpm dev
```

Open [http://localhost:3000](http://localhost:3000).

---

## One-time setup checklist

### 1. Create the GitHub repo (new account if yours is full)

1. Sign in / create a new GitHub account.
2. Create an **empty** repo named `inovers-web` (Private or Public).
3. Back in this folder:

   ```bash
   git init
   git add .
   git commit -m "chore: bootstrap inovers-web"
   git branch -M main
   git remote add origin https://github.com/<you>/inovers-web.git
   git push -u origin main
   ```

### 2. Create the Supabase project (new account if needed)

1. Go to https://supabase.com and sign in with the fresh email.
2. **New project** → name: `inovers`, region: **Mumbai (ap-south-1)**, strong DB password (save it).
3. Wait ~2 min for provisioning.
4. **SQL Editor** → paste `supabase/schema.sql` → **Run**.
5. **SQL Editor** → paste `supabase/policies.sql` → **Run**.
6. **Settings → API** → copy:
   - `Project URL` → `NEXT_PUBLIC_SUPABASE_URL`
   - `anon public` key → `NEXT_PUBLIC_SUPABASE_ANON_KEY`
7. Paste both into `.env.local`, run `pnpm dev`, submit the waitlist form.
   - **Verify**: Supabase → Table editor → `waitlist` row appears.

### 3. Deploy to Vercel

1. Go to https://vercel.com → **Add New → Project**.
2. Import the `inovers-web` GitHub repo.
3. Add env vars: `NEXT_PUBLIC_SUPABASE_URL` + `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
4. Deploy. Vercel gives you `inovers-web-*.vercel.app`.
5. (Optional) **Settings → Domains** → add `inovers.in` when the domain is ready.

---

## Project structure

```
inovers-web/
├── src/
│   ├── app/                  Next.js App Router
│   │   ├── page.tsx          Landing (hero, how-it-works, govt, CTA)
│   │   ├── manifesto/        Manifesto page
│   │   ├── waitlist/         Founding Innovator waitlist
│   │   ├── ideas/            Idea wall (placeholder until beta)
│   │   ├── layout.tsx        Root layout + header + footer
│   │   └── globals.css       Design tokens
│   ├── components/
│   │   ├── site-header.tsx
│   │   ├── site-footer.tsx
│   │   └── waitlist-form.tsx Client component, writes to Supabase
│   ├── lib/
│   │   ├── utils.ts          cn() helper
│   │   └── supabase/
│   │       ├── client.ts     Browser Supabase client
│   │       └── server.ts     Server Supabase client (RSC + route handlers)
│   └── types/database.ts     Hand-written DB types (regenerate later)
├── supabase/
│   ├── schema.sql            Run first
│   └── policies.sql          Run second
└── .env.local.example
```

---

## MVP roadmap (matches product plan)

- [x] Landing page + manifesto
- [x] Waitlist (writing to Supabase)
- [x] DB schema + RLS for ideas / Pods
- [ ] Auth (email OTP via Supabase)
- [ ] Idea Wall (post + feed)
- [ ] "I'm interested" button
- [ ] Pod formation flow
- [ ] Profile + Innovator Score
- [ ] Public Build Log

---

## Scripts

```bash
pnpm dev          # start dev server on :3000
pnpm build        # production build
pnpm start        # run production build
pnpm lint         # eslint
```

---

## Design principles

1. **Never look empty.** Seed ideas manually.
2. **Community first, features second.**
3. **Public by default.**
4. **Ship weekly.**
5. **You are the movement.**
