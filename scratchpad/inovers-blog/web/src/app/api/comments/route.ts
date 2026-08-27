import { NextResponse } from 'next/server';
import { z } from 'zod';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { moderateComment, moderationMessage } from '@/lib/blog/moderation';

const schema = z.object({
  post_id: z.string().uuid(),
  parent_id: z.string().uuid().nullable().optional(),
  body: z.string().min(2).max(4000),
});

export async function POST(req: Request) {
  const supabase = await getSupabaseServerClient();
  if (!supabase) return NextResponse.json({ error: 'db_unavailable' }, { status: 503 });

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'signin_required' }, { status: 401 });

  const parsed = schema.safeParse(await req.json().catch(() => ({})));
  if (!parsed.success) {
    return NextResponse.json({ error: 'bad_request', details: parsed.error.issues }, { status: 400 });
  }

  const check = moderateComment(parsed.data.body);
  if (!check.ok) {
    return NextResponse.json(
      { error: 'moderation_blocked', message: moderationMessage(check.reason!) },
      { status: 422 }
    );
  }

  // Cheap rate-limit: refuse if this user already posted in the last 15 seconds.
  const fifteenSecondsAgo = new Date(Date.now() - 15_000).toISOString();
  const { count } = await supabase
    .from('blog_comments')
    .select('id', { count: 'exact', head: true })
    .eq('author_id', user.id)
    .gte('created_at', fifteenSecondsAgo);
  if ((count ?? 0) > 0) {
    return NextResponse.json({ error: 'slow_down' }, { status: 429 });
  }

  const { data, error } = await supabase
    .from('blog_comments')
    .insert({
      post_id: parsed.data.post_id,
      parent_id: parsed.data.parent_id ?? null,
      author_id: user.id,
      body: parsed.data.body.trim(),
    })
    .select()
    .single();

  if (error) {
    return NextResponse.json({ error: 'insert_failed', message: error.message }, { status: 500 });
  }
  return NextResponse.json({ comment: data }, { status: 201 });
}
