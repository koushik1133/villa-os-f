# Requirement Traceability — Praneeth's call

**What this is:** every requirement Praneeth stated on the call, one per side-heading, with the actual file that implements it — or an honest note that it isn't built.

**How to read the statuses:**

| Status | Meaning |
| --- | --- |
| ✅ Implemented | Built, wired end to end, works with the keys already in `.env.local` |
| ⚠️ Partially implemented | Something real exists, but it does not cover the whole ask |
| 🔨 Scaffolded, needs credentials | Schema/UI/policy exists; the vendor account or API access does not |
| ❌ Not built | Nothing in this repo does this |

Two cross-cutting caveats before the list:

- Nothing here has been exercised against live Meta or Anthropic APIs — the build, typecheck and route handlers pass, and the webhook correctly rejects unsigned requests, but the actual call paths need real keys to prove out. See the "Not done yet" section of [README.md](README.md).
- There is **no login gate on the console**. `DASHBOARD_PASSWORD` exists in [.env.example](.env.example) but nothing reads it — `grep` finds it only in [src/lib/env.ts](src/lib/env.ts). There is no `src/middleware.ts`. Every page below, including `/admin`, is open to anyone who reaches the URL. This matters more than usual here, because the "admin control panel" *is* one of the requirements.

---

## 1. "I want it as a typical standard BRD document… so we can finalize on that BRD, we will go with the application development"

- **What he asked for** — a written Business Requirements Document he can review and correct, produced *before* more development happens, so both sides are agreeing to the same thing.
- **Status** — ✅ Implemented
- **Where** — [BRD.md](BRD.md), [OPEN-QUESTIONS.md](OPEN-QUESTIONS.md), [PHASE-2-VOICE-AND-SOCIAL-AUTOMATION.md](PHASE-2-VOICE-AND-SOCIAL-AUTOMATION.md)
- **How** — `BRD.md` covers executive summary, business context, seven functional requirement areas (a–g), non-functional requirements including his cost sensitivity, an explicit **Assumptions** section that labels every gap Vivek filled in himself, out-of-scope, a two-bucket phasing recommendation (buildable this weekend vs. blocked on his accounts), and ten open questions for sign-off. `OPEN-QUESTIONS.md` is the second round — the questions the four uploaded PDFs genuinely could not answer, graded P0/P1/P2.
- **Gap** — none on the document itself. It is still marked `Status: DRAFT` and has not been signed off; the ten questions in §8 and the six P0 items in `OPEN-QUESTIONS.md` (per-villa-type pricing, what "++" covers, corner-unit rates, payment schedule, cancellation policy, APF banks) are unanswered. The agent quotes "not recorded" on all of them today.

---

## 2. Social media integration and publishing "at optimal cost"

- **What he asked for** — the system should reach customers on the platforms they actually use (WhatsApp, Instagram), and the cost per lead should be kept low deliberately, not as an afterthought.
- **Status** — ⚠️ Partially implemented (WhatsApp only; cost engineering is real, cross-platform publishing is not)
- **Where** — [src/app/api/whatsapp/route.ts](src/app/api/whatsapp/route.ts), [src/lib/whatsapp/client.ts](src/lib/whatsapp/client.ts), [src/lib/whatsapp/verify.ts](src/lib/whatsapp/verify.ts), [src/lib/agent/prompt.ts](src/lib/agent/prompt.ts), [src/lib/agent/run.ts](src/lib/agent/run.ts), [src/lib/agent/scoring.ts](src/lib/agent/scoring.ts), [src/lib/env.ts](src/lib/env.ts)
- **How** — WhatsApp is fully wired: Meta's `GET` handshake, HMAC signature verification on every `POST` (unsigned requests get a 401), fast ack so Meta doesn't retry into a double-reply, and click-to-WhatsApp ad referral capture (`message.referral` → source/ad ID/campaign on the lead). On cost: the prompt is engineered as a stable cached prefix — `tools → system prompt → knowledge base`, cache breakpoint on the last system block, with all per-customer volatile content pushed into the user turn by `buildLeadContext()` so the prefix stays byte-identical across every customer. Lead scoring is deterministic arithmetic in `scoring.ts`, not a model call. `LLM_PROVIDER=groq` switches the whole agent to a free-tier provider ([src/lib/agent/run-groq.ts](src/lib/agent/run-groq.ts)) for testing without burning Anthropic spend.
- **Gap** — Instagram is a row in a settings table, not an integration. No Instagram messaging, no Instagram publishing. "Optimal cost" has no number attached to it — `BRD.md` §8 Q2 asks for the ceiling and it hasn't come back, so there is no budget guard anywhere in code.

---

## 3. "It should read the documents and understand the product"

- **What he asked for** — upload the project documents and have the system genuinely understand the villa product from them, rather than being hand-fed facts.
- **Status** — ⚠️ Partially implemented (the documents *were* read and the understanding is real; the *pipeline* to do it again is not)
- **Where** — [supabase/migrations/0007_pdf_resolved_facts.sql](supabase/migrations/0007_pdf_resolved_facts.sql), [supabase/migrations/0005_real_glentree_data.sql](supabase/migrations/0005_real_glentree_data.sql), [supabase/migrations/0002_seed_glentree_serenity.sql](supabase/migrations/0002_seed_glentree_serenity.sql), [supabase/migrations/0008_register_real_assets.sql](supabase/migrations/0008_register_real_assets.sql), [OPEN-QUESTIONS.md](OPEN-QUESTIONS.md)
- **How** — All four PDFs in `/public` (full brochure, mini brochure with the 185-row area statement, site layout, sales presentation) plus the six images were read and transcribed into `villa_projects` / `villa_types` / `villa_faqs`. `0007` resolved facts that `0002` had left NULL — which plot size is 3BHK vs 4BHK (200→3, 267→4, 300→4+maid, confirmed by matching built-up SFT), ~28 named connectivity destinations with the developer's own drive-time minutes, clubhouse names and sizes, the legal entity, permit numbers. `0005` fact-checked the live website separately. Conflicts were **not** silently resolved: the June 2029 vs. October 2029 possession-date conflict and the 184 vs. 185 villa-count discrepancy are both written up in `OPEN-QUESTIONS.md` rather than papered over.
- **Gap** — there is no upload endpoint and no document-parsing code. `grep` for `formData` finds only admin/booking/inventory form posts; there is no `pdf-parse`, no Supabase Storage write, no ingestion route. The reading was done once, by hand, and the output committed as SQL. **A new brochure means someone writes migration `0010` by hand.** That is a materially different thing from "the system reads uploaded documents", and it should be said plainly.

