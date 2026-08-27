import { listPublishedPosts } from '@/lib/blog/queries';

export const revalidate = 600;

export async function GET() {
  const { posts } = await listPublishedPosts({ page: 1 });
  const site = 'https://inovers.in';
  const items = posts.slice(0, 30).map((p) => {
    const url = `${site}/blog/${p.slug}`;
    return `
      <item>
        <title><![CDATA[${p.title}]]></title>
        <link>${url}</link>
        <guid isPermaLink="true">${url}</guid>
        <pubDate>${new Date(p.publish_at).toUTCString()}</pubDate>
        ${p.dek ? `<description><![CDATA[${p.dek}]]></description>` : ''}
        ${p.author_name ? `<author>editorial@inovers.in (${p.author_name})</author>` : ''}
        ${p.tags.map((t) => `<category>${t}</category>`).join('\n        ')}
      </item>`;
  });

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>Inovers Journal</title>
    <link>${site}/blog</link>
    <description>Long-form thinking on innovation, creative thinking, education and the AI-shaped world.</description>
    <language>en-in</language>
    <atom:link href="${site}/api/rss" rel="self" type="application/rss+xml" />
    ${items.join('\n')}
  </channel>
</rss>`;

  return new Response(xml, {
    headers: {
      'content-type': 'application/rss+xml; charset=utf-8',
      'cache-control': 'public, s-maxage=600, stale-while-revalidate=1200',
    },
  });
}
