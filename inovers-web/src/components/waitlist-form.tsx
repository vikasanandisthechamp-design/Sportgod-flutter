"use client";

import { useState } from "react";
import { z } from "zod";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";

const schema = z.object({
  name: z.string().trim().min(2, "Tell us your name"),
  email: z.string().trim().toLowerCase().email("Use a real email"),
  city: z.string().trim().min(2, "Which city are you in?"),
  skills: z.string().trim().min(3, "Add a few skills or interests"),
  why: z.string().trim().max(500).optional().or(z.literal("")),
});

type FieldErrors = Partial<Record<keyof z.infer<typeof schema>, string>>;

export function WaitlistForm() {
  const [status, setStatus] = useState<"idle" | "submitting" | "success" | "error">("idle");
  const [errorMsg, setErrorMsg] = useState<string>("");
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setStatus("submitting");
    setErrorMsg("");
    setFieldErrors({});

    const form = new FormData(e.currentTarget);
    const parsed = schema.safeParse({
      name: form.get("name"),
      email: form.get("email"),
      city: form.get("city"),
      skills: form.get("skills"),
      why: form.get("why") ?? "",
    });

    if (!parsed.success) {
      const errs: FieldErrors = {};
      for (const issue of parsed.error.issues) {
        const key = issue.path[0] as keyof FieldErrors;
        if (!errs[key]) errs[key] = issue.message;
      }
      setFieldErrors(errs);
      setStatus("idle");
      return;
    }

    const supabase = getSupabaseBrowserClient();
    if (!supabase) {
      setStatus("error");
      setErrorMsg("Waitlist is not configured yet. Check back shortly.");
      return;
    }

    const { error } = await supabase.from("waitlist").insert({
      name: parsed.data.name,
      email: parsed.data.email,
      city: parsed.data.city,
      skills: parsed.data.skills,
      why: parsed.data.why || null,
    });

    if (error) {
      setStatus("error");
      setErrorMsg(
        error.code === "23505"
          ? "You're already on the list. Welcome back!"
          : "Something went wrong. Try again in a moment."
      );
      return;
    }

    setStatus("success");
  }

  if (status === "success") {
    return (
      <div className="text-center py-6">
        <div className="text-3xl mb-3">🎉</div>
        <h3 className="text-xl font-semibold">You&apos;re in.</h3>
        <p className="mt-2 text-muted-foreground">
          Welcome to Inovers. We&apos;ll reach out soon with your Founding
          Innovator invite.
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={onSubmit} className="space-y-4">
      <Field label="Your name" name="name" placeholder="Ravi Kumar" error={fieldErrors.name} />
      <Field label="Email" name="email" type="email" placeholder="you@example.com" error={fieldErrors.email} />
      <Field label="City" name="city" placeholder="Bengaluru" error={fieldErrors.city} />
      <Field label="Skills or interests" name="skills" placeholder="Design, Flutter, policy research, storytelling…" error={fieldErrors.skills} />
      <div>
        <label className="block text-sm font-medium mb-1.5">Why do you want in? <span className="text-muted-foreground font-normal">(optional)</span></label>
        <textarea
          name="why"
          rows={3}
          placeholder="A problem you want to solve, an idea you have, a skill you want to use…"
          className="w-full rounded-lg border border-border bg-background px-3 py-2.5 text-sm outline-none focus:ring-2 focus:ring-ring/40 focus:border-ring"
        />
      </div>

      {errorMsg && (
        <p className="text-sm text-red-600 bg-red-50 border border-red-200 rounded-lg px-3 py-2">
          {errorMsg}
        </p>
      )}

      <button
        type="submit"
        disabled={status === "submitting"}
        className="w-full h-11 rounded-full bg-primary text-primary-foreground font-semibold text-sm hover:opacity-90 transition-opacity disabled:opacity-60"
      >
        {status === "submitting" ? "Joining…" : "Join the Waitlist"}
      </button>
      <p className="text-xs text-muted-foreground text-center">
        We&apos;ll never spam you. No ads. Ever.
      </p>
    </form>
  );
}

function Field({
  label,
  name,
  type = "text",
  placeholder,
  error,
}: {
  label: string;
  name: string;
  type?: string;
  placeholder?: string;
  error?: string;
}) {
  return (
    <div>
      <label className="block text-sm font-medium mb-1.5">{label}</label>
      <input
        name={name}
        type={type}
        placeholder={placeholder}
        className="w-full h-11 rounded-lg border border-border bg-background px-3 text-sm outline-none focus:ring-2 focus:ring-ring/40 focus:border-ring"
      />
      {error && <p className="mt-1 text-xs text-red-600">{error}</p>}
    </div>
  );
}