---

## 4. Auto-create templates, WhatsApp ads and Instagram Reels from those documents

- **What he asked for** — from the uploaded material, the system should produce the ad templates and the Reel/creative itself, so nobody sits and makes them by hand.
- **Status** — ⚠️ Partially implemented (copy and scripts yes; rendered creative no)
- **Where** — [src/lib/marketing/gemini.ts](src/lib/marketing/gemini.ts), [src/app/api/marketing/generate/route.ts](src/app/api/marketing/generate/route.ts), [src/app/marketing/MarketingClient.tsx](src/app/marketing/MarketingClient.tsx), [src/app/marketing/page.tsx](src/app/marketing/page.tsx), [supabase/migrations/0006_content_drafts.sql](supabase/migrations/0006_content_drafts.sql)
- **How** — the Content Studio at `/marketing` generates against five formats (`post`, `reel_short`, `whatsapp`, `meta_ad`, `google_ad`), five tones and five languages. `inputsFromProject()` pulls the project name, location, price and USPs out of the real Supabase rows rather than hand-typed strings, and the Gemini prompt is explicitly instructed never to invent price, amenities, approvals or discounts. For `reel_short` it returns a four-scene script with per-scene visual prompt, voiceover line and audio suggestion. Output is saved to `villa_content_drafts` with a `generated_by_ai` flag that is `false` when the offline fallback template ran instead of Gemini — so a draft never claims AI authorship it didn't have.
- **Gap** — two real gaps. (a) It generates from the *structured project row*, not from the PDF — so it inherits whatever `0007` transcribed, and a fact that never made it into the DB can't reach an ad. (b) It produces a **script and a `visualPrompt` string, not a rendered image or a video file**. Nothing in this repo turns those into an actual Reel. `PHASE-2` §2.1 flags Canva MCP as the candidate for static creative and §2.2 flags video assembly as a separate, undecided vendor choice.

---

## 5. Publish to the social platforms

- **What he asked for** — once the content exists, the system posts it, rather than someone downloading and uploading it manually.
- **Status** — ❌ Not built
- **Where** — [supabase/migrations/0006_content_drafts.sql](supabase/migrations/0006_content_drafts.sql) (header explains why), [src/app/api/marketing/mark-ready/route.ts](src/app/api/marketing/mark-ready/route.ts), [PHASE-2-VOICE-AND-SOCIAL-AUTOMATION.md](PHASE-2-VOICE-AND-SOCIAL-AUTOMATION.md) §2.3
- **How** — the only "publish-adjacent" endpoint is `mark-ready`, which flips `villa_content_drafts.status` between `draft`/`ready`/`archived` and nothing else. Its docblock says so: *"Never publishes anything."* The `/marketing` page header says the same to the user: *"Nothing here publishes anywhere — mark a draft ready, then post it yourself until real channel credentials are connected."*
- **Gap** — this is deliberate, and worth knowing why: the demo repo this generation logic came from **had** a publish endpoint, and it was fake — hardcoded URLs and invented reach numbers. That was not ported, on purpose (see the `0006` migration header). Real publishing needs a verified Meta Business account with a linked Instagram Business account (Graph API) and, for Shorts, a Google Cloud OAuth app on the YouTube Data API. Both require platform review that takes days and is outside our control.

---

## 6. Inbound calls redirected to an AI agent

- **What he asked for** — calls to his number get picked up by an AI instead of a person, so inquiries are handled outside his working hours.
- **Status** — ❌ Not built
- **Where** — [PHASE-2-VOICE-AND-SOCIAL-AUTOMATION.md](PHASE-2-VOICE-AND-SOCIAL-AUTOMATION.md) §1
- **How** — nothing. There is no telephony code, no STT, no TTS, no call-transfer path anywhere in `src/`.
- **Gap** — a phone call is five layers that must all run inside a live-conversation latency budget: a forwardable number, speech-to-text, the reasoning layer, text-to-speech, and a live warm-transfer mechanism. `PHASE-2` §1.2 lays out the two honest options — an all-in-one voice platform (Vapi / Bland / Retell: days to stand up, less control, platform dependency) versus a build-it-yourself stack (Twilio + Deepgram + the existing Claude agent + ElevenLabs: more control and reuses `src/lib/agent/scoring.ts` directly, materially more integration and maintenance). **Four decisions block the first line of code:** which vendor, which phone number, the per-minute budget ceiling, and forward-vs-replace on his existing landline. This one genuinely cannot be faked or half-built.

---

## 7. AI answers from approved uploaded data — villa size, launch date, approvals, "all the questions"

- **What he asked for** — the AI should be able to field the real questions buyers ask, using only the material he has approved.
- **Status** — ✅ Implemented (on WhatsApp text)
- **Where** — [src/lib/agent/kb.ts](src/lib/agent/kb.ts), [src/lib/agent/execute.ts](src/lib/agent/execute.ts), [src/lib/agent/prompt.ts](src/lib/agent/prompt.ts), [src/lib/agent/tools.ts](src/lib/agent/tools.ts)
- **How** — the guardrail is structural, not just instructional. `knowledgeBaseBlock()` renders the approved Supabase rows into the cached prompt prefix, wrapped in `# APPROVED KNOWLEDGE BASE … Everything below is approved for you to state to a customer. Nothing outside it is.` `searchKnowledgeBase()` scores the query against eleven derived sections per project — overview, location, approvals/legal (HMDA permit + RERA), pricing, USPs, amenities, specifications, sustainability, connectivity, social infrastructure, financing — plus the FAQ table, and returns the top five. Villa sizes come from `get_villa_types` (plot sq yd, built-up SFT, facing, bedrooms, floors, price). Crucially, **a NULL is treated as meaningful**: `formatInr(null)` returns the literal string *"not recorded — you must tell the customer the sales team will confirm"*, and the prompt states that a missing value "is information, not an invitation to fill the gap."
- **Gap** — the biggest questions buyers ask are still NULL because Praneeth hasn't answered them: per-type pricing, what "++" covers, corner-unit rates, payment schedule ([OPEN-QUESTIONS.md](OPEN-QUESTIONS.md) P0 items 1–6). The agent handles this correctly — it declines and logs — but the customer experience of "the team will confirm" repeats on the single most common question until that price sheet lands.

