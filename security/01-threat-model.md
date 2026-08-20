# Threat model — Villa WhatsApp agent

Reviewed 2026-08-19. Boundaries (A)–(H) are defined in `00-inventory.md` §3.

**Scoring.** Likelihood and Impact are 1–5. Score = L × I. **Anything ≥ 15 is
must-fix before launch.** Scores describe the state of the system as found,
with the mitigation column noting what has changed since.

Ownership note: this pass owned security headers, secrets hygiene, dependency
CVEs and error leakage. Authentication is a parallel workstream — `middleware.ts`
and `/api/auth/*` appeared during this review and their correctness is **not**
verified here. Items depending on them are marked *in progress*, not *closed*.

---

## STRIDE table

| # | Boundary | Threat | STRIDE | L | I | Score | Mitigation | Status |
|---|---|---|---|---|---|---|---|---|
| T1 | (G) dev laptop / chat | Live Groq key and Supabase anon + service_role keys were pasted into an AI chat during development. Transcripts are retained and outside the developer's control. | Info Disclosure | 5 | 5 | **25** | Rotate all three, plus WhatsApp token and dashboard password. No technical control substitutes for rotation. | **OPEN — must fix** |
| T2 | (C) internet | Admin console and all `/api/*` mutation routes had no auth check: read every lead and transcript, move pipeline stages, toggle the AI off, edit inventory and pricing. | Elevation of Privilege / Tampering / Info Disclosure | 5 | 5 | **25** | `middleware.ts` + `/api/auth/*` added by the auth workstream. Not verified in this pass. | **IN PROGRESS** |
| T3 | (H) repo → git remote | `.env.example` is a byte-identical copy of `.env.local` and was not covered by `.gitignore`. First `git init && git add .` publishes the RLS-bypassing service_role key. | Info Disclosure / Elevation of Privilege | 4 | 5 | **20** | `.gitignore` now has catch-all `.env.*` + explicit `.env.example`; verified `git add .` stages neither. Stopgap only — sanitise the template and rotate. | **MITIGATED (stopgap); sanitise OPEN** |
| T4 | (E) server → Supabase | `db()` uses service_role, which bypasses RLS. Any auth bypass, SSRF or RCE on the server yields a full dump of every lead, transcript and payment. Single key, no scoping. | Info Disclosure / Elevation of Privilege | 3 | 5 | **15** | Invariant currently holds (no client component imports it). Reduce blast radius: use an RLS-respecting client for read paths and reserve service_role for writes that genuinely need it. | **OPEN — must fix** |
| T5 | (F) server → LLM providers | Customer names, phone numbers and full chat transcripts are sent to Groq / Anthropic / Gemini as prompt context. This is a third-country PII transfer with no DPA referenced anywhere in the repo. | Info Disclosure / Repudiation (compliance) | 5 | 3 | **15** | Confirm DPA and zero-retention terms with each provider; disclose processing in the customer-facing privacy notice; consider redacting phone numbers from prompts. | **OPEN — must fix** |
| T6 | (C) internet | `DASHBOARD_PASSWORD` is a single shared secret with no per-user identity, no lockout and no rate limiting, so it is brute-forceable and unattributable. | Spoofing / Repudiation | 3 | 5 | **15** | Rate-limit and lock out on the login route; move to per-user accounts before more than one person has access. Owned by the auth workstream. | **OPEN — must fix** |
| T7 | (C) internet | `/api/simulate` runs the full agent unauthenticated: burns LLM budget on demand, writes real rows into `villa_leads`, and returns raw exception text. | DoS (financial) / Tampering | 4 | 3 | **12** | Auth (in progress) plus a rate limit. See "Error leakage" below for the error-text judgement. | **IN PROGRESS** |
| T8 | (D) browser | CSP grants `script-src 'unsafe-inline'`, so any future HTML-injection sink becomes script execution. | Tampering / Elevation of Privilege | 2 | 4 | 8 | No `dangerouslySetInnerHTML` anywhere in `src/` today, so there is no sink. `'unsafe-eval'` is *not* granted in production. Upgrade path below. | **ACCEPTED (short-term)** |
| T9 | (D) network | Credentials and PII sent over plaintext HTTP; TLS strip / hostile Wi-Fi. | Info Disclosure | 2 | 4 | 8 | `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload` + `upgrade-insecure-requests`, production only. | **MITIGATED** |
| T10 | (C) internet | Raw Supabase `error.message` returned to the client leaks table, column and constraint names — a free schema map for an attacker. | Info Disclosure | 3 | 2 | 6 | Return a generic message, log the detail server-side. Files not owned by this pass; reported below. | **OPEN (reported)** |
| T11 | (C) internet | `/api/marketing/generate` invokes Gemini unauthenticated — cost amplification. | DoS (financial) | 3 | 2 | 6 | Auth + rate limit. | **IN PROGRESS** |
| T12 | (A) internet | Forged inbound WhatsApp messages drive the agent and the LLM bill. | Spoofing | 1 | 4 | 4 | HMAC over the raw body, constant-time compare, fails closed when `WHATSAPP_APP_SECRET` is unset. Correctly implemented. | **MITIGATED** |
| T13 | (B) internet | Unauthorised trigger of the follow-up dispatcher blasts templates at real customers; repeated abuse gets the number banned by Meta. | Spoofing / DoS | 1 | 4 | 4 | Bearer secret, constant-time compare, **fails closed** (503) when unset. Best-defended route in the app. | **MITIGATED** |
| T14 | (A) internet | Replay of a captured webhook payload reprocesses the same customer message. | Tampering | 2 | 2 | 4 | Message-id dedupe in the conversation layer. | **MITIGATED** |
| T15 | (D) browser | Admin console framed by a hostile page; clickjacked "pause AI" / stage-move controls. | Tampering | 1 | 3 | 3 | `frame-ancestors 'none'` + `X-Frame-Options: DENY`. | **MITIGATED** |
| T16 | build chain + (C) internet | 3 high-severity CVEs in `postcss` and `sharp`, transitive under `next`. `sharp` *is* reachable at runtime via `/_next/image` (confirmed 200), but only on first-party images — remote URLs are rejected 400 and there is no upload path, so the malicious image the libvips CVEs need cannot be supplied. `postcss` is build-time only. | Info Disclosure / DoS | 1 | 3 | 3 | See `dependency-audit.md`. Fix requires a Next 15→16 major bump; an `overrides` block is the surgical alternative. **Do not add `images.remotePatterns` without re-scoring this.** | **ACCEPTED** |

