import { db } from "./supabase";

/**
 * Team roster, per-rep performance, and lead ownership.
 *
 * Writes return a result object instead of throwing, so a plain form POST can
 * show the failure on the page rather than blowing up into a 500.
 * Schema: supabase/migrations/0009_business_os.sql.
 */

export type TeamRole =
  | "owner"
  | "admin"
  | "manager"
  | "sales_manager"
  | "sales_agent"
  | "marketing_manager"
  | "marketing_agent"
  | "viewer";

export const TEAM_ROLES: TeamRole[] = [
  "owner",
  "admin",
  "manager",
  "sales_manager",
  "sales_agent",
  "marketing_manager",
  "marketing_agent",
  "viewer",
];

export const ROLE_LABELS: Record<TeamRole, string> = {
  owner: "Owner",
  admin: "Admin",
  manager: "Manager",
  sales_manager: "Sales Manager",
  sales_agent: "Sales Agent",
  marketing_manager: "Marketing Manager",
  marketing_agent: "Marketing Agent",
  viewer: "Viewer",
};

/** Only these roles are ever handed a lead by round-robin. */
export const SALES_ROLES: TeamRole[] = ["sales_manager", "sales_agent"];

const ROLE_SET = new Set<string>(TEAM_ROLES);

export function isTeamRole(value: string): value is TeamRole {
  return ROLE_SET.has(value);
}

export const DEPARTMENTS = ["sales", "marketing", "operations", "management"];

export interface TeamMember {
  id: string;
  name: string;
  email: string | null;
  phone: string | null;
  role: TeamRole;
  department: string;
  is_active: boolean;
  accepts_leads: boolean;
  joined_at: string;
  created_at: string;
}

export interface TeamPerformance {
  id: string;
  name: string;
  role: TeamRole;
  department: string;
  assigned_leads: number;
  hot_leads: number;
  site_visits: number;
  bookings: number;
  revenue_inr: number;
  conversion_rate: number | null;
}

export type WriteResult = { ok: true } | { ok: false; error: string };

export async function listTeamMembers(): Promise<TeamMember[]> {
  const { data } = await db()
    .from("villa_team_members")
    .select("*")
    .order("is_active", { ascending: false })
    .order("name", { ascending: true });
  return (data ?? []) as TeamMember[];
}

/** Reads the villa_team_performance view — every number is an aggregate of real rows. */
export async function teamPerformance(): Promise<TeamPerformance[]> {
  const { data } = await db()
    .from("villa_team_performance")
    .select("*")
    .order("revenue_inr", { ascending: false });

  return (data ?? []).map((row) => {
    const r = row as Record<string, unknown>;
    return {
      id: String(r.id),
      name: String(r.name ?? ""),
      role: r.role as TeamRole,
      department: String(r.department ?? ""),
      assigned_leads: Number(r.assigned_leads ?? 0),
      hot_leads: Number(r.hot_leads ?? 0),
      site_visits: Number(r.site_visits ?? 0),
      bookings: Number(r.bookings ?? 0),
      revenue_inr: Number(r.revenue_inr ?? 0),
      conversion_rate: r.conversion_rate === null || r.conversion_rate === undefined
        ? null
        : Number(r.conversion_rate),
    };
  });
}

export interface NewTeamMember {
  name: string;
  email?: string | null;
  phone?: string | null;
  role?: string;
  department?: string;
  acceptsLeads?: boolean;
}

export async function createTeamMember(
  input: NewTeamMember,
): Promise<{ ok: true; id: string } | { ok: false; error: string }> {
  const name = input.name?.trim();
  if (!name) return { ok: false, error: "Name is required" };

  const role = input.role?.trim() || "sales_agent";
  if (!isTeamRole(role)) return { ok: false, error: `Unknown role: ${role}` };

  const department = input.department?.trim() || (role.startsWith("marketing") ? "marketing" : "sales");

  const { data, error } = await db()
    .from("villa_team_members")
    .insert({
      name,
      email: input.email?.trim() || null,
      phone: input.phone?.trim() || null,
      role,
      department,
      accepts_leads: input.acceptsLeads ?? true,
    })
    .select("id")
    .single();

  if (error) return { ok: false, error: error.message };
  return { ok: true, id: String((data as { id: string }).id) };
}

