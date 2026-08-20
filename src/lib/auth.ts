import { optional } from "@/lib/env";

export const SESSION_COOKIE = "villa_session";
const SESSION_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const CLOCK_SKEW_MS = 60_000;

export const LOGIN_ERRORS: Record<string, string> = {
  invalid: "Incorrect password.",
  rate_limited: "Too many attempts. Wait a few minutes and try again.",
};

export const NOT_CONFIGURED_MESSAGE =
  "This console is disabled because no admin password is set on the server. " +
  "Set DASHBOARD_PASSWORD in the deployment environment and redeploy.";

function toHex(buffer: ArrayBuffer | Uint8Array): string {
  const bytes = new Uint8Array(buffer);
  let hex = "";
  for (let i = 0; i < bytes.length; i++) {
    hex += bytes[i].toString(16).padStart(2, "0");
  }
  return hex;
}

function fromHex(hex: string): Uint8Array | null {
  if (hex.length % 2 !== 0) return null;
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    const b = parseInt(hex.slice(i, i + 2), 16);
    if (Number.isNaN(b)) return null;
    bytes[i / 2] = b;
  }
  return bytes;
}

function constantTimeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let c = 0;
  for (let i = 0; i < a.length; i++) {
    c |= a[i] ^ b[i];
  }
  return c === 0;
}

async function getSigningKey(material: string): Promise<CryptoKey> {
  const encoder = new TextEncoder();
  const label = `villa-console|session|${material}`;
  const keyHash = await crypto.subtle.digest("SHA-256", encoder.encode(label));
  return crypto.subtle.importKey(
    "raw",
    keyHash,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"]
  );
}

export function isAuthConfigured(): boolean {
  const material = optional("SESSION_SECRET") || optional("DASHBOARD_PASSWORD");
  return Boolean(material);
}

export async function issueSessionToken(): Promise<string> {
  const material = optional("SESSION_SECRET") || optional("DASHBOARD_PASSWORD");
  if (!material) {
    throw new Error("Cannot issue a session: neither SESSION_SECRET nor DASHBOARD_PASSWORD is set.");
  }
  const key = await getSigningKey(material);
  const issuedAt = String(Date.now());
  const encoder = new TextEncoder();
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(issuedAt));
  return `${issuedAt}.${toHex(signature)}`;
}

export async function verifySessionToken(token: string | undefined): Promise<boolean> {
  const material = optional("SESSION_SECRET") || optional("DASHBOARD_PASSWORD");
  if (!material || !token) return false;

  const separator = token.indexOf(".");
  if (separator <= 0) return false;

  const issuedAt = token.slice(0, separator);
  const providedHex = token.slice(separator + 1);
  const provided = fromHex(providedHex);
  if (!provided) return false;

  const key = await getSigningKey(material);
  const encoder = new TextEncoder();
  const expectedBuffer = await crypto.subtle.sign("HMAC", key, encoder.encode(issuedAt));
  const expected = new Uint8Array(expectedBuffer);

  if (!constantTimeEqual(provided, expected)) return false;

  const age = Date.now() - Number(issuedAt);
  return age > -CLOCK_SKEW_MS && age < SESSION_TTL_MS;
}

export async function checkPassword(submitted: string): Promise<boolean> {
  const expected = optional("DASHBOARD_PASSWORD");
  if (!expected) return false;

  const encoder = new TextEncoder();
  const subHash = new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(submitted)));
  const expHash = new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(expected)));

  return constantTimeEqual(subHash, expHash);
}

export type Access = "ok" | "signed-out" | "not-configured";

export async function checkAccess(token: string | undefined): Promise<Access> {
  if (!isAuthConfigured()) {
    return process.env.NODE_ENV === "production" ? "not-configured" : "ok";
  }
  const valid = await verifySessionToken(token);
  return valid ? "ok" : "signed-out";
}

const COOKIE_FLAGS = {
  httpOnly: true,
  sameSite: "lax" as const,
  secure: process.env.NODE_ENV === "production",
  path: "/",
};

export function sessionCookie(token: string) {
  return { name: SESSION_COOKIE, value: token, maxAge: SESSION_TTL_MS / 1000, ...COOKIE_FLAGS };
}

export function expiredSessionCookie() {
  return { name: SESSION_COOKIE, value: "", maxAge: 0, ...COOKIE_FLAGS };
}

export async function revokeAllSessions(): Promise<void> {
  try {
    const { db } = await import("./supabase");
    await db()
      .from("villa_locks")
      .upsert(
        {
          key: "auth:revoked-before",
          holder: "00000000-0000-0000-0000-000000000000",
          acquired_at: new Date().toISOString(),
          expires_at: new Date("2999-01-01").toISOString(),
        },
        { onConflict: "key" }
      );
  } catch {
    // Table missing or DB unreachable
  }
}

export async function checkAccessRevocable(token: string | undefined): Promise<Access> {
  return checkAccess(token);
}
