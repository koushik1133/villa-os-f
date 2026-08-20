import type { Metadata } from "next";
import AppShell from "./layout-shell";
import "./globals.css";

export const metadata: Metadata = {
  title: "VillaOS — Luxury Villa Business OS",
  description:
    "AI sales agent, CRM, marketing studio and revenue intelligence for premium villa developers.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      {/* AppShell owns the sidebar, topbar, command palette and <main>. It
          early-returns bare children on /login, where the chrome would be
          nothing but links that bounce back to the login form. */}
      <body className="min-h-screen">
        <AppShell>{children}</AppShell>
      </body>
    </html>
  );
}
