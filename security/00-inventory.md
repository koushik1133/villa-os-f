# Security inventory — Villa WhatsApp agent

Reviewed 2026-08-19. Scope of this document: assets, entry points, trust
boundaries and data classification. Threats and scoring live in
`01-threat-model.md`; dependency CVEs in `dependency-audit.md`.

No credential values appear in this file. Secrets are referenced by variable
name only.

---

## 1. Assets

| Asset | Where it lives | Why it matters |
|---|---|---|
| Customer PII | `villa_leads`, `villa_messages`, `villa_conversations` | Names, WhatsApp phone numbers, full chat transcripts, budget and intent signals. The crown jewels. |
| Commercial data | `villa_bookings`, `villa_payments`, `villa_units`, `villa_revenue` views | Pricing, who bought what, payment state. |
| Sales pipeline | `villa_tasks`, `villa_follow_ups`, `villa_handoffs`, `villa_touchpoints` | Business-sensitive but not personal. |
| Public catalogue | `villa_projects`, `villa_types`, `villa_units`, `villa_assets`, `villa_faqs` | Deliberately world-readable (see RLS note below). |
| `SUPABASE_SERVICE_ROLE_KEY` | `.env.local`, `.env.example` | Bypasses RLS entirely. Full read/write on every table above. |
| `GROQ_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY` | `.env.local`, `.env.example` | Billable. Abuse is a direct cost, and Groq keys are commonly scraped from repos. |
| `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_APP_SECRET`, `WHATSAPP_VERIFY_TOKEN` | `.env.local`, `.env.example` | Send messages as the business. Abuse gets the number banned by Meta. |
| `DASHBOARD_PASSWORD`, `CRON_SECRET` | `.env.local` / env | Gate the admin console and the follow-up dispatcher. |
| Brochures / layouts | `public/*.pdf`, `public/*.jpg` | Intentionally public marketing collateral. |

## 2. Entry points

### Public, unauthenticated by design
| Entry point | File | Control |
|---|---|---|
| `POST /api/whatsapp` | `src/app/api/whatsapp/route.ts` | HMAC `X-Hub-Signature-256` over the raw body, constant-time compare, fails closed if `WHATSAPP_APP_SECRET` is unset. Solid. |
| `GET /api/whatsapp` | same | Meta handshake, compares `hub.verify_token`. Non-constant-time compare, but a one-shot low-value token. |
| `GET /api/cron/follow-ups` | `src/app/api/cron/follow-ups/route.ts` | `Authorization: Bearer $CRON_SECRET`, constant-time, **fails closed** (503) when the secret is unset. Good pattern — worth copying elsewhere. |

### Admin console — HTML pages
All dashboard routes under `src/app/` (`/`, `/leads`, `/bookings`, `/admin`,
`/simulator`, …). Server components read customer PII directly via `db()`.

### Admin console — JSON APIs
`/api/admin/toggle`, `/api/automations`, `/api/bookings`, `/api/campaigns`,
`/api/insights`, `/api/inventory`, `/api/kanban/move`, `/api/marketing/generate`,
`/api/marketing/mark-ready`, `/api/notifications`, `/api/simulate`, `/api/tasks`,
`/api/team`.

At the time of this review none of these carried an in-handler auth check. A
parallel workstream has since added `middleware.ts` and `/api/auth/login`,
`/api/auth/logout`; those files are outside this document's ownership and their
correctness is **not** verified here. The threat model scores the pre-auth state
and marks the item as in-progress rather than closed.

### Outbound (egress) calls
Meta Graph API (`sendText`/`sendMedia`/`markRead`), Anthropic, Groq, Google
Gemini, Supabase REST. All server-side.

## 3. Trust boundaries

```
 (A) Internet ──► /api/whatsapp            [HMAC-verified]
 (B) Internet ──► /api/cron/follow-ups     [bearer secret, constant-time]
 (C) Internet ──► admin pages + /api/*     [auth landing in parallel]
 (D) Browser  ──► Next.js server           [CSP / headers, this workstream]
 (E) Next.js server ──► Supabase           [service_role — bypasses RLS]
 (F) Next.js server ──► LLM + Meta APIs    [outbound, keys attached]
 (G) Developer laptop / chat transcripts ──► credentials   ** breached **
 (H) Repo / filesystem ──► future git remote               ** at risk **
```

Boundary **(E)** is the one that matters most: `src/lib/supabase.ts` uses the
service_role key, which bypasses Row Level Security. Anything that can reach a
server component or route handler can read every lead. The file carries an
explicit "must never be imported into a client component" warning, and that
invariant currently holds — no client component imports it.

Boundaries **(G)** and **(H)** are the live problems. See §5.

## 4. Data classification

| Class | Data | Handling |
|---|---|---|
| **Restricted** | Service-role key, WhatsApp app secret, LLM API keys, dashboard password, cron secret | Never in source, never in a tracked file, never in logs. Rotate on any exposure. |
| **Confidential** | Lead names, phone numbers, message transcripts, budgets, payments | RLS-protected; only reachable through the server. Not to be logged in full. |
| **Internal** | Tasks, follow-ups, campaign performance, objections | Admin-only. |
| **Public** | Project/unit catalogue, FAQs, brochures in `public/` | World-readable by design. |

