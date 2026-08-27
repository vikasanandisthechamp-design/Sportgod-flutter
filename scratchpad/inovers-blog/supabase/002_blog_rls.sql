-- =====================================================================
-- Inovers Blog — Row Level Security
-- Run AFTER 001_blog_schema.sql.
-- =====================================================================

alter table public.blog_posts       enable row level security;
alter table public.blog_post_tags   enable row level security;
alter table public.blog_comments    enable row level security;
alter table public.blog_reactions   enable row level security;
alter table public.blog_reports     enable row level security;
alter table public.blog_post_views  enable row level security;
alter table public.blog_tags        enable row level security;

-- Helper: is current user an editor or admin?
create or replace function public.is_blog_editor()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(
    (select role in ('editor','admin') from public.profiles where id = auth.uid()),
    false
  );
$$;

create or replace function public.is_blog_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(
    (select role = 'admin' from public.profiles where id = auth.uid()),
    false
  );
$$;

-- ---- blog_tags ---------------------------------------------------------
drop policy if exists "tags_read_all" on public.blog_tags;
create policy "tags_read_all"
  on public.blog_tags for select to anon, authenticated using (true);

drop policy if exists "tags_write_editor" on public.blog_tags;
create policy "tags_write_editor"
  on public.blog_tags for all to authenticated
  using (public.is_blog_editor()) with check (public.is_blog_editor());

-- ---- blog_posts --------------------------------------------------------
-- Anonymous users can read published posts only.
drop policy if exists "posts_read_public" on public.blog_posts;
create policy "posts_read_public"
  on public.blog_posts for select to anon, authenticated
  using (
    status = 'published' and publish_at <= now()
    or auth.uid() = author_id
    or public.is_blog_editor()
  );

-- Authors can insert their own drafts.
drop policy if exists "posts_insert_authed" on public.blog_posts;
create policy "posts_insert_authed"
  on public.blog_posts for insert to authenticated
  with check (
    (author_id is null and public.is_blog_editor())        -- bot drafts inserted by editor role
    or (author_id = auth.uid())                            -- normal author path
  );

-- Authors can update their own drafts; editors can update anything.
drop policy if exists "posts_update_own_or_editor" on public.blog_posts;
create policy "posts_update_own_or_editor"
  on public.blog_posts for update to authenticated
  using (
    (author_id = auth.uid() and status in ('draft','pending_review'))
    or public.is_blog_editor()
  )
  with check (
    (author_id = auth.uid() and status in ('draft','pending_review'))
    or public.is_blog_editor()
  );

-- Only admins can delete.
drop policy if exists "posts_delete_admin" on public.blog_posts;
create policy "posts_delete_admin"
  on public.blog_posts for delete to authenticated
  using (public.is_blog_admin());

-- ---- blog_post_tags ----------------------------------------------------
drop policy if exists "post_tags_read_all" on public.blog_post_tags;
create policy "post_tags_read_all"
  on public.blog_post_tags for select to anon, authenticated using (true);

drop policy if exists "post_tags_write_owner_or_editor" on public.blog_post_tags;
create policy "post_tags_write_owner_or_editor"
  on public.blog_post_tags for all to authenticated
  using (
    exists (
      select 1 from public.blog_posts p
      where p.id = post_id and (p.author_id = auth.uid() or public.is_blog_editor())
    )
  )
  with check (
    exists (
      select 1 from public.blog_posts p
      where p.id = post_id and (p.author_id = auth.uid() or public.is_blog_editor())
    )
  );

-- ---- blog_comments -----------------------------------------------------
-- Public read of non-deleted, non-hidden comments on published posts.
drop policy if exists "comments_read_public" on public.blog_comments;
create policy "comments_read_public"
  on public.blog_comments for select to anon, authenticated
  using (
    (is_deleted = false and is_hidden = false)
    or author_id = auth.uid()
    or public.is_blog_editor()
  );

-- Only signed-in users can insert. Author locked to auth.uid().
-- Comments are only permitted on published posts.
drop policy if exists "comments_insert_authed" on public.blog_comments;
create policy "comments_insert_authed"
  on public.blog_comments for insert to authenticated
  with check (
    author_id = auth.uid()
    and exists (
      select 1 from public.blog_posts p
      where p.id = post_id and p.status = 'published' and p.publish_at <= now()
    )
  );

-- Author can edit their own comment (edited_at set by the API layer).
drop policy if exists "comments_update_own" on public.blog_comments;
create policy "comments_update_own"
  on public.blog_comments for update to authenticated
  using (author_id = auth.uid() or public.is_blog_editor())
  with check (author_id = auth.uid() or public.is_blog_editor());

-- Author can hard-delete (usually the API soft-deletes instead).
drop policy if exists "comments_delete_own_or_editor" on public.blog_comments;
create policy "comments_delete_own_or_editor"
  on public.blog_comments for delete to authenticated
  using (author_id = auth.uid() or public.is_blog_editor());

-- ---- blog_reactions ----------------------------------------------------
drop policy if exists "reactions_read_all" on public.blog_reactions;
create policy "reactions_read_all"
  on public.blog_reactions for select to anon, authenticated using (true);

drop policy if exists "reactions_insert_own" on public.blog_reactions;
create policy "reactions_insert_own"
  on public.blog_reactions for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "reactions_delete_own" on public.blog_reactions;
create policy "reactions_delete_own"
  on public.blog_reactions for delete to authenticated
  using (user_id = auth.uid());

-- ---- blog_reports ------------------------------------------------------
drop policy if exists "reports_insert_authed" on public.blog_reports;
create policy "reports_insert_authed"
  on public.blog_reports for insert to authenticated
  with check (reporter_id = auth.uid());

drop policy if exists "reports_read_editor" on public.blog_reports;
create policy "reports_read_editor"
  on public.blog_reports for select to authenticated
  using (reporter_id = auth.uid() or public.is_blog_editor());

drop policy if exists "reports_update_editor" on public.blog_reports;
create policy "reports_update_editor"
  on public.blog_reports for update to authenticated
  using (public.is_blog_editor()) with check (public.is_blog_editor());

-- ---- blog_post_views ---------------------------------------------------
-- Anyone can insert a view (including anon). No one reads directly — use rollups.
drop policy if exists "views_insert_any" on public.blog_post_views;
create policy "views_insert_any"
  on public.blog_post_views for insert to anon, authenticated with check (true);

drop policy if exists "views_read_editor" on public.blog_post_views;
create policy "views_read_editor"
  on public.blog_post_views for select to authenticated using (public.is_blog_editor());

-- =====================================================================
-- End of 002_blog_rls.sql
-- =====================================================================
