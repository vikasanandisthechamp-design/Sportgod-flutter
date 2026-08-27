import { getSupabaseServerClient } from '@/lib/supabase/server';
import type { BlogPost, BlogPostPublic, BlogTag, BlogComment } from '@/types/blog';

const PAGE_SIZE = 12;

export async function listPublishedPosts(opts: {
  page?: number;
  tag?: string;
  q?: string;
} = {}): Promise<{ posts: BlogPostPublic[]; page: number; hasMore: boolean }> {
  const supabase = await getSupabaseServerClient();
  if (!supabase) return { posts: [], page: 1, hasMore: false };

  const page = Math.max(1, opts.page ?? 1);
  const from = (page - 1) * PAGE_SIZE;
  const to = from + PAGE_SIZE; // fetch one extra to detect hasMore

  let query = supabase
    .from('blog_posts_public')
    .select('*')
    .order('publish_at', { ascending: false })
    .range(from, to);

  if (opts.tag) {
    query = query.contains('tags', [opts.tag]);
  }
  if (opts.q && opts.q.trim().length >= 2) {
    query = query.ilike('title', `%${opts.q.trim()}%`);
  }

  const { data, error } = await query;
  if (error || !data) return { posts: [], page, hasMore: false };

  const hasMore = data.length > PAGE_SIZE;
  return { posts: (data as BlogPostPublic[]).slice(0, PAGE_SIZE), page, hasMore };
}

export async function getPublishedPost(slug: string): Promise<BlogPost | null> {
  const supabase = await getSupabaseServerClient();
  if (!supabase) return null;

  const { data, error } = await supabase
    .from('blog_posts')
    .select('*')
    .eq('slug', slug)
    .eq('status', 'published')
    .lte('publish_at', new Date().toISOString())
    .maybeSingle();

  if (error) return null;
  return (data as BlogPost | null) ?? null;
}

export async function getPostTags(postId: string): Promise<BlogTag[]> {
  const supabase = await getSupabaseServerClient();
  if (!supabase) return [];
  const { data } = await supabase
    .from('blog_post_tags')
    .select('tag:blog_tags(*)')
    .eq('post_id', postId);
  return ((data ?? []).map((r: { tag: BlogTag }) => r.tag).filter(Boolean));
}

export async function listAllTags(): Promise<BlogTag[]> {
  const supabase = await getSupabaseServerClient();
  if (!supabase) return [];
  const { data } = await supabase
    .from('blog_tags')
    .select('*')
    .order('label');
  return (data as BlogTag[]) ?? [];
}

export async function listCommentsForPost(postId: string): Promise<BlogComment[]> {
  const supabase = await getSupabaseServerClient();
  if (!supabase) return [];

  const { data } = await supabase
    .from('blog_comments')
    .select(
      'id, post_id, author_id, parent_id, body, is_deleted, is_hidden, reaction_count, report_count, created_at, edited_at, author:profiles(id, name, avatar_url, role)'
    )
    .eq('post_id', postId)
    .order('created_at', { ascending: true });

  const flat = (data as BlogComment[] | null) ?? [];
  return threadComments(flat);
}

function threadComments(flat: BlogComment[]): BlogComment[] {
  const byId = new Map<string, BlogComment>();
  const roots: BlogComment[] = [];
  for (const c of flat) {
    byId.set(c.id, { ...c, replies: [] });
  }
  for (const c of byId.values()) {
    if (c.parent_id && byId.has(c.parent_id)) {
      byId.get(c.parent_id)!.replies!.push(c);
    } else {
      roots.push(c);
    }
  }
  return roots;
}

export async function listDraftsForReview(): Promise<BlogPost[]> {
  const supabase = await getSupabaseServerClient();
  if (!supabase) return [];
  const { data } = await supabase
    .from('blog_posts')
    .select('*')
    .in('status', ['pending_review', 'draft'])
    .order('updated_at', { ascending: false });
  return (data as BlogPost[]) ?? [];
}

export async function recordPostView(postId: string, visitorKey: string) {
  const supabase = await getSupabaseServerClient();
  if (!supabase) return;
  // Idempotent per (post, day, visitor)
  await supabase
    .from('blog_post_views')
    .insert({ post_id: postId, visitor_key: visitorKey })
    .select()
    .maybeSingle()
    .then(async () => {
      // Increment denorm counter only when the insert wasn't a dup.
      // Cheap approach: always bump; small over-count is tolerable for a public counter.
      await supabase.rpc('increment_post_view', { p_post_id: postId }).then(() => {}, () => {});
    })
    .catch(() => {});
}