---

## 8. The AI must GENERATE answers, not read out a canned Q&A

- **What he asked for** — explicitly not a scripted FAQ bot. It should form the answer, and it shouldn't parrot the question back before answering.
- **Status** — ✅ Implemented
- **Where** — [src/lib/agent/run.ts](src/lib/agent/run.ts), [src/lib/agent/prompt.ts](src/lib/agent/prompt.ts), [src/lib/agent/execute.ts](src/lib/agent/execute.ts)
- **How** — `runAgentAnthropic()` runs a real tool loop against Claude (adaptive thinking, up to 8 tool round-trips per customer message, 40 messages of replayed history). The FAQ rows are *retrieval inputs* scored alongside project sections — they are not response templates, and nothing in the code path can return one verbatim. The prompt enforces the delivery style directly: *"Write like a helpful person texting, not like a brochure"*, *"Do not narrate what you are about to do. Just do it and give them the result"*, *"Never repeat a question they already answered"*, two-to-four lines, one or two questions at a time, match the customer's language (Hindi/Telugu/Tamil/Kannada/Malayalam).
- **Gap** — none. Worth noting the tension is handled the right way round: it generates freely in *style*, but is hard-constrained in *substance* by the knowledge base.

---

## 9. Separate potential clients from casual inquiries "based on the emotion, based on the conversation"

- **What he asked for** — the AI should tell a serious buyer from someone just curious, reading both what they say and how they say it.
- **Status** — ⚠️ Partially implemented — "based on the conversation" yes, "based on the emotion" no
- **Where** — [src/lib/agent/scoring.ts](src/lib/agent/scoring.ts), [src/lib/agent/finalize.ts](src/lib/agent/finalize.ts), [BRD.md](BRD.md) §5 (assumption)
- **How** — `scoreLead()` produces a 0–100 score from stated facts plus behavioural signals gathered during the turn: purchase timeline (up to 30 points), buyer purpose (up to 12), requirement specificity (bedrooms 6, villa type 8, facing 3), budget disclosed (8), contactability (name 4, email 3, financing 4), then live signals — site visit requested +20, asked about booking +15, requested handoff +12, material requested +5, and sustained engagement capped at 6 *"so a chatty tyre-kicker can't reach HOT."* `temperatureFor()` maps ≥80 → hot, ≥50 → warm, else cold. It is deliberately deterministic and rule-based rather than model-judged, so the sales team can see exactly why a lead is hot and the number means the same thing next month.
- **Gap** — **this is not emotion detection.** It reads intent signals in the text; it does not analyse tone, sentiment or voice affect. `BRD.md` §5 flags this as an explicit assumption needing his confirmation, and `BRD.md` §8 Q3 asks him directly. If he meant literal voice-emotion analysis on calls, that is a different and more expensive build, and it is also downstream of requirement 6 existing at all. Separately, the score thresholds have never been tuned against real converted leads — the point weights are a reasoned starting position, not a calibrated model.

---

## 10. Escalate qualified leads to the sales/marketing team

- **What he asked for** — when the AI decides someone is serious, a human on his team gets them immediately, and the customer shouldn't have to repeat themselves.
- **Status** — ✅ Implemented
- **Where** — [src/lib/agent/execute.ts](src/lib/agent/execute.ts) (`requestHumanHandoff`, `buildHandoffPayload`), [src/lib/agent/tools.ts](src/lib/agent/tools.ts), [src/lib/automations.ts](src/lib/automations.ts), [src/lib/team.ts](src/lib/team.ts), [src/lib/notifications.ts](src/lib/notifications.ts)
- **How** — `request_human_handoff` fires on twelve enumerated reasons (asked for a salesperson, wants to negotiate, ready to book, legal/tax/financing question, complaint, outside the knowledge base, strong buying intent…). `buildHandoffPayload()` composes a briefing a rep reads in under 30 seconds: temperature and score, name/phone/email/location/NRI flag, source and campaign, project, villa type, bedrooms, budget, purpose, timeline, financing, requirements notes, what material has already been sent, the handoff reason, urgency, and a two-line summary. It writes to `villa_handoffs`, flips the lead to `handoff_status = 'requested'`, then WhatsApps the briefing to `SALES_TEAM_WHATSAPP`. **If that send fails, `notified` stays false and the tool result explicitly tells the model not to claim it went out** — it says the team will be in touch without mentioning a technical fault. On top of that, the `assign_lead` automation action picks the least-loaded active rep from `villa_team_members` (load-based round-robin, so a rep returning from leave catches up rather than being skipped).
- **Gap** — routing today is one `SALES_TEAM_WHATSAPP` number for the WhatsApp alert; `villa_team_members` drives in-console assignment but the outbound alert doesn't yet fan out per-rep. `OPEN-QUESTIONS.md` P2 item 13 asks for the real rep names and numbers.

---

## 11. Store casual inquiries as "future clients or future perspectives"

