"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useMemo, useState } from "react";
import { ChevronDown, LogOut } from "lucide-react";
import { NAV_GROUPS, activeHref } from "./nav-config";

/**
 * The sidebar panel: wordmark, grouped nav, sign out.
 *
 * Rendered twice — once in the fixed desktop rail, once inside the mobile
 * drawer — so it owns no positioning of its own. Collapse state is per
 * instance, which is fine because only one is ever visible at a time.
 */
export default function Sidebar({ onNavigate }: { onNavigate?: () => void }) {
  const pathname = usePathname();
  const active = useMemo(() => activeHref(pathname), [pathname]);
  const [collapsed, setCollapsed] = useState<Record<string, boolean>>({});

  function toggle(label: string) {
    setCollapsed((prev) => ({ ...prev, [label]: !prev[label] }));
  }

  return (
    <div className="flex h-full flex-col bg-[--color-canvas]">
      <div className="shrink-0 px-5 pb-4 pt-5">
        <Link href="/" onClick={onNavigate} className="flex items-center gap-2.5">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl border border-[--color-gold-line] bg-[--color-gold-soft] font-[family-name:--font-display] text-[15px] leading-none text-[--color-gold-300]">
            V
          </span>
          <span className="min-w-0">
            <span className="block font-[family-name:--font-display] text-[18px] leading-none tracking-tight text-[--color-gold-300]">
              VillaOS
            </span>
            <span className="mt-1.5 block text-[9px] font-semibold uppercase tracking-[0.18em] text-[--color-faint]">
              Business OS
            </span>
          </span>
        </Link>
      </div>

      <div className="hairline-gold mx-5 h-px shrink-0" />

      <nav className="min-h-0 flex-1 overflow-y-auto px-3 py-4">
        <ul className="space-y-4">
          {NAV_GROUPS.map((group) => {
            const isCollapsed = collapsed[group.label] === true;
            const groupHasActive = group.items.some((item) => item.href === active);

            return (
              <li key={group.label}>
                <button
                  type="button"
                  onClick={() => toggle(group.label)}
                  aria-expanded={!isCollapsed}
                  className="group flex w-full items-center justify-between rounded-lg px-3 py-1.5 text-left transition hover:bg-[--color-raised]"
                >
                  <span
                    className={`label transition-colors ${
                      groupHasActive ? "text-[--color-gold-500]" : "group-hover:text-[--color-muted]"
                    }`}
                  >
                    {group.label}
                  </span>
                  <ChevronDown
                    size={13}
                    strokeWidth={2.5}
                    aria-hidden
                    className={`shrink-0 text-[--color-faint] transition-transform duration-200 ${
                      isCollapsed ? "-rotate-90" : ""
                    }`}
                  />
                </button>

                {!isCollapsed && (
                  <ul className="mt-1 space-y-0.5">
                    {group.items.map((item) => {
                      const isActive = item.href === active;
                      const Icon = item.icon;
                      return (
                        <li key={item.href}>
                          <Link
                            href={item.href}
                            onClick={onNavigate}
                            aria-current={isActive ? "page" : undefined}
                            className={`nav-link ${isActive ? "nav-link-active" : ""}`}
                          >
                            <Icon
                              size={15}
                              strokeWidth={1.75}
                              aria-hidden
                              className={`shrink-0 ${isActive ? "" : "text-[--color-faint]"}`}
                            />
                            <span className="truncate">{item.label}</span>
                          </Link>
                        </li>
                      );
                    })}
                  </ul>
                )}
              </li>
            );
          })}
        </ul>
      </nav>

      {/*
        A form POST, not a link: the logout route is POST-only so a third-party
        <img src=".../api/auth/logout"> can't sign a rep out mid-conversation.
      */}
      <form
        action="/api/auth/logout"
        method="POST"
        className="shrink-0 border-t border-[--color-line] p-3"
      >
        <button
          type="submit"
          className="nav-link w-full hover:text-[--color-danger]"
        >
          <LogOut size={15} strokeWidth={1.75} aria-hidden className="shrink-0 text-[--color-faint]" />
          Sign out
        </button>
      </form>
    </div>
  );
}
