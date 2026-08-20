# Phase 2 Scoping: AI Voice Call Handling & Multi-Platform Publishing

**Prepared for:** Praneeth
**Prepared by:** Vivek (Development)
**Date:** 2026-08-18
**Status:** Scoping only — nothing in this document has been built. It exists so Praneeth can make the account/vendor/budget decisions these two pieces depend on, before any code is written for them.

> These are the two hardest pieces of the original ask, and the two that genuinely cannot be built blind. Everything else discussed in the same call — the WhatsApp text agent's knowledge base, lead qualification and routing, the admin control panel, conversion tracking, the leads kanban — was built or extended this session and is covered separately. This document only covers what's still blocked, and exactly what unblocks it.

---

## 1. AI Voice Call Handling

**The ask:** inbound calls get redirected to an AI agent that reads admin-approved documents and generates answers on the fly (not scripted playback), listens to how the caller talks — content and tone — to judge serious buyer vs. casual inquiry, and hands hot leads to a live person on the sales team mid-call or immediately after.

### 1.1 What this needs, technically

A phone call is not a single system — it's five layers that all have to work together in near-real time:

1. **A telephony number capable of call forwarding/redirection.** Something has to answer the call and connect it into whatever handles the AI logic. This can be a new number, or Praneeth's existing landline forwarded to a new number (see decisions below).
2. **Speech-to-text (STT).** Converts the caller's live audio into text the AI can reason over. Needs to be fast — every second of lag is felt by the caller as dead air.
3. **The AI reasoning layer.** This is the part that reads the approved documents and generates an actual answer, plus judges the caller's intent from what they're saying and how they're saying it. This can reuse the Claude-based agent architecture already built for WhatsApp in `src/lib/agent/` — same model, same idea of a grounded knowledge base and lead scoring (see `src/lib/agent/kb.ts`, `src/lib/agent/scoring.ts`, `src/lib/agent/run.ts`) — adapted for voice-turn latency and a spoken-language system prompt instead of a chat one.
4. **Text-to-speech (TTS).** Converts the AI's generated answer back into audio the caller hears. Voice quality and latency both matter here — a slow or robotic-sounding voice undermines the "actually answers, not a script" goal Praneeth described.
5. **A live call transfer/routing mechanism.** When the AI scores the caller as hot, the system needs to actually connect that live call to a human on the sales team — not just log it and hang up. This is a distinct capability from the first four; not every stack makes it easy.

All five layers have to run within the latency budget of a live phone conversation — this is a materially harder real-time problem than the WhatsApp agent, where a few extra seconds of reply time is invisible to the customer.

### 1.2 Vendor options — honest tradeoff, not a recommendation

| Option | What it is | Tradeoff |
|---|---|---|
| **(a) All-in-one conversational voice AI platform** (e.g. Vapi, Bland AI, Retell AI) | A single product that bundles telephony + STT + AI reasoning + TTS + call transfer, configured rather than integrated. You typically bring your own LLM (can point it at Claude) and get a number, a dashboard, and transfer rules out of the box. | Fastest to stand up — days, not weeks. Less custom control over exact latency, voice choice, and how deeply the lead-scoring logic mirrors the WhatsApp agent's. Ongoing per-minute pricing is set by the platform, and you're dependent on their reliability and roadmap. |
| **(b) Build-it-yourself stack** — Twilio Voice (telephony) + a separate STT provider (e.g. Deepgram) + the existing Claude agent (reasoning) + a TTS provider (e.g. ElevenLabs) | Each layer is a separate vendor, wired together by code Vivek writes and maintains. | Full control over latency tuning, voice, and reusing/extending the actual scoring logic already in `src/lib/agent/scoring.ts`. Materially more integration work up front, and more moving pieces that can each independently break or drift out of sync — this is real ongoing maintenance surface, not a one-time build. |

**This is Praneeth's call, not a default we're picking.** Option (a) gets something live fastest, at the cost of less control and a platform dependency. Option (b) gives more control and reuses more of what's already built, at the cost of more build time and more things to keep reliable. The right answer depends entirely on Praneeth's budget and how fast he actually needs this live versus how much he cares about it being tightly integrated with the existing lead system.