- **What he asked for** — don't throw away the people who aren't ready. Keep them as a future prospect pool.
- **Status** — ✅ Implemented
- **Where** — [supabase/migrations/0001_schema.sql](supabase/migrations/0001_schema.sql), [src/lib/conversation.ts](src/lib/conversation.ts), [src/lib/kanban.ts](src/lib/kanban.ts), [src/app/leads/page.tsx](src/app/leads/page.tsx), [src/app/production/page.tsx](src/app/production/page.tsx)
- **How** — every inbound contact becomes a `villa_leads` row at first message via `getOrCreateLead()`, regardless of temperature — cold leads are stored identically to hot ones, just scored below 50. Nothing deletes them. They carry the full profile the agent learned, the conversation history, and a `pipeline_stage` from the seven-stage funnel in `kanban.ts` (`new → qualifying → qualified → site_visit_scheduled → negotiation → booked → lost`). `/leads` lists them and `/production` shows the board.
- **Gap** — none structurally. Note the prompt tells the agent to be useful and *not* push a cold lead — which is the right behaviour, but it means the cold pool grows quietly and only requirement 12 gives it any value.

---

## 12. Reconnect with stored prospects after 15 days, "a month or two"

- **What he asked for** — go back to the people who weren't ready, automatically, after a couple of weeks or months.
- **Status** — 🔨 Scaffolded, needs credentials (and a scheduler, and an approved template)
- **Where** — [src/app/api/cron/follow-ups/route.ts](src/app/api/cron/follow-ups/route.ts), [src/lib/tasks.ts](src/lib/tasks.ts), [src/lib/automations.ts](src/lib/automations.ts), [supabase/migrations/0009_business_os.sql](supabase/migrations/0009_business_os.sql), [src/app/tasks/page.tsx](src/app/tasks/page.tsx)
- **How** — `villa_follow_ups` holds a scheduled time, channel, message-or-template, and status. The dispatcher at `GET /api/cron/follow-ups` is genuinely production-shaped: it **fails closed** if `CRON_SECRET` is unset (503 with instructions rather than running open), does constant-time bearer comparison, claims each row with a conditional `update … is('dispatched_at', null)` so two overlapping cron runs can't double-send, cancels anything for an opted-out lead, and never auto-retries a failure because a failed request may still have been delivered. The `send_message` / `generate_ai_followup` automation actions queue rows at a configurable `delayHours`, and `/tasks` has a manual scheduling form.
- **Gap** — three things stand between this and a 15-day reconnect actually happening. (a) **No cron is configured** — there is no `vercel.json` or scheduler in the repo; the route exists and nothing calls it. (b) **It only ever sends approved WhatsApp templates**, by design — a 15-day-old follow-up is far outside Meta's 24-hour customer-service window, where free text is rejected and retrying it gets a business number rate-limited then banned. `manualReason()` therefore flags any row without a `template_name` for a human. **No template is registered today**, so every follow-up would currently land as `manual`. (c) **No 15-day or 30-day rule is seeded** — `villa_automations` ships empty; someone has to author the rule at `/automations`, and `BRD.md` §8 Q7 still asks for the exact cadence.

---

## 13. AI sends pictures and layout details on request

- **What he asked for** — when a customer asks to see the villa or the layout, the AI sends it.
- **Status** — ✅ Implemented
- **Where** — [src/lib/agent/execute.ts](src/lib/agent/execute.ts) (`getAssets`, `sendMedia`), [src/lib/agent/tools.ts](src/lib/agent/tools.ts), [src/lib/whatsapp/client.ts](src/lib/whatsapp/client.ts), [supabase/migrations/0008_register_real_assets.sql](supabase/migrations/0008_register_real_assets.sql)
- **How** — `0008` registers the ten real files sitting in `/public` as `villa_assets` rows: full brochure, mini brochure (with the 185-row area statement), the site layout PDF as `master_plan`, the sales presentation, and the six villa images. `get_assets` retrieves by kind; `send_media` delivers over the WhatsApp media API and then writes a `villa_messages` row and flips the matching `brochure_sent` / `floor_plan_sent` / `price_sheet_sent` / `video_sent` flag on the lead, which feeds back into the prompt as *"Brochure already sent — do not send it again unless asked."* Retrieval and sending are deliberately two tools, and the tool description forbids passing any URL the model constructed itself. If delivery throws, the tool result tells the agent it failed and that it **must not claim it was sent**.
- **Gap** — none for the core ask. All six images are marked `is_ai_generated = true` (the project completes in 2029, so a photo of finished villas cannot be real), and the tool result instructs the agent to say so — pending Praneeth's confirmation in `OPEN-QUESTIONS.md` P1 item 11.

---

## 14. The AI picks WHICH asset to send — current-status images vs. model villa vs. the 267 sq yd details

- **What he asked for** — not just "send the brochure", but judgement: if someone asks how construction is going, send the current-status photos; if they ask about the 267 sq yd villa, send *that* villa's details.
- **Status** — ⚠️ Partially implemented
- **Where** — [src/lib/agent/tools.ts](src/lib/agent/tools.ts), [src/lib/agent/execute.ts](src/lib/agent/execute.ts), [supabase/migrations/0008_register_real_assets.sql](supabase/migrations/0008_register_real_assets.sql)
- **How** — the machinery for this exists. `get_assets` takes a ten-value `kind` enum (`brochure`, `floor_plan`, `site_plan`, `master_plan`, `price_sheet`, `image`, `video`, `virtual_tour`, `location_map`, `other`) **plus an optional `villa_type` filter** that resolves the type name to a `villa_type_id` and narrows the query — that is exactly the "the 267 one specifically" path. Each asset row carries a `description`, so the model chooses between candidates on their content, and the tool description nudges it proactively (*"when sending one would obviously help — e.g. after recommending a villa type, get its floor plan"*).
- **Gap** — the *data* doesn't yet support the judgement the *code* allows. (a) **There are no construction-status photos at all** — all six images are conceptual renders of the finished community, so "how does it look right now" has nothing correct to send. `OPEN-QUESTIONS.md` P1 item 12 asks whether there is even a model villa or site office to show. (b) **No asset row has a `villa_type_id` set** — `0008` registers everything at project level, so the `villa_type` filter currently narrows nothing and a 267-specific request resolves to the whole brochure. Per-type floor plans exist inside the brochure PDF (pages 11–16) but have not been split out as individual assets.

---

## 15. "This, this, this, you can share, this, this, this, you cannot share"

