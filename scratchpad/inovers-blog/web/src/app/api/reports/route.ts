import { NextResponse } from 'next/server';
import { z } from 'zod';
import { getSupabaseServerClient } from '@/lib/supabase/server';

const schema = z.object({
  post_id: z.string().uuid().nullable().optional(),
  comment_id: z.string().uuid().nullable().optional(),
  reason: z.enum(['spam', 'harassment', 'misinfo', 'off_topic', 'other']).default('other'),
  note: z.string().max(1000).optional(),
});

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

  const { error } = await supabase.from('blog_reports').insert({
    reporter_id: user.id,
    post_id: parsed.data.post_id ?? null,
    comment_id: parsed.data.comment_id ?? null,
    reason: parsed.data.reason,
    note: parsed.data.note ?? null,
  });
  if (error) return NextResponse.json({ error: 'insert_failed' }, { status: 500 });
  return NextResponse.json({ ok: true }, { status: 201 });
}
