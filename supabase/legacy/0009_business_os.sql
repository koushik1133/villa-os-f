-- =============================================================================
-- Business OS layer — ported from the villa-ai-system repo.
--
-- That repo was a UI demo backed entirely by static mock data in
-- src/lib/demo-data/index.ts. Its data model was well thought out, so this
-- migration makes it real: every entity it rendered now has a table, and the
-- pages in this app read from Supabase instead of a hardcoded array.
--
-- Everything is additive. Existing tables (villa_leads, villa_conversations,
-- villa_site_visits, villa_projects, ...) are reused rather than duplicated —
-- e.g. the source repo's `Lead` maps onto villa_leads, which already has
-- scoring, attribution and pipeline_stage.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Enums
-- -----------------------------------------------------------------------------
do $$ begin
  create type villa_user_role as enum (
    'owner', 'admin', 'manager', 'sales_manager', 'sales_agent',
    'marketing_manager', 'marketing_agent', 'viewer'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type villa_task_status as enum ('pending', 'in_progress', 'completed', 'overdue');
exception when duplicate_object then null; end $$;

do $$ begin
  create type villa_task_priority as enum ('low', 'medium', 'high', 'urgent');
exception when duplicate_object then null; end $$;

do $$ begin
  create type villa_booking_status as enum (
    'initiated', 'agreement_sent', 'signed', 'advance_paid', 'registered', 'cancelled'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type villa_payment_status as enum ('pending', 'partial', 'paid', 'overdue', 'refunded');
exception when duplicate_object then null; end $$;

do $$ begin
  create type villa_campaign_status as enum ('active', 'paused', 'ended', 'draft');
exception when duplicate_object then null; end $$;

do $$ begin
  create type villa_followup_status as enum ('pending', 'completed', 'missed', 'rescheduled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type villa_insight_severity as enum ('info', 'warning', 'critical', 'success');
exception when duplicate_object then null; end $$;


-- -----------------------------------------------------------------------------
-- Team — sales and marketing staff. Leads get assigned to these people, and
-- handoffs route to them instead of the single SALES_TEAM_WHATSAPP number.
-- -----------------------------------------------------------------------------
create table if not exists villa_team_members (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  email        text unique,
  phone        text,
  role         villa_user_role not null default 'sales_agent',
  department   text not null default 'sales',
  is_active    boolean not null default true,
  -- Round-robin assignment respects this; set false for someone on leave.
  accepts_leads boolean not null default true,
  joined_at    timestamptz not null default now(),
  created_at   timestamptz not null default now()
);

alter table villa_leads add column if not exists assigned_to uuid references villa_team_members(id) on delete set null;
create index if not exists villa_leads_assigned_idx on villa_leads (assigned_to);


-- -----------------------------------------------------------------------------
-- Tasks and follow-ups.
--
-- Follow-ups are the scheduler the original spec (sections 23-24) asked for
-- and this app never had: a due time, a channel, and a status. A cron hitting
-- /api/cron/follow-ups processes the ones that come due.
-- -----------------------------------------------------------------------------
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
  channel       text not null default 'whatsapp',
  -- What to actually say. For WhatsApp outside the 24h window this must be an
  -- approved template name, not free text — see template_name.
  message       text,
  template_name text,
  notes         text,
  ai_generated  boolean not null default false,
  -- Guard against the same follow-up firing twice if a cron overlaps.
  dispatched_at timestamptz,
  created_at    timestamptz not null default now()
);

create index if not exists villa_followups_due_idx on villa_follow_ups (status, scheduled_at);


-- -----------------------------------------------------------------------------
-- Bookings — the revenue record. A booking closes the loop from ad spend to
-- rupees, which is what makes attribution meaningful.
-- -----------------------------------------------------------------------------
create table if not exists villa_bookings (
  id              uuid primary key default gen_random_uuid(),
  booking_number  text unique not null,
  lead_id         uuid references villa_leads(id) on delete set null,
  project_id      uuid references villa_projects(id) on delete set null,
  villa_type_id   uuid references villa_types(id) on delete set null,
  unit_id         uuid references villa_units(id) on delete set null,

  customer_name   text not null,
  customer_phone  text not null,
  customer_email  text,

  value_inr       bigint not null default 0,
  amount_paid_inr bigint not null default 0,
  booking_date    date not null default current_date,
  agreement_date  date,
  registration_date date,

  status          villa_booking_status not null default 'initiated',
  payment_status  villa_payment_status not null default 'pending',
  assigned_to     uuid references villa_team_members(id) on delete set null,

  -- Copied off the lead at booking time so revenue attribution survives even
  -- if the lead record is later edited.
  source          text,
  campaign        text,

  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists villa_bookings_date_idx on villa_bookings (booking_date desc);

-- Milestone payment schedule against a booking.
create table if not exists villa_payments (
  id          uuid primary key default gen_random_uuid(),
  booking_id  uuid not null references villa_bookings(id) on delete cascade,
  milestone   text not null,
  amount_inr  bigint not null,
  due_date    date,
  paid_date   date,
  status      villa_payment_status not null default 'pending',
  created_at  timestamptz not null default now()
);


-- -----------------------------------------------------------------------------
-- Campaigns — ad spend per channel. Without this, cost-per-lead and ROAS are
-- unknowable, so the attribution page can only ever show lead counts.
-- -----------------------------------------------------------------------------
create table if not exists villa_campaigns (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,
  platform       text not null,
  status         villa_campaign_status not null default 'draft',
  project_id     uuid references villa_projects(id) on delete set null,
  external_id    text,
  start_date     date,
  end_date       date,
  budget_inr     bigint not null default 0,
  spent_inr      bigint not null default 0,
  impressions    bigint not null default 0,
  clicks         bigint not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (platform, name)
);


-- -----------------------------------------------------------------------------
-- Activity feed — one row per notable event, so a rep opening a lead sees the
-- whole history rather than just messages.
-- -----------------------------------------------------------------------------
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


-- -----------------------------------------------------------------------------
-- Automations — trigger + conditions + actions, evaluated server-side.
-- -----------------------------------------------------------------------------
create table if not exists villa_automations (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  description     text,
  is_active       boolean not null default false,
  trigger_event   text not null,
  conditions      jsonb not null default '[]'::jsonb,
  actions         jsonb not null default '[]'::jsonb,
  execution_count integer not null default 0,
  last_executed_at timestamptz,
  created_at      timestamptz not null default now()
);

create table if not exists villa_automation_runs (
  id            uuid primary key default gen_random_uuid(),
  automation_id uuid not null references villa_automations(id) on delete cascade,
  lead_id       uuid references villa_leads(id) on delete set null,
  ok            boolean not null default true,
  detail        text,
  created_at    timestamptz not null default now()
);


-- -----------------------------------------------------------------------------
-- Notifications and AI insights.
--
-- Insights are generated from real aggregates by /api/ai/insights — they are
-- never invented. Each row keeps the numbers it was derived from in
-- `evidence` so a claim can be checked rather than trusted.
-- -----------------------------------------------------------------------------
create table if not exists villa_notifications (
  id          uuid primary key default gen_random_uuid(),
  kind        text not null,
  title       text not null,
  description text,
  severity    villa_insight_severity not null default 'info',
  href        text,
  is_read     boolean not null default false,
  lead_id     uuid references villa_leads(id) on delete cascade,
  created_at  timestamptz not null default now()
);

create index if not exists villa_notifications_unread_idx on villa_notifications (is_read, created_at desc);

create table if not exists villa_ai_insights (
  id              uuid primary key default gen_random_uuid(),
  insight_type    text not null default 'recommendation',
  severity        villa_insight_severity not null default 'info',
  title           text not null,
  description     text not null,
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


-- -----------------------------------------------------------------------------
-- Multi-touch attribution. villa_leads already stores first-touch; this
-- records every subsequent touch so first/last-touch can be compared.
-- -----------------------------------------------------------------------------
create table if not exists villa_touchpoints (
  id           uuid primary key default gen_random_uuid(),
  lead_id      uuid not null references villa_leads(id) on delete cascade,
  channel      text not null,
  campaign     text,
  detail       text,
  occurred_at  timestamptz not null default now()
);

create index if not exists villa_touchpoints_lead_idx on villa_touchpoints (lead_id, occurred_at);


-- -----------------------------------------------------------------------------
-- Integrations registry — what's connected, for the settings page. Extends
-- the channel on/off switches from 0004 to non-messaging providers too.
-- -----------------------------------------------------------------------------
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

insert into villa_integrations (provider, label, category) values
  ('whatsapp_cloud', 'WhatsApp Cloud API', 'messaging'),
  ('instagram',      'Instagram',          'messaging'),
  ('meta_ads',       'Meta Ads',           'advertising'),
  ('google_ads',     'Google Ads',         'advertising'),
  ('youtube',        'YouTube',            'messaging'),
  ('gemini',         'Google Gemini',      'analytics'),
  ('anthropic',      'Anthropic Claude',   'analytics'),
  ('groq',           'Groq',               'analytics')
on conflict (provider) do nothing;


-- -----------------------------------------------------------------------------
-- Triggers
-- -----------------------------------------------------------------------------
drop trigger if exists villa_bookings_touch on villa_bookings;
create trigger villa_bookings_touch before update on villa_bookings
  for each row execute function villa_touch_updated_at();

drop trigger if exists villa_campaigns_touch on villa_campaigns;
create trigger villa_campaigns_touch before update on villa_campaigns
  for each row execute function villa_touch_updated_at();


-- -----------------------------------------------------------------------------
-- RLS — server-only, same posture as every other customer-data table.
-- -----------------------------------------------------------------------------
alter table villa_team_members    enable row level security;
alter table villa_tasks           enable row level security;
alter table villa_follow_ups      enable row level security;
alter table villa_bookings        enable row level security;
alter table villa_payments        enable row level security;
alter table villa_campaigns       enable row level security;
alter table villa_activities      enable row level security;
alter table villa_automations     enable row level security;
alter table villa_automation_runs enable row level security;
alter table villa_notifications   enable row level security;
alter table villa_ai_insights     enable row level security;
alter table villa_touchpoints     enable row level security;
alter table villa_integrations    enable row level security;


-- -----------------------------------------------------------------------------
-- Reporting views
-- -----------------------------------------------------------------------------

-- Revenue by month, from real bookings only.
create or replace view villa_revenue_monthly as
select
  date_trunc('month', booking_date)::date as month,
  count(*)                                 as bookings,
  sum(value_inr)                           as booked_value_inr,
  sum(amount_paid_inr)                     as collected_inr
from villa_bookings
where status <> 'cancelled'
group by 1
order by 1 desc;

-- Per-campaign economics. Leads join on campaign name, so a campaign with no
-- matching leads correctly shows zero rather than being hidden.
create or replace view villa_campaign_performance as
select
  c.id,
  c.name,
  c.platform,
  c.status,
  c.budget_inr,
  c.spent_inr,
  c.impressions,
  c.clicks,
  count(distinct l.id)                                              as leads,
  count(distinct l.id) filter (where l.lead_score >= 50)            as qualified_leads,
  count(distinct b.id)                                              as bookings,
  coalesce(sum(b.value_inr), 0)                                     as revenue_inr,
  case when count(distinct l.id) > 0
       then round(c.spent_inr::numeric / count(distinct l.id), 0) end as cpl_inr,
  case when c.spent_inr > 0
       then round(coalesce(sum(b.value_inr), 0)::numeric / c.spent_inr, 2) end as roas
from villa_campaigns c
left join villa_leads l on l.campaign = c.name
left join villa_bookings b on b.lead_id = l.id and b.status <> 'cancelled'
group by c.id, c.name, c.platform, c.status, c.budget_inr, c.spent_inr, c.impressions, c.clicks
order by c.spent_inr desc;

-- Per-rep performance.
--
-- Bookings are pre-aggregated rather than joined inline: they hang off the rep
-- directly, not off the lead, so joining them alongside leads and site visits
-- multiplies each booking row by the lead x site-visit cartesian product and
-- inflates sum(value_inr). count(distinct) hides that for counts but a sum
-- cannot be de-duplicated after the fan-out.
create or replace view villa_team_performance as
select
  t.id,
  t.name,
  t.role,
  t.department,
  count(distinct l.id)                                        as assigned_leads,
  count(distinct l.id) filter (where l.lead_temperature = 'hot') as hot_leads,
  count(distinct sv.id)                                       as site_visits,
  coalesce(b.bookings, 0)                                     as bookings,
  coalesce(b.revenue_inr, 0)                                  as revenue_inr,
  case when count(distinct l.id) > 0
       then round(100.0 * coalesce(b.bookings, 0) / count(distinct l.id), 1) end as conversion_rate
from villa_team_members t
left join villa_leads l on l.assigned_to = t.id
left join villa_site_visits sv on sv.lead_id = l.id
left join (
  select assigned_to,
         count(*)        as bookings,
         sum(value_inr)  as revenue_inr
  from villa_bookings
  where status <> 'cancelled' and assigned_to is not null
  group by assigned_to
) b on b.assigned_to = t.id
group by t.id, t.name, t.role, t.department, b.bookings, b.revenue_inr
order by revenue_inr desc;

-- Daily lead flow for time-series charts.
create or replace view villa_daily_leads as
select
  created_at::date                                     as day,
  count(*)                                             as leads,
  count(*) filter (where lead_score >= 50)             as qualified,
  count(*) filter (where lead_temperature = 'hot')     as hot
from villa_leads
group by 1
order by 1 desc;
