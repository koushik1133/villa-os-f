# Business Requirements Document (BRD)
## AI-Powered Content Generation, Multi-Platform Publishing & Lead Engagement System

**Prepared for:** Praneeth (Business Owner / Client)
**Prepared by:** Vivek (Development)
**Date:** 2026-08-18
**Status:** DRAFT — for Praneeth's review and correction before development proceeds

> Praneeth asked for this document specifically so it can be checked and fixed before more is built: *"I want it as a typical standard BRD document... so we can finalize on that BRD, we will go with the application development."* Nothing here should be treated as locked in — please correct anything that's wrong or missing.

---

## 1. Executive Summary

Praneeth wants a system that turns a single uploaded project document into ready-to-publish marketing content, distributes that content automatically across WhatsApp, Instagram, YouTube, and WhatsApp Status on a controlled daily schedule, and uses an AI voice agent to handle inbound calls — qualifying callers as serious or casual and routing the serious ones straight to his sales/marketing team. The system should also track whether routed leads actually convert, so cost and return can be measured, and be built in a way that can eventually be sold to other businesses as a self-serve product.

## 2. Business Context and Goal

In Praneeth's own words and intent: he's trying to stop doing the manual work of creating marketing content and personally handling every inbound inquiry, and wants AI to cover this — including outside his own working hours. Specifically:

- Upload one document, and have the system generate the WhatsApp, Instagram, and other social content automatically from it.
- Publish that content across the channels his customers actually use, on a schedule he controls, without him doing it by hand every day.
- Redirect phone calls to an AI that can actually answer questions (not read a script), and that can tell a seriously interested caller apart from someone just curious — sending the serious ones to his team immediately and holding onto the rest for a later follow-up.
- Keep cost per lead "optimal" — this was said explicitly and should shape technical choices, not be an afterthought.
- Keep control over what information and images ever leave the system: *"this, this, this you can share, this, this, this you cannot share"* — this decision stays with Praneeth (or his designated admin), not with any client-facing agent.
- Eventually turn this into a product other businesses can use on their own — upload their own content, connect their own social accounts.

## 3. Functional Requirements

### a. Document-to-Content Generation
Admin uploads a project document (brochure, spec sheet, description, etc.). The system reads it and generates draft WhatsApp/Instagram/social ad templates and creative, using the text and images contained in that document as the source material.

### b. Multi-Platform Publishing
Using the same source images, the system publishes content across WhatsApp Business/social, Instagram, YouTube Reels/Shorts, and WhatsApp Status. Publishing happens on a recurring daily basis, but what goes out and when is controlled by an admin-set schedule — not fully autonomous, unsupervised posting.

### c. AI Voice Call Handling
Inbound calls are redirected to an AI voice agent. The agent:
- Answers from a set of documents that admin has approved for it to use.
- **Generates** answers rather than reading from a fixed, scripted Q&A list.
- Does **not** repeat the caller's question back before answering — it responds directly.

### d. Lead Qualification and Routing
The AI judges, from the conversation's content and tone, whether the caller/inquirer is a genuine potential customer or a casual inquiry:
- **Hot / potential leads** are escalated immediately to the sales/marketing team.
- **Cold / casual leads** are stored in the system for a future follow-up, roughly 15–30 days out.

### e. Admin Control Panel
A panel giving Praneeth (or his designated admin) granular control over:
- Exactly which data and images can or cannot be shared with clients/customers.
- Which social platform accounts, credentials, and permissions are connected to the system for publishing.

This was one of Praneeth's most explicit requirements — the decision of what's shareable is deliberately kept in admin hands, not automated.

### f. Conversion Tracking and Revenue Attribution
When a lead is routed to sales/marketing, that team manually confirms in the system whether it converted into an actual sale. The system uses this confirmation to attribute revenue back to the leads the system generated, so Vivek (and Praneeth) can see the return being produced.

### g. Multi-Tenant Productization (Long-Term Goal)
Beyond Praneeth's own business, the longer-term goal is to package this as a product other businesses can self-serve: they upload their own content, connect their own social accounts, and run their own version of the same pipeline. This is a future-phase goal, not part of the initial build.

## 4. Non-Functional Requirements

- **Response time / SLA:** Both the voice agent and any chat responses need to feel responsive to a live caller/customer. An exact numeric target (e.g., "answer within X seconds") was not given and needs to be set by Praneeth.
- **Cost sensitivity:** Praneeth was explicit that the system must run at "optimal cost" per lead. Every AI action (content generation, voice generation, lead scoring) carries a real cost — architecture and vendor choices should be made with this in mind from the start, not bolted on later.
- **Data security:** Documents and images uploaded by Praneeth (and later, other tenant businesses) must be stored securely and only exposed in line with what the admin panel explicitly permits.
- **Access control:** Sensitive controls — sharing permissions, connected social account credentials, API keys — are restricted to admin-level access only. The sales/marketing team and any client-facing surface should not have access to these controls.

## 5. Assumptions

The transcript left some things ambiguous. Vivek has filled these gaps with a reasonable working assumption so work can start — **Praneeth should correct anything below that's wrong.**

