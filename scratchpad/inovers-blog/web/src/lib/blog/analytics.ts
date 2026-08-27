// Consent-gated analytics stub. Wire your real provider (Plausible / PostHog /
// Umami) inside `send()` — until then everything is a no-op except in dev.

type EventName =
  | 'blog_post_view'
  | 'blog_post_scroll_50'
  | 'blog_post_scroll_90'
  | 'blog_comment_submit'
  | 'blog_comment_signin_required'
  | 'blog_reaction_add'
  | 'blog_share_click'
  | 'blog_tag_click';

interface EventPayload {
  slug?: string;
  post_id?: string;
  tag?: string;
  reaction?: string;
  extra?: Record<string, string | number | boolean | null>;
}

export function track(name: EventName, payload: EventPayload = {}) {
  if (typeof window === 'undefined') return;
  const consent = window.localStorage?.getItem('analytics_consent');
  if (consent !== 'granted') {
    if (process.env.NODE_ENV !== 'production') {
      console.debug('[analytics]', name, payload, '(consent not granted; skipped)');
    }
    return;
  }
  send(name, payload);
}

function send(name: EventName, payload: EventPayload) {
  // Example Plausible wiring:
  //   const w = window as unknown as { plausible?: (n: string, o?: unknown) => void };
  //   w.plausible?.(name, { props: payload });
  if (process.env.NODE_ENV !== 'production') {
    console.debug('[analytics:sent]', name, payload);
  }
}

export function visitorKey(): string {
  // Client-only, best-effort. For real per-viewer counting use IP+UA hash server-side.
  if (typeof window === 'undefined') return 'server';
  const existing = window.localStorage?.getItem('vk');
  if (existing) return existing;
  const fresh = crypto.randomUUID();
  try {
    window.localStorage?.setItem('vk', fresh);
  } catch {
    // storage disabled
  }
  return fresh;
}