- **What he asked for** — his single most explicit requirement: an admin panel where *he* decides which data and which images the AI is allowed to give a customer. That decision stays with him, not with the agent.
- **Status** — ⚠️ Partially implemented — **and the enforcement half is missing**
- **Where** — [src/app/admin/page.tsx](src/app/admin/page.tsx), [src/lib/permissions.ts](src/lib/permissions.ts), [src/app/api/admin/toggle/route.ts](src/app/api/admin/toggle/route.ts), [supabase/migrations/0004_content_permissions.sql](supabase/migrations/0004_content_permissions.sql), [src/lib/agent/execute.ts](src/lib/agent/execute.ts)
- **How** — `0004` adds `villa_assets.shareable_by_ai` (defaulting `true` so existing assets keep behaving as they did). `/admin` renders every asset with a SHAREABLE / NOT SHAREABLE pill and a "Block sharing" / "Allow sharing" button; the toggle route reads the current value and inverts it via `setAssetShareable()`. The page copy is exactly the right framing: *"Uploaded and current does not mean shareable."* On the data side, the NULL-means-unapproved convention in the knowledge base is the same idea applied to facts rather than files — a price Praneeth hasn't approved simply isn't there for the agent to state.
- **Gap** — **the agent does not honour the flag.** `getAssets()` in [src/lib/agent/execute.ts](src/lib/agent/execute.ts) builds its query as:

  ```ts
  .from("villa_assets")
  .select("*")
  .in("project_id", ids)
  .eq("kind", input.kind)
  .eq("is_current", true)
  ```

  There is no `.eq("shareable_by_ai", true)`. A `grep` for `shareable_by_ai` across the repo returns hits only in `permissions.ts`, `admin/page.tsx`, the toggle route and the migration — **nothing on the agent path reads it**. So pressing "Block sharing" today changes the badge in the console and nothing else: the agent can still retrieve that asset and `send_media` will still deliver it to a customer. This is one line of code, but until it is added the control panel is advisory, not enforcing — and this is the requirement Praneeth was most emphatic about. (Flagged, not fixed: this file belongs to another agent this session.)

  Second gap: the panel governs **assets**, not **facts**. There is no per-field "don't share the possession date" switch — field-level control is expressed only by leaving a column NULL in the database, which nobody can do from the UI.

  Third, smaller gap: `villa_assets` carries a permissive `for select using (true)` RLS policy in [supabase/migrations/0001_schema.sql](supabase/migrations/0001_schema.sql) — the knowledge base is treated as public marketing collateral, write-locked but world-readable. That was a reasonable call when every asset was a brochure, but `shareable_by_ai = false` is meant to mark something *sensitive*, and a row marked sensitive is still readable with the anon key. Whatever gets marked "cannot share" should probably not sit behind a public read policy.

---

## 16. Control panel for which social platforms are enabled, and the credentials per platform

- **What he asked for** — he decides which platforms are switched on, and the platform credentials live under admin control.
- **Status** — 🔨 Scaffolded, needs credentials
- **Where** — [supabase/migrations/0004_content_permissions.sql](supabase/migrations/0004_content_permissions.sql), [src/app/admin/page.tsx](src/app/admin/page.tsx), [src/lib/permissions.ts](src/lib/permissions.ts), [supabase/migrations/0009_business_os.sql](supabase/migrations/0009_business_os.sql) (`villa_integrations`)
- **How** — `villa_channel_settings` seeds four rows — `whatsapp`, `instagram`, `youtube`, `whatsapp_status` — each with `enabled` and a `credential_status` of `not_connected` / `connected` / `error`. `/admin` renders them as a table with an Enable/Disable button and a credential pill. `0009` extends the same idea to non-messaging providers in `villa_integrations` (WhatsApp Cloud, Instagram, Meta Ads, Google Ads, YouTube, Gemini, Anthropic, Groq) with `is_connected`, `status`, `last_sync_at` and `error_message`.
- **Gap** — the file's own first four lines say it: *"Toggling a channel here only flips the on/off + sharing policy stored in `villa_channel_settings`. Actually wiring a channel's OAuth/API credentials … is a separate integration task per channel and is not built here — there is no publishing pipeline yet."* Concretely: there is no UI or storage for entering credentials (they live in `.env.local`), `credential_status` is never written by anything — it stays `not_connected` forever — and **nothing reads `enabled` at send time**. `grep` confirms `channelSettings()` is called only by `/admin` and its own toggle route. Disabling WhatsApp in the panel would not stop the WhatsApp agent replying.

---

## 17. His own database for both potential clients and future inquiries

- **What he asked for** — the system holds its own lead data; both the hot ones and the ones parked for later.
- **Status** — ✅ Implemented
- **Where** — [supabase/migrations/0001_schema.sql](supabase/migrations/0001_schema.sql), [supabase/migrations/0009_business_os.sql](supabase/migrations/0009_business_os.sql), [src/lib/supabase.ts](src/lib/supabase.ts), [src/lib/queries.ts](src/lib/queries.ts)
- **How** — Supabase Postgres, everything prefixed `villa_` so it drops into an existing project without collision. Core: `villa_leads`, `villa_conversations`, `villa_messages`, `villa_projects`, `villa_types`, `villa_units`, `villa_assets`, `villa_faqs`, `villa_site_visits`, `villa_handoffs`, `villa_objections`, `villa_questions`, `villa_tool_calls`. `0009` adds the business layer: `villa_team_members`, `villa_tasks`, `villa_follow_ups`, `villa_bookings`, `villa_payments`, `villa_campaigns`, `villa_activities`, `villa_automations`, `villa_automation_runs`, `villa_notifications`, `villa_ai_insights`, `villa_touchpoints`, `villa_integrations`, plus four reporting views. Security posture: every customer-data table has **RLS on with no permissive policy**, so a leaked anon key reads nothing; the app reaches the data only through the server-side service-role client in `supabase.ts`.
- **Gap** — `BRD.md` §8 Q4 asks whether an existing CRM (Zoho/HubSpot/Salesforce) should be the system of record instead. Unanswered, so this is currently the sole system of record.

---

## 18. Check back with the marketing team whether a routed lead converted

