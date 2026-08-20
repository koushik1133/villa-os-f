import {
  Activity,
  Bell,
  Bot,
  Brain,
  Building2,
  ChartColumn,
  Clock,
  Contact,
  FilePen,
  FileText,
  Funnel,
  GitBranch,
  Grid3x3,
  House,
  Inbox,
  IndianRupee,
  LayoutDashboard,
  Mail,
  MapPin,
  Megaphone,
  MessageCircle,
  MessageSquare,
  Plug,
  Ruler,
  Settings,
  Share2,
  Shield,
  Sparkle,
  Sparkles,
  SquareCheck,
  SquareKanban,
  Target,
  TrendingUp,
  Trophy,
  UserCheck,
  Users,
  WandSparkles,
  Workflow,
  type LucideIcon,
} from "lucide-react";

/**
 * The one nav definition. Sidebar, command palette and mobile drawer all read
 * from here so a route can never exist in one surface and not the others.
 *
 * lucide-react 1.x dropped the old numeric/positional icon aliases, so a few
 * names differ from the ones you'd reach for from memory:
 * SquareKanban (KanbanSquare), SquareCheck (CheckSquare), FilePen
 * (FileSignature), House (Home), WandSparkles (Wand2), ChartColumn (BarChart3),
 * Funnel (Filter).
 */

export interface NavItem {
  href: string;
  label: string;
  icon: LucideIcon;
  /** Extra command-palette search terms that don't belong in the visible label. */
  keywords?: string[];
}

export interface NavGroup {
  label: string;
  items: NavItem[];
}

export const NAV_GROUPS: NavGroup[] = [
  {
    label: "Overview",
    items: [{ href: "/", label: "Dashboard", icon: LayoutDashboard, keywords: ["home", "today"] }],
  },
  {
    label: "AI",
    items: [
      { href: "/ai/copilot", label: "Copilot", icon: Sparkles, keywords: ["ask", "chat", "assistant"] },
      { href: "/ai/insights", label: "Insights", icon: Brain, keywords: ["signals", "analysis"] },
      {
        href: "/ai/lead-intelligence",
        label: "Lead Intelligence",
        icon: Target,
        keywords: ["scoring", "intent", "objections"],
      },
      {
        href: "/ai/recommendations",
        label: "Recommendations",
        icon: TrendingUp,
        keywords: ["next best action", "suggestions"],
      },
    ],
  },
  {
    label: "CRM",
    items: [
      { href: "/crm/leads", label: "Leads", icon: Users, keywords: ["enquiries", "prospects"] },
      { href: "/crm/pipeline", label: "Pipeline", icon: SquareKanban, keywords: ["kanban", "stages", "deals"] },
      { href: "/crm/contacts", label: "Contacts", icon: Contact, keywords: ["people", "phone"] },
      { href: "/crm/customers", label: "Customers", icon: UserCheck, keywords: ["buyers", "owners"] },
      { href: "/crm/tasks", label: "Tasks", icon: SquareCheck, keywords: ["todo", "assignments"] },
      { href: "/crm/follow-ups", label: "Follow-ups", icon: Clock, keywords: ["reminders", "due", "overdue"] },
    ],
  },
  {
    label: "Sales",
    items: [
      { href: "/sales/site-visits", label: "Site Visits", icon: MapPin, keywords: ["tours", "walkthrough"] },
      { href: "/sales/bookings", label: "Bookings", icon: FilePen, keywords: ["agreements", "sold", "tokens"] },
      { href: "/sales/revenue", label: "Revenue", icon: IndianRupee, keywords: ["collections", "value", "gmv"] },
      { href: "/sales/team", label: "Team Performance", icon: Trophy, keywords: ["reps", "leaderboard", "quota"] },
    ],
  },
  {
    label: "Properties",
    items: [
      { href: "/properties/projects", label: "Projects", icon: Building2, keywords: ["developments"] },
      { href: "/properties/villas", label: "Villas", icon: House, keywords: ["units", "types", "homes"] },
      { href: "/properties/inventory", label: "Inventory", icon: Grid3x3, keywords: ["availability", "stock", "plots"] },
      { href: "/properties/floor-plans", label: "Floor Plans", icon: Ruler, keywords: ["layouts", "sqft", "drawings"] },
      { href: "/properties/amenities", label: "Amenities", icon: Sparkle, keywords: ["clubhouse", "facilities"] },
    ],
  },
  {
    label: "Marketing",
    items: [
      { href: "/marketing/studio", label: "Content Studio", icon: WandSparkles, keywords: ["generate", "copy", "creative"] },
      { href: "/marketing/overview", label: "Overview", icon: ChartColumn, keywords: ["performance", "spend"] },
      { href: "/marketing/campaigns", label: "Campaigns", icon: Megaphone, keywords: ["ads", "meta", "google"] },
      { href: "/marketing/broadcasts", label: "Broadcasts", icon: Megaphone, keywords: ["templates", "blast", "bulk", "drip"] },
      { href: "/marketing/whatsapp", label: "WhatsApp Analytics", icon: MessageCircle, keywords: ["templates", "stats"] },
    ],
  },
  {
    label: "Communication",
    items: [
      { href: "/communication/inbox", label: "Inbox", icon: Inbox, keywords: ["unified", "threads", "messages"] },
      { href: "/communication/whatsapp", label: "WhatsApp", icon: MessageSquare, keywords: ["chats", "conversations"] },
      { href: "/communication/email", label: "Email", icon: Mail, keywords: ["mail", "outbound"] },
    ],
  },
  {
    label: "Automation",
    items: [
      { href: "/automation/workflows", label: "Workflows", icon: Workflow, keywords: ["rules", "triggers", "sequences"] },
      { href: "/automation/routing", label: "Routing", icon: Share2, keywords: ["assignment", "round robin"] },
      { href: "/automation/notifications", label: "Notifications", icon: Bell, keywords: ["alerts", "handoffs"] },
    ],
  },
  {
    label: "Analytics",
    items: [
      { href: "/analytics/attribution", label: "Attribution", icon: GitBranch, keywords: ["sources", "channels", "utm"] },
      { href: "/analytics/funnel", label: "Funnel", icon: Funnel, keywords: ["conversion", "drop off"] },
      { href: "/analytics/sales", label: "Sales Analytics", icon: Activity, keywords: ["velocity", "trends"] },
      { href: "/analytics/reports", label: "Reports", icon: FileText, keywords: ["export", "csv", "download"] },
    ],
  },
  {
    label: "System",
    items: [
      { href: "/settings", label: "Settings", icon: Settings, keywords: ["preferences", "config"] },
      { href: "/settings/team", label: "Team & Roles", icon: Shield, keywords: ["users", "permissions", "access"] },
      { href: "/settings/integrations", label: "Integrations", icon: Plug, keywords: ["api keys", "webhooks", "meta"] },
      { href: "/whatsapp", label: "WhatsApp Setup", icon: MessageCircle, keywords: ["go live", "webhook", "meta", "voice", "readiness"] },
      { href: "/simulator", label: "Simulator", icon: Bot, keywords: ["test", "sandbox", "agent"] },
    ],
  },
];

