# Performance

Why the console felt slow, what was measured, and what changed.

## Summary

Every dashboard page was making **two to four Supabase round-trips in sequence**
before it rendered anything. Against the project's Supabase region a round-trip
measures **~85–95 ms**, so the guards alone cost more than everything else on the
page combined. Next.js rendering was never the problem: a page that touches no
database renders in **~36 ms**.

Making the independent round-trips concurrent removed one full round-trip from
every page in the console — **~77 ms, or 36% of page time**, measured in a
controlled A/B.

## How this was measured

`curl` against the dev server on `localhost:3000`, five to seven samples per
page, median reported. Reproduce with:

```sh
for p in / /insights /activity /leads /production /conversations /tasks \
         /bookings /team /marketing /campaigns /attribution /intelligence \
         /revenue /inventory /automations /notifications /admin; do
  printf "%-16s " "$p"
  curl -s -o /dev/null -w "%{time_total}s\n" "http://localhost:3000$p" --max-time 30
done
```

**`/simulator` is the control.** It renders no database data, so it isolates
Next.js dev-server overhead from Supabase latency. Every number below should be
read as *page time minus the `/simulator` baseline* — that difference is the
database cost, and it is the only part this work could change.

## Before / after

First column is the first hit of the session (includes route compilation for
some pages), the rest are warm medians.

| Page | Cold (first hit) | Before (warm) | After (warm) | Δ |
|---|---|---|---|---|
| `/simulator` *(control, no DB)* | 0.368 | **0.035** | **0.039** | — |
| `/` | 0.325 | 0.233 | 0.146 | −37% |
| `/insights` | 0.286 | 0.202 | 0.132 | −35% |
| `/activity` | 0.209 | 0.197 | 0.136 | −31% |
| `/leads` | 0.239 | 0.228 | 0.141 | −38% |
| `/production` | 0.213 | 0.201 | 0.137 | −32% |
| `/conversations` | 0.220 | 0.211 | 0.139 | −34% |
| `/tasks` | 0.786 | 0.206 | 0.141 | −32% |
| `/bookings` | 0.854 | 0.199 | 0.148 | −26% |
| `/team` | 0.516 | 0.212 | 0.129 | −39% |
| `/marketing` | 0.585 | 0.193 | 0.139 | −28% |
| `/campaigns` | 0.567 | 0.199 | 0.133 | −33% |
| `/attribution` | 0.598 | 0.210 | 0.138 | −34% |
| `/intelligence` | 0.233 | 0.218 | 0.136 | −38% |
| `/revenue` | 0.494 | 0.198 | 0.133 | −33% |
| `/inventory` | 0.677 | 0.345 | 0.155 | −55% |
| `/automations` | 0.772 | 0.189 | 0.159 | −16% |
| `/notifications` | 0.548 | 0.208 | 0.166 | −20% |
| `/admin` | 0.629 | 0.199 | 0.137 | −31% |

**Caveat, stated plainly:** an authentication `middleware.ts` landed from another
workstream partway through this session, and Supabase round-trip latency drifted
between ~50 ms and ~95 ms across runs. Absolute numbers in the two columns were
therefore not captured under identical conditions. To get a trustworthy figure I
reverted `/insights` to the old sequential code, measured both versions
back-to-back in the same minute, and restored it:

| `/insights` | Median | minus baseline = DB time |
|---|---|---|
| Old (sequential `gate` → `requireTable` → `listInsights`) | 0.211 s | 0.175 s |
| New (all three concurrent) | 0.134 s | **0.098 s** |
| Control `/simulator` (both runs) | 0.036 s | — |

**77 ms saved, 44% of the database time, 36% of total page time** — and 0.175 s
is almost exactly 2 × 0.098 s, which is the expected signature of collapsing two
sequential round-trips into one.

## What today's numbers hide

Migrations 0003 and 0006–0009 are **not applied** to the project's Supabase.
Twelve of eighteen pages currently hit a `requireTable` guard, render a
"run this migration" notice, and do no real work:

