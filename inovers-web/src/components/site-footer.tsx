import Link from "next/link";

export function SiteFooter() {
  return (
    <footer className="border-t border-border bg-muted/40 mt-16">
      <div className="container-page py-12">
        <div className="grid gap-10 md:grid-cols-4">
          <div className="md:col-span-2">
            <div className="flex items-center gap-2 mb-4">
              <div className="h-8 w-8 rounded-lg bg-primary flex items-center justify-center text-primary-foreground font-bold">
                i
              </div>
              <span className="font-semibold tracking-tight text-lg">
                Inovers
              </span>
            </div>
            <p className="text-sm text-muted-foreground max-w-sm leading-relaxed">
              Bharat&apos;s community-powered innovation ecosystem. Ideas.
              Collaboration. Execution.
            </p>
          </div>
          <div>
            <h4 className="font-semibold text-sm mb-3">Platform</h4>
            <ul className="space-y-2 text-sm text-muted-foreground">
              <li><Link href="/ideas" className="hover:text-foreground">Ideas</Link></li>
              <li><Link href="/waitlist" className="hover:text-foreground">Waitlist</Link></li>
              <li><Link href="/manifesto" className="hover:text-foreground">Manifesto</Link></li>
            </ul>
          </div>
          <div>
            <h4 className="font-semibold text-sm mb-3">For Institutions</h4>
            <ul className="space-y-2 text-sm text-muted-foreground">
              <li><Link href="/#government" className="hover:text-foreground">Government</Link></li>
              <li><Link href="/#government" className="hover:text-foreground">Universities</Link></li>
              <li><Link href="/#government" className="hover:text-foreground">Partners</Link></li>
            </ul>
          </div>
        </div>
        <div className="mt-10 pt-6 border-t border-border flex flex-col md:flex-row items-start md:items-center justify-between gap-3 text-xs text-muted-foreground">
          <p>© {new Date().getFullYear()} Inovers. Built by the community, for the community.</p>
          <p>अपनी सोच, अपना देश.</p>
        </div>
      </div>
    </footer>
  );
}
