import type { Metadata } from "next";
import Link from "next/link";
import { ArrowRight } from "lucide-react";

export const metadata: Metadata = {
  title: "The Inovers Manifesto",
  description:
    "Why Inovers exists, what we believe, and how Bharat will innovate from the ground up.",
};

export default function ManifestoPage() {
  return (
    <div className="container-page py-20 max-w-3xl">
      <p className="text-sm font-semibold text-primary uppercase tracking-wider">
        Manifesto
      </p>
      <h1 className="mt-3 text-4xl md:text-5xl font-bold tracking-tight leading-tight">
        Ideas don&apos;t wait for permission anymore.
      </h1>

      <div className="mt-10 space-y-6 text-lg leading-relaxed text-foreground/90">
        <p>
          We believe India&apos;s greatest resource isn&apos;t its capital. It isn&apos;t even
          its technology. It&apos;s the <strong>billion minds</strong> that wake up every
          morning carrying solutions to problems no boardroom will ever name.
        </p>
        <p>
          For too long, those ideas have lived in notebooks, in WhatsApp drafts,
          in conversations that faded at midnight. For too long, innovation
          belonged to the few who had access — to capital, to networks, to
          permission.
        </p>
        <p className="text-2xl font-semibold text-primary border-l-4 border-primary pl-5 py-1">
          Inovers is the end of that era.
        </p>
        <p>
          We are building a platform where an idea posted by a student in
          Hyderabad can be picked up by a designer in Indore, shaped by a
          developer in Pune, and executed as a government project for a school
          in Bhopal. In weeks, not years.
        </p>
        <p>
          We are not a company that delivers services. We are an{" "}
          <strong>ecosystem</strong> where the community is the service. Every
          Pod is a mini-startup. Every build log is a public commitment. Every
          contribution is credited.
        </p>
      </div>

      <hr className="my-12 border-border" />

      <h2 className="text-2xl font-bold mb-6">What we believe</h2>
      <ul className="space-y-4 text-base">
        <Belief n="01" title="Execution is the real test of an idea.">
          Anyone can talk. Inovers rewards those who ship.
        </Belief>
        <Belief n="02" title="Transparency creates trust.">
          Every Pod, every build log, every milestone is public by default.
        </Belief>
        <Belief n="03" title="Collaboration beats competition.">
          We win when Pods ship. Not when individuals hoard credit.
        </Belief>
        <Belief n="04" title="Bharat-first, always.">
          Hosted in India. Designed for Bharat. Compliant with DPDP.
        </Belief>
        <Belief n="05" title="No permission required.">
          If you have a skill and an idea, you are already an Innovator.
        </Belief>
      </ul>

      <div className="mt-14 rounded-2xl border border-border bg-muted/50 p-8 text-center">
        <h3 className="text-2xl font-bold">Ready to build Bharat with us?</h3>
        <p className="mt-2 text-muted-foreground">
          The first 1,000 innovators get a permanent Founding Innovator badge.
        </p>
        <Link
          href="/waitlist"
          className="mt-6 inline-flex h-11 items-center gap-2 rounded-full bg-primary px-6 text-sm font-semibold text-primary-foreground hover:opacity-90 transition-opacity"
        >
          Join the Movement <ArrowRight className="h-4 w-4" />
        </Link>
      </div>
    </div>
  );
}

function Belief({ n, title, children }: { n: string; title: string; children: React.ReactNode }) {
  return (
    <li className="rounded-xl border border-border p-5 bg-background">
      <div className="flex items-baseline gap-3">
        <span className="text-xs font-mono text-muted-foreground">{n}</span>
        <h3 className="font-semibold">{title}</h3>
      </div>
      <p className="mt-2 text-sm text-muted-foreground ml-8">{children}</p>
    </li>
  );
}