- **What he asked for** — after a lead is handed over, the system should come back and ask whether it turned into anything, rather than losing sight of it.
- **Status** — ⚠️ Partially implemented
- **Where** — [src/lib/insights.ts](src/lib/insights.ts), [src/lib/automations.ts](src/lib/automations.ts), [src/lib/tasks.ts](src/lib/tasks.ts), [src/app/tasks/page.tsx](src/app/tasks/page.tsx), [src/app/insights/page.tsx](src/app/insights/page.tsx)
- **How** — the console does chase the loop. `ruleBasedInsights()` raises **"Handoff requests were never notified"** (critical — a buyer asked for a human and nobody was told), **"Hot leads have no owner"**, **"Live leads are going cold"** (no contact in 3+ days, excluding opted-out/booked/lost) and **"Follow-ups are overdue"**, each carrying the actual counts it was derived from in an `evidence` array so a claim can be checked rather than trusted. Automations can auto-create a `villa_tasks` row on a matching lead, and `/tasks` is where a rep works that queue.
- **Gap** — there is **no automatic "did this handoff convert?" check-back**. Two reasons. (a) `handoff_requested` is listed in `TRIGGER_EVENTS` but is deliberately excluded from `LIVE_TRIGGERS` — the only two events anything actually fires are `lead_created` and `lead_status_changed`, both from [src/lib/conversation.ts](src/lib/conversation.ts). `site_visit_scheduled`, `handoff_requested` and `booking_created` rules can be authored but will never run. The code is honest about this and labels them dormant in the UI rather than letting an operator believe a rule is live. (b) No such rule is seeded anyway. Today the loop closes because a human notices a stale-lead insight, not because the system asked.

---

## 19. Update the database when a lead becomes an actual client

- **What he asked for** — when the sale happens, the record reflects it.
- **Status** — ✅ Implemented
- **Where** — [src/lib/bookings.ts](src/lib/bookings.ts), [src/app/bookings/page.tsx](src/app/bookings/page.tsx), [src/app/bookings/[id]/page.tsx](src/app/bookings/[id]/page.tsx), [src/app/api/bookings/route.ts](src/app/api/bookings/route.ts)
- **How** — `createBooking()` allocates a `GS-<year>-NNNN` booking number (retrying on the unique-violation race if two reps book at once), writes the `villa_bookings` row, and **moves the lead to `pipeline_stage: 'booked'` in the same call**. It copies `source` and `campaign` off the lead onto the booking at booking time, *"so revenue attribution survives even if the lead record is later edited."* `updateBookingStatus()` walks the six-state ladder (`initiated → agreement_sent → signed → advance_paid → registered`, plus `cancelled`) and stamps `agreement_date` / `registration_date` automatically on the transitions that mean those things. `derivePaymentStatus()` computes paid/partial/pending from the two amount columns rather than trusting a stored status that could have drifted.
- **Gap** — conversion is confirmed **manually** by a rep in the console, as `BRD.md` §5 assumed. `BRD.md` §8 Q9 — what exactly counts as a conversion (signed contract? payment? deposit?) and who marks it — is still unanswered, so the six statuses are our proposal, not his definition.

---

## 20. Track the revenue generated

- **What he asked for** — see the money the system produced, so the return is measurable.
- **Status** — ✅ Implemented (for booking revenue; ad spend is manual entry)
- **Where** — [src/app/revenue/page.tsx](src/app/revenue/page.tsx), [src/lib/bookings.ts](src/lib/bookings.ts), [src/lib/campaigns.ts](src/lib/campaigns.ts), [src/app/campaigns/page.tsx](src/app/campaigns/page.tsx), [src/app/attribution/page.tsx](src/app/attribution/page.tsx), [supabase/migrations/0009_business_os.sql](supabase/migrations/0009_business_os.sql)
- **How** — three Postgres views do the arithmetic. `villa_revenue_monthly` gives bookings, booked value and collected value per month, excluding cancellations. `villa_campaign_performance` joins campaigns to leads to bookings and computes leads, qualified leads, bookings, revenue, **cost-per-lead and ROAS**. `villa_team_performance` gives per-rep numbers — and pre-aggregates bookings in a subquery rather than joining them inline, specifically because joining bookings alongside leads and site visits fans out the rows and silently inflates `sum(value_inr)`. `/revenue` shows booked vs. collected by month and by source, `/attribution` shows first-touch alongside multi-touch journeys from `villa_touchpoints`.
- **Gap** — no ad-platform API is connected, so `spent_inr`, `impressions` and `clicks` on `villa_campaigns` are whatever a human types into the form at `/campaigns`. CPL and ROAS are therefore only as accurate as that manual entry. The numbers themselves are real — nothing is mocked — but the spend side is hand-fed.

---

## 21. "Up and running by this weekend" — campaigns restarting, 1–2 calls a week expected

- **What he asked for** — he is about to restart his campaigns and expects one or two inbound calls a week; he wants something live by the weekend.
- **Status** — ⚠️ Partially implemented — the WhatsApp half can be live this weekend; the calls half cannot
- **Where** — [src/app/simulator/page.tsx](src/app/simulator/page.tsx), [src/app/api/simulate/route.ts](src/app/api/simulate/route.ts), [SETUP-GUIDE.md](SETUP-GUIDE.md), [README.md](README.md), [PHASE-2-VOICE-AND-SOCIAL-AUTOMATION.md](PHASE-2-VOICE-AND-SOCIAL-AUTOMATION.md) §3
- **How** — the simulator runs the **identical** agent path a real WhatsApp customer hits — same `handleInbound()`, same prompt, same tools, same CRM writes — but returns replies to the browser instead of calling Meta, so the whole flow is demoable before the Meta app is even configured. It surfaces per-message cache read/write so cost behaviour is visible. `SETUP-GUIDE.md` is the step-by-step. The dashboard degrades to a setup checklist rather than an error page when keys are missing (`gate()` in [src/lib/queries.ts](src/lib/queries.ts)).
- **Gap** — restarting campaigns points at requirement 5 (publishing, not built) and the calls point at requirement 6 (voice, not built). Ironically the "1–2 calls a week" volume is an argument *for* the cheaper all-in-one voice platform in `PHASE-2` §1.2 — at that volume, per-minute pricing barely matters and integration time dominates. Worth raising with him.

