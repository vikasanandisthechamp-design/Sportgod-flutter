import { NextResponse } from 'next/server';
import { z } from 'zod';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { moderateComment, moderationMessage } from '@/lib/blog/moderation';

const patchSchema = z.object({
  body: z.string().min(2).max(4000),
});

export async function PATCH(req: Request, ctx: { params: Promise<{ id: string }> }) {
  const supabase = await getSupabaseServerClient();
  if (!supabase) return NextResponse.json({ error: 'db_unavailable' }, { status: 503 });

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'signin_required' }, { status: 401 });

  const parsed = patchSchema.safeParse(await req.json().catch(() => ({})));
  if (!parsed.success) return NextResponse.json({ error: 'bad_request' }, { status: 400 });

  const check = moderateComment(parsed.data.body);
  if (!check.ok) {
    return NextResponse.json(
      { error: 'moderation_blocked', message: moderationMessage(check.reason!) },
      { status: 422 }
    );
  }

  const { id } = await ctx.params;
  const { data, error } = await supabase
    .from('blog_comments')
    .update({ body: parsed.data.body.trim(), edited_at: new Date().toISOString() })
    .eq('id', id)
    .eq('author_id', user.id)  // RLS also enforces this
    .select()
    .maybeSingle();

  if (error || !data) {
    return NextResponse.json({ error: 'not_found' }, { status: 404 });
  }
  return NextResponse.json({ comment: data });
}

export async function DELETE(_req: Request, ctx: { params: Promise<{ id: string }> }) {
  const supabase = await getSupabaseServerClient();
  if (!supabase) return NextResponse.json({ error: 'db_unavailable' }, { status: 503 });

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'signin_required' }, { status: 401 });

  const { id } = await ctx.params;
  // Soft delete — preserve the thread shape for readers.
  const { error } = await supabase
    .from('blog_comments')
    .update({ is_deleted: true, body: '[deleted by author]' })
    .eq('id', id)
    .eq('author_id', user.id);

  if (error) return NextResponse.json({ error: 'delete_failed' }, { status: 500 });
  return NextResponse.json({ ok: true });
}
