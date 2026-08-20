-- =============================================================================
-- Villa WhatsApp AI Sales Agent — core schema
--
-- Everything lives in `public` with a `villa_` prefix so it can be dropped into
-- an existing Supabase project without colliding with what's already there.
--
-- Apply with:  Supabase Dashboard → SQL Editor → paste → Run
-- =============================================================================

create extension if not exists "pgcrypto";

-- -----------------------------------------------------------------------------
-- Enums
-- -----------------------------------------------------------------------------
do $$ begin
  create type villa_lead_temperature as enum ('hot', 'warm', 'cold');
exception when duplicate_object then null; end $$;

do $$ begin
  create type villa_buyer_purpose as enum (
    'self_use', 'family', 'investment', 'second_home', 'vacation_home',
    'rental_income', 'nri_purchase', 'undecided'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type villa_timeline as enum (
    'immediate', 'within_1_month', '1_3_months', '3_6_months',
    '6_12_months', 'researching', 'unknown'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type villa_financing as enum ('cash', 'home_loan', 'combination', 'undecided');
exception when duplicate_object then null; end $$;

do $$ begin
  create type villa_handoff_status as enum ('none', 'requested', 'notified', 'accepted', 'closed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type villa_asset_kind as enum (
    'brochure', 'floor_plan', 'site_plan', 'master_plan', 'price_sheet',
    'image', 'video', 'virtual_tour', 'location_map', 'other'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type villa_message_role as enum ('customer', 'agent', 'human_agent', 'system');
exception when duplicate_object then null; end $$;

do $$ begin
  create type villa_visit_status as enum ('requested', 'scheduled', 'confirmed', 'completed', 'no_show', 'cancelled');
exception when duplicate_object then null; end $$;


-- =============================================================================
-- KNOWLEDGE BASE  (Company → Projects → Villa Types → Units → Assets)
--
-- This is the ONLY source of truth the agent is allowed to quote from.
-- A NULL price / NULL bedroom count is meaningful: it tells the agent the fact
-- is unverified, so it must defer to a human instead of guessing.
-- =============================================================================

create table if not exists villa_projects (
  id                    uuid primary key default gen_random_uuid(),
  slug                  text unique not null,
  name                  text not null,
  developer             text,
  status                text,                       -- e.g. 'Under Construction'
  expected_delivery     text,                       -- free text: 'June 2029 (T&C apply)'

  -- Location
  address_line          text,
  village               text,
  mandal                text,
  district              text,
  state                 text,
  pincode               text,
  survey_no             text,
  maps_url              text,

  -- Approvals — never paraphrase these, quote them verbatim
  hmda_permit_no        text,
  hmda_permit_date      text,
  rera_number           text,
  rera_status           text,

  -- Scale
  total_land_acres      numeric,
  total_units           integer,
  configurations        text[],                     -- ['3 BHK + Home Theatre', ...]

  -- Commercials. NULL = not approved for the agent to state.
  starting_price_inr    bigint,
  price_note            text,
  currency              text not null default 'INR',

  -- Narrative blocks the agent may quote
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
  id                 uuid primary key default gen_random_uuid(),
  project_id         uuid not null references villa_projects(id) on delete cascade,
  name               text not null,
  plot_area_sqyd     numeric,
  built_up_sft       numeric,
  facing             text,                          -- 'East' | 'West'
  bedrooms           integer,                       -- NULL = unconfirmed
  floors             integer,
  has_home_theatre   boolean,
  private_pool       boolean,
  price_inr          bigint,                        -- NULL = unconfirmed
  -- Set when a field above is deliberately unknown. The agent surfaces this
  -- instead of inventing a value.
  verification_note  text,
  is_active          boolean not null default true,
  created_at         timestamptz not null default now(),
  unique (project_id, name)
);

-- Optional per-unit inventory. If a project has zero rows here the agent must
-- NOT claim live availability — it says the sales team will confirm.
create table if not exists villa_units (
  id            uuid primary key default gen_random_uuid(),
  project_id    uuid not null references villa_projects(id) on delete cascade,
  villa_type_id uuid references villa_types(id) on delete set null,
  unit_number   text not null,
  facing        text,
  is_corner     boolean not null default false,
  price_inr     bigint,
  status        text not null default 'available',  -- available | blocked | sold
  updated_at    timestamptz not null default now(),
  unique (project_id, unit_number)
);

create table if not exists villa_assets (
  id            uuid primary key default gen_random_uuid(),
  project_id    uuid not null references villa_projects(id) on delete cascade,
  villa_type_id uuid references villa_types(id) on delete set null,
  kind          villa_asset_kind not null,
  title         text not null,
  description   text,
  url           text not null,
  mime_type     text,
  -- Section 14: AI-generated marketing visuals must be labelled as such.
  is_ai_generated boolean not null default false,
  version       integer not null default 1,
  is_current    boolean not null default true,
  created_at    timestamptz not null default now()
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

create table if not exists villa_leads (
  id                    uuid primary key default gen_random_uuid(),

  -- Identity. `phone` is the WhatsApp number in E.164 digits, no '+'.
  phone                 text unique not null,
  name                  text,
  email                 text,
  country               text,
  city                  text,
  is_nri                boolean not null default false,
  preferred_language    text not null default 'en',

  -- Requirements
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

  -- Qualification (internal — never exposed to the customer)
  lead_score            integer not null default 0 check (lead_score between 0 and 100),
  lead_temperature      villa_lead_temperature not null default 'cold',

  -- Attribution
  source                text not null default 'whatsapp',
  campaign              text,
  ad_id                 text,
  creative              text,
  keyword               text,
  landing_page          text,
  utm                   jsonb not null default '{}'::jsonb,
  referrer              text,

  -- Engagement
  brochure_sent         boolean not null default false,
  floor_plan_sent       boolean not null default false,
  price_sheet_sent      boolean not null default false,
  video_sent            boolean not null default false,

  -- Handoff
  sales_owner           text,
  handoff_status        villa_handoff_status not null default 'none',
  handoff_reason        text,
  handoff_at            timestamptz,

  -- Consent (section 25). When opted out, all automation must stop.
  consent_status        text not null default 'implied',
  opted_out             boolean not null default false,
  opted_out_at          timestamptz,

  -- AI pause switch (section 46 — human override)
  ai_paused             boolean not null default false,

  notes                 text,
  first_contact_at      timestamptz not null default now(),
  last_contact_at       timestamptz not null default now(),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create index if not exists villa_leads_temp_idx  on villa_leads (lead_temperature, lead_score desc);
create index if not exists villa_leads_last_idx  on villa_leads (last_contact_at desc);
create index if not exists villa_leads_src_idx   on villa_leads (source, campaign);

create table if not exists villa_conversations (
  id             uuid primary key default gen_random_uuid(),
  lead_id        uuid not null references villa_leads(id) on delete cascade,
  channel        text not null default 'whatsapp',   -- whatsapp | simulator
  status         text not null default 'open',       -- open | closed
  started_at     timestamptz not null default now(),
  last_message_at timestamptz not null default now(),
  message_count  integer not null default 0,
  summary        text
);

create index if not exists villa_conv_lead_idx on villa_conversations (lead_id, last_message_at desc);

create table if not exists villa_messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references villa_conversations(id) on delete cascade,
  lead_id         uuid not null references villa_leads(id) on delete cascade,
  role            villa_message_role not null,
  body            text,
  media_url       text,
  media_kind      villa_asset_kind,
  -- Meta's message id, so redelivered webhooks are ignored rather than
  -- answered twice.
  wa_message_id   text unique,
  created_at      timestamptz not null default now()
);

create index if not exists villa_msg_conv_idx on villa_messages (conversation_id, created_at);

-- Every tool the agent invokes, for audit + debugging. Section 44 requires the
-- agent never claim an action succeeded when the tool failed, so we record it.
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
  id             uuid primary key default gen_random_uuid(),
  lead_id        uuid not null references villa_leads(id) on delete cascade,
  project_id     uuid references villa_projects(id) on delete set null,
  preferred_date date,
  preferred_time text,
  visitor_count  integer,
  visit_type     text not null default 'site',      -- site | virtual
  status         villa_visit_status not null default 'requested',
  special_requirements text,
  notes          text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table if not exists villa_handoffs (
  id              uuid primary key default gen_random_uuid(),
  lead_id         uuid not null references villa_leads(id) on delete cascade,
  conversation_id uuid references villa_conversations(id) on delete set null,
  reason          text not null,
  payload         text not null,                    -- the section-38 briefing
  notified        boolean not null default false,
  notified_at     timestamptz,
  created_at      timestamptz not null default now()
);


-- =============================================================================
-- MARKETING INTELLIGENCE  (sections 40–42)
-- =============================================================================

create table if not exists villa_objections (
  id              uuid primary key default gen_random_uuid(),
  lead_id         uuid references villa_leads(id) on delete set null,
  conversation_id uuid references villa_conversations(id) on delete set null,
  category        text not null,   -- price | location | size | possession | ...
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
  -- True when the KB could not answer it. These are the content gaps that
  -- feed back into marketing.
  unanswered      boolean not null default false,
  created_at      timestamptz not null default now()
);

create index if not exists villa_q_topic_idx on villa_questions (topic, created_at desc);


-- =============================================================================
-- Triggers
-- =============================================================================

create or replace function villa_touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists villa_leads_touch on villa_leads;
create trigger villa_leads_touch before update on villa_leads
  for each row execute function villa_touch_updated_at();

drop trigger if exists villa_projects_touch on villa_projects;
create trigger villa_projects_touch before update on villa_projects
  for each row execute function villa_touch_updated_at();


-- =============================================================================
-- Row Level Security
--
-- The app reaches this data only through the service_role key on the server,
-- which bypasses RLS. We still enable RLS with no permissive policies so that
-- a leaked anon key cannot read a single customer record.
-- =============================================================================

alter table villa_leads         enable row level security;
alter table villa_conversations enable row level security;
alter table villa_messages      enable row level security;
alter table villa_tool_calls    enable row level security;
alter table villa_site_visits   enable row level security;
alter table villa_handoffs      enable row level security;
alter table villa_objections    enable row level security;
alter table villa_questions     enable row level security;

-- Knowledge base is public-readable (it's marketing collateral), write-locked.
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
-- Reporting views (section 39 dashboard)
-- =============================================================================

create or replace view villa_funnel as
select
  (select count(*) from villa_conversations)                                as conversations,
  (select count(*) from villa_leads)                                        as leads,
  (select count(*) from villa_leads where lead_score >= 50)                 as qualified_leads,
  (select count(*) from villa_leads where lead_temperature = 'hot')         as hot_leads,
  (select count(*) from villa_leads where lead_temperature = 'warm')        as warm_leads,
  (select count(*) from villa_leads where lead_temperature = 'cold')        as cold_leads,
  (select count(*) from villa_site_visits)                                  as site_visits_requested,
  (select count(*) from villa_site_visits where status = 'completed')       as site_visits_completed,
  (select count(*) from villa_handoffs)                                     as handoffs;

create or replace view villa_objection_summary as
select
  category,
  count(*)                                                    as total,
  round(100.0 * count(*) / nullif(sum(count(*)) over (), 0), 1) as pct
from villa_objections
group by category
order by total desc;

create or replace view villa_source_summary as
select
  source,
  campaign,
  count(*)                                             as leads,
  count(*) filter (where lead_temperature = 'hot')     as hot,
  count(*) filter (where lead_score >= 50)             as qualified,
  round(avg(lead_score), 1)                            as avg_score
from villa_leads
group by source, campaign
order by leads desc;