---

## 22. Eventually deploy this as a multi-tenant product for other clients

- **What he asked for** — longer term, package this so other businesses can upload their own content, connect their own accounts, and run their own version.
- **Status** — ❌ Not built (correctly — it is explicitly a future phase)
- **Where** — [BRD.md](BRD.md) §3g
- **How** — nothing. A `grep` for `tenant`, `org_id` and `workspace` across `src/` and `supabase/` returns **zero hits**. The schema is single-tenant throughout.
- **Gap** — this is a deliberate non-decision, not an oversight: `BRD.md` §8 Q10 asks him directly whether to design for multi-tenancy now or later, so the first build isn't over-engineered for it. The honest engineering note is that retrofitting is real work — a tenant column and RLS policy on every `villa_*` table, tenant-scoped credentials (which today are process-wide env vars, not per-tenant rows), and tenant-scoped prompt caching. That said, two current choices happen to help: the `villa_` prefix means the schema already coexists with other tables, and the knowledge base is data in Postgres rather than baked into the prompt, so a second tenant's project data is an insert, not a code change.

---

## 23. The multi-social template platform he'd mentioned previously

- **What he asked for** — the thing he'd raised on an earlier call: one place that produces templated creative for several social platforms at once.
- **Status** — ⚠️ Partially implemented
- **Where** — [src/app/marketing/MarketingClient.tsx](src/app/marketing/MarketingClient.tsx), [src/lib/marketing/gemini.ts](src/lib/marketing/gemini.ts), [supabase/migrations/0006_content_drafts.sql](supabase/migrations/0006_content_drafts.sql)
- **How** — the Content Studio is the recognisable shape of that platform: one project + one tone + one language in, and per-format output out across `post`, `reel_short`, `whatsapp`, `meta_ad` and `google_ad`. Each generated draft carries its own `target_platforms` array — the reel fallback targets `instagram_reels` / `facebook_reels` / `youtube_shorts`, the WhatsApp format targets `whatsapp_status` / `whatsapp_broadcast`, the Google format targets `google_search_ads` — so the multi-platform routing intent is already modelled in the data.
- **Gap** — it is a *drafting* platform, not a *publishing* platform (requirement 5), it is single-tenant (requirement 22), and it produces copy plus a visual prompt rather than finished creative (requirement 4). Those three gaps are what separate what exists from what he described.

---

## 24. Daily automated conversion of uploaded images into a YouTube Reel, an Instagram Reel and a WhatsApp Status

- **What he asked for** — upload the images once, and every day the system turns them into a Reel for YouTube, a Reel for Instagram and a WhatsApp Status, and posts them.
- **Status** — ❌ Not built
- **Where** — [PHASE-2-VOICE-AND-SOCIAL-AUTOMATION.md](PHASE-2-VOICE-AND-SOCIAL-AUTOMATION.md) §2.2 and §2.3, [supabase/migrations/0004_content_permissions.sql](supabase/migrations/0004_content_permissions.sql)
- **How** — the pieces that exist are the four channel toggles (`instagram`, `youtube`, `whatsapp_status`, `whatsapp`), the four-scene reel *script* generator, and the images registered as assets in `0008`. That is the input tray and the storyboard — not the pipeline.
- **Gap** — three separate blockers, and it is worth being precise that they are separate. (a) **Video generation**: turning still images into a Reel — motion, transitions, pacing, captions, possibly voiceover — is a different technical problem from generating a static image, and Canva does not solve it. It needs its own video-assembly API or AI video vendor, undecided. (b) **Publishing**: Instagram and WhatsApp Status need a verified Meta Business account with a linked Instagram Business account; YouTube Shorts needs a channel plus a Google Cloud OAuth app on the YouTube Data API. **Both require platform review that takes days and can take longer if Meta or Google come back asking for more** — no amount of build speed compresses that. (c) **The daily scheduler** doesn't exist either; the only cron-shaped route in the repo is the follow-up dispatcher, and nothing is calling that yet.

---

## 25. Kriska Security / criska.in — OUT OF SCOPE

- **What he asked for** — mentioned briefly near the end of the call, in passing.
- **Status** — 🚫 Explicitly out of scope
- **Where** — [BRD.md](BRD.md) §6, [PHASE-2-VOICE-AND-SOCIAL-AUTOMATION.md](PHASE-2-VOICE-AND-SOCIAL-AUTOMATION.md) §4
- **How** — recorded as excluded in both documents so it doesn't quietly leak into this engagement's scope, timeline or budget.
- **Gap** — it is a separate, unrelated engagement and needs its own scoping and its own tracking. Nothing in this repo touches it, and nothing should.

---

# Requirements found in the call that weren't on the original list

## 26. "Outside my own working hours" — 24/7 coverage

- **What he asked for** — part of his stated motivation for the whole system: inquiries shouldn't wait for him to be at his desk ([BRD.md](BRD.md) §2).
- **Status** — ✅ Implemented (WhatsApp), ❌ (voice)
- **Where** — [src/app/api/whatsapp/route.ts](src/app/api/whatsapp/route.ts), [src/lib/conversation.ts](src/lib/conversation.ts)
- **How** — the webhook is stateless and always-on; the agent answers whenever a message arrives. `handleInbound()` returns `skipped` rather than throwing for the three cases where silence is correct — a redelivered webhook (deduped by the unique index on `wa_message_id`), an opted-out customer, and a conversation a human has taken over (`ai_paused`).
- **Gap** — the after-hours *calls* half of this is requirement 6.

---

## 27. Never invent a fact — the anti-hallucination requirement

