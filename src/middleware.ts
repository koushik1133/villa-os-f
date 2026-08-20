import { NextResponse, type NextRequest } from "next/server";
import { NOT_CONFIGURED_MESSAGE, SESSION_COOKIE, checkAccessRevocable } from "@/lib/auth";

// The session HMAC is verified with node:crypto's timingSafeEqual, which the
// Edge runtime does not provide. Node middleware is supported from Next 15.5.
export const runtime = "nodejs";

/**
 * Routes that must work without a session:
 *
 *   /login      — signing in cannot require being signed in.
 *   /api/auth/* — same.
 *   /api/whatsapp, /api/instagram — Meta POSTs here and authenticates with its
 *                   own HMAC signature. A 401 (or worse, a redirect) would
 *                   make Meta retry and eventually disable the subscription.
 *                   EXACT matches only: /api/whatsapp/test-voice and any other
 *                   sub-route is an operator tool and stays behind the login —
 *                   a prefix match here once left it open to anonymous callers
 *                   burning transcription credit.
 *   /api/cron/* — already guarded by a constant-time CRON_SECRET bearer check.
 */
const PUBLIC_PREFIXES = ["/login", "/api/auth", "/api/cron"];
const PUBLIC_EXACT = ["/api/whatsapp", "/api/instagram"];

function isPublicRoute(pathname: string): boolean {
  if (PUBLIC_EXACT.includes(pathname)) return true;
  return PUBLIC_PREFIXES.some((base) => pathname === base || pathname.startsWith(`${base}/`));
}

/**
 * Files served straight out of /public — brochures, renders, the layout PDF.
 *
 * WhatsApp's servers fetch those URLs themselves to attach media to a message,
 * with no cookie and no way to supply one, so they have to stay open. Scoped to
 * non-API paths on purpose: a future /api/export.csv must not be able to opt
 * itself out of the gate just by having a dot in its name.
 */
function isPublicAsset(pathname: string): boolean {
  return !pathname.startsWith("/api/") && /\.[a-z0-9]+$/i.test(pathname);
}

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  if (isPublicRoute(pathname) || isPublicAsset(pathname)) return NextResponse.next();

  const access = await checkAccessRevocable(request.cookies.get(SESSION_COOKIE)?.value);
  if (access === "ok") return NextResponse.next();

  const isApi = pathname.startsWith("/api/");

  if (access === "not-configured") {
    return isApi
      ? NextResponse.json({ error: NOT_CONFIGURED_MESSAGE }, { status: 503 })
      : new NextResponse(NOT_CONFIGURED_MESSAGE, {
          status: 503,
          headers: { "content-type": "text/plain; charset=utf-8" },
        });
  }

  // API callers get a status they can branch on. Redirecting a fetch() would
  // follow to /login and hand back the login page's HTML with a 200, so a
  // rejected CRM write would look like it succeeded.
  if (isApi) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const login = new URL("/login", request.url);
  login.searchParams.set("next", `${pathname}${request.nextUrl.search}`);
  return NextResponse.redirect(login);
}

export const config = {
  // Next's own build output is the only blanket exclusion — it also covers the
  // dev server's HMR endpoint. Everything else is decided in the body above so
  // the allow-list stays in one readable place.
  matcher: ["/((?!_next/).*)"],
};
