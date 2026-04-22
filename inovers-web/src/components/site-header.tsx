import Link from "next/link";

export function SiteHeader() {
  return (
    <header className="border-b border-border bg-background/80 backdrop-blur sticky top-0 z-40">
      <div className="container-page flex h-16 items-center justify-between">
        <Link href="/" className="flex items-center gap-2">
          <div className="h-8 w-8 rounded-lg bg-primary flex items-center justify-center text-primary-foreground font-bold">
            i
          </div>
          <span className="font-semibold tracking-tight text-lg">Inovers</span>
        </Link>
        <nav className="hidden md:flex items-center gap-8 text-sm">
          <Link href="/ideas" className="hover:text-primary transition-colors">
            Ideas
          </Link>
          <Link
            href="/manifesto"
            className="hover:text-primary transition-colors"
          >
            Manifesto
          </Link>
          <Link href="/#government" className="hover:text-primary transition-colors">
            Government
          </Link>
        </nav>
        <div className="flex items-center gap-3">
          <Link
            href="/waitlist"
            className="hidden sm:inline-flex h-9 items-center rounded-full border border-border px-4 text-sm font-medium hover:bg-muted transition-colors"
          >
            Join Waitlist
          </Link>
          <Link
            href="/waitlist"
            className="inline-flex h-9 items-center rounded-full bg-primary px-4 text-sm font-medium text-primary-foreground hover:opacity-90 transition-opacity"
          >
            Become an Innovator
          </Link>
        </div>
      </div>
    </header>
  );
}