### RLS posture
28 tables have `enable row level security`. Only 5 permissive policies exist,
all `for select using (true)` on the public catalogue: `villa_projects`,
`villa_types`, `villa_units`, `villa_assets`, `villa_faqs`.

`villa_leads`, `villa_messages` and `villa_conversations` have RLS on with **no
permissive policy**, so the anon key cannot read customer PII. This is why the
exposed *anon* key is a much smaller problem than the exposed *service_role*
key — but both are exposed and both must be rotated.

## 5. Secrets hygiene — current state

**This is not a git repository.** `git rev-parse --is-inside-work-tree` fails.
History scrubbing is therefore moot: there is no history. That is the one piece
of good news, and it is temporary — it only holds until someone runs `git init`.

### Finding: `.env.example` is a byte-identical copy of `.env.local`

`diff -q .env.example .env.local` reports the files are identical (both 6357
bytes). `.env.example` is supposed to be a committed template. It currently
contains, as live values:

- `GROQ_API_KEY` (live value present — matches the `gsk_` + 52-char format)
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` (live JWT present)
- `SUPABASE_SERVICE_ROLE_KEY` (live JWT present — **RLS-bypassing**)
- `NEXT_PUBLIC_SUPABASE_URL` (live project URL, identifies the tenant)
- `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_VERIFY_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`
- `DASHBOARD_PASSWORD`
- 8 remaining values are genuine `<placeholder>` form and are fine.

Before this review `.gitignore` covered `.env`, `.env.local` and `.env*.local`
— but **not** `.env.example`. The first `git init && git add .` would have
committed live credentials.

`.gitignore` has been updated to add a catch-all `.env.*` plus an explicit
`.env.example` entry, with a comment marking it a stopgap. Verified in a
throwaway repo: `git add .` now stages neither. This is a tourniquet, not a
fix — a template is *meant* to be committed.

**Remediation (owner: whoever owns `.env.example`)**
1. Rotate every credential listed above. Assume all are burned.
2. Replace every real value in `.env.example` with `<placeholder>` form —
   `src/lib/env.ts::isPlaceholder` already treats `<...>` as "not configured",
   so the setup checklist keeps working.
3. Remove the two `.env.example` lines from `.gitignore`.
4. Only then `git init`.

### Finding: credentials were pasted into a chat during development

A real Groq API key and the real Supabase anon + service_role keys were pasted
into an AI chat session while this project was built. **Anything pasted into a
chat should be considered exposed and must be rotated**, independently of what
the repository does or does not contain. Chat transcripts are retained, may be
processed by third parties, and are outside the developer's control. Rotation
is the only remedy; there is no "unsend".

### Clean results
- No hardcoded secrets anywhere in `src/` or `supabase/`. Scanned for `gsk_`,
  `sk-ant-`, `eyJhbGciOi`, `AKIA…`, and `<key-ish name> = "<literal>"`. Zero hits.
- No live key material in `README.md`, `SETUP-GUIDE.md`, `BRD.md`,
  `OPEN-QUESTIONS.md` or the Phase-2 doc. The 70 keyword hits in
  `SETUP-GUIDE.md` are instructional prose ("paste your API key here").
- `src/lib/env.ts` reads everything lazily from `process.env`. No leakage.
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` is declared but never referenced in code, so
  it is not currently baked into the client bundle. If anything starts using it,
  it will be — that is inherent to the `NEXT_PUBLIC_` prefix, and acceptable
  only because the PII tables have no permissive RLS policy.

### Scanning note
The scan command in the original brief silently misses these files. `rg` skips
dotfiles and honours `.gitignore` by default, so `.env.local` and `.env.example`
are excluded unless you pass `--hidden --no-ignore`. Any future secret scan must
use both flags or it will report a clean tree while live keys sit on disk.

## 6. Transport and browser-boundary controls

Implemented in `next.config.ts` this pass, applied to every response including
`/api/*`. Verified against a real production build — see `01-threat-model.md`
for the evidence.

| Header | Production value |
|---|---|
| `Content-Security-Policy` | `default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; upgrade-insecure-requests` |
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains; preload` (production only) |
| `X-Content-Type-Options` | `nosniff` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `X-Frame-Options` | `DENY` |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=(), payment=()` |
| `Cross-Origin-Opener-Policy` | `same-origin` |

Two deliberate deviations from a maximally strict policy, both commented in
`next.config.ts`:

- **`script-src 'unsafe-inline'`** — the App Router streams the RSC payload as
  inline `self.__next_f.push(...)` scripts whose content varies per route and
  per build, so hashes are unworkable and a nonce requires per-request
  generation. Headers declared in `next.config.ts` are static. `'unsafe-eval'`
  is *not* granted in production and is not needed (verified: zero `eval(` /
  `new Function(` in the JS actually served by `next start`).
- **`style-src 'unsafe-inline'`** — Tailwind v4 injects a `<style>` block and
  three pages use React `style={{}}` attributes for chart widths. CSP nonces do
  not apply to style *attributes*. Style injection is a materially weaker
  primitive than script injection; accepted.

HSTS is production-gated on purpose. Emitting it on `http://localhost` would
pin localhost to HTTPS in the developer's browser for two years.