- **What he asked for** — implicit in "answers from approved data", but load-bearing enough to trace separately: in real estate, an invented price or approval status is a legal problem, not a quality problem.
- **Status** — ✅ Implemented
- **Where** — [src/lib/agent/prompt.ts](src/lib/agent/prompt.ts), [src/lib/agent/kb.ts](src/lib/agent/kb.ts), [src/lib/agent/execute.ts](src/lib/agent/execute.ts), [supabase/migrations/0001_schema.sql](supabase/migrations/0001_schema.sql)
- **How** — five independent layers. (1) The prompt's single overriding rule: never state a property fact not read from the knowledge base or a tool result *in this conversation* — not prices, availability, unit numbers, discounts, approvals, completion dates, legal status, returns, financing terms, taxes or distances. (2) NULL is meaningful, rendered as an explicit "NOT RECORDED — sales team must confirm" rather than omitted. (3) `check_availability` returns `live_inventory_connected: false` when no units are loaded, with an instruction not to state a count or imply live stock. (4) Every "I'll have someone check" must be written to `villa_questions` via `log_unanswered_question`, so the promise becomes a real follow-up. (5) Every tool call — input, output, ok/error, duration — is written to `villa_tool_calls`, and a failed send returns `ok: false` with instructions not to claim success.
- **Gap** — none. This is the strongest part of the build. Two adversarial openers are pre-loaded on the simulator page for exactly this — "What's the final price?" and "What guaranteed returns will I get?" — and the agent should decline both.

## 28. Opt-out / do-not-contact

- **What he asked for** — not raised explicitly on the call, but non-negotiable for anything that messages Indian consumers on WhatsApp at scale.
- **Status** — ✅ Implemented
- **Where** — [src/lib/agent/execute.ts](src/lib/agent/execute.ts) (`optOut`), [src/lib/conversation.ts](src/lib/conversation.ts), [src/app/api/cron/follow-ups/route.ts](src/app/api/cron/follow-ups/route.ts)
- **How** — the `opt_out` tool fires on stop/unsubscribe/remove-me *in any language*, sets `opted_out`, `opted_out_at`, `consent_status` and closes the conversation. `handleInbound()` then records future inbound messages but sends nothing back. The follow-up dispatcher independently cancels any queued follow-up for an opted-out lead and logs why.
- **Gap** — none.

---

# Summary table

| # | Requirement | Status |
| --- | --- | --- |
| 1 | BRD document before development | ✅ Implemented |
| 2 | Social integration / publishing at "optimal cost" | ⚠️ Partial — WhatsApp only |
| 3 | System reads uploaded documents and understands the product | ⚠️ Partial — done once by hand, no pipeline |
| 4 | Auto-create templates, WhatsApp ads, Instagram Reels | ⚠️ Partial — copy + script, no rendered creative |
| 5 | Publish to social platforms | ❌ Not built |
| 6 | Inbound calls redirected to an AI agent | ❌ Not built — needs telephony vendor |
| 7 | AI answers from approved uploaded data | ✅ Implemented (WhatsApp text) |
| 8 | AI generates answers, not canned Q&A | ✅ Implemented |
| 9 | Potential vs. casual, "based on the emotion" | ⚠️ Partial — conversation signals, not emotion |
| 10 | Escalate qualified leads to sales/marketing | ✅ Implemented |
| 11 | Store casual inquiries as future prospects | ✅ Implemented |
| 12 | Reconnect after 15 days / a month or two | 🔨 Scaffolded — no cron, no approved template |
| 13 | AI sends pictures and layout on request | ✅ Implemented |
| 14 | AI picks *which* asset intelligently | ⚠️ Partial — code ready, assets not tagged |
| 15 | Admin panel: shareable vs. sensitive | ⚠️ Partial — **toggle is not enforced on the agent path** |
| 16 | Platform on/off + credentials panel | 🔨 Scaffolded — policy only, no credential wiring |
| 17 | Own database for potential + future inquiries | ✅ Implemented |
| 18 | Check back whether a routed lead converted | ⚠️ Partial — insights nudge, no auto check-back |
| 19 | Update the database when a lead converts | ✅ Implemented |
| 20 | Track revenue generated | ✅ Implemented — ad spend entered manually |
| 21 | Live by the weekend | ⚠️ Partial — WhatsApp yes, voice/publishing no |
| 22 | Multi-tenant product | ❌ Not built — deliberate future phase |
| 23 | Multi-social template platform | ⚠️ Partial — drafts yes, publish no |
| 24 | Daily images → YouTube + Instagram Reels + Status | ❌ Not built |
| 25 | Kriska Security / criska.in | 🚫 Out of scope |
| 26 | 24/7 coverage outside working hours | ✅ Implemented (WhatsApp) |
| 27 | Never invent a fact | ✅ Implemented |
| 28 | Opt-out / do-not-contact | ✅ Implemented |

## Bottom line

**Demoable this weekend, with no account he doesn't already have:** the WhatsApp agent end to end — it answers from the four real brochures, refuses to invent a price, sends the actual brochure and layout PDFs, scores and qualifies the buyer, and WhatsApps a 30-second briefing to the sales team when someone is serious. Behind it, the console: leads, the seven-stage pipeline board, conversations, tasks and follow-ups, bookings with revenue attribution back to source and campaign, campaign CPL/ROAS, the objection and knowledge-gap intelligence, the automations engine, and the admin panel. The simulator runs the identical agent path in a browser, so all of that can be shown before the Meta app is even configured. Two things to fix before showing him: **the admin "Block sharing" toggle doesn't actually stop the agent sending the asset** (one missing `.eq()` on the agent's asset query — this is the requirement he was most emphatic about, so it should not be demoed as working until it is), and there is **no password on the console**, which needs at minimum a gate before anything is deployed anywhere public.

**Needs his accounts or a vendor decision first, and no amount of build speed changes that:** voice call handling is blocked on four decisions from him (vendor, phone number, per-minute budget ceiling, forward-vs-replace) and cannot be simulated convincingly. Instagram and YouTube publishing are blocked on Meta Business verification and a Google Cloud OAuth app — **that review clock is the long pole and should start now, this week, regardless of what else we build**, because it is measured in days-to-weeks and is entirely outside our control. Video generation from stills is a third, separate vendor choice that hasn't been made. And the 15-day reconnect — the piece he'd probably most expect to "just work" — is one cron entry and one Meta-approved message template away from being live; both are small, but neither is done, so today it queues rather than sends.