```
/insights /activity /tasks /bookings /team /marketing
/campaigns /revenue /automations /notifications      → short-circuit
/production                                          → missing pipeline_stage column
```

So the "before" column measured **two round-trips and nothing else** on most
pages. Once those tables exist, each page's real queries land on top. That is
why the fix targets the fixed per-page overhead rather than any single slow
query — the overhead is what every page pays, today and later.

## Bottlenecks found

### 1. Two to four sequential round-trips per page — the whole problem

Every page opened with:

```ts
const status = await gate();                    // round-trip 1: villa_leads probe
if (!status.ready) ...
const schema = await requireTable("villa_tasks", ...);  // round-trip 2: table probe
if (!schema.ok) ...
const [a, b, c] = await Promise.all([...]);     // round-trip 3: the actual data
```

The three are mutually independent — the table probe does not depend on the
schema probe, and neither depends on the page's data — but `await` forced them
into a chain. `/bookings/[id]` was the worst at four in a row
(`gate` → `requireTable` → `bookingById` → `listPayments`).

**Fix:** `gatedLoad()` in `src/lib/queries.ts` runs all three concurrently via
`Promise.allSettled` and applies the results in the original precedence order,
so behaviour is unchanged:

- config missing → checked **synchronously first**, before anything is
  dispatched, because `db()` throws without credentials;
- schema failure still beats a table failure, which still beats the data;
- a genuine data rejection still propagates instead of being swallowed.

The cost is at most two wasted queries on the failure paths, which only occur
while the project is still being set up. Applied to all 19 pages.

Verified: every "needs the *table*" notice still renders on the twelve
short-circuiting pages, and all data pages still render rows.

### 2. `gate()` and `requireTable()` were not memoised

Both are now wrapped in React's `cache()`. This does not save a round-trip on
its own — no page called either twice — but `gatedLoad()` and the shared schema
probe now both route through the same memo, so a page that calls `gatedLoad()`
*and* `requireTable()` (`/attribution`, `/production`) pays for one probe rather
than two. It also makes the guards safe to call from a shared component later.

### 3. `select("*")` on a 47-column table

`villa_leads` has ~47 columns including free-text notes, a `utm` JSON blob and
`requirements_notes`. The lead tables render **eleven** of them.
`recentLeads()` now selects only those eleven and returns a `LeadRow` type;
the detail page still reads the full row via `leadById()`. `/leads` requests 100
of these, so this is the largest payload reduction available. Verified: budget,
timeline, source, score, temperature and "last active" all still render.

### 4. Missing indexes → `supabase/migrations/0010_performance_indexes.sql`

**Written but deliberately NOT applied** — apply it yourself in the SQL editor.

Every `.eq()` / `.order()` / `.in()` in `src/lib/*.ts` was cross-checked against
the indexes in 0001, 0003, 0006 and 0009. The genuinely missing ones:

- **`villa_messages (lead_id, created_at)`** — the most important. The lead
  detail thread filters on `lead_id`, but the only index is
  `(conversation_id, created_at)`, whose leading column does not apply. This is
  the largest table in the schema.
- **`villa_conversations (last_message_at desc)`** — `/conversations` sorts
  globally on this; the existing index leads with `lead_id` and cannot serve it.
- **`villa_questions (unanswered, created_at desc)`** — existing index leads
  with `topic`.
- **`villa_handoffs`**, **`villa_site_visits`** — no indexes at all today.
- **`villa_leads (created_at)`** — the insights time-window scans.
- **Foreign keys.** Postgres indexes primary keys and unique constraints but
  *not* foreign keys. Every unindexed child FK makes a parent delete
  sequentially scan the child table. Covered for the tables that grow without
  bound: messages, tool calls, bookings, payments, tasks, follow-ups,
  automation runs, units, assets.

