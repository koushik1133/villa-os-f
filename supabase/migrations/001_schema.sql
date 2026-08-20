-- =============================================================================
-- VillaOS — complete schema. Self-contained and safely re-runnable.
--
-- This replaces the ten incremental migrations that came before it (archived
-- under supabase/legacy/). Because the database is being reset, there is no
-- value in replaying that history — this is the same end state, readable in
-- one pass.
--
-- Apply: Supabase dashboard → SQL Editor → paste → Run. Then run 002_seed.sql.
--
-- !! DESTRUCTIVE !! The teardown below drops every `villa_`-prefixed object
-- and all data in it. Nothing outside that prefix is touched.
--
-- WHY the teardown is part of this file rather than a separate one you run
-- first: the table bodies use `create table if not exists`, which silently
-- no-ops against a surviving older table. The next `create index` or `create
-- view` referencing a column that old table lacks then aborts the whole
-- script — and since the SQL editor runs it in one transaction, everything
-- rolls back and you are left exactly where you started, with a confusing
-- "column does not exist" error pointing at a line that is not the problem.
-- Dropping first makes that state unreachable.
--
-- Convention: every table is prefixed `villa_` so this drops into a shared
-- Supabase project without colliding. Every table holding customer data has
-- RLS enabled with NO permissive policy — the app reaches it only through the
-- service_role key server-side, so a leaked anon key reads nothing.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Teardown. Views first (they depend on tables), then tables, then the types
-- and function the tables depend on. `cascade` covers anything missed.
-- -----------------------------------------------------------------------------
drop view if exists
  villa_funnel, villa_daily_leads, villa_revenue_monthly,
  villa_objection_summary, villa_source_summary, villa_team_performance,
  villa_campaign_performance, villa_inventory_summary, villa_sales_velocity
cascade;

drop table if exists
  villa_payments, villa_bookings,
  villa_publish_log, villa_content_drafts,
  villa_automation_runs, villa_automations,
  villa_tool_calls, villa_messages, villa_conversations,
  villa_handoffs, villa_site_visits, villa_follow_ups, villa_tasks,
  villa_objections, villa_questions, villa_activities,
  villa_notifications, villa_ai_insights, villa_touchpoints,
  villa_campaigns, villa_channel_settings, villa_integrations,
  villa_leads, villa_contacts,
  villa_assets, villa_faqs, villa_units, villa_types, villa_projects,
  villa_team_members, villa_tenant
cascade;

drop type if exists
  villa_lead_temperature, villa_pipeline_stage, villa_buyer_purpose,
  villa_timeline, villa_financing, villa_handoff_status, villa_asset_kind,
  villa_message_role, villa_visit_status, villa_unit_status, villa_user_role,
  villa_task_status, villa_task_priority, villa_booking_status,
  villa_payment_status, villa_campaign_status, villa_followup_status,
  villa_severity, villa_content_format, villa_content_tone,
  villa_content_status, villa_comm_channel
cascade;

drop function if exists villa_touch_updated_at() cascade;

create extension if not exists "pgcrypto";

-- -----------------------------------------------------------------------------
-- Enums
-- -----------------------------------------------------------------------------
do $$ begin create type villa_lead_temperature as enum ('hot','warm','cold'); exception when duplicate_object then null; end $$;

do $$ begin create type villa_pipeline_stage as enum (
  'new','contacted','qualifying','qualified','site_visit_scheduled',
  'site_visit_completed','negotiation','token_paid','booked','lost'
); exception when duplicate_object then null; end $$;

do $$ begin create type villa_buyer_purpose as enum (
  'self_use','family','investment','second_home','vacation_home',
  'rental_income','nri_purchase','undecided'
); exception when duplicate_object then null; end $$;

do $$ begin create type villa_timeline as enum (
  'immediate','within_1_month','1_3_months','3_6_months','6_12_months','researching','unknown'
); exception when duplicate_object then null; end $$;

do $$ begin create type villa_financing as enum ('cash','home_loan','combination','undecided'); exception when duplicate_object then null; end $$;
do $$ begin create type villa_handoff_status as enum ('none','requested','notified','accepted','closed'); exception when duplicate_object then null; end $$;

do $$ begin create type villa_asset_kind as enum (
  'brochure','floor_plan','site_plan','master_plan','price_sheet',
  'image','video','virtual_tour','location_map','other'
); exception when duplicate_object then null; end $$;

do $$ begin create type villa_message_role as enum ('customer','agent','human_agent','system'); exception when duplicate_object then null; end $$;
do $$ begin create type villa_visit_status as enum ('requested','scheduled','confirmed','completed','no_show','cancelled'); exception when duplicate_object then null; end $$;
do $$ begin create type villa_unit_status as enum ('available','under_booking','reserved','sold','blocked'); exception when duplicate_object then null; end $$;

