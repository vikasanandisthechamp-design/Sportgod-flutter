-- =====================================================================
-- Inovers — Row Level Security policies
-- Run AFTER schema.sql in the Supabase SQL Editor.
-- =====================================================================

-- 1. Enable RLS --------------------------------------------------------
alter table public.waitlist        enable row level security;
alter table public.profiles        enable row level security;
alter table public.ideas           enable row level security;
alter table public.idea_interests  enable row level security;
alter table public.pods            enable row level security;
alter table public.pod_members     enable row level security;

-- 2. Waitlist ---------------------------------------------------------
-- Anyone (even anon) can insert. No one can read from the client.
drop policy if exists "waitlist_insert_anon" on public.waitlist;
create policy "waitlist_insert_anon"
  on public.waitlist for insert
  to anon, authenticated
  with check (true);

-- 3. Profiles ---------------------------------------------------------
-- Anyone can read profiles (public directory). Users manage their own row.
drop policy if exists "profiles_read_all" on public.profiles;
create policy "profiles_read_all"
  on public.profiles for select
  to anon, authenticated
  using (true);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

-- 4. Ideas ------------------------------------------------------------
drop policy if exists "ideas_read_all" on public.ideas;
create policy "ideas_read_all"
  on public.ideas for select
  to anon, authenticated
  using (true);

drop policy if exists "ideas_insert_authed" on public.ideas;
create policy "ideas_insert_authed"
  on public.ideas for insert
  to authenticated
  with check (author_id = auth.uid());

drop policy if exists "ideas_update_own" on public.ideas;
create policy "ideas_update_own"
  on public.ideas for update
  to authenticated
  using (author_id = auth.uid())
  with check (author_id = auth.uid());

drop policy if exists "ideas_delete_own" on public.ideas;
create policy "ideas_delete_own"
  on public.ideas for delete
  to authenticated
  using (author_id = auth.uid());

-- 5. Idea interests ---------------------------------------------------
drop policy if exists "interests_read_all" on public.idea_interests;
create policy "interests_read_all"
  on public.idea_interests for select
  to anon, authenticated
  using (true);

drop policy if exists "interests_insert_own" on public.idea_interests;
create policy "interests_insert_own"
  on public.idea_interests for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "interests_delete_own" on public.idea_interests;
create policy "interests_delete_own"
  on public.idea_interests for delete
  to authenticated
  using (user_id = auth.uid());

-- 6. Pods + members ---------------------------------------------------
drop policy if exists "pods_read_all" on public.pods;
create policy "pods_read_all"
  on public.pods for select
  to anon, authenticated
  using (true);

drop policy if exists "pods_insert_lead" on public.pods;
create policy "pods_insert_lead"
  on public.pods for insert
  to authenticated
  with check (lead_id = auth.uid());

drop policy if exists "pods_update_lead" on public.pods;
create policy "pods_update_lead"
  on public.pods for update
  to authenticated
  using (lead_id = auth.uid())
  with check (lead_id = auth.uid());

drop policy if exists "pod_members_read_all" on public.pod_members;
create policy "pod_members_read_all"
  on public.pod_members for select
  to anon, authenticated
  using (true);

drop policy if exists "pod_members_insert_self" on public.pod_members;
create policy "pod_members_insert_self"
  on public.pod_members for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "pod_members_delete_self" on public.pod_members;
create policy "pod_members_delete_self"
  on public.pod_members for delete
  to authenticated
  using (user_id = auth.uid());