The file is idempotent (`create index if not exists`) and each 0006/0009 block
is wrapped in a `to_regclass` check, so it is safe to run **before** those
migrations — the blocks for absent tables are skipped. Re-run it afterwards to
pick them up. The footer lists the seventeen indexes that already exist and were
deliberately not duplicated, plus two skipped on purpose
(`villa_leads.opted_out`, `villa_units.status`) with reasons.

### 5. Knowledge-base memoisation — verified working, with a caveat

`knowledgeBaseBlock()` in `src/lib/agent/kb.ts` **is** correctly memoised: a
module-level `cached` value, a `TTL_MS` check on entry, and an
`invalidateKbCache()` escape hatch. It is not rebuilt per request.

But `loadKb()` — the underlying three-query fetch — is **not** memoised, and
`src/lib/agent/execute.ts` calls it at **seven** separate tool handlers. Each
call is 3 Supabase queries, so an agent turn that uses four tools issues twelve
redundant queries against data that changes daily at most. Reported rather than
fixed: `kb.ts` and `execute.ts` belong to another workstream.

## Deliberately NOT changed

- **`export const dynamic = "force-dynamic"` stays on every page.** This is a
  live CRM. A sales rep looking at a stale `/leads` table, a stale hot-lead
  count or a stale inventory board makes worse decisions than one who waited
  another 90 ms. Caching would also mask the write-then-read flows the console
  is built around (create a booking → `/revenue` must reflect it), which the
  API routes already handle correctly with `revalidatePath`. The fixed overhead
  was the real cost, and removing it does not trade away freshness.
- **No `revalidate` or `unstable_cache` on the project/villa-type catalogue.**
  It is tempting — `projectsWithTypes()` is called from three pages and changes
  rarely — but it is one query inside an already-concurrent batch, so it is off
  the critical path. Adding a second cache layer with its own invalidation rules
  for ~0 ms is not worth the correctness risk.
- **`requireTable()` still uses `select("*").limit(1)`.** A narrower select
  would save a kilobyte against an ~85 ms round-trip, and the existing comment
  documents why `head: true` cannot be used (PostgREST returns a bodiless 404
  that supabase-js reports as success, making a missing table look empty).
- **`messagesForLead()` still selects `*`.** It is capped at 200 rows and the
  detail view uses most columns; the index in 0010 is the real fix there.
- **No `src/lib/perf.ts`.** Everything needed was measurable from outside the
  process with `curl` plus the `/simulator` control. A permanent instrumentation
  module would have been unused code.
- **No N+1 queries found.** `inventorySummary()` and `unitsByStatus()` look like
  N+1 at a glance but loop over rows already fetched in one query; the grouping
  is in application code.

## What is still slow, and is not the app's fault

- **The agent turn on `/simulator` and the WhatsApp webhook.** `src/lib/agent/run.ts`
  runs a tool loop of up to `MAX_TURNS = 8`, each turn a full LLM call with
  `max_tokens: 16000`. With `LLM_PROVIDER=groq` on the free tier, that is
  provider queue time and rate-limit throttling, not application code — no
  amount of query tuning moves it. Reduce it by lowering `MAX_TURNS`, cutting
  `max_tokens`, or moving to a paid tier. *Not quantified here: measuring it
  means driving real traffic to Groq, which is out of scope for this task.*
  The `/simulator` **page** itself renders in ~36 ms; the latency is entirely in
  `POST /api/simulate`.
- **The ~85–95 ms Supabase round-trip.** This is physical distance between the
  dev machine and the Supabase region. The app is now down to roughly one such
  round-trip per page, which is the floor without co-locating the deployment
  with the database or adding a cache layer. Deploying to a region near the
  Supabase project is the single biggest remaining win and is a hosting choice,
  not a code change.
- **Dev-server compile on first hit.** The 0.5–0.85 s first-hit numbers are
  Next.js compiling routes on demand. `next build` + `next start` does not have
  this; it is not a production characteristic.
