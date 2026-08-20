import { NextResponse } from "next/server";
import { revalidatePath } from "next/cache";
import { readPost, respond, safePath, type ActionResult } from "@/lib/form-post";
import { assignLead, createTeamMember, roundRobinAssign, toggleActive } from "@/lib/team";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Team roster writes: add a member, activate/deactivate one, own a lead.
 *
 * `assign` takes two sentinels in memberId so the caller never has to hit a
 * different endpoint: "auto" runs round-robin, "none" clears the owner.
 */
export async function POST(request: Request) {
  const body = await readPost(request);
  const action = body.get("action");
  const redirectTo = safePath(body.get("next"), "/sales/team");

  let result: ActionResult;

  switch (action) {
    case "create": {
      result = await createTeamMember({
        name: body.get("name") ?? "",
        email: body.get("email") ?? null,
        phone: body.get("phone") ?? null,
        role: body.get("role"),
        department: body.get("department"),
        acceptsLeads: body.bool("acceptsLeads"),
      });
      break;
    }

    case "toggle": {
      const id = body.get("id");
      if (!id) {
        return NextResponse.json({ error: "id is required" }, { status: 400 });
      }
      result = await toggleActive(id);
      break;
    }

    case "assign": {
      const leadId = body.get("leadId");
      if (!leadId) {
        return NextResponse.json({ error: "leadId is required" }, { status: 400 });
      }
      const memberId = body.get("memberId");
      if (memberId === "auto") {
        result = await roundRobinAssign(leadId);
      } else {
        result = await assignLead(leadId, memberId === "none" || !memberId ? null : memberId);
      }
      break;
    }

    default:
      return NextResponse.json(
        { error: "action must be one of create, toggle, assign" },
        { status: 400 },
      );
  }

  if (result.ok) {
    revalidatePath("/sales/team");
    revalidatePath("/crm/leads");
  }

  return respond(request, body, redirectTo, result);
}
