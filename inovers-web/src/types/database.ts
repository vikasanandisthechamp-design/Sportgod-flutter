// Minimal hand-written DB types for MVP.
// Regenerate with `pnpm dlx supabase gen types typescript` once CLI is wired up.

export type Database = {
  public: {
    Tables: {
      waitlist: {
        Row: {
          id: string;
          created_at: string;
          name: string;
          email: string;
          city: string;
          skills: string;
          why: string | null;
          source: string | null;
        };
        Insert: {
          id?: string;
          created_at?: string;
          name: string;
          email: string;
          city: string;
          skills: string;
          why?: string | null;
          source?: string | null;
        };
        Update: Partial<Database["public"]["Tables"]["waitlist"]["Insert"]>;
        Relationships: [];
      };
      profiles: {
        Row: {
          id: string;
          created_at: string;
          name: string;
          city: string | null;
          headline: string | null;
          skills: string[] | null;
          avatar_url: string | null;
          innovator_score: number;
        };
        Insert: {
          id: string;
          created_at?: string;
          name: string;
          city?: string | null;
          headline?: string | null;
          skills?: string[] | null;
          avatar_url?: string | null;
          innovator_score?: number;
        };
        Update: Partial<Database["public"]["Tables"]["profiles"]["Insert"]>;
        Relationships: [];
      };
      ideas: {
        Row: {
          id: string;
          created_at: string;
          author_id: string;
          title: string;
          problem: string;
          proposal: string;
          tags: string[];
          skills_needed: string[];
          stage:
            | "spark"
            | "validate"
            | "pod_form"
            | "blueprint"
            | "execute"
            | "impact";
          upvotes: number;
          interested_count: number;
        };
        Insert: {
          id?: string;
          created_at?: string;
          author_id: string;
          title: string;
          problem: string;
          proposal: string;
          tags?: string[];
          skills_needed?: string[];
          stage?:
            | "spark"
            | "validate"
            | "pod_form"
            | "blueprint"
            | "execute"
            | "impact";
          upvotes?: number;
          interested_count?: number;
        };
        Update: Partial<Database["public"]["Tables"]["ideas"]["Insert"]>;
        Relationships: [];
      };
      idea_interests: {
        Row: {
          id: string;
          created_at: string;
          idea_id: string;
          user_id: string;
          role: string | null;
        };
        Insert: {
          id?: string;
          created_at?: string;
          idea_id: string;
          user_id: string;
          role?: string | null;
        };
        Update: Partial<
          Database["public"]["Tables"]["idea_interests"]["Insert"]
        >;
        Relationships: [];
      };
      pods: {
        Row: {
          id: string;
          created_at: string;
          idea_id: string;
          lead_id: string;
          name: string;
          status:
            | "forming"
            | "active"
            | "stalled"
            | "shipped"
            | "archived";
          summary: string | null;
        };
        Insert: {
          id?: string;
          created_at?: string;
          idea_id: string;
          lead_id: string;
          name: string;
          status?:
            | "forming"
            | "active"
            | "stalled"
            | "shipped"
            | "archived";
          summary?: string | null;
        };
        Update: Partial<Database["public"]["Tables"]["pods"]["Insert"]>;
        Relationships: [];
      };
      pod_members: {
        Row: {
          id: string;
          created_at: string;
          pod_id: string;
          user_id: string;
          role: string;
        };
        Insert: {
          id?: string;
          created_at?: string;
          pod_id: string;
          user_id: string;
          role: string;
        };
        Update: Partial<
          Database["public"]["Tables"]["pod_members"]["Insert"]
        >;
        Relationships: [];
      };
    };
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: {
      idea_stage:
        | "spark"
        | "validate"
        | "pod_form"
        | "blueprint"
        | "execute"
        | "impact";
      pod_status:
        | "forming"
        | "active"
        | "stalled"
        | "shipped"
        | "archived";
    };
    CompositeTypes: Record<string, never>;
  };
};
