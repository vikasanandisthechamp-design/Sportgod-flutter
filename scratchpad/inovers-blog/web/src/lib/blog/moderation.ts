// Lightweight comment safety — first line of defense before submission.
// Backed by a wordlist file at runtime; here we ship a small starter set.
// The real moderation happens via reports + editor review; this catches only
// the most obvious cases so the DB is not full of one-word slurs.

const NORMALIZED_BLOCKLIST: string[] = [
  // Add or replace with your curated list. Keep it short — false positives are
  // more damaging than false negatives when comments matter.
];

const MIN_LEN = 2;
const MAX_LEN = 4000;
const LINK_LIMIT = 3;

export interface ModerationResult {
  ok: boolean;
  reason?: 'too_short' | 'too_long' | 'blocked_term' | 'too_many_links' | 'all_caps';
}

export function moderateComment(body: string): ModerationResult {
  const trimmed = body.trim();
  if (trimmed.length < MIN_LEN) return { ok: false, reason: 'too_short' };
  if (trimmed.length > MAX_LEN) return { ok: false, reason: 'too_long' };

  const lowered = trimmed.toLowerCase();
  for (const word of NORMALIZED_BLOCKLIST) {
    if (lowered.includes(word)) return { ok: false, reason: 'blocked_term' };
  }

  const linkMatches = trimmed.match(/https?:\/\//g);
  if (linkMatches && linkMatches.length > LINK_LIMIT) {
    return { ok: false, reason: 'too_many_links' };
  }

  const letters = trimmed.replace(/[^a-zA-Z]/g, '');
  if (letters.length >= 20 && letters === letters.toUpperCase()) {
    return { ok: false, reason: 'all_caps' };
  }

  return { ok: true };
}

export function moderationMessage(reason: NonNullable<ModerationResult['reason']>): string {
  switch (reason) {
    case 'too_short':
      return 'Comments need at least a couple of words.';
    case 'too_long':
      return 'That is longer than we allow — trim it below 4000 characters.';
    case 'blocked_term':
      return 'That contains a term we do not allow.';
    case 'too_many_links':
      return 'Please limit links to 3 per comment.';
    case 'all_caps':
      return 'Please avoid writing entirely in capital letters.';
  }
}
