-- =============================================================================
-- Leads pipeline Kanban ("production management" for the sales funnel)
--
-- Adds a manual pipeline stage on top of the existing lead_temperature /
-- lead_score signals. Those stay AI-driven; pipeline_stage is the sales team's
-- own view of where a deal sits and is only ever moved by a human on the
-- /production board.
--
-- Apply with:  Supabase Dashboard → SQL Editor → paste → Run
-- =============================================================================

do $$ begin
  create type villa_pipeline_stage as enum (
    'new', 'qualifying', 'qualified', 'site_visit_scheduled', 'negotiation', 'booked', 'lost'
  );
exception when duplicate_object then null; end $$;

alter table villa_leads
  add column if not exists pipeline_stage villa_pipeline_stage not null default 'new';

-- Backfill for rows that predate this column: a hot lead that has already
-- been handed off is further along the funnel than a brand-new 'new' row,
-- so start it at 'qualified' rather than making the sales team re-triage
-- everything that was already in flight. Everything else stays 'new' —
-- there's no reliable signal to place it any further along.
update villa_leads
set pipeline_stage = 'qualified'
where lead_temperature = 'hot'
  and handoff_status <> 'none'
  and pipeline_stage = 'new';

create index if not exists villa_leads_pipeline_idx on villa_leads (pipeline_stage);
