-- =====================================================================
-- Inovers — MVP Schema (Supabase Free Tier)
-- Run this in Supabase SQL Editor: https://app.supabase.com/project/_/sql
-- Safe to run multiple times (uses IF NOT EXISTS + create-or-replace).
-- =====================================================================

-- 0. Extensions --------------------------------------------------------
create extension if not exists "pgcrypto";

-- 1. Waitlist (public signup, works before auth is wired) --------------
create table if not exists public.waitlist (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  name        text not null,
  email       text not null unique,
  city        text not null,
  skills      text not null,
  why         text,
  source      text
);

-- 2. Profiles (mirror of auth.users) -----------------------------------
create table if not exists public.profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  created_at      timestamptz not null default now(),
  name            text not null,
  city            text,
  headline        text,
  skills          text[] default '{}',
  avatar_url      text,
  innovator_score integer not null default 0
);

-- 3. Ideas -------------------------------------------------------------
do $$ begin
  create type idea_stage as enum ('spark','validate','pod_form','blueprint','execute','impact');
exception when duplicate_object then null; end $$;

create table if not exists public.ideas (
  id                uuid primary key default gen_random_uuid(),
  created_at        timestamptz not null default now(),
  author_id         uuid not null references public.profiles(id) on delete cascade,
  title             text not null,
  problem           text not null,
  proposal          text not null,
  tags              text[] default '{}',
  skills_needed     text[] default '{}',
  stage             idea_stage not null default 'spark',
  upvotes           integer not null default 0,
  interested_count  integer not null default 0
);
create index if not exists ideas_created_at_idx on public.ideas (created_at desc);
create index if not exists ideas_author_idx on public.ideas (author_id);

-- 4. Idea interests (the "I'm interested" button) ----------------------
create table if not exists public.idea_interests (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  idea_id     uuid not null references public.ideas(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  role        text,
  unique (idea_id, user_id)
);

-- 5. Pods --------------------------------------------------------------
do $$ begin
  create type pod_status as enum ('forming','active','stalled','shipped','archived');
exception when duplicate_object then null; end $$;

create table if not exists public.pods (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  idea_id     uuid not null references public.ideas(id) on delete cascade,
  lead_id     uuid not null references public.profiles(id),
  name        text not null,
  status      pod_status not null default 'forming',
  summary     text
);

create table if not exists public.pod_members (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  pod_id      uuid not null references public.pods(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  role        text not null,
  unique (pod_id, user_id)
);

-- 6. Keep interested_count fresh --------------------------------------
create or replace function public.bump_interest_count()
returns trigger language plpgsql as $$
begin
  if (tg_op = 'INSERT') then
    update public.ideas set interested_count = interested_count + 1 where id = new.idea_id;
  elsif (tg_op = 'DELETE') then
    update public.ideas set interested_count = greatest(interested_count - 1, 0) where id = old.idea_id;
  end if;
  return null;
end $$;

drop trigger if exists idea_interest_count_trg on public.idea_interests;
create trigger idea_interest_count_trg
after insert or delete on public.idea_interests
for each row execute function public.bump_interest_count();

-- 7. Auto-create profile when a user signs up -------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();