export interface FlatNavItem extends NavItem {
  group: string;
}

/** Flattened once at module scope — the palette re-filters this on every keystroke. */
export const NAV_ITEMS: FlatNavItem[] = NAV_GROUPS.flatMap((group) =>
  group.items.map((item) => ({ ...item, group: group.label })),
);

/**
 * Longest-prefix match, not a per-link `startsWith`.
 *
 * `/settings/team` is a prefix match for both `/settings` and itself; picking
 * the longest href means exactly one link ever highlights.
 */
export function activeHref(pathname: string): string | null {
  let best: string | null = null;
  for (const item of NAV_ITEMS) {
    const matches =
      item.href === "/" ? pathname === "/" : pathname === item.href || pathname.startsWith(`${item.href}/`);
    if (matches && (best === null || item.href.length > best.length)) best = item.href;
  }
  return best;
}

// -----------------------------------------------------------------------------
// Date range
// -----------------------------------------------------------------------------

export const RANGE_KEYS = ["7d", "30d", "90d", "ytd", "all"] as const;
export type RangeKey = (typeof RANGE_KEYS)[number];

export const RANGE_PRESETS: { key: RangeKey; label: string; short: string }[] = [
  { key: "7d", label: "Last 7 days", short: "7D" },
  { key: "30d", label: "Last 30 days", short: "30D" },
  { key: "90d", label: "Last 90 days", short: "90D" },
  { key: "ytd", label: "Year to date", short: "YTD" },
  { key: "all", label: "All time", short: "ALL" },
];

export const DEFAULT_RANGE: RangeKey = "30d";

/** Narrows an untrusted `?range=` value; anything unrecognised falls back. */
export function parseRange(value: string | string[] | undefined | null): RangeKey {
  const raw = Array.isArray(value) ? value[0] : value;
  return RANGE_KEYS.includes(raw as RangeKey) ? (raw as RangeKey) : DEFAULT_RANGE;
}

export function rangeLabel(range: string): string {
  const key = parseRange(range);
  return RANGE_PRESETS.find((p) => p.key === key)!.label;
}

/**
 * Lookback window in days, or null for all time.
 *
 * Every page filters on this rather than rolling its own arithmetic, so "last
 * 30 days" means the same thing on the funnel as it does on revenue. YTD is
 * computed from the calendar year rather than fixed at 365 — on 12 January it
 * must mean twelve days, not the previous January.
 */
export function rangeToDays(range: string): number | null {
  const key = parseRange(range);
  if (key === "all") return null;
  if (key === "ytd") {
    const now = new Date();
    const jan1 = new Date(now.getFullYear(), 0, 1);
    return Math.max(1, Math.ceil((now.getTime() - jan1.getTime()) / 86_400_000));
  }
  return { "7d": 7, "30d": 30, "90d": 90 }[key];
}

/** ISO timestamp for the start of the window, or null for all time. */
export function rangeStartIso(range: string): string | null {
  const days = rangeToDays(range);
  if (days === null) return null;
  return new Date(Date.now() - days * 86_400_000).toISOString();
}
