import { NextResponse } from "next/server";
import { checkPassword, isAuthConfigured, issueSessionToken, sessionCookie } from "@/lib/auth";
import { readPost, safePath, type PostBody } from "@/lib/form-post";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Brute-force limit, keyed by client IP: 10 attempts per 15 minutes.
 *
 * The counters live in a plain Map, which is honest about what it is:
 *   - it resets to empty on every process restart or redeploy, so an attacker
 *     who can trigger a restart clears their own budget;
 *   - it is per-instance, so on a serverless or multi-replica host the real
 *     ceiling is 10 x (number of live instances) and each cold start is fresh.
 * That is acceptable for the single-instance deploy this app targets. Moving to
 * more than one instance means moving this counter into Supabase or Redis.
 */
const MAX_ATTEMPTS = 10;
const WINDOW_MS = 15 * 60 * 1000;
const attempts = new Map<string, { count: number; resetAt: number }>();

function clientIp(request: Request): string {
  const forwarded = request.headers.get("x-forwarded-for");
  if (forwarded) return forwarded.split(",")[0].trim();
  return request.headers.get("x-real-ip")?.trim() || "unknown";
}

function withinRateLimit(ip: string): boolean {
  const now = Date.now();

  // Sweep on write so one-off IPs can't grow the map without bound.
  if (attempts.size > 5000) {
    for (const [key, value] of attempts) {
      if (value.resetAt <= now) attempts.delete(key);
    }
  }

  const entry = attempts.get(ip);
  if (!entry || entry.resetAt <= now) {
    attempts.set(ip, { count: 1, resetAt: now + WINDOW_MS });
    return true;
  }

  entry.count += 1;
  return entry.count <= MAX_ATTEMPTS;
}

function fail(request: Request, body: PostBody, next: string, code: string, status: number) {
  if (body.json) return NextResponse.json({ error: code }, { status });

  const back = new URL("/login", request.url);
  back.searchParams.set("error", code);
  if (next !== "/") back.searchParams.set("next", next);
  return NextResponse.redirect(back, { status: 303 });
}

export async function POST(request: Request) {
  const body = await readPost(request);
  // safePath keeps a crafted ?next= from turning sign-in into an open redirect.
  const next = safePath(body.get("next"), "/");
  const ip = clientIp(request);

  if (!withinRateLimit(ip)) {
    return fail(request, body, next, "rate_limited", 429);
  }

  // The submitted password is never logged, never echoed into an error, and
  // never put in a redirect URL — query strings end up in server access logs.
  const submitted = body.get("password") ?? "";

  // One generic code for every failure, including "the server has no password
  // configured", so the form can't be used to probe the deployment's state.
  if (!isAuthConfigured() || !(await checkPassword(submitted))) {
    return fail(request, body, next, "invalid", 401);
  }

  attempts.delete(ip);

  const response = body.json
    ? NextResponse.json({ ok: true })
    : NextResponse.redirect(new URL(next, request.url), { status: 303 });
  response.cookies.set(sessionCookie(await issueSessionToken()));
  return response;
}