- **ASSUMPTION:** "Tone-based" or "emotion-based" qualification means the AI infers interest level from language and conversational cues (specificity of questions, urgency, follow-up behavior) — not literal voice-emotion/audio sentiment analysis. If real voice-emotion detection is actually required, that is a materially different and more expensive technical build, and needs to be called out explicitly.
- **ASSUMPTION:** The line between "potential" and "casual" inquiry is judged by intent signals in the conversation (e.g., asking about price, availability, or next steps vs. generic questions). The exact criteria/threshold for this classification is not defined in the transcript and should be refined with input from Praneeth's sales team.
- **ASSUMPTION:** Cold-lead follow-up is scheduled 15–30 days after first contact. The exact number of days, and whether there are multiple follow-up attempts after that, is not confirmed.
- **ASSUMPTION:** WhatsApp Business/social and WhatsApp Status are must-have for launch, since Praneeth already has WhatsApp infrastructure. Instagram and YouTube are desired but gated by external API/account access (see Phasing) — which of these are truly must-have vs. nice-to-have at launch needs Praneeth's confirmation.
- **ASSUMPTION:** "Admin" refers to Praneeth (and possibly one delegate). The sales/marketing team has a narrower role — receiving hot leads and confirming conversions — without access to sharing controls or platform credentials.
- **ASSUMPTION:** The AI voice agent will run on a third-party telephony/voice AI vendor (for call redirection, speech-to-text, text-to-speech) rather than being built from scratch. This requires a vendor account and credentials that Praneeth must choose and provision — it is not something that can be simulated convincingly without them.
- **ASSUMPTION:** "Admin-approved documents" for the voice agent are the same or similar source documents used for content generation, reviewed by Praneeth before the AI is allowed to answer calls from them.
- **ASSUMPTION:** Conversion confirmation by the marketing/sales team is a manual step (not an automated CRM/payment integration) for the initial build.

## 6. Out of Scope

The brief mention near the end of the call about "Kriska Security" / criska.in team-page work is a **separate, unrelated engagement**. It is explicitly **excluded** from this BRD and should be scoped and tracked on its own.

## 7. Phasing Recommendation

Given Praneeth's stated urgency (wanting progress this weekend), the work splits into two honest categories:

**Can realistically be built this weekend — no external accounts needed beyond what's already available:**
- Document upload and AI content generation (drafts of WhatsApp/social copy and creative from an uploaded document).
- Admin control panel for marking which data/images are shareable vs. restricted.
- Publishing schedule logic — the admin-controlled scheduling and content-management layer itself.
- Lead qualification logic and internal routing (hot-lead escalation, cold-lead storage), tested on whichever channel is already available (e.g., WhatsApp).
- A basic data model for the sales team to mark leads as converted, for revenue tracking.

**Cannot be built blind — requires Praneeth's accounts, credentials, or vendor decisions first:**
- **AI voice call handling** — needs a telephony/voice AI vendor for call redirection, speech-to-text, and text-to-speech, plus a phone number. This cannot be faked or simulated; Praneeth needs to pick a provider and provision access before this can be built.
- **Instagram publishing** — needs a connected Instagram Business/Creator account with API access through Meta, and possibly Meta's app review before publishing is allowed.
- **YouTube Reels/Shorts publishing** — needs a YouTube/Google account with API access (YouTube Data API) and channel authorization.
- **Ad account credentials** — if the generated creative is meant to run as paid ads (not just organic posts), this needs ad account access (e.g., Meta Ads Manager) and billing set up.

These four will not be silently mocked or worked around — they genuinely need real accounts and credentials from Praneeth before they can be built and tested properly. Everything else above can proceed in parallel this weekend.

## 8. Open Questions for Praneeth (Answer Before Sign-Off)

1. Which channels are must-have at launch versus nice-to-have later — WhatsApp only first, or WhatsApp + Instagram + YouTube + Status all at once?
2. What's the actual budget ceiling per lead ("optimal cost")? Is there a number in mind, or should Vivek propose one based on typical usage costs?
3. What does "tone/emotion-based" qualification mean in practice — conversation/text cues only, or real voice-emotion analysis on calls?
4. Is there an existing CRM (Zoho, HubSpot, Salesforce, etc.) leads should flow into, or should this system be the system of record on its own?
5. Who provisions the voice AI/telephony vendor, and is there a preferred one — or should Vivek recommend one with expected setup cost and timeline?
6. Who currently has admin access to Instagram, YouTube, and any ad accounts, and can that API-level access be granted this week?
7. What's the exact cold-lead follow-up cadence, and how many follow-up attempts happen before a lead is considered dead?
8. Who exactly counts as "admin" with sharing/credential control, and who specifically is on the sales/marketing team receiving hot leads?
9. What counts as a "conversion" for revenue attribution — signed contract, payment received, deposit, something else — and who marks it in the system?
10. Is the multi-tenant/productization goal a near-term priority to design around now, or a longer-term ambition, so the first build isn't over-engineered for it?

---

*This document reflects Vivek's understanding of what was discussed. Praneeth should review each section, correct anything mis-stated or wrongly assumed, and confirm sign-off before further development proceeds.*
