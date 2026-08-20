import crypto from "node:crypto";
import { optional } from "@/lib/env";

/**
 * Shared-password gate for the console.
 *
 * A three-person sales team does not need per-user accounts, so there is one
 * password. What the browser holds is deliberately NOT that password: it is an
 * HMAC-signed "issued at" stamp. A cookie that leaks (shoulder-surf, shared
 * laptop, log capture) therefore can't be replayed as the password anywhere
 * else, and it stops working on its own after the TTL.
 */

export const SESSION_COOKIE = "villa_session";

const SESSION_TTL_MS = 7 * 24 * 60 * 60 * 1000;

/** Tolerance so a cookie minted on a slightly fast clock still verifies. */
const CLOCK_SKEW_MS = 60_000;

/**
 * Error codes the login form round-trips through `?error=`.
 *
 * Codes rather than raw text: `?error=` is attacker-controlled, and rendering
 * whatever it contains would let anyone send a link that shows arbitrary text
 * inside our own login card ("Call this number to restore access…").
 */
export const LOGIN_ERRORS: Record<string, string> = {
  invalid: "Incorrect password.",
  rate_limited: "Too many attempts. Wait a few minutes and try again.",
};

export const NOT_CONFIGURED_MESSAGE =
  "This console is disabled because no admin password is set on the server. " +
  "Set DASHBOARD_PASSWORD in the deployment environment and redeploy.";

/**
 * Key used to sign session cookies, or null when the app is unconfigured.
 *
 * SESSION_SECRET wins so the password can be rotated without invalidating every
 * live session (and vice versa). Falling back to DASHBOARD_PASSWORD keeps a
 * one-variable setup working; hashing with a domain-separating label first
 * means the cookie signature is never keyed on the raw password itself.
 */
function signingKey(): Buffer | null {
  const material = optional("SESSION_SECRET") || optional("DASHBOARD_PASSWORD");
  if (!material) return null;
  return crypto.createHash("sha256").update(`villa-console|session|${material}`).digest();
}

/**
 * Whether a session can be signed at all.
 *
 * Note the deliberate asymmetry: SESSION_SECRET alone satisfies this but cannot
 * satisfy checkPassword(), so setting SESSION_SECRET without DASHBOARD_PASSWORD
 * locks everyone out. That is the safe direction to fail — a half-configured
 * deployment stays shut rather than open.
 */
export function isAuthConfigured(): boolean {
  return signingKey() !== null;
}

function sign(payload: string, key: Buffer): Buffer {
  return crypto.createHmac("sha256", key).update(payload).digest();
}

export function issueSessionToken(): string {
  const key = signingKey();
  if (!key) {
    throw new Error("Cannot issue a session: neither SESSION_SECRET nor DASHBOARD_PASSWORD is set.");
  }
  const issuedAt = String(Date.now());
  return `${issuedAt}.${sign(issuedAt, key).toString("hex")}`;
}

export function verifySessionToken(token: string | undefined): boolean {
  const key = signingKey();
  if (!key || !token) return false;

  const separator = token.indexOf(".");
  if (separator <= 0) return false;

  const issuedAt = token.slice(0, separator);
  const provided = Buffer.from(token.slice(separator + 1), "hex");
  const expected = sign(issuedAt, key);

  // timingSafeEqual throws on a length mismatch, and a malformed hex string
  // decodes short — so the length guard has to come first.
  if (provided.length !== expected.length) return false;
  if (!crypto.timingSafeEqual(provided, expected)) return false;

  const age = Date.now() - Number(issuedAt);
  return age > -CLOCK_SKEW_MS && age < SESSION_TTL_MS;
}

/**
 * Timing-safe on content *and* length: comparing SHA-256 digests keeps the work
 * identical no matter how wrong the guess is, so the response time leaks
 * neither the password's characters nor how long it is.
 */
export function checkPassword(submitted: string): boolean {
  const expected = optional("DASHBOARD_PASSWORD");
  if (!expected) return false;
  return crypto.timingSafeEqual(
    crypto.createHash("sha256").update(submitted).digest(),
    crypto.createHash("sha256").update(expected).digest(),
  );
}

export type Access = "ok" | "signed-out" | "not-configured";

