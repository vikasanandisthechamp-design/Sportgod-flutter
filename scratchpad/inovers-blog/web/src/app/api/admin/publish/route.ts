import { NextResponse } from 'next/server';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { getCurrentUser, isEditor } from '@/lib/blog/auth';
import { slugify } from '@/lib/blog/slug';
import { estimateReadingTime } from '@/lib/blog/mdx';

export async function POST(req: Request) {
  const supabase = await getSupabaseServerClient();
  if (!supabase) return NextResponse.json({ error: 'db_unavailable' }, { status: 503 });

  const me = await getCurrentUser();
  if (!me) return NextResponse.redirect(new URL('/auth/login?next=/blog/admin', req.url));
  if (!isEditor(me)) return NextResponse.redirect(new URL('/blog', req.url));

  const form = await req.formData();
  const id = String(form.get('id') ?? '');
  const action = String(form.get('action') ?? '');
  if (!id || !action) return NextResponse.json({ error: 'bad_request' }, { status: 400 });

  const { data: post } = await supabase
    .from('blog_posts')
    .select('id, slug, title, body_mdx, reading_time, status')
    .eq('id', id)
    .maybeSingle();
  if (!post) return NextResponse.json({ error: 'not_found' }, { status: 404 });

  const updates: Record<string, unknown> = { editor_id: me.id };

  if (action === 'publish') {
    updates.status = 'published';
    updates.publish_at = new Date().toISOString();
    if (!post.slug) updates.slug = slugify(post.title || `post-${Date.now()}`);
    if (!post.reading_time) updates.reading_time = estimateReadingTime(post.body_mdx || '');
  } else if (action === 'pending_review') {
    updates.status = 'pending_review';
  } else if (action === 'archive') {
    updates.status = 'archived';
  } else {
    return NextResponse.json({ error: 'unknown_action' }, { status: 400 });
  }

  const { error } = await supabase.from('blog_posts').update(updates).eq('id', id);
  if (error) return NextResponse.json({ error: 'update_failed', message: error.message }, { status: 500 });

  return NextResponse.redirect(new URL('/blog/admin', req.url), { status: 303 });
}