do $$ begin create type villa_user_role as enum (
  'super_admin','sales_director','sales_manager','property_consultant',
  'marketing_manager','marketing_agent','viewer'
); exception when duplicate_object then null; end $$;

do $$ begin create type villa_task_status as enum ('pending','in_progress','completed'); exception when duplicate_object then null; end $$;
do $$ begin create type villa_task_priority as enum ('low','medium','high','urgent'); exception when duplicate_object then null; end $$;
do $$ begin create type villa_booking_status as enum ('initiated','agreement_sent','signed','token_paid','registered','cancelled'); exception when duplicate_object then null; end $$;
do $$ begin create type villa_payment_status as enum ('pending','partial','paid','overdue','refunded'); exception when duplicate_object then null; end $$;
do $$ begin create type villa_campaign_status as enum ('active','paused','ended','draft'); exception when duplicate_object then null; end $$;
do $$ begin create type villa_followup_status as enum ('pending','completed','missed','rescheduled'); exception when duplicate_object then null; end $$;
do $$ begin create type villa_severity as enum ('info','warning','critical','success'); exception when duplicate_object then null; end $$;
do $$ begin create type villa_content_format as enum ('post','reel_short','whatsapp','meta_ad','google_ad'); exception when duplicate_object then null; end $$;
do $$ begin create type villa_content_tone as enum ('ultra_luxury','urgency_scarcity','investor_roi','nri_special','architectural_spotlight'); exception when duplicate_object then null; end $$;
do $$ begin create type villa_content_status as enum ('draft','ready','scheduled','published','archived'); exception when duplicate_object then null; end $$;
do $$ begin create type villa_comm_channel as enum ('whatsapp','instagram','facebook','email','sms','web_form','call'); exception when duplicate_object then null; end $$;


-- -----------------------------------------------------------------------------
-- Shared trigger
-- -----------------------------------------------------------------------------
create or replace function villa_touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;


-- =============================================================================
-- ORGANISATION
-- =============================================================================