/**
 * What to do with a request carrying `token`.
 *
 * FAIL-CLOSED DECISION, unconfigured case.
 * Two bad outcomes are in tension. Refusing everything when no password is set
 * would lock the owner out of his own laptop the first time he clones the repo
 * — the app would appear broken before he has read a single setup line.
 * Allowing everything would mean a real deploy that forgot one env var serves
 * customer names, phone numbers and full WhatsApp transcripts to the open
 * internet, silently, with no signal that anything is wrong.
 *
 * They are resolved by environment rather than by picking one globally: with no
 * password configured, local dev is wide open (frictionless, and the data there
 * is fake), while production refuses with an explicit "set DASHBOARD_PASSWORD".
 * A forgotten env var then produces a loud, obvious outage instead of a quiet
 * data leak, which is the failure mode we want.
 */
export function checkAccess(token: string | undefined): Access {
  if (!isAuthConfigured()) {
    return process.env.NODE_ENV === "production" ? "not-configured" : "ok";
  }
  return verifySessionToken(token) ? "ok" : "signed-out";
}

const COOKIE_FLAGS = {
  httpOnly: true,
  sameSite: "lax" as const,
  // Only over TLS in production; localhost is plain http, so forcing it there
  // would silently drop the cookie and make sign-in look broken.
  secure: process.env.NODE_ENV === "production",
  path: "/",
};

export function sessionCookie(token: string) {
  return { name: SESSION_COOKIE, value: token, maxAge: SESSION_TTL_MS / 1000, ...COOKIE_FLAGS };
}

export function expiredSessionCookie() {
  return { name: SESSION_COOKIE, value: "", maxAge: 0, ...COOKIE_FLAGS };
}

// -----------------------------------------------------------------------------
// Server-side revocation
//
// The token is a stateless HMAC, so clearing the cookie is all a plain logout
// can do — a copy taken before logout kept verifying for its full 7-day TTL.
// The fix is a watermark: logout records "sessions issued before now are dead"
// in villa_locks (key 'auth:revoked-before', abused as a tiny KV; its
// acquired_at carries the watermark). Verification then requires
// issuedAt > watermark.
//
// One shared password means one logical user, so logging out revoking every
// session is the correct behaviour, not a side effect.
//
// The middleware runs on every request, so the watermark is cached for 30s —
// bounding both the DB load and the worst-case replay window after logout.
// Before 003_platform.sql exists the table is missing; that degrades to the
// old cookie-only logout rather than locking anyone out.
// -----------------------------------------------------------------------------

const REVOKED_KEY = "auth:revoked-before";
const WATERMARK_CACHE_MS = 30_000;

let watermarkCache: { value: number; fetchedAt: number } | null = null;

async function revokedBefore(): Promise<number> {
  const now = Date.now();
  if (watermarkCache && now - watermarkCache.fetchedAt < WATERMARK_CACHE_MS) {
    return watermarkCache.value;
  }
  try {
    const { db } = await import("./supabase");
    const { data, error } = await db()
      .from("villa_locks")
      .select("acquired_at")
      .eq("key", REVOKED_KEY)
      .maybeSingle();
    const value = !error && data?.acquired_at ? new Date(data.acquired_at).getTime() : 0;
    watermarkCache = { value, fetchedAt: now };
    return value;
  } catch {
    // Unreachable DB or missing table: fall back to stateless behaviour.
    watermarkCache = { value: 0, fetchedAt: now };
    return 0;
  }
}

/** Marks every currently-issued session invalid. Called by logout. */
export async function revokeAllSessions(): Promise<void> {
  try {
    const { db } = await import("./supabase");
    await db()
      .from("villa_locks")
      .upsert(
        {
          key: REVOKED_KEY,
          holder: "00000000-0000-0000-0000-000000000000",
          acquired_at: new Date().toISOString(),
          // Far future: this row is a watermark, not a lease, and the lock
          // acquirer's steal-if-expired path must never reclaim it.
          expires_at: new Date("2999-01-01").toISOString(),
        },
        { onConflict: "key" },
      );
    watermarkCache = null;
  } catch {
    // Table missing (pre-003): cookie clearing is all we can do.
  }
}

/**
 * checkAccess plus the revocation watermark. The middleware calls this; the
 * sync checkAccess above remains for callers that cannot await.
 */
export async function checkAccessRevocable(token: string | undefined): Promise<Access> {
  const access = checkAccess(token);
  if (access !== "ok" || !token) return access;
  // Already know the token parses (checkAccess verified it).
  const issuedAt = Number(token.slice(0, token.indexOf(".")));
  if (issuedAt <= (await revokedBefore())) return "signed-out";
  return access;
}