### Must-fix before launch (score ≥ 15)
T1 (25), T2 (25), T3 (20), T4 (15), T5 (15), T6 (15).

Of these, **T1 and T3 are the ones to act on today**: rotate the credentials and
sanitise `.env.example`. They are cheap, and every hour they stay open is an
hour a live service_role key sits in a chat transcript and on disk in a file
that was one `git add` away from publication.

---

## Evidence for the header work

Verified against a real production build (`npm run build` && `next start -p 3100`),
not just the dev server.

**Headers present in production** — `curl -sD - -o /dev/null http://localhost:3100/`:

```
Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline';
  style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:;
  connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self';
  frame-ancestors 'none'; upgrade-insecure-requests
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
X-Frame-Options: DENY
Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()
Cross-Origin-Opener-Policy: same-origin
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
```

Also confirmed present on `/api/*` responses, including error statuses.

**Dev keeps `'unsafe-eval'` and `ws:` and omits HSTS**, as designed:

```
script-src 'self' 'unsafe-inline' 'unsafe-eval'; ... connect-src 'self' ws: wss:
(no Strict-Transport-Security)
```

**The app still works under the strict policy.** Rather than eyeballing one
page, every resource class the CSP governs was enumerated:

- `/`, `/simulator`, `/marketing`, `/automations`, `/production`, `/inventory`,
  `/leads`, `/admin` all return HTTP 200 with **zero** external `src`/`href`
  resources — every script, style, image and font is same-origin, satisfying
  `'self'`.
- **Zero `eval(` / `new Function(`** in the JS actually served by `next start`
  (all 7 chunks fetched over HTTP and grepped). This is what makes dropping
  `'unsafe-eval'` in production safe.
- No `dangerouslySetInnerHTML` in `src/`, so `'unsafe-inline'` on `script-src`
  has no injection sink to pair with today.
- Client components fetch only same-origin `/api/*`, satisfying `connect-src 'self'`.
- Supabase is never contacted from the browser (`db()` is server-only), so
  `connect-src` needs no Supabase origin.

A caveat worth recording: `.next/` contains a mix of dev and production
artifacts because a dev server was running against the same directory. Grepping
`.next/static/chunks` on disk shows 72 `eval(` hits — all from *unhashed dev*
chunks. The content-hashed files that `next start` actually serves have none.
Any future check must fetch over HTTP rather than grep the directory.

`npx tsc --noEmit` passes clean.

### CSP upgrade path (closes T8)
`middleware.ts` now exists, which unblocks the proper fix. Generate a nonce per
request in middleware, set `script-src 'nonce-<value>' 'strict-dynamic'`, and
delete `'unsafe-inline'` from the `script-src` line in `next.config.ts`. Leave
`style-src 'unsafe-inline'` alone — nonces do not apply to style attributes and
three pages set `style={{}}` for chart widths.

---

## Error leakage — findings (report only; files not owned by this pass)

Surveyed every route handler. Most return fixed strings (`"unauthorized"`,
`"id is required"`) and are fine. Three leak raw error text:

**1. `src/app/api/marketing/mark-ready/route.ts:16` — the one worth fixing.**

```ts
if (error) return NextResponse.json({ error: error.message }, { status: 500 });
```

A raw Supabase `PostgrestError.message` reaches an unauthenticated client and
names tables, columns and constraints. Same pattern at
`src/app/api/marketing/generate/route.ts` (`insertError.message`,
`projectError.message`). Suggested shape: log `error` server-side, return
`{ error: "Could not update draft" }`.

**2. `src/app/api/cron/follow-ups/route.ts:93–94, 102` — acceptable.** It also
returns `error.message`, but only *after* a constant-time bearer check that
fails closed. The detail is deliberate and useful (it distinguishes "migration
0009 not run" from "dispatcher broken"), and the audience is already trusted.
Leave it.

**3. `src/app/api/simulate/route.ts:67–71` — acceptable once auth lands, with a
caveat.** The comment states the intent plainly: surfacing the real error *is*
the feature, because this is where a missing key or unapplied migration shows
up. That judgement is sound for a developer tool behind auth, and the leaked
text is local error detail rather than credential material.

The caveat is that error text is the *least* of this route's exposure. It runs
the full agent, so unauthenticated it is a billable-LLM DoS that also writes
real rows into `villa_leads`. Auth fixes the error leak and the far larger cost
problem together — but it needs a rate limit too, since an authenticated
insider can still run the bill up. Tracked as T7.
