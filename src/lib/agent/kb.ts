import { db } from "../supabase";
import type { Faq, Project, VillaType } from "../types";

/**
 * The knowledge-base snapshot that gets baked into the cached prompt prefix.
 *
 * Rendering is deterministic on purpose — fixed field order, sorted lists, no
 * JSON.stringify of arbitrary objects — because any byte that moves between
 * requests invalidates the prompt cache for every customer at once.
 *
 * Detail beyond this summary is fetched on demand through tools; this block is
 * only what the agent needs constantly in view to stay grounded.
 */

const TTL_MS = 10 * 60 * 1000;

let cached: { text: string; at: number } | null = null;

export interface KbBundle {
  projects: Project[];
  villaTypes: VillaType[];
  faqs: Faq[];
}

export async function loadKb(): Promise<KbBundle> {
  const supabase = db();

  const [projects, villaTypes, faqs] = await Promise.all([
    supabase.from("villa_projects").select("*").eq("is_active", true).order("slug"),
    supabase.from("villa_types").select("*").eq("is_active", true).order("name"),
    supabase.from("villa_faqs").select("*").order("question"),
  ]);

  if (projects.error) throw new Error(`Knowledge base unavailable: ${projects.error.message}`);

  return {
    projects: (projects.data ?? []) as Project[],
    villaTypes: (villaTypes.data ?? []) as VillaType[],
    faqs: (faqs.data ?? []) as Faq[],
  };
}

function money(inr: number | null): string {
  if (inr === null || inr === undefined) return "NOT RECORDED — sales team must confirm";
  return `₹${(inr / 10000000).toFixed(2)} Cr (₹${inr.toLocaleString("en-IN")})`;
}

function list(values: unknown): string {
  if (!Array.isArray(values)) return "";
  return values
    .map((v) => (typeof v === "string" ? v : JSON.stringify(v)))
    .join("; ");
}

/** Renders a nested amenities/specs object as stable, readable lines. */
function renderObject(obj: unknown, indent = "  "): string {
  if (!obj || typeof obj !== "object") return "";
  const entries = Object.entries(obj as Record<string, unknown>);
  const lines: string[] = [];
  for (const [key, value] of entries) {
    const label = key.replace(/_/g, " ");
    if (Array.isArray(value)) {
      lines.push(`${indent}${label}: ${list(value)}`);
    } else if (value && typeof value === "object") {
      lines.push(`${indent}${label}:`);
      lines.push(renderObject(value, indent + "  "));
    } else if (value !== null && value !== undefined) {
      lines.push(`${indent}${label}: ${String(value)}`);
    }
  }
  return lines.filter(Boolean).join("\n");
}

function renderProject(p: Project, types: VillaType[], faqs: Faq[]): string {
  const mine = types.filter((t) => t.project_id === p.id);
  const myFaqs = faqs.filter((f) => f.project_id === p.id || f.project_id === null);

  const location = [p.survey_no, p.village, p.mandal, p.district, p.state, p.pincode]
    .filter(Boolean)
    .join(", ");

  const typeLines = mine.length
    ? mine
        .map((t) => {
          const bits = [
            t.plot_area_sqyd ? `${t.plot_area_sqyd} sq yd plot` : null,
            t.built_up_sft ? `${t.built_up_sft} SFT built-up` : null,
            t.facing ? `${t.facing} facing` : null,
            t.bedrooms ? `${t.bedrooms} BHK` : "bedroom count NOT RECORDED",
            t.floors ? `${t.floors} floors` : null,
            t.has_home_theatre ? "home theatre" : null,
          ].filter(Boolean);
          const note = t.verification_note ? `\n      note: ${t.verification_note}` : "";
          return `    - ${t.name}: ${bits.join(", ")}. Price: ${money(t.price_inr)}${note}`;
        })
        .join("\n")
    : "    (no villa types recorded)";

  const faqLines = myFaqs.length
    ? myFaqs.map((f) => `    Q: ${f.question}\n    A: ${f.answer}`).join("\n")
    : "    (none)";

  return `## ${p.name}

  Status: ${p.status ?? "not recorded"}
  Expected delivery: ${p.expected_delivery ?? "not recorded"}
  Location: ${location || "not recorded"}
  HMDA permit: ${p.hmda_permit_no ?? "not recorded"}${p.hmda_permit_date ? ` dated ${p.hmda_permit_date}` : ""}
  RERA: ${p.rera_number ?? p.rera_status ?? "not recorded"}
  Land area: ${p.total_land_acres ? `${p.total_land_acres} acres` : "not recorded"}
  Total villas: ${p.total_units ?? "not recorded"}
  Configurations: ${p.configurations?.join(", ") ?? "not recorded"}
  Starting price: ${money(p.starting_price_inr)}
  Price note: ${p.price_note ?? "none"}

  Positioning: ${p.positioning ?? "not recorded"}

  Key selling points:
${Array.isArray(p.usps) ? (p.usps as string[]).map((u) => `    - ${u}`).join("\n") : "    (none)"}

  Villa types:
${typeLines}

  Amenities:
${renderObject(p.amenities)}

  Specifications:
${renderObject(p.specifications)}

  Sustainability:
${renderObject(p.sustainability)}

  Connectivity (developer-published estimates — always add that actual travel time varies with traffic):
${
  Array.isArray(p.connectivity)
    ? (p.connectivity as Array<{ place: string; distance_km?: string; minutes?: string }>)
        .map((c) => {
          const bits = [
            c.distance_km ? `approx ${c.distance_km} km` : null,
            c.minutes ? `approx ${c.minutes} min drive` : null,
          ].filter(Boolean);
          return `    - ${c.place}: ${bits.join(", ") || "distance not recorded"}`;
        })
        .join("\n")
    : "    (none)"
}

  Social infrastructure:
${renderObject(p.social_infrastructure)}

  Home loan partners: ${p.financing_partners?.join(", ") ?? "not recorded"}

  Frequently asked:
${faqLines}`;
}

/**
 * Returns the rendered knowledge base, memoised for TTL_MS.
 *
 * The memo matters for cost as much as latency: a stable string keeps the
 * prompt-cache prefix intact between requests.
 */
export async function knowledgeBaseBlock(): Promise<string> {
  if (cached && Date.now() - cached.at < TTL_MS) return cached.text;

  const { projects, villaTypes, faqs } = await loadKb();

  const body = projects.length
    ? projects.map((p) => renderProject(p, villaTypes, faqs)).join("\n\n")
    : "(No projects are loaded. Tell the customer you will have the sales team assist them, and do not describe any property.)";

  const text = `# APPROVED KNOWLEDGE BASE

Everything below is approved for you to state to a customer. Nothing outside it is.

Where a field reads "not recorded" or "NOT RECORDED", that fact is not approved for you to state. Do not infer it, do not estimate it, do not reason it out from other fields. Tell the customer the sales team will confirm, and log it.

${body}

# END OF APPROVED KNOWLEDGE BASE`;

  cached = { text, at: Date.now() };
  return text;
}

/** Call after editing project data so the next reply reflects it. */
export function invalidateKbCache(): void {
  cached = null;
}
