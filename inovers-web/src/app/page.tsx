import Link from "next/link";
import { ArrowRight, Lightbulb, Users, Rocket, Building2, Sparkles, GraduationCap, ShieldCheck } from "lucide-react";

export default function Home() {
  return (
    <>
      {/* HERO */}
      <section className="relative overflow-hidden">
        <div className="absolute inset-0 -z-10 bg-[radial-gradient(ellipse_at_top,rgba(43,43,255,0.12),transparent_60%)]" />
        <div className="container-page py-20 md:py-28">
          <div className="flex flex-col items-center text-center max-w-3xl mx-auto">
            <span className="inline-flex items-center gap-2 rounded-full border border-border bg-muted px-3 py-1 text-xs font-medium text-muted-foreground mb-6">
              <Sparkles className="h-3.5 w-3.5 text-accent" />
              Bharat&apos;s community-powered innovation ecosystem
            </span>
            <h1 className="text-4xl md:text-6xl font-bold tracking-tight leading-[1.05]">
              Bharat&apos;s ideas don&apos;t need permission.
              <br />
              <span className="text-primary">They need a platform.</span>
            </h1>
            <p className="mt-6 text-lg md:text-xl text-muted-foreground max-w-2xl leading-relaxed">
              Inovers is where ideas meet people, people form Pods, and Pods
              execute real-world projects — government, private, community.
              Together.
            </p>
            <div className="mt-8 flex flex-col sm:flex-row items-center gap-3">
              <Link
                href="/waitlist"
                className="inline-flex h-12 items-center gap-2 rounded-full bg-primary px-7 text-base font-semibold text-primary-foreground hover:opacity-90 transition-opacity"
              >
                Join the Movement <ArrowRight className="h-4 w-4" />
              </Link>
              <Link
                href="/manifesto"
                className="inline-flex h-12 items-center rounded-full border border-border px-7 text-base font-semibold hover:bg-muted transition-colors"
              >
                Read the Manifesto
              </Link>
            </div>
            <div className="mt-10 flex items-center gap-6 text-xs text-muted-foreground">
              <div className="flex items-center gap-1.5"><ShieldCheck className="h-3.5 w-3.5" /> Public by default</div>
              <div className="flex items-center gap-1.5"><GraduationCap className="h-3.5 w-3.5" /> Students welcome</div>
              <div className="flex items-center gap-1.5"><Building2 className="h-3.5 w-3.5" /> Govt-ready</div>
            </div>
          </div>
        </div>
      </section>

      {/* PROBLEM */}
      <section className="container-page py-16 md:py-20">
        <div className="max-w-3xl mx-auto text-center">
          <h2 className="text-3xl md:text-4xl font-bold tracking-tight">
            Millions of ideas die in notebooks.
          </h2>
          <p className="mt-4 text-lg text-muted-foreground leading-relaxed">
            Thousands of innovators work alone. Institutions struggle to mobilize
            talent. Projects wait for permission. The gap between <em>thinking</em>{" "}
            and <em>shipping</em> has never been wider.
          </p>
          <p className="mt-4 text-lg font-semibold">
            Inovers closes that gap — through the community.
          </p>
        </div>
      </section>

      {/* HOW IT WORKS */}
      <section className="container-page py-16 md:py-20">
        <div className="text-center mb-12">
          <p className="text-sm font-semibold text-primary uppercase tracking-wider">
            The Inovers Way
          </p>
          <h2 className="mt-2 text-3xl md:text-4xl font-bold tracking-tight">
            Share. Collaborate. Execute.
          </h2>
        </div>
        <div className="grid gap-6 md:grid-cols-3">
          <Step
            icon={<Lightbulb className="h-6 w-6" />}
            step="01"
            title="Share your idea"
            body="Post a problem, a spark, a vision. Get feedback from innovators across Bharat. Refine it in the open."
          />
          <Step
            icon={<Users className="h-6 w-6" />}
            step="02"
            title="Form a Pod"
            body="When people say 'I&apos;m interested', a Pod forms. Skills combine. Roles emerge. Execution begins."
          />
          <Step
            icon={<Rocket className="h-6 w-6" />}
            step="03"
            title="Execute together"
            body="Real projects — including government initiatives — get delivered by community Pods. Transparent. Accountable. Credited."
          />
        </div>
      </section>

      {/* LIFECYCLE */}
      <section className="container-page py-16 md:py-20">
        <div className="rounded-3xl border border-border bg-muted/50 p-8 md:p-12">
          <div className="text-center mb-10">
            <h2 className="text-2xl md:text-3xl font-bold tracking-tight">
              How an idea becomes impact
            </h2>
            <p className="mt-2 text-muted-foreground">
              Six stages. Every one of them public.
            </p>
          </div>
          <div className="grid gap-4 md:grid-cols-6">
            {[
              { k: "Spark", d: "Idea is posted" },
              { k: "Validate", d: "Community refines" },
              { k: "Pod Form", d: "3+ innovators join" },
              { k: "Blueprint", d: "Plan is drafted" },
              { k: "Execute", d: "Weekly build logs" },
              { k: "Impact", d: "Outcome + credit" },
            ].map((s, i) => (
              <div
                key={s.k}
                className="rounded-xl border border-border bg-background p-4"
              >
                <div className="text-xs text-muted-foreground">Stage 0{i + 1}</div>
                <div className="mt-1 font-semibold">{s.k}</div>
                <div className="mt-1 text-xs text-muted-foreground">{s.d}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* GOVERNMENT */}
      <section id="government" className="container-page py-16 md:py-20">
        <div className="rounded-3xl bg-gradient-to-br from-primary to-[#1a1aff] p-8 md:p-12 text-primary-foreground">
          <div className="grid md:grid-cols-2 gap-8 items-center">
            <div>
              <span className="inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1 text-xs font-medium">
                <Building2 className="h-3.5 w-3.5" />
                For Government & Institutions
              </span>
              <h2 className="mt-4 text-3xl md:text-4xl font-bold tracking-tight">
                Mobilize 10,000 innovators for your initiative.
              </h2>
              <p className="mt-4 text-white/80 text-lg leading-relaxed">
                Post a project. Community Pods apply. Execution happens
                transparently, milestone by milestone. India-first, India-hosted,
                DPDP-ready.
              </p>
              <Link
                href="/waitlist"
                className="mt-6 inline-flex h-11 items-center gap-2 rounded-full bg-white px-6 text-sm font-semibold text-primary hover:bg-white/90 transition-colors"
              >
                Partner with Inovers <ArrowRight className="h-4 w-4" />
              </Link>
            </div>
            <div className="grid grid-cols-2 gap-3">
              {[
                "Atal Innovation Mission aligned",
                "Public Build Logs",
                "Section 8 ready",
                "DPDP Act compliant",
                "Milestone payouts",
                "Verified Innovators",
              ].map((item) => (
                <div
                  key={item}
                  className="rounded-xl bg-white/10 backdrop-blur px-4 py-3 text-sm font-medium"
                >
                  {item}
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* CLOSING CTA */}
      <section className="container-page py-20 md:py-28">
        <div className="max-w-2xl mx-auto text-center">
          <h2 className="text-3xl md:text-5xl font-bold tracking-tight leading-tight">
            An idea is a spark.
            <br />
            <span className="text-accent">A community turns it into fire.</span>
          </h2>
          <p className="mt-6 text-lg text-muted-foreground">
            Be one of the first 1,000 Founding Innovators. Permanent badge.
            Lifetime recognition.
          </p>
          <Link
            href="/waitlist"
            className="mt-8 inline-flex h-12 items-center gap-2 rounded-full bg-primary px-7 text-base font-semibold text-primary-foreground hover:opacity-90 transition-opacity"
          >
            Become an Innovator <ArrowRight className="h-4 w-4" />
          </Link>
        </div>
      </section>
    </>
  );
}

function Step({
  icon,
  step,
  title,
  body,
}: {
  icon: React.ReactNode;
  step: string;
  title: string;
  body: string;
}) {
  return (
    <div className="group rounded-2xl border border-border bg-background p-6 hover:border-primary transition-colors">
      <div className="flex items-center justify-between mb-4">
        <div className="h-10 w-10 rounded-xl bg-primary/10 text-primary flex items-center justify-center">
          {icon}
        </div>
        <span className="text-xs font-mono text-muted-foreground">{step}</span>
      </div>
      <h3 className="text-lg font-semibold">{title}</h3>
      <p className="mt-2 text-sm text-muted-foreground leading-relaxed">{body}</p>
    </div>
  );
}
