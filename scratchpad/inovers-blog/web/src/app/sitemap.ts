import type { MetadataRoute } from 'next';
import { listPublishedPosts, listAllTags } from '@/lib/blog/queries';

const SITE = 'https://inovers.in';

export const revalidate = 600;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const staticRoutes: MetadataRoute.Sitemap = [
    { url: `${SITE}/`, changeFrequency: 'weekly', priority: 1 },
    { url: `${SITE}/blog`, changeFrequency: 'daily', priority: 0.9 },
    { url: `${SITE}/manifesto`, changeFrequency: 'monthly', priority: 0.6 },
    { url: `${SITE}/waitlist`, changeFrequency: 'weekly', priority: 0.6 },
  ];

  // Paginate through all published posts (cap 500 for sitemap size).
  const collected: MetadataRoute.Sitemap = [];
  for (let page = 1; page < 42; page += 1) {
    const { posts, hasMore } = await listPublishedPosts({ page });
    for (const p of posts) {
      collected.push({
        url: `${SITE}/blog/${p.slug}`,
        lastModified: p.publish_at,
        changeFrequency: 'weekly',
        priority: 0.7,
      });
    }
    if (!hasMore || collected.length >= 500) break;
  }

  const tags = await listAllTags();
  const tagRoutes: MetadataRoute.Sitemap = tags.map((t) => ({
    url: `${SITE}/blog/tag/${t.slug}`,
    changeFrequency: 'weekly',
    priority: 0.5,
  }));

  return [...staticRoutes, ...collected, ...tagRoutes];
}
