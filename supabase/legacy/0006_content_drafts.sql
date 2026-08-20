-- =============================================================================
-- AI-generated marketing content drafts.
--
-- Ported the generation logic from a separate demo repo (villa-ai-system) —
-- its Gemini prompt/schema were solid and worth reusing. Its "publish"
-- endpoint was fake (hardcoded URLs, made-up reach numbers) and is
-- deliberately NOT ported: nothing here claims content was actually posted
-- anywhere. A draft is marked 'ready' by a human; actually publishing it to
-- a channel is still a manual step until real platform credentials exist
-- (see villa_channel_settings from 0004, and PHASE-2-VOICE-AND-SOCIAL-AUTOMATION.md).
-- =============================================================================

do $$ begin
  create type villa_content_format as enum ('post', 'reel_short', 'whatsapp', 'meta_ad', 'google_ad');
exception when duplicate_object then null; end $$;

do $$ begin
  create type villa_content_tone as enum (
    'ultra_luxury', 'urgency_scarcity', 'investor_roi', 'nri_special', 'architectural_spotlight'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type villa_content_status as enum ('draft', 'ready', 'archived');
exception when duplicate_object then null; end $$;

create table if not exists villa_content_drafts (
  id                    uuid primary key default gen_random_uuid(),
  project_id            uuid references villa_projects(id) on delete cascade,
  villa_type_id         uuid references villa_types(id) on delete set null,

  format                villa_content_format not null,
  tone                  villa_content_tone not null default 'ultra_luxury',
  language              text not null default 'en',
  custom_notes          text,

  headline              text not null,
  primary_text          text not null,
  secondary_text        text,
  hashtags              text[] not null default '{}',
  call_to_action        text,
  cta_button_text       text,
  suggested_audio       text,
  video_script          jsonb,
  visual_prompt         text,
  target_audience_advice text,
  target_platforms      text[] not null default '{}',

  -- True when Gemini actually generated this vs. the offline fallback
  -- template (no GEMINI_API_KEY configured, or the call failed).
  generated_by_ai       boolean not null default false,

  status                villa_content_status not null default 'draft',
  created_at            timestamptz not null default now()
);

create index if not exists villa_content_drafts_project_idx
  on villa_content_drafts (project_id, created_at desc);

alter table villa_content_drafts enable row level security;
