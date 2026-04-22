import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Ideas — Inovers",
  description: "Fresh ideas from the Inovers community.",
};

export default function IdeasPage() {
  return (
    <div className="container-page py-20 max-w-2xl text-center">
      <p className="text-sm font-semibold text-primary uppercase tracking-wider">
        Coming in Beta
      </p>
      <h1 className="mt-3 text-4xl md:text-5xl font-bold tracking-tight">
        The Idea Wall is almost live.
      </h1>
      <p className="mt-4 text-lg text-muted-foreground">
        Join the waitlist to get first access when we open the feed to Founding
        Innovators.
      </p>
      <Link
        href="/waitlist"
        className="mt-8 inline-flex h-11 items-center rounded-full bg-primary px-6 text-sm font-semibold text-primary-foreground hover:opacity-90 transition-opacity"
      >
        Join the Waitlist
      </Link>
    </div>
  );
}
