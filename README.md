# Villa WhatsApp AI Sales Agent — Glentree Serenity

A WhatsApp sales agent that qualifies villa buyers, answers only from approved
material, books site visits, and hands hot leads to a human — plus the admin
console the sales and marketing teams work from.

One Next.js app serves both: the webhook Meta calls, and the dashboard you look at.

---

## Getting started

### 1. Fill in your keys

`.env.local` already exists, copied from `.env.example`. Every value is a
`<placeholder>` you replace. It's organised into six sections:

| Section | What it unlocks |
| --- | --- |
| 1. Anthropic | The agent can think and reply |
| 2. Supabase | Leads and conversations get stored |
| 3. WhatsApp Cloud API | Real customers can reach it |
| 4. Sales team | Hot-lead alerts get delivered |
| 5. App | Dashboard access, media links |
| 6. Optional | Maps link, brochure URL |

You only need sections 1 and 2 to start testing. The simulator works without
WhatsApp being connected at all.

### 2. Create the database

In the Supabase dashboard → **SQL Editor**, run these two files in order:

1. `supabase/migrations/0001_schema.sql`
2. `supabase/migrations/0002_seed_glentree_serenity.sql`

Everything is prefixed `villa_`, so it drops into an existing project without
colliding with what's already there.

### 3. Run it

```bash
npm run dev
```

Open http://localhost:3000. If anything is missing you get a setup checklist
rather than an error page.

### 4. Talk to it

Go to **Simulator**. It runs the identical agent path a real WhatsApp customer
hits — same prompt, same tools, same CRM writes — but returns the replies to
your browser instead of calling Meta. Leads you create there appear in the
dashboard immediately.

Try the two adversarial openers on that page. `"What's the final price?"` and
`"What guaranteed returns will I get?"` are the ones worth watching: the agent
should decline to invent either.

### 5. Connect WhatsApp

Deploy somewhere with a public HTTPS URL, then in the Meta app dashboard →
WhatsApp → Configuration:

- **Callback URL**: `https://your-domain.com/api/whatsapp`
- **Verify token**: the same string you put in `WHATSAPP_VERIFY_TOKEN`
- **Subscribe to**: the `messages` field

Meta will call `GET` to verify, then `POST` every inbound message.

---

## How it works

```
Customer on WhatsApp
        ↓
POST /api/whatsapp          ← HMAC signature verified, else 401
        ↓
handleInbound()             ← dedupe, opt-out check, human-takeover check
        ↓
runAgent()                  ← Claude Opus 4.8, adaptive thinking, tool loop
        ↓
  ├─ searches the knowledge base before answering anything factual
  ├─ writes what it learns to the CRM as it learns it
  ├─ sends approved brochures / floor plans
  ├─ logs objections and unanswered questions
  └─ hands off to a rep with a 30-second briefing
        ↓
Reply sent · lead rescored · dashboard updated
```

### The anti-hallucination design

This is the part that matters most in real estate, and it's structural rather
than just instructional:

- The knowledge base is the **only** source the agent can quote. It lives in
  Supabase, not in the model's memory.
- A `NULL` price or `NULL` bedroom count is **meaningful** — it means the fact
  is not approved for the agent to state. It says the sales team will confirm.
- If no unit inventory is loaded, the agent cannot claim live availability.
- Every "I'll have someone check that" is written to `villa_questions`, so the
  promise turns into a real follow-up instead of vanishing.
- Every tool call is written to `villa_tool_calls`. If a send fails, the agent
  is told it failed and must not claim success.

**Known gap in the seeded data:** the presentation gives six villa variants
(three plot sizes × two facings) and separately says the project offers 3 BHK
and 4 BHK, but never says which plot size is which. Per-type prices aren't in
the deck either. Both are seeded as `NULL` with a `verification_note`. Fill them
in from the approved price sheet:

```sql
update villa_types
set bedrooms = 4, price_inr = 24500000, verification_note = null
where name = '267 Sq. Yards — East Facing';
```

### Prompt caching

The cached prefix is `tools → system prompt → knowledge base`, with the cache
breakpoint on the last system block. Nothing volatile goes in there — the
per-customer profile is attached to the user turn instead, so the prefix stays
byte-identical across every customer.

The simulator shows `cache read` / `cache write` per message. Cache read should
climb after the first message; if it stays at zero, something in the prefix is
changing between calls.

Editing `SYSTEM_PROMPT`, `TOOLS`, or project data invalidates the cache — that's
expected, it re-warms on the next message.

---

## Project layout

```
supabase/migrations/     schema + Glentree seed data
src/lib/
  env.ts                 lazy env access with actionable errors
  supabase.ts            service-role client (server only)
  conversation.ts        the single inbound path
  queries.ts             dashboard reads
  agent/
    prompt.ts            system prompt (the cached prefix — read the header)
    kb.ts                knowledge base → deterministic cached text block
    tools.ts             tool definitions (fixed order, see the header)
    execute.ts           tool handlers + audit logging
    run.ts               the agent loop
    scoring.ts           lead scoring (deterministic, not model-judged)
  whatsapp/
    client.ts            send text / media / template
    verify.ts            HMAC signature + webhook handshake
src/app/
  api/whatsapp/          Meta webhook
  api/simulate/          local test harness
  (dashboard pages)
```

## Security notes

- `SUPABASE_SERVICE_ROLE_KEY` is server-only and bypasses RLS. Never prefix it
  `NEXT_PUBLIC_`.
- Every customer-data table has RLS on with **no** permissive policy, so a
  leaked anon key reads nothing.
- The webhook verifies Meta's HMAC signature on every POST. Without it, anyone
  who finds the URL could drive the agent and your API bill.
- `.env.local` is gitignored. `.env.example` is safe to commit.

## Not done yet

- **Dashboard auth.** `DASHBOARD_PASSWORD` is in the env template but no login
  gate is wired up. Don't deploy this publicly as-is.
- **Follow-up engine** (spec §23–24). The schema supports it and
  `sendTemplate()` exists, but no scheduler is running.
- **Media assets.** `villa_assets` is empty — upload brochures and floor plans
  to Supabase Storage and insert rows, or set `BROCHURE_URL` for a quick start.
- **Verified against live APIs.** The build, typecheck and all routes pass, and
  the webhook correctly rejects unsigned requests. The Anthropic and Supabase
  call paths have not been exercised end to end, because that needs your keys.
  The simulator is where you'll find out.
