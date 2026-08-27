import { NextResponse } from 'next/server';
import { z } from 'zod';
import { getSupabaseServerClient } from '@/lib/supabase/server';

const schema = z.object({
  post_id: z.string().uuid().nullable().optional(),
  comment_id: z.string().uuid().nullable().optional(),
  kind: z.enum(['up', 'insightful', 'curious', 'disagree']),
});

// Toggle behavior: if the user already reacted with the same kind to the same
// target, we remove it. If they reacted with a different kind, we replace.
export async function POST(req: Request) {
  const supabase = await getSupabaseServerClient();
  if (!supabase) return NextResponse.json({ error: 'db_unavailable' }, { status: 503 });

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'signin_required' }, { status: 401 });

  const parsed = schema.safeParse(await req.json().catch(() => ({})));
  if (!parsed.success || (!parsed.data.post_id && !parsed.data.comment_id)) {
    return NextResponse.json({ error: 'bad_request' }, { status: 400 });
  }

  const target = parsed.data.post_id
    ? { column: 'post_id', value: parsed.data.post_id }
    : { column: 'comment_id', value: parsed.data.comment_id! };

  const { data: existing } = await supabase
    .from('blog_reactions')
    .select('id, kind')
    .eq('user_id', user.id)
    .eq(target.column, target.value)
    .maybeSingle();

  if (existing) {
    if (existing.kind === parsed.data.kind) {
      await supabase.from('blog_reactions').delete().eq('id', existing.id);
      return NextResponse.json({ state: 'removed' });
    }
    await supabase.from('blog_reactions').update({ kind: parsed.data.kind }).eq('id', existing.id);
    return NextResponse.json({ state: 'changed', kind: parsed.data.kind });
  }

  await supabase.from('blog_reactions').insert({
    user_id: user.id,
    kind: parsed.data.kind,
    post_id: parsed.data.post_id ?? null,
    comment_id: parsed.data.comment_id ?? null,
  });
  return NextResponse.json({ state: 'added', kind: parsed.data.kind }, { status: 201 });
}
