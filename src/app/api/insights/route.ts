import { NextResponse } from "next/server";
import { revalidatePath } from "next/cache";
import { dismissInsight, generateInsights } from "@/lib/insights";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Regenerates or dismisses insights.
 *
 * Accepts a plain form POST (the /insights buttons, so both work with zero
 * client JS) or a JSON body for anything scripted — a cron could hit this the
 * same way the page does.
 */
export async function POST(request: Request) {
  const contentType = request.headers.get("content-type") ?? "";
  const isJson = contentType.includes("application/json");

  let action: unknown;
  let id: unknown;

  if (isJson) {
    const body = await request.json().catch(() => ({}) as Record<string, unknown>);
    action = body.action;
    id = body.id;
  } else {
    const form = await request.formData();
    action = form.get("action");
    id = form.get("id");
  }

  const respond = (payload: Record<string, unknown>, status = 200) => {
    if (!isJson) {
      return NextResponse.redirect(new URL("/ai/insights", request.url), { status: 303 });
    }
    return NextResponse.json(payload, { status });
  };

  if (action === "dismiss") {
    if (typeof id !== "string" || !id) {
      return NextResponse.json({ error: "id is required to dismiss" }, { status: 400 });
    }
    const result = await dismissInsight(id);
    revalidatePath("/ai/insights");
    return result.ok ? respond({ ok: true }) : respond({ error: result.error }, 500);
  }

  if (action === "generate" || action === undefined || action === null || action === "") {
    const result = await generateInsights();
    revalidatePath("/ai/insights");
    if (!result.ok) return respond({ error: result.error }, 500);
    return respond({
      ok: true,
      inserted: result.inserted,
      updated: result.updated,
      removed: result.removed,
      suppressed: result.suppressed,
      generatedByAi: result.aiCount,
      signals: result.signals,
    });
  }

  return NextResponse.json({ error: `unknown action: ${String(action)}` }, { status: 400 });
}
