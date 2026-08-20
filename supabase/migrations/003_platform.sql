-- =============================================================================
-- 003 — Conversation platform. ADDITIVE: run this AFTER 001 and 002.
--
-- Adds what a WhatsApp/Instagram business platform needs beyond a single agent:
--   * a lease-based lock so two messages from one customer never run the agent
--     twice in parallel
--   * message templates, broadcasts and a per-recipient send queue
--   * drip sequences with enrollments
--   * interactive flows (button/list menus and forms) and their responses
--   * Instagram as a first-class channel alongside WhatsApp
--
-- Safe to re-run.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Concurrency: lease-based locks.
--
-- Postgres advisory locks are session-scoped, and Supabase pools connections —
-- a lock taken in one PostgREST call is not held in the next. So the lock lives
-- in a table instead, keyed by conversation, with an expiry so a crashed worker
-- cannot wedge a customer's thread forever.
-- -----------------------------------------------------------------------------
create table if not exists villa_locks (
  key         text primary key,
  holder      uuid not null,
  acquired_at timestamptz not null default now(),
  expires_at  timestamptz not null
);
alter table villa_locks enable row level security;
create index if not exists villa_locks_expires_idx on villa_locks (expires_at);

-- Atomic take-or-steal-if-expired. Returns true only to the caller that holds
-- it. `on conflict do update ... where` makes the expiry check part of the same
-- statement, so two racing callers cannot both succeed.
create or replace function villa_acquire_lock(
  p_key text, p_holder uuid, p_ttl_seconds integer default 60
) returns boolean language plpgsql as $$
declare v_holder uuid;
begin
  insert into villa_locks (key, holder, acquired_at, expires_at)
  values (p_key, p_holder, now(), now() + make_interval(secs => p_ttl_seconds))
  on conflict (key) do update
    set holder = excluded.holder, acquired_at = now(), expires_at = excluded.expires_at
    where villa_locks.expires_at < now()
  returning holder into v_holder;
  return v_holder is not distinct from p_holder;
end $$;

create or replace function villa_release_lock(p_key text, p_holder uuid)
returns void language sql as $$
  delete from villa_locks where key = p_key and holder = p_holder;
$$;

-- -----------------------------------------------------------------------------
-- Atomic lead upsert.
--
-- The app previously did select-then-insert, which races: two webhooks for the
-- same new phone number both see "no lead" and both insert, and the unique
-- index turns the loser into a hard error that drops a real customer message.
-- One statement removes the window entirely.
--
-- `p_name` only ever fills a NULL name — a name the customer actually told us
-- must never be overwritten by a WhatsApp profile name.
-- -----------------------------------------------------------------------------
create or replace function villa_upsert_lead(
  p_phone text, p_name text, p_source text, p_campaign text, p_ad_id text,
  p_creative text, p_keyword text, p_landing_page text, p_referrer text,
  p_utm jsonb default '{}'::jsonb
) returns table (lead villa_leads, created boolean) language plpgsql as $$
declare v_lead villa_leads; v_created boolean := false;
begin
  insert into villa_leads (phone, name, source, campaign, ad_id, creative,
                           keyword, landing_page, referrer, utm)
  values (p_phone, p_name, coalesce(p_source,'whatsapp'), p_campaign, p_ad_id,
          p_creative, p_keyword, p_landing_page, p_referrer, coalesce(p_utm,'{}'::jsonb))
  on conflict (phone) do nothing
  returning * into v_lead;

  if found then
    v_created := true;
  else
    update villa_leads set name = coalesce(name, p_name)
    where phone = p_phone returning * into v_lead;
  end if;

  return query select v_lead, v_created;
end $$;

-- Same race on conversations: two messages, no open thread yet, two threads.
-- A partial unique index makes "at most one open conversation per lead and
-- channel" a database rule rather than an application hope.
create unique index if not exists villa_one_open_conversation
  on villa_conversations (lead_id, channel) where status = 'open';

