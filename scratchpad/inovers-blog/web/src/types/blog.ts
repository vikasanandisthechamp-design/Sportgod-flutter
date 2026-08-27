// Hand-written types for the blog module.
// Merge into the project's existing src/types/database.ts (see FILE-MAP.md).

export type UserRole = 'reader' | 'author' | 'editor' | 'admin';

export type PostStatus =
  | 'draft'
  | 'pending_review'
  | 'scheduled'
  | 'published'
  | 'archived';

export type ReactionKind = 'up' | 'insightful' | 'curious' | 'disagree';

export type ReportReason = 'spam' | 'harassment' | 'misinfo' | 'off_topic' | 'other';
export type ReportStatus = 'open' | 'dismissed' | 'actioned';

export interface BlogTag {
  slug: string;
  label: string;
  description: string | null;
  created_at: string;
}

export interface BlogPost {
  id: string;
  slug: string;
  title: string;
  dek: string | null;
  cover_image: string | null;
  reading_time: number | null;
  body_mdx: string;
  body_excerpt: string | null;
  author_id: string | null;
  author_name: string | null;
  author_avatar: string | null;
  publish_at: string | null;
  status: PostStatus;
  comment_count: number;
  reaction_count: number;
  view_count: number;
  created_at: string;
  updated_at: string;
  source_note: string | null;
  research_json: unknown | null;
  editor_id: string | null;
  editor_notes: string | null;
}

// Row returned by the blog_posts_public view.
export interface BlogPostPublic {
  id: string;
  slug: string;
  title: string;
  dek: string | null;
  cover_image: string | null;
  reading_time: number | null;
  body_excerpt: string | null;
  author_name: string | null;
  author_avatar: string | null;
  publish_at: string;
  comment_count: number;
  reaction_count: number;
  view_count: number;
  tags: string[];
}

export interface BlogComment {
  id: string;
  post_id: string;
  author_id: string;
  parent_id: string | null;
  body: string;
  is_deleted: boolean;
  is_hidden: boolean;
  reaction_count: number;
  report_count: number;
  created_at: string;
  edited_at: string | null;
  // joined
  author?: {
    id: string;
    name: string;
    avatar_url: string | null;
    role: UserRole;
  };
  replies?: BlogComment[];
}

export interface BlogReactionAggregate {
  target_id: string;
  kind: ReactionKind;
  count: number;
  mine: boolean;
}
