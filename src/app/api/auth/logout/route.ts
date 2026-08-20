import { NextResponse } from "next/server";
import { expiredSessionCookie, revokeAllSessions } from "@/lib/auth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * POST only, on purpose. A GET sign-out link can be fired by any third-party
 * page embedding <img src="…/api/auth/logout">, which is a cheap way to keep
 * logging the sales team out mid-call.
 *
 * The body is deliberately not parsed: there are no fields to read, and
 * readPost() throws on a POST with no body at all.
 */
export async function POST(request: Request) {
  const wantsJson = (request.headers.get("content-type") ?? "").includes("application/json");

  // Server-side revocation first, so a cookie copied before this moment stops
  // verifying everywhere — not just in the browser that clicked Sign out.
  await revokeAllSessions();

  const response = wantsJson
    ? NextResponse.json({ ok: true })
    : NextResponse.redirect(new URL("/login", request.url), { status: 303 });
  response.cookies.set(expiredSessionCookie());
  return response;
}
