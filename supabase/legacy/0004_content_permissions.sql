-- =============================================================================
-- Content permissions — per-asset AI sharing approval + per-channel publishing
-- status.
--
-- This is policy storage only. It does not connect anything: enabling a
-- channel here just flips a flag an admin controls from /admin. Wiring the
-- actual OAuth/API credentials for Instagram, YouTube, etc. is a separate
-- integration task per channel.
--
-- Apply with:  Supabase Dashboard → SQL Editor → paste → Run
-- =============================================================================

-- An asset can be uploaded and current but still off-limits for the agent to
-- share with a customer (e.g. an internal floor plan draft). Defaults to true
-- so existing assets keep behaving exactly as they do today until an admin
-- turns one off.
alter table villa_assets
  add column if not exists shareable_by_ai boolean not null default true;

create table if not exists villa_channel_settings (
  id                uuid primary key default gen_random_uuid(),
  channel           text unique not null,               -- whatsapp | instagram | youtube | whatsapp_status
  enabled           boolean not null default false,
  -- not_connected | connected | error. Set by whatever wires up that channel's
  -- credentials later — this table does not verify anything itself.
  credential_status text not null default 'not_connected',
  notes             text,
  updated_at        timestamptz not null default now()
);

drop trigger if exists villa_channel_settings_touch on villa_channel_settings;
create trigger villa_channel_settings_touch before update on villa_channel_settings
  for each row execute function villa_touch_updated_at();

-- Same posture as villa_leads: the app only reaches this through the
-- service_role key on the server, so RLS stays on with no permissive policy.
alter table villa_channel_settings enable row level security;

insert into villa_channel_settings (channel, enabled, credential_status)
values
  ('whatsapp',        false, 'not_connected'),
  ('instagram',       false, 'not_connected'),
  ('youtube',         false, 'not_connected'),
  ('whatsapp_status', false, 'not_connected')
on conflict (channel) do nothing;