create table if not exists villa_tenant (
  id              uuid primary key default gen_random_uuid(),
  org_name        text not null default 'Glentree Homes',
  legal_entity    text,
  logo_url        text,
  currency        text not null default 'INR',
  timezone        text not null default 'Asia/Kolkata',
  primary_phone   text,
  primary_email   text,
  address         text,
  website         text,
  -- Single-tenant today. The column exists so multi-tenant is a filter change
  -- rather than a schema rewrite when the product is resold (spec: "deploy
  -- this product to other clients").
  is_active       boolean not null default true,
  updated_at      timestamptz not null default now()
);

create table if not exists villa_team_members (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  email         text unique,
  phone         text,
  role          villa_user_role not null default 'property_consultant',
  department    text not null default 'sales',
  avatar_url    text,
  is_active     boolean not null default true,
  accepts_leads boolean not null default true,
  -- Quota drives the leaderboard; null means "not on a quota".
  quota_inr     bigint,
  languages     text[],
  joined_at     timestamptz not null default now(),
  created_at    timestamptz not null default now()
);


-- =============================================================================
-- KNOWLEDGE BASE  (Projects → Villa types → Units → Assets)
--
-- The ONLY source the AI agent may quote from. A NULL price or NULL bedroom
-- count is meaningful: it means the fact is not approved for the agent to
-- state, so it defers to a human instead of inventing one.
-- =============================================================================

create table if not exists villa_projects (
  id                    uuid primary key default gen_random_uuid(),
  slug                  text unique not null,
  name                  text not null,
  developer             text,
  status                text,
  phase                 text,
  expected_delivery     text,
  launch_date           date,

  address_line          text,
  village               text,
  mandal                text,
  district              text,
  state                 text,
  pincode               text,
  survey_no             text,
  maps_url              text,
  latitude              numeric,
  longitude             numeric,

  hmda_permit_no        text,
  hmda_permit_date      text,
  rera_number           text,
  rera_status           text,

  total_land_acres      numeric,
  total_units           integer,
  configurations        text[],

  starting_price_inr    bigint,
  max_price_inr         bigint,
  price_note            text,
  currency              text not null default 'INR',

  -- Indian villa pricing is a rate per saleable sft, not a sticker price. The
  -- headline number a buyer is quoted is rate × area, then premiums (facing,
  -- corner, park-facing), amenities, corpus, maintenance, legal and GST on top.
  -- Storing the rate and the charge structure lets the agent show the build-up
  -- honestly instead of quoting one number that is never what anyone pays.
  price_per_sft_inr     integer,
  -- { payment_schedule: [{stage, percent}], premium_charges: [{name, amount, unit}],
  --   inclusions: [], exclusions: [], offer: {...} }
  pricing               jsonb not null default '{}'::jsonb,

  cover_image           text,
  gallery               jsonb not null default '[]'::jsonb,
  positioning           text,
  usps                  jsonb not null default '[]'::jsonb,
  amenities             jsonb not null default '{}'::jsonb,
  specifications        jsonb not null default '{}'::jsonb,
  sustainability        jsonb not null default '{}'::jsonb,
  connectivity          jsonb not null default '[]'::jsonb,
  social_infrastructure jsonb not null default '{}'::jsonb,
  financing_partners    text[],

  is_active             boolean not null default true,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create table if not exists villa_types (
  id                uuid primary key default gen_random_uuid(),
  project_id        uuid not null references villa_projects(id) on delete cascade,
  name              text not null,
  plot_area_sqyd    numeric,
  built_up_sft      numeric,
  carpet_area_sft   numeric,
  facing            text,
  bedrooms          integer,
  bathrooms         integer,
  floors            integer,
  has_home_theatre  boolean,
  has_maid_room     boolean,
  private_pool      boolean,
  price_inr         bigint,
  floor_plan_url    text,
  -- Set when a field above is deliberately unknown. Surfaced to the agent so
  -- it says "the sales team will confirm" instead of guessing.
  verification_note text,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  unique (project_id, name)
);

create table if not exists villa_units (
  id            uuid primary key default gen_random_uuid(),
  project_id    uuid not null references villa_projects(id) on delete cascade,
  villa_type_id uuid references villa_types(id) on delete set null,
  unit_number   text not null,
  facing        text,
  plot_area_sqyd numeric,
  -- Corner/premium plots carry area charged beyond the standard plot size.
  chargeable_extra_sqyd numeric,
  saleable_sft  numeric,
  is_corner     boolean not null default false,
  price_inr     bigint,
  status        villa_unit_status not null default 'available',
  updated_at    timestamptz not null default now(),
  unique (project_id, unit_number)
);

create table if not exists villa_assets (
  id              uuid primary key default gen_random_uuid(),
  project_id      uuid references villa_projects(id) on delete cascade,
  villa_type_id   uuid references villa_types(id) on delete set null,
  kind            villa_asset_kind not null,
  title           text not null,
  description     text,
  url             text not null unique,
  mime_type       text,
  -- Section 14 of the agent spec: a render must be labelled as one, never
  -- passed off as a photograph of a built villa.
  is_ai_generated boolean not null default false,
  -- Admin control panel: the AI may only send assets flagged shareable.
  shareable_by_ai boolean not null default true,
  version         integer not null default 1,
  is_current      boolean not null default true,
  created_at      timestamptz not null default now()
);

create table if not exists villa_faqs (
  id         uuid primary key default gen_random_uuid(),
  project_id uuid references villa_projects(id) on delete cascade,
  question   text not null,
  answer     text not null,
  tags       text[],
  created_at timestamptz not null default now()
);


-- =============================================================================
-- CRM
-- =============================================================================

create table if not exists villa_contacts (
  id            uuid primary key default gen_random_uuid(),
  name          text,
  phone         text unique not null,
  email         text,
  contact_type  text not null default 'buyer',
  company       text,
  notes         text,
  first_seen_at timestamptz not null default now(),
  last_seen_at  timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

create table if not exists villa_leads (
  id                    uuid primary key default gen_random_uuid(),
  contact_id            uuid references villa_contacts(id) on delete set null,

  phone                 text unique not null,
  name                  text,
  email                 text,
  country               text,
  city                  text,
  is_nri                boolean not null default false,
  preferred_language    text not null default 'en',

  project_interest      uuid references villa_projects(id) on delete set null,
  villa_type_interest   uuid references villa_types(id) on delete set null,
  bedrooms              integer,
  budget_min_inr        bigint,
  budget_max_inr        bigint,
  buyer_purpose         villa_buyer_purpose,
  purchase_timeline     villa_timeline not null default 'unknown',
  financing_preference  villa_financing,
  preferred_location    text,
  facing_preference     text,
  amenities_of_interest text[],
  requirements_notes    text,

  lead_score            integer not null default 0 check (lead_score between 0 and 100),
  lead_temperature      villa_lead_temperature not null default 'cold',
  pipeline_stage        villa_pipeline_stage not null default 'new',
  -- Derived by the AI from conversation tone. Advisory only — it never
  -- overrides the deterministic lead_score.
  sentiment             text,
  ai_summary            text,

  assigned_to           uuid references villa_team_members(id) on delete set null,

  source                text not null default 'whatsapp',
  campaign              text,
  ad_id                 text,
  creative              text,
  keyword               text,
  landing_page          text,
  utm                   jsonb not null default '{}'::jsonb,
  referrer              text,

  brochure_sent         boolean not null default false,
  floor_plan_sent       boolean not null default false,
  price_sheet_sent      boolean not null default false,
  video_sent            boolean not null default false,

  handoff_status        villa_handoff_status not null default 'none',
  handoff_reason        text,
  handoff_at            timestamptz,
  -- Closes the loop the client asked for: after a lead is routed to sales,
  -- someone records whether it actually converted.
  conversion_confirmed  boolean,
  conversion_checked_at timestamptz,
  conversion_notes      text,

  consent_status        text not null default 'implied',
  opted_out             boolean not null default false,
  opted_out_at          timestamptz,
  ai_paused             boolean not null default false,

  -- Casual enquiries parked for a later nudge (15 days / 1-2 months).
  is_future_prospect    boolean not null default false,
  reconnect_at          timestamptz,

  notes                 text,
  first_contact_at      timestamptz not null default now(),
  last_contact_at       timestamptz not null default now(),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create index if not exists villa_leads_temp_idx     on villa_leads (lead_temperature, lead_score desc);
create index if not exists villa_leads_last_idx     on villa_leads (last_contact_at desc);
create index if not exists villa_leads_src_idx      on villa_leads (source, campaign);
create index if not exists villa_leads_stage_idx    on villa_leads (pipeline_stage);
create index if not exists villa_leads_assigned_idx on villa_leads (assigned_to);
create index if not exists villa_leads_created_idx  on villa_leads (created_at desc);
create index if not exists villa_leads_reconnect_idx on villa_leads (is_future_prospect, reconnect_at)
  where is_future_prospect = true;

create table if not exists villa_conversations (
  id              uuid primary key default gen_random_uuid(),
  lead_id         uuid not null references villa_leads(id) on delete cascade,
  channel         villa_comm_channel not null default 'whatsapp',
  status          text not null default 'open',
  started_at      timestamptz not null default now(),
  last_message_at timestamptz not null default now(),
  message_count   integer not null default 0,
  summary         text
);
create index if not exists villa_conv_lead_idx on villa_conversations (lead_id, last_message_at desc);

create table if not exists villa_messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references villa_conversations(id) on delete cascade,
  lead_id         uuid not null references villa_leads(id) on delete cascade,
  role            villa_message_role not null,
  channel         villa_comm_channel not null default 'whatsapp',
  body            text,
  media_url       text,
  media_kind      villa_asset_kind,
  -- Meta's id, so a redelivered webhook is ignored rather than answered twice.
  wa_message_id   text unique,
  created_at      timestamptz not null default now()
);
create index if not exists villa_msg_conv_idx on villa_messages (conversation_id, created_at);
create index if not exists villa_msg_lead_idx on villa_messages (lead_id, created_at desc);

create table if not exists villa_tool_calls (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid references villa_conversations(id) on delete cascade,
  lead_id         uuid references villa_leads(id) on delete cascade,
  tool_name       text not null,
  input           jsonb,
  output          jsonb,
  ok              boolean not null default true,
  error           text,
  duration_ms     integer,
  created_at      timestamptz not null default now()
);

create table if not exists villa_site_visits (
  id                   uuid primary key default gen_random_uuid(),
  lead_id              uuid not null references villa_leads(id) on delete cascade,
  project_id           uuid references villa_projects(id) on delete set null,
  assigned_to          uuid references villa_team_members(id) on delete set null,
  scheduled_at         timestamptz,
  preferred_date       date,
  preferred_time       text,
  completed_at         timestamptz,
  visitor_count        integer,
  visit_type           text not null default 'site',
  status               villa_visit_status not null default 'requested',
  transport_arranged   boolean not null default false,
  outcome              text,
  feedback             text,
  special_requirements text,
  notes                text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
create index if not exists villa_visits_sched_idx on villa_site_visits (scheduled_at desc);

create table if not exists villa_handoffs (
  id              uuid primary key default gen_random_uuid(),
  lead_id         uuid not null references villa_leads(id) on delete cascade,
  conversation_id uuid references villa_conversations(id) on delete set null,
  assigned_to     uuid references villa_team_members(id) on delete set null,
  reason          text not null,
  payload         text not null,
  notified        boolean not null default false,
  notified_at     timestamptz,
  created_at      timestamptz not null default now()
);

create table if not exists villa_tasks (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  description  text,
  lead_id      uuid references villa_leads(id) on delete cascade,
  assigned_to  uuid references villa_team_members(id) on delete set null,
  status       villa_task_status not null default 'pending',
  priority     villa_task_priority not null default 'medium',
  task_type    text not null default 'follow_up',
  due_at       timestamptz,
  completed_at timestamptz,
  created_at   timestamptz not null default now()
);
create index if not exists villa_tasks_due_idx on villa_tasks (status, due_at);

create table if not exists villa_follow_ups (
  id            uuid primary key default gen_random_uuid(),
  lead_id       uuid not null references villa_leads(id) on delete cascade,
  assigned_to   uuid references villa_team_members(id) on delete set null,
  scheduled_at  timestamptz not null,
  completed_at  timestamptz,
  status        villa_followup_status not null default 'pending',
  channel       villa_comm_channel not null default 'whatsapp',
  message       text,
  -- Outside WhatsApp's 24h window only an approved template may be sent, so
  -- free text and template name are stored separately.
  template_name text,
  notes         text,
  ai_generated  boolean not null default false,
  dispatched_at timestamptz,
  created_at    timestamptz not null default now()
);
create index if not exists villa_followups_due_idx on villa_follow_ups (status, scheduled_at);


-- =============================================================================
-- SALES & REVENUE
-- =============================================================================

create table if not exists villa_bookings (
  id                uuid primary key default gen_random_uuid(),
  booking_number    text unique not null,
  lead_id           uuid references villa_leads(id) on delete set null,
  contact_id        uuid references villa_contacts(id) on delete set null,
  project_id        uuid references villa_projects(id) on delete set null,
  villa_type_id     uuid references villa_types(id) on delete set null,
  unit_id           uuid references villa_units(id) on delete set null,

  customer_name     text not null,
  customer_phone    text not null,
  customer_email    text,
  kyc_complete      boolean not null default false,

  value_inr         bigint not null default 0,
  token_amount_inr  bigint not null default 0,
  amount_paid_inr   bigint not null default 0,
  booking_date      date not null default current_date,
  agreement_date    date,
  registration_date date,

  status            villa_booking_status not null default 'initiated',
  payment_status    villa_payment_status not null default 'pending',
  assigned_to       uuid references villa_team_members(id) on delete set null,

  -- Copied off the lead at booking time so revenue attribution survives a
  -- later edit to the lead row.
  source            text,
  campaign          text,

  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index if not exists villa_bookings_date_idx on villa_bookings (booking_date desc);

create table if not exists villa_payments (
  id         uuid primary key default gen_random_uuid(),
  booking_id uuid not null references villa_bookings(id) on delete cascade,
  milestone  text not null,
  amount_inr bigint not null,
  due_date   date,
  paid_date  date,
  status     villa_payment_status not null default 'pending',
  created_at timestamptz not null default now()
);
create index if not exists villa_payments_booking_idx on villa_payments (booking_id);


-- =============================================================================
-- MARKETING
-- =============================================================================

create table if not exists villa_campaigns (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  platform    text not null,
  status      villa_campaign_status not null default 'draft',
  project_id  uuid references villa_projects(id) on delete set null,
  external_id text,
  start_date  date,
  end_date    date,
  budget_inr  bigint not null default 0,
  spent_inr   bigint not null default 0,
  impressions bigint not null default 0,
  clicks      bigint not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (platform, name)
);

create table if not exists villa_content_drafts (
  id                     uuid primary key default gen_random_uuid(),
  project_id             uuid references villa_projects(id) on delete cascade,
  villa_type_id          uuid references villa_types(id) on delete set null,
  format                 villa_content_format not null,
  tone                   villa_content_tone not null default 'ultra_luxury',
  language               text not null default 'en',
  custom_notes           text,

  headline               text not null,
  primary_text           text not null,
  secondary_text         text,
  hashtags               text[] not null default '{}',
  call_to_action         text,
  cta_button_text        text,
  suggested_audio        text,
  video_script           jsonb,
  visual_prompt          text,
  target_audience_advice text,
  target_platforms       text[] not null default '{}',

  -- False when the offline template produced this (no Gemini key, or the call
  -- failed) — surfaced in the UI so nobody mistakes it for AI output.
  generated_by_ai        boolean not null default false,
  status                 villa_content_status not null default 'draft',
  scheduled_for          timestamptz,
  created_at             timestamptz not null default now()
);
create index if not exists villa_drafts_project_idx on villa_content_drafts (project_id, created_at desc);

-- Publish attempts. A row here is a RECORD OF INTENT, not proof of a post:
-- `status` stays 'pending_manual' until a real platform integration exists.
create table if not exists villa_publish_log (
  id           uuid primary key default gen_random_uuid(),
  draft_id     uuid references villa_content_drafts(id) on delete cascade,
  channel      text not null,
  status       text not null default 'pending_manual',
  external_url text,
  error        text,
  published_at timestamptz,
  created_at   timestamptz not null default now()
);

create table if not exists villa_channel_settings (
  id                uuid primary key default gen_random_uuid(),
  channel           text unique not null,
  label             text not null,
  enabled           boolean not null default false,
  credential_status text not null default 'not_connected',
  notes             text,
  updated_at        timestamptz not null default now()
);

create table if not exists villa_integrations (
  id            uuid primary key default gen_random_uuid(),
  provider      text unique not null,
  label         text not null,
  category      text not null,
  is_connected  boolean not null default false,
  status        text not null default 'disconnected',
  last_sync_at  timestamptz,
  error_message text,
  updated_at    timestamptz not null default now()
);

create table if not exists villa_touchpoints (
  id          uuid primary key default gen_random_uuid(),
  lead_id     uuid not null references villa_leads(id) on delete cascade,
  channel     text not null,
  campaign    text,
  detail      text,
  occurred_at timestamptz not null default now()
);
create index if not exists villa_touchpoints_lead_idx on villa_touchpoints (lead_id, occurred_at);


-- =============================================================================
-- AUTOMATION, INTELLIGENCE, AUDIT
-- =============================================================================

create table if not exists villa_automations (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  description      text,
  is_active        boolean not null default false,
  trigger_event    text not null,
  conditions       jsonb not null default '[]'::jsonb,
  actions          jsonb not null default '[]'::jsonb,
  execution_count  integer not null default 0,
  last_executed_at timestamptz,
  created_at       timestamptz not null default now()
);

create table if not exists villa_automation_runs (
  id            uuid primary key default gen_random_uuid(),
  automation_id uuid not null references villa_automations(id) on delete cascade,
  lead_id       uuid references villa_leads(id) on delete set null,
  ok            boolean not null default true,
  detail        text,
  created_at    timestamptz not null default now()
);

create table if not exists villa_activities (
  id            uuid primary key default gen_random_uuid(),
  lead_id       uuid references villa_leads(id) on delete cascade,
  actor         text,
  activity_type text not null,
  description   text not null,
  channel       text,
  metadata      jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now()
);
create index if not exists villa_activities_lead_idx on villa_activities (lead_id, created_at desc);
create index if not exists villa_activities_time_idx on villa_activities (created_at desc);

create table if not exists villa_notifications (
  id          uuid primary key default gen_random_uuid(),
  kind        text not null,
  title       text not null,
  description text,
  severity    villa_severity not null default 'info',
  href        text,
  is_read     boolean not null default false,
  lead_id     uuid references villa_leads(id) on delete cascade,
  created_at  timestamptz not null default now()
);
create index if not exists villa_notif_unread_idx on villa_notifications (is_read, created_at desc);

create table if not exists villa_ai_insights (
  id              uuid primary key default gen_random_uuid(),
  insight_type    text not null default 'recommendation',
  severity        villa_severity not null default 'info',
  title           text not null,
  description     text not null,
  -- The actual numbers the insight was derived from, so any claim it makes
  -- can be checked rather than trusted.
  evidence        jsonb not null default '[]'::jsonb,
  recommendation  text,
  expected_impact text,
  action_label    text,
  action_href     text,
  category        text,
  is_dismissed    boolean not null default false,
  generated_by_ai boolean not null default false,
  created_at      timestamptz not null default now()
);

create table if not exists villa_objections (
  id              uuid primary key default gen_random_uuid(),
  lead_id         uuid references villa_leads(id) on delete set null,
  conversation_id uuid references villa_conversations(id) on delete set null,
  category        text not null,
  verbatim        text,
  created_at      timestamptz not null default now()
);
create index if not exists villa_obj_cat_idx on villa_objections (category, created_at desc);

create table if not exists villa_questions (
  id              uuid primary key default gen_random_uuid(),
  lead_id         uuid references villa_leads(id) on delete set null,
  conversation_id uuid references villa_conversations(id) on delete set null,
  topic           text not null,
  verbatim        text,
  unanswered      boolean not null default false,
  created_at      timestamptz not null default now()
);
create index if not exists villa_q_topic_idx on villa_questions (topic, created_at desc);


-- -----------------------------------------------------------------------------
-- Triggers
-- -----------------------------------------------------------------------------
drop trigger if exists villa_leads_touch on villa_leads;
create trigger villa_leads_touch before update on villa_leads
  for each row execute function villa_touch_updated_at();

drop trigger if exists villa_projects_touch on villa_projects;
create trigger villa_projects_touch before update on villa_projects
  for each row execute function villa_touch_updated_at();

drop trigger if exists villa_bookings_touch on villa_bookings;
create trigger villa_bookings_touch before update on villa_bookings
  for each row execute function villa_touch_updated_at();

drop trigger if exists villa_campaigns_touch on villa_campaigns;
create trigger villa_campaigns_touch before update on villa_campaigns
  for each row execute function villa_touch_updated_at();


-- -----------------------------------------------------------------------------
-- Row Level Security
--
-- Customer data: RLS on, no policy. Only the server-side service_role key can
-- read it, so a leaked anon key returns zero rows.
-- Marketing collateral: public read, write locked.
-- -----------------------------------------------------------------------------
alter table villa_tenant           enable row level security;
alter table villa_team_members     enable row level security;
alter table villa_contacts         enable row level security;
alter table villa_leads            enable row level security;
alter table villa_conversations    enable row level security;
alter table villa_messages         enable row level security;
alter table villa_tool_calls       enable row level security;
alter table villa_site_visits      enable row level security;
alter table villa_handoffs         enable row level security;
alter table villa_tasks            enable row level security;
alter table villa_follow_ups       enable row level security;
alter table villa_bookings         enable row level security;
alter table villa_payments         enable row level security;
alter table villa_campaigns        enable row level security;
alter table villa_content_drafts   enable row level security;
alter table villa_publish_log      enable row level security;
alter table villa_channel_settings enable row level security;
alter table villa_integrations     enable row level security;
alter table villa_touchpoints      enable row level security;
alter table villa_automations      enable row level security;
alter table villa_automation_runs  enable row level security;
alter table villa_activities       enable row level security;
alter table villa_notifications    enable row level security;
alter table villa_ai_insights      enable row level security;
alter table villa_objections       enable row level security;
alter table villa_questions        enable row level security;

alter table villa_projects enable row level security;
alter table villa_types    enable row level security;
alter table villa_units    enable row level security;
alter table villa_assets   enable row level security;
alter table villa_faqs     enable row level security;

do $$ begin
  create policy villa_projects_read on villa_projects for select using (true);
  create policy villa_types_read    on villa_types    for select using (true);
  create policy villa_units_read    on villa_units    for select using (true);
  create policy villa_assets_read   on villa_assets   for select using (true);
  create policy villa_faqs_read     on villa_faqs     for select using (true);
exception when duplicate_object then null; end $$;


-- =============================================================================
-- REPORTING VIEWS
-- =============================================================================

create or replace view villa_funnel as
select
  (select count(*) from villa_conversations)                          as conversations,
  (select count(*) from villa_leads)                                  as leads,
  (select count(*) from villa_leads where lead_score >= 50)           as qualified_leads,
  (select count(*) from villa_leads where lead_temperature = 'hot')   as hot_leads,
  (select count(*) from villa_leads where lead_temperature = 'warm')  as warm_leads,
  (select count(*) from villa_leads where lead_temperature = 'cold')  as cold_leads,
  (select count(*) from villa_site_visits)                            as site_visits_requested,
  (select count(*) from villa_site_visits where status = 'completed') as site_visits_completed,
  (select count(*) from villa_bookings where status <> 'cancelled')   as bookings,
  (select coalesce(sum(value_inr),0) from villa_bookings where status <> 'cancelled') as revenue_inr,
  (select count(*) from villa_handoffs)                               as handoffs;

create or replace view villa_daily_leads as
select
  created_at::date                                 as day,
  count(*)                                         as leads,
  count(*) filter (where lead_score >= 50)         as qualified,
  count(*) filter (where lead_temperature = 'hot') as hot
from villa_leads
group by 1 order by 1 desc;

create or replace view villa_revenue_monthly as
select
  date_trunc('month', booking_date)::date as month,
  count(*)                                as bookings,
  sum(value_inr)                          as booked_value_inr,
  sum(amount_paid_inr)                    as collected_inr
from villa_bookings
where status <> 'cancelled'
group by 1 order by 1 desc;

create or replace view villa_objection_summary as
select category, count(*) as total,
  round(100.0 * count(*) / nullif(sum(count(*)) over (), 0), 1) as pct
from villa_objections group by category order by total desc;

create or replace view villa_source_summary as
select source, campaign,
  count(*)                                         as leads,
  count(*) filter (where lead_temperature = 'hot') as hot,
  count(*) filter (where lead_score >= 50)         as qualified,
  round(avg(lead_score), 1)                        as avg_score
from villa_leads group by source, campaign order by leads desc;

-- Bookings are pre-aggregated in a subquery on purpose: joining them directly
-- alongside leads and site visits fans each booking out across the cartesian
-- product, which count(distinct) hides but sum() cannot undo.
create or replace view villa_team_performance as
select
  t.id, t.name, t.role, t.department, t.quota_inr,
  count(distinct l.id)                                          as assigned_leads,
  count(distinct l.id) filter (where l.lead_temperature = 'hot') as hot_leads,
  count(distinct sv.id)                                         as site_visits,
  coalesce(b.bookings, 0)                                       as bookings,
  coalesce(b.revenue_inr, 0)                                    as revenue_inr,
  case when count(distinct l.id) > 0
       then round(100.0 * coalesce(b.bookings,0) / count(distinct l.id), 1) end as conversion_rate,
  case when t.quota_inr > 0
       then round(100.0 * coalesce(b.revenue_inr,0) / t.quota_inr, 1) end as quota_attainment
from villa_team_members t
left join villa_leads l on l.assigned_to = t.id
left join villa_site_visits sv on sv.lead_id = l.id
left join (
  select assigned_to, count(*) as bookings, sum(value_inr) as revenue_inr
  from villa_bookings where status <> 'cancelled' and assigned_to is not null
  group by assigned_to
) b on b.assigned_to = t.id
group by t.id, t.name, t.role, t.department, t.quota_inr, b.bookings, b.revenue_inr
order by revenue_inr desc;

-- Bookings are pre-aggregated per campaign for the same reason as in
-- villa_team_performance: joining them alongside leads fans each booking out
-- across the lead rows. `sum(distinct value_inr)` was the old defence, and it
-- was wrong — two villas sold at the SAME price are one distinct value, so the
-- second sale silently vanished from revenue and ROAS. Identical prices are
-- the norm here, not the exception: units of one villa type share a list price.
create or replace view villa_campaign_performance as
select
  c.id, c.name, c.platform, c.status, c.budget_inr, c.spent_inr,
  c.impressions, c.clicks,
  case when c.impressions > 0
       then round(100.0 * c.clicks / c.impressions, 2) end        as ctr,
  count(distinct l.id)                                            as leads,
  count(distinct l.id) filter (where l.lead_score >= 50)          as qualified_leads,
  coalesce(b.bookings, 0)                                         as bookings,
  coalesce(b.revenue_inr, 0)                                      as revenue_inr,
  case when count(distinct l.id) > 0
       then round(c.spent_inr::numeric / count(distinct l.id), 0) end as cpl_inr,
  case when c.spent_inr > 0
       then round(coalesce(b.revenue_inr,0)::numeric / c.spent_inr, 2) end as roas
from villa_campaigns c
left join villa_leads l on l.campaign = c.name
left join (
  select l2.campaign, count(*) as bookings, sum(b2.value_inr) as revenue_inr
  from villa_bookings b2
  join villa_leads l2 on l2.id = b2.lead_id
  where b2.status <> 'cancelled' and l2.campaign is not null
  group by l2.campaign
) b on b.campaign = c.name
group by c.id, c.name, c.platform, c.status, c.budget_inr, c.spent_inr,
         c.impressions, c.clicks, b.bookings, b.revenue_inr
order by c.spent_inr desc;

-- Real-time inventory per villa type, for the availability board.
create or replace view villa_inventory_summary as
select
  p.name as project_name,
  vt.name as villa_type,
  vt.id   as villa_type_id,
  count(u.id)                                                as total_units,
  count(u.id) filter (where u.status = 'available')          as available,
  count(u.id) filter (where u.status = 'under_booking')      as under_booking,
  count(u.id) filter (where u.status = 'reserved')           as reserved,
  count(u.id) filter (where u.status = 'sold')               as sold
from villa_types vt
join villa_projects p on p.id = vt.project_id
left join villa_units u on u.villa_type_id = vt.id
group by p.name, vt.name, vt.id
order by p.name, vt.name;

-- Days from first contact to booking — sales velocity.
create or replace view villa_sales_velocity as
select
  b.id as booking_id,
  b.booking_number,
  l.source,
  l.campaign,
  b.value_inr,
  extract(day from (b.created_at - l.first_contact_at))::int as days_to_close
from villa_bookings b
join villa_leads l on l.id = b.lead_id
where b.status <> 'cancelled';


-- =============================================================================
-- VIEW SECURITY  — must come after every view is defined.
--
-- A Postgres view runs with the permissions of its OWNER, not its caller. That
-- means a view over an RLS-protected table happily returns rows the caller
-- could never select directly — Supabase flags these as UNRESTRICTED in the
-- table editor. Verified against the live project: villa_funnel,
-- villa_source_summary, villa_daily_leads and villa_inventory_summary all
-- returned real data to the ANON key, which is public and ships to browsers.
--
-- security_invoker = on makes each view evaluate as the caller, so the base
-- table's RLS applies and anon sees nothing. The app is unaffected: it uses the
-- service_role key, which bypasses RLS as before.
--
-- The explicit revoke is belt and braces — it stops a future `grant select on
-- all tables` from silently re-opening them.
-- =============================================================================
alter view villa_funnel               set (security_invoker = on);
alter view villa_daily_leads          set (security_invoker = on);
alter view villa_revenue_monthly      set (security_invoker = on);
alter view villa_objection_summary    set (security_invoker = on);
alter view villa_source_summary       set (security_invoker = on);
alter view villa_team_performance     set (security_invoker = on);
alter view villa_campaign_performance set (security_invoker = on);
alter view villa_inventory_summary    set (security_invoker = on);
alter view villa_sales_velocity       set (security_invoker = on);

revoke all on
  villa_funnel, villa_daily_leads, villa_revenue_monthly,
  villa_objection_summary, villa_source_summary, villa_team_performance,
  villa_campaign_performance, villa_inventory_summary, villa_sales_velocity
from anon, authenticated;

-- Customer-data tables: RLS already returns zero rows to anon, but revoking
-- removes the surface entirely rather than relying on a policy staying absent.
revoke all on
  villa_leads, villa_messages, villa_conversations, villa_contacts,
  villa_bookings, villa_payments, villa_tool_calls, villa_handoffs,
  villa_site_visits, villa_tasks, villa_follow_ups, villa_team_members,
  villa_tenant, villa_activities, villa_notifications, villa_ai_insights,
  villa_touchpoints, villa_objections, villa_questions,
  villa_automations, villa_automation_runs, villa_campaigns,
  villa_content_drafts, villa_publish_log, villa_channel_settings,
  villa_integrations
from anon, authenticated;