/** Flips is_active. An inactive member drops out of round-robin automatically. */
export async function toggleActive(id: string): Promise<WriteResult> {
  if (!id) return { ok: false, error: "Team member id is required" };

  const { data, error } = await db()
    .from("villa_team_members")
    .select("is_active")
    .eq("id", id)
    .maybeSingle();
  if (error) return { ok: false, error: error.message };
  if (!data) return { ok: false, error: "Team member not found" };

  const next = !(data as { is_active: boolean }).is_active;
  const { error: updateError } = await db()
    .from("villa_team_members")
    .update({ is_active: next })
    .eq("id", id);
  if (updateError) return { ok: false, error: updateError.message };
  return { ok: true };
}

/** Pass null to unassign. */
export async function assignLead(leadId: string, memberId: string | null): Promise<WriteResult> {
  if (!leadId) return { ok: false, error: "leadId is required" };

  if (memberId) {
    const { data, error } = await db()
      .from("villa_team_members")
      .select("id, is_active")
      .eq("id", memberId)
      .maybeSingle();
    if (error) return { ok: false, error: error.message };
    if (!data) return { ok: false, error: "Team member not found" };
    if (!(data as { is_active: boolean }).is_active) {
      return { ok: false, error: "Cannot assign a lead to an inactive team member" };
    }
  }

  const { error } = await db()
    .from("villa_leads")
    .update({ assigned_to: memberId })
    .eq("id", leadId);
  if (error) return { ok: false, error: error.message };
  return { ok: true };
}

/**
 * Gives a lead the sales member carrying the fewest open leads.
 *
 * "Open" excludes booked and lost: a rep who closed fifty deals has capacity
 * again, so balancing on lifetime volume would starve the best closer.
 */
export async function roundRobinAssign(
  leadId: string,
): Promise<{ ok: true; memberId: string; memberName: string } | { ok: false; error: string }> {
  if (!leadId) return { ok: false, error: "leadId is required" };

  const { data: lead, error: leadError } = await db()
    .from("villa_leads")
    .select("id, assigned_to")
    .eq("id", leadId)
    .maybeSingle();
  if (leadError) return { ok: false, error: leadError.message };
  if (!lead) return { ok: false, error: "Lead not found" };

  const { data: members, error: memberError } = await db()
    .from("villa_team_members")
    .select("id, name")
    .eq("is_active", true)
    .eq("accepts_leads", true)
    .in("role", SALES_ROLES)
    .order("joined_at", { ascending: true });
  if (memberError) return { ok: false, error: memberError.message };

  const eligible = (members ?? []) as Array<{ id: string; name: string }>;
  if (eligible.length === 0) {
    return { ok: false, error: "No active sales member is currently accepting leads" };
  }

  // Re-running this on an already-owned lead must not move it: the customer is
  // mid-conversation with that rep.
  const currentOwner = eligible.find((m) => m.id === (lead as { assigned_to: string | null }).assigned_to);
  if (currentOwner) return { ok: true, memberId: currentOwner.id, memberName: currentOwner.name };

  const { data: openLeads, error: loadError } = await db()
    .from("villa_leads")
    .select("assigned_to")
    .not("assigned_to", "is", null)
    .not("pipeline_stage", "in", "(booked,lost)");
  if (loadError) return { ok: false, error: loadError.message };

  const load = new Map<string, number>(eligible.map((m) => [m.id, 0]));
  for (const row of (openLeads ?? []) as Array<{ assigned_to: string | null }>) {
    const owner = row.assigned_to;
    if (owner && load.has(owner)) load.set(owner, (load.get(owner) ?? 0) + 1);
  }

  // reduce() keeps the first minimum, and members are ordered by joined_at, so
  // ties resolve to the longest-serving rep rather than at random.
  const winner = eligible.reduce(
    (best, m) => ((load.get(m.id) ?? 0) < (load.get(best.id) ?? 0) ? m : best),
    eligible[0],
  );

  const assigned = await assignLead(leadId, winner.id);
  if (!assigned.ok) return assigned;
  return { ok: true, memberId: winner.id, memberName: winner.name };
}