create or replace function villa_upsert_conversation(
  p_lead_id uuid, p_channel text default 'whatsapp'
) returns villa_conversations language plpgsql as $$
declare v_conv villa_conversations;
begin
  -- channel is an enum, so the text parameter needs an explicit cast; without
  -- it Postgres refuses the insert outright rather than coercing.
  insert into villa_conversations (lead_id, channel)
  values (p_lead_id, p_channel::villa_comm_channel)
  on conflict (lead_id, channel) where status = 'open' do nothing
  returning * into v_conv;

  if not found then
    select * into v_conv from villa_conversations
    where lead_id = p_lead_id
      and channel = p_channel::villa_comm_channel
      and status = 'open'
    order by last_message_at desc nulls last limit 1;
  end if;
  return v_conv;
end $$;

-- -----------------------------------------------------------------------------
-- Channels. Instagram DMs run the same agent over a different transport.
-- -----------------------------------------------------------------------------
alter table villa_leads add column if not exists instagram_id text;
alter table villa_leads add column if not exists last_channel  text;

create unique index if not exists villa_leads_instagram_idx
  on villa_leads (instagram_id) where instagram_id is not null;

-- An Instagram lead usually has no phone number — Meta gives an opaque IGSID
-- and the customer may never share a number. phone was `not null`, which made
-- such a lead impossible to store at all. It becomes nullable, and a check
-- takes over the job the not-null was really doing: every lead must be
-- reachable by *something*.
alter table villa_leads alter column phone drop not null;

alter table villa_leads drop constraint if exists villa_leads_has_identity;
alter table villa_leads add constraint villa_leads_has_identity
  check (phone is not null or instagram_id is not null or email is not null);

-- Upsert keyed on the Instagram id, mirroring villa_upsert_lead.
create or replace function villa_upsert_lead_instagram(
  p_instagram_id text, p_name text, p_source text default 'instagram'
) returns table (lead villa_leads, created boolean) language plpgsql as $$
declare v_lead villa_leads; v_created boolean := false;
begin
  insert into villa_leads (instagram_id, name, source, last_channel)
  values (p_instagram_id, p_name, coalesce(p_source,'instagram'), 'instagram')
  on conflict (instagram_id) where instagram_id is not null do nothing
  returning * into v_lead;

  if found then
    v_created := true;
  else
    update villa_leads
       set name = coalesce(name, p_name), last_channel = 'instagram'
     where instagram_id = p_instagram_id
    returning * into v_lead;
  end if;

  return query select v_lead, v_created;
end $$;

-- -----------------------------------------------------------------------------
-- Templates. Outside the 24-hour service window Meta rejects free-form text,
-- so re-engagement must go through a template Meta has already approved.
-- `status` mirrors Meta's own review state — we never invent it.
-- -----------------------------------------------------------------------------
do $$ begin create type villa_template_status as enum
  ('draft','pending','approved','rejected','paused','disabled');
exception when duplicate_object then null; end $$;

do $$ begin create type villa_template_category as enum
  ('marketing','utility','authentication');
exception when duplicate_object then null; end $$;

create table if not exists villa_templates (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  language      text not null default 'en',
  category      villa_template_category not null default 'marketing',
  status        villa_template_status not null default 'draft',
  -- Meta's own id, once submitted. NULL means it exists only here.
  meta_id       text,
  header_kind   text check (header_kind in ('none','text','image','video','document')) default 'none',
  header_text   text,
  header_media_url text,
  body          text not null,
  footer        text,
  -- [{type:'quick_reply'|'url'|'phone', text:..., url:..., phone:...}]
  buttons       jsonb not null default '[]'::jsonb,
  -- Number of {{n}} placeholders in body, so a broadcast can validate its
  -- variable count before Meta rejects the whole send.
  variables     integer not null default 0,
  rejection_reason text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (name, language)
);
alter table villa_templates enable row level security;
drop trigger if exists villa_templates_touch on villa_templates;
create trigger villa_templates_touch before update on villa_templates
  for each row execute function villa_touch_updated_at();

-- -----------------------------------------------------------------------------
-- Broadcasts. A broadcast fans out into one villa_broadcast_recipients row per
-- lead, each independently retryable — a single bad number must not stall or
-- silently truncate a 5,000-recipient send.
-- -----------------------------------------------------------------------------
do $$ begin create type villa_broadcast_status as enum
  ('draft','scheduled','sending','paused','completed','failed','cancelled');
exception when duplicate_object then null; end $$;

