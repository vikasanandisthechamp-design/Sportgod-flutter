import { getSupabaseServerClient } from '@/lib/supabase/server';
import type { UserRole } from '@/types/blog';

export interface CurrentUser {
  id: string;
  email: string | null;
  name: string;
  avatarUrl: string | null;
  role: UserRole;
}

export async function getCurrentUser(): Promise<CurrentUser | null> {
  const supabase = await getSupabaseServerClient();
  if (!supabase) return null;

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: profile } = await supabase
    .from('profiles')
    .select('id, name, avatar_url, role')
    .eq('id', user.id)
    .maybeSingle();

  return {
    id: user.id,
    email: user.email ?? null,
    name: profile?.name ?? user.email?.split('@')[0] ?? 'Reader',
    avatarUrl: profile?.avatar_url ?? null,
    // profiles.role defaults to 'reader' via the schema; guard for absent row.
    role: (profile?.role as UserRole | undefined) ?? 'reader',
  };
}

export function isEditor(user: CurrentUser | null) {
  return user?.role === 'editor' || user?.role === 'admin';
}

export function isAdmin(user: CurrentUser | null) {
  return user?.role === 'admin';
}