### 1.3 What's needed before a single line of this gets built

None of this can be simulated or half-built without real answers to:

1. **Which vendor** — option (a) platform choice, or option (b) provider-by-provider choice (Twilio + Deepgram + ElevenLabs, or equivalents). This decision alone determines the entire build shape.
2. **A phone number** — provisioned through whichever vendor is chosen, or ported/configured to work with it.
3. **Budget per minute** — every one of these vendors bills per minute of call time (some layer multiple per-minute costs on top of each other in option b). Praneeth was explicit on the call about wanting "optimal cost" per lead — this needs an actual ceiling number, not an open-ended commitment, before vendor selection.
4. **Forward vs. replace** — does Praneeth's existing landline stay the number customers call, with calls forwarded to the new AI number behind the scenes? Or does the new number become the primary published number, replacing the current one? This changes what gets configured where, and needs to be decided up front.

---

## 2. Document-to-Content and Multi-Platform Publishing

**The ask:** upload one project document (with images) → the system reads it and generates WhatsApp ad templates, Instagram Reels, YouTube Shorts/Reels, and WhatsApp Status images from the same source images, daily — then publishes automatically, but only to platforms an admin has explicitly enabled and credentialed. The admin on/off toggle for this exists already, built in this same round of work, at `src/app/admin/page.tsx`.

### 2.1 Static image/template generation — Canva

A Canva MCP integration is already available in this environment — it can generate designs from templates or a brief, no new vendor account required. This is a strong fit for the static-image side of the ask: ad creative for WhatsApp/Instagram, and WhatsApp Status images. Worth trying first for exactly that reason — it's the one piece of this whole section that doesn't need a new account or a waiting period. It does not, however, solve video.

### 2.2 Video (Reels/Shorts) generation — separate capability

Turning static source images into a Reel or a Short (motion, transitions, pacing, possibly voiceover/captions) is a different technical problem than generating a static image, and Canva alone does not solve it. This needs either a video-assembly tool/API (stitching the same source images into a templated video sequence) or an AI video generation vendor. This is a separate build decision from the Canva work in 2.1, and needs its own vendor/tool choice before it can be built.

### 2.3 Actual publishing — what's required per platform

Generating the creative and publishing it are two different problems. Publishing requires real, verified developer access to each platform:

- **Instagram + WhatsApp Status:** a verified Meta Business account with an Instagram Business account linked, accessed through the Graph API.
- **YouTube Shorts:** a YouTube channel plus a Google Cloud OAuth app, accessed through the YouTube Data API.

**Both of these require app review/verification from Meta and Google respectively — and that is not instant.** Given Praneeth wants progress by the weekend, this needs to be flagged plainly: platform verification alone can take days, sometimes longer if Meta or Google come back with additional review requirements. Even if the generation side (Canva, video tooling) is fully working, publishing to Instagram or YouTube cannot go live until that verification clears, no matter how fast the rest of the build moves.

### 2.4 What to hand back before any of this ships

1. **Which platforms are must-have for this weekend vs. can wait.** WhatsApp (already has infrastructure) is realistic for this weekend. Instagram and YouTube publishing are gated by verification timelines outside our control — Praneeth needs to decide whether the weekend target means "WhatsApp live, others following as verification clears" or whether the whole set needs to wait.
2. **Meta Business verification status** — is there already a verified Meta Business account, or does that process need to start now (in which case the clock on it should start immediately, since it's the long pole).
3. **Whether Instagram and YouTube accounts already exist**, or need to be created from scratch — this changes both the timeline and who needs to do the creating (an existing personal Instagram account is not the same as a Business account with API access).

---

## 3. What doesn't need any of this

Everything else from the call — document ingestion for the WhatsApp text agent's knowledge base, lead qualification and routing, the admin control panel for sharing permissions, conversion tracking, and the leads kanban — was built or extended in this same session and does not depend on any new vendor account. Those are the pieces that can realistically be ready this weekend. The two pieces in this document are the ones that genuinely can't move further until Praneeth makes the decisions above.

## 4. Out of scope

The "Kriska Security" / criska.in mention near the end of the call transcript is a separate, unrelated project and is out of scope here.
