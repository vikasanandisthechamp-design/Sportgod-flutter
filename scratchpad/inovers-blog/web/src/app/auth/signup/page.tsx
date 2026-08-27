'use client';

import { useState, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { getSupabaseBrowserClient } from '@/lib/supabase/client';

function SignupInner() {
  const supabase = getSupabaseBrowserClient();
  const router = useRouter();
  const sp = useSearchParams();
  const next = sp.get('next') || '/blog';

  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!supabase) return;
    setError(null);
    setPending(true);
    const { error, data } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { name },
        emailRedirectTo: `${window.location.origin}/auth/callback?next=${encodeURIComponent(next)}`,
      },
    });
    setPending(false);
    if (error) {
      setError(error.message);
      return;
    }
    if (data.user && !data.session) {
      setMessage('Check your email to confirm your account, then sign in.');
      return;
    }
    router.push(next);
    router.refresh();
  }

  return (
    <div className="container-page py-16">
      <div className="mx-auto max-w-sm">
        <h1 className="text-3xl font-bold tracking-tight">Create account</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          Free forever. Used to attribute your comments so this community stays real.
        </p>

        <form onSubmit={submit} className="mt-6 space-y-3">
          <input
            required
            placeholder="Your name (shown next to your comments)"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="h-11 w-full rounded-xl border border-border bg-background px-4 text-sm focus:border-primary outline-none"
          />
          <input
            type="email"
            required
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="h-11 w-full rounded-xl border border-border bg-background px-4 text-sm focus:border-primary outline-none"
          />
          <input
            type="password"
            required
            minLength={8}
            placeholder="Password (min 8 chars)"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="h-11 w-full rounded-xl border border-border bg-background px-4 text-sm focus:border-primary outline-none"
          />
          <button
            type="submit"
            disabled={pending}
            className="h-11 w-full rounded-full bg-primary text-sm font-semibold text-primary-foreground hover:opacity-90 disabled:opacity-40"
          >
            {pending ? 'Creating…' : 'Create account'}
          </button>
        </form>

        {error && <p className="mt-3 text-xs text-red-600">{error}</p>}
        {message && <p className="mt-3 text-xs text-green-700">{message}</p>}

        <p className="mt-6 text-sm text-muted-foreground">
          Already have one?{' '}
          <Link href={`/auth/login?next=${encodeURIComponent(next)}`} className="text-primary underline">
            Sign in
          </Link>
          .
        </p>

        <p className="mt-6 text-xs text-muted-foreground">
          By creating an account you agree to the{' '}
          <Link href="/terms" className="underline">Terms</Link> and{' '}
          <Link href="/privacy" className="underline">Privacy Policy</Link>, and to abide by the{' '}
          <Link href="/comment-policy" className="underline">Comment Policy</Link>.
        </p>
      </div>
    </div>
  );
}

export default function SignupPage() {
  return (
    <Suspense fallback={null}>
      <SignupInner />
    </Suspense>
  );
}
