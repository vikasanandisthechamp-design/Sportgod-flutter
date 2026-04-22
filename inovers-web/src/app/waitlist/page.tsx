import type { Metadata } from "next";
import { WaitlistForm } from "@/components/waitlist-form";

export const metadata: Metadata = {
  title: "Join the Waitlist — Inovers",
  description:
    "Be one of the first 1,000 Founding Innovators. Lifetime badge. Governance rights. Priority access.",
};

export default function WaitlistPage() {
  return (
    <div className="container-page py-20 max-w-xl">
      <p className="text-sm font-semibold text-primary uppercase tracking-wider">
        Founding Innovators
      </p>
      <h1 className="mt-3 text-4xl md:text-5xl font-bold tracking-tight leading-tight">
        Be one of the first 1,000.
      </h1>
      <p className="mt-4 text-lg text-muted-foreground">
        Permanent badge. Governance rights. Lifetime recognition.
      </p>

      <div className="mt-10 rounded-2xl border border-border p-6 md:p-8 bg-background">
        <WaitlistForm />
      </div>

      <ul className="mt-10 space-y-3 text-sm text-muted-foreground">
        <li>✦ Early access to idea feed and Pods</li>
        <li>✦ First access to government and institutional projects</li>
        <li>✦ Founding Innovator badge (permanent, verifiable)</li>
        <li>✦ Invite to private WhatsApp community</li>
      </ul>
    </div>
  );
}
