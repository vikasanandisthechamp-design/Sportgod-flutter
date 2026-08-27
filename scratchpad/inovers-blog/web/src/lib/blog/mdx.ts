// Minimal MDX-ish renderer. Ships zero runtime deps beyond React.
// For production we recommend switching to `next-mdx-remote/rsc` or `@mdx-js/react`.
// This shim is intentional — it lets the module render posts before you install
// the full MDX pipeline, then you swap in a proper renderer via one prop.

import { Fragment, type ReactNode } from 'react';

interface RenderOpts {
  className?: string;
}

/**
 * Very small markdown subset (safe by default; only the tags we output).
 * Handles: # h1, ## h2, ### h3, paragraphs, **bold**, *italic*, `code`,
 * code fences (```), lists (- item), blockquote (> ...), links, images, hr (---).
 */
export function renderMarkdown(src: string, opts: RenderOpts = {}): ReactNode {
  const blocks = splitBlocks(src.trim());
  return (
    <div className={opts.className}>
      {blocks.map((b, i) => (
        <Fragment key={i}>{renderBlock(b, i)}</Fragment>
      ))}
    </div>
  );
}

function splitBlocks(src: string): string[] {
  const lines = src.split(/\r?\n/);
  const out: string[] = [];
  let buf: string[] = [];
  let inFence = false;
  for (const line of lines) {
    if (line.startsWith('```')) {
      buf.push(line);
      if (inFence) {
        out.push(buf.join('\n'));
        buf = [];
      }
      inFence = !inFence;
      if (!inFence) continue;
      continue;
    }
    if (inFence) {
      buf.push(line);
      continue;
    }
    if (line.trim() === '') {
      if (buf.length) {
        out.push(buf.join('\n'));
        buf = [];
      }
    } else {
      buf.push(line);
    }
  }
  if (buf.length) out.push(buf.join('\n'));
  return out;
}

function renderBlock(block: string, key: number): ReactNode {
  if (block.startsWith('```')) {
    const inner = block.replace(/^```[a-z]*\n?/, '').replace(/```$/, '');
    return (
      <pre
        key={key}
        className="my-6 overflow-x-auto rounded-xl bg-muted p-4 text-sm font-mono leading-relaxed"
      >
        <code>{inner}</code>
      </pre>
    );
  }
  if (block.startsWith('### ')) {
    return (
      <h3 key={key} className="mt-10 mb-3 text-xl font-semibold tracking-tight">
        {inline(block.slice(4))}
      </h3>
    );
  }
  if (block.startsWith('## ')) {
    return (
      <h2 key={key} className="mt-12 mb-4 text-2xl md:text-3xl font-bold tracking-tight">
        {inline(block.slice(3))}
      </h2>
    );
  }
  if (block.startsWith('# ')) {
    return (
      <h1 key={key} className="mt-12 mb-4 text-3xl md:text-4xl font-bold tracking-tight">
        {inline(block.slice(2))}
      </h1>
    );
  }
  if (block.startsWith('> ')) {
    return (
      <blockquote
        key={key}
        className="my-6 border-l-4 border-primary bg-muted/50 px-5 py-3 italic text-foreground/90"
      >
        {inline(block.replace(/^> ?/gm, ''))}
      </blockquote>
    );
  }
  if (/^---+$/.test(block.trim())) {
    return <hr key={key} className="my-10 border-border" />;
  }
  if (block.split('\n').every((l) => /^[-*] /.test(l))) {
    return (
      <ul key={key} className="my-4 list-disc space-y-1.5 pl-6 leading-relaxed">
        {block.split('\n').map((l, i) => (
          <li key={i}>{inline(l.replace(/^[-*] /, ''))}</li>
        ))}
      </ul>
    );
  }
  if (block.split('\n').every((l) => /^\d+\. /.test(l))) {
    return (
      <ol key={key} className="my-4 list-decimal space-y-1.5 pl-6 leading-relaxed">
        {block.split('\n').map((l, i) => (
          <li key={i}>{inline(l.replace(/^\d+\. /, ''))}</li>
        ))}
      </ol>
    );
  }
  return (
    <p key={key} className="my-5 text-lg leading-relaxed text-foreground/90">
      {inline(block)}
    </p>
  );
}

function inline(text: string): ReactNode {
  // Order matters: code first (protect literal chars), then images, links, bold, italic.
  const nodes: ReactNode[] = [];
  const pattern =
    /(`[^`]+`)|(!\[[^\]]*\]\([^)]+\))|(\[[^\]]+\]\([^)]+\))|(\*\*[^*]+\*\*)|(\*[^*]+\*)/g;
  let last = 0;
  let m: RegExpExecArray | null;
  let key = 0;
  while ((m = pattern.exec(text)) !== null) {
    if (m.index > last) nodes.push(text.slice(last, m.index));
    const token = m[0];
    if (token.startsWith('`')) {
      nodes.push(
        <code key={key++} className="rounded bg-muted px-1.5 py-0.5 text-[0.9em] font-mono">
          {token.slice(1, -1)}
        </code>
      );
    } else if (token.startsWith('![')) {
      const alt = /!\[([^\]]*)\]/.exec(token)?.[1] ?? '';
      const url = /\(([^)]+)\)/.exec(token)?.[1] ?? '';
      nodes.push(
        // eslint-disable-next-line @next/next/no-img-element
        <img key={key++} src={url} alt={alt} className="my-6 rounded-2xl" loading="lazy" />
      );
    } else if (token.startsWith('[')) {
      const label = /\[([^\]]+)\]/.exec(token)?.[1] ?? '';
      const url = /\(([^)]+)\)/.exec(token)?.[1] ?? '';
      const external = /^https?:\/\//.test(url);
      nodes.push(
        <a
          key={key++}
          href={url}
          className="text-primary underline decoration-primary/40 underline-offset-4 hover:decoration-primary"
          {...(external ? { target: '_blank', rel: 'noopener noreferrer' } : {})}
        >
          {label}
        </a>
      );
    } else if (token.startsWith('**')) {
      nodes.push(
        <strong key={key++} className="font-semibold">
          {token.slice(2, -2)}
        </strong>
      );
    } else if (token.startsWith('*')) {
      nodes.push(
        <em key={key++} className="italic">
          {token.slice(1, -1)}
        </em>
      );
    }
    last = m.index + token.length;
  }
  if (last < text.length) nodes.push(text.slice(last));
  return nodes;
}

export function estimateReadingTime(mdx: string): number {
  const words = mdx.trim().split(/\s+/).length;
  return Math.max(1, Math.round(words / 220));
}