do $$ begin create type villa_delivery_status as enum
  ('queued','sent','delivered','read','failed','skipped');
exception when duplicate_object then null; end $$;

create table if not exists villa_broadcasts (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  channel       villa_comm_channel not null default 'whatsapp',
  template_id   uuid references villa_templates(id) on delete restrict,
  status        villa_broadcast_status not null default 'draft',
  -- Saved lead filter, e.g. {"temperature":["hot"],"stage":["qualified"]}
  audience      jsonb not null default '{}'::jsonb,
  -- Positional {{1}}..{{n}} values; supports @name style lead-field tokens.
  variables     jsonb not null default '[]'::jsonb,
  scheduled_for timestamptz,
  started_at    timestamptz,
  completed_at  timestamptz,
  total         integer not null default 0,
  sent          integer not null default 0,
  delivered     integer not null default 0,
  read          integer not null default 0,
  failed        integer not null default 0,
  created_by    uuid references villa_team_members(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
alter table villa_broadcasts enable row level security;
drop trigger if exists villa_broadcasts_touch on villa_broadcasts;
create trigger villa_broadcasts_touch before update on villa_broadcasts
  for each row execute function villa_touch_updated_at();

create table if not exists villa_broadcast_recipients (
  id            uuid primary key default gen_random_uuid(),
  broadcast_id  uuid not null references villa_broadcasts(id) on delete cascade,
  lead_id       uuid not null references villa_leads(id) on delete cascade,
  phone         text not null,
  status        villa_delivery_status not null default 'queued',
  wa_message_id text,
  error         text,
  attempts      integer not null default 0,
  sent_at       timestamptz,
  delivered_at  timestamptz,
  read_at       timestamptz,
  unique (broadcast_id, lead_id)
);
alter table villa_broadcast_recipients enable row level security;
create index if not exists villa_bcast_rcpt_pending_idx
  on villa_broadcast_recipients (broadcast_id, status);
create index if not exists villa_bcast_rcpt_wamid_idx
  on villa_broadcast_recipients (wa_message_id) where wa_message_id is not null;

-- Claims a batch and marks it in-flight in one statement, so two workers
-- running at once cannot both grab the same recipient. skip locked is what
-- makes this safe under concurrency rather than merely unlikely to collide.
create or replace function villa_claim_broadcast_batch(
  p_broadcast_id uuid, p_limit integer default 50
) returns setof villa_broadcast_recipients language sql as $$
  update villa_broadcast_recipients r
  set status = 'sent', attempts = r.attempts + 1
  where r.id in (
    select id from villa_broadcast_recipients
    where broadcast_id = p_broadcast_id and status = 'queued'
    order by id limit p_limit for update skip locked
  )
  returning r.*;
$$;

-- -----------------------------------------------------------------------------
-- Drip sequences. Steps fire relative to enrollment, so "day 3" means three
-- days after this lead joined, not a fixed calendar date.
-- -----------------------------------------------------------------------------
create table if not exists villa_sequences (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  description text,
  channel     villa_comm_channel not null default 'whatsapp',
  active      boolean not null default false,
  -- Lead filter that auto-enrolls, e.g. {"stage":["new"]}. Empty = manual only.
  entry       jsonb not null default '{}'::jsonb,
  -- Stop the drip the moment the lead does what it was pushing for.
  exit_on     text[] not null default array['booked','lost']::text[],
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
alter table villa_sequences enable row level security;
drop trigger if exists villa_sequences_touch on villa_sequences;
create trigger villa_sequences_touch before update on villa_sequences
  for each row execute function villa_touch_updated_at();

create table if not exists villa_sequence_steps (
  id           uuid primary key default gen_random_uuid(),
  sequence_id  uuid not null references villa_sequences(id) on delete cascade,
  position     integer not null,
  delay_hours  integer not null default 24,
  template_id  uuid references villa_templates(id) on delete set null,
  -- Used when the lead is still inside the 24h window (no template needed).
  body         text,
  asset_id     uuid references villa_assets(id) on delete set null,
  unique (sequence_id, position)
);
alter table villa_sequence_steps enable row level security;

do $$ begin create type villa_enrollment_status as enum
  ('active','completed','exited','failed');
exception when duplicate_object then null; end $$;

create table if not exists villa_sequence_enrollments (
  id            uuid primary key default gen_random_uuid(),
  sequence_id   uuid not null references villa_sequences(id) on delete cascade,
  lead_id       uuid not null references villa_leads(id) on delete cascade,
  status        villa_enrollment_status not null default 'active',
  current_step  integer not null default 0,
  next_run_at   timestamptz not null default now(),
  enrolled_at   timestamptz not null default now(),
  completed_at  timestamptz,
  exit_reason   text,
  unique (sequence_id, lead_id)
);
alter table villa_sequence_enrollments enable row level security;
create index if not exists villa_seq_enroll_due_idx
  on villa_sequence_enrollments (next_run_at) where status = 'active';

-- -----------------------------------------------------------------------------
-- Interactive flows: button menus, list pickers and multi-question forms.
-- Answers land in villa_flow_responses and can map onto lead columns.
-- -----------------------------------------------------------------------------
do $$ begin create type villa_flow_kind as enum ('menu','form','qualifier');
exception when duplicate_object then null; end $$;

create table if not exists villa_flows (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,
  kind        villa_flow_kind not null default 'menu',
  active      boolean not null default false,
  -- Keywords that open this flow, matched case-insensitively.
  triggers    text[] not null default '{}',
  -- [{id, prompt, type:'buttons'|'list'|'text'|'number', options:[...],
  --   maps_to:'budget_max_inr', next:'step-id'}]
  steps       jsonb not null default '[]'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
alter table villa_flows enable row level security;
drop trigger if exists villa_flows_touch on villa_flows;
create trigger villa_flows_touch before update on villa_flows
  for each row execute function villa_touch_updated_at();

create table if not exists villa_flow_responses (
  id            uuid primary key default gen_random_uuid(),
  flow_id       uuid not null references villa_flows(id) on delete cascade,
  lead_id       uuid not null references villa_leads(id) on delete cascade,
  step_id       text not null,
  answer        text,
  answered_at   timestamptz not null default now()
);
alter table villa_flow_responses enable row level security;
create index if not exists villa_flow_resp_lead_idx on villa_flow_responses (lead_id);

-- Where a lead currently sits in a flow. One active flow per lead at a time —
-- two half-finished questionnaires in one thread is worse than none.
create table if not exists villa_flow_sessions (
  lead_id       uuid primary key references villa_leads(id) on delete cascade,
  flow_id       uuid not null references villa_flows(id) on delete cascade,
  step_id       text not null,
  started_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
alter table villa_flow_sessions enable row level security;

-- -----------------------------------------------------------------------------
-- Delivery receipts. Meta reports sent/delivered/read/failed against the
-- message id, for agent replies and broadcasts alike.
-- -----------------------------------------------------------------------------
alter table villa_messages add column if not exists delivery_status villa_delivery_status;
alter table villa_messages add column if not exists delivered_at timestamptz;
alter table villa_messages add column if not exists read_at timestamptz;
alter table villa_messages add column if not exists error text;

-- -----------------------------------------------------------------------------
-- Reporting
-- -----------------------------------------------------------------------------
create or replace view villa_broadcast_performance as
select b.id, b.name, b.status, b.channel, b.created_at, b.total,
       count(*) filter (where r.status in ('sent','delivered','read')) as sent,
       count(*) filter (where r.status in ('delivered','read'))        as delivered,
       count(*) filter (where r.status = 'read')                       as read,
       count(*) filter (where r.status = 'failed')                     as failed,
       round(100.0 * count(*) filter (where r.status = 'read')
             / nullif(count(*) filter (where r.status in ('delivered','read')), 0), 1) as read_rate
from villa_broadcasts b
left join villa_broadcast_recipients r on r.broadcast_id = b.id
group by b.id;

-- Same rule as every other view in this database: evaluate as the caller so
-- the base tables' RLS applies, and keep anon off it entirely.
alter view villa_broadcast_performance set (security_invoker = on);

revoke all on
  villa_locks, villa_templates, villa_broadcasts, villa_broadcast_recipients,
  villa_sequences, villa_sequence_steps, villa_sequence_enrollments,
  villa_flows, villa_flow_responses, villa_flow_sessions,
  villa_broadcast_performance
from anon, authenticated;
