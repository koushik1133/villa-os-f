-- 0010_performance_indexes.sql
--
-- Indexes for filter/order pairs the dashboard actually issues, plus the
-- foreign keys Postgres leaves unindexed.
--
-- Every index below was chosen by reading the .eq()/.order()/.in() calls in
-- src/lib/*.ts and checking it is not already covered by 0001, 0003, 0006 or
-- 0009. Redundant ones are deliberately omitted and listed at the bottom.
--
-- Postgres creates an index for a primary key and for a unique constraint, but
-- NOT for a foreign key. An unindexed child FK means every delete or update of
-- a parent row sequentially scans the whole child table to enforce the
-- referential action, and every parent -> child embed in PostgREST does the
-- same. The FK indexes here are the ones on tables that grow without bound
-- (messages, tool calls, activities, touchpoints, bookings).
--
-- Safe to run more than once, and safe to run before 0006/0009: each block is
-- skipped when its table is absent, so this file never fails half-applied.
-- Re-run it after those migrations to pick up the skipped indexes.

-- -----------------------------------------------------------------------------
-- 0001 tables — always present.
-- -----------------------------------------------------------------------------

-- messagesForLead() filters on lead_id and orders by created_at. The only
-- existing index is (conversation_id, created_at), which cannot serve this:
-- lead_id is not a prefix of it. This is the hottest read on the lead detail
-- page and villa_messages is the largest table in the schema.
create index if not exists villa_msg_lead_idx
  on villa_messages (lead_id, created_at);

-- recentConversations() does a global "order by last_message_at desc" with no
-- lead filter. villa_conv_lead_idx is (lead_id, last_message_at desc), whose
-- leading column is unusable here, so the sort falls back to a full scan.
create index if not exists villa_conv_recent_idx
  on villa_conversations (last_message_at desc);

-- conversation.ts looks up the open thread for a lead by status.
create index if not exists villa_conv_status_idx
  on villa_conversations (status, last_message_at desc);

-- unansweredQuestions(): .eq("unanswered", true).order("created_at", desc).
-- Existing villa_q_topic_idx leads with topic and does not apply.
create index if not exists villa_q_unanswered_idx
  on villa_questions (unanswered, created_at desc)
  where unanswered;

-- pendingHandoffs() orders by created_at desc; the notifier filters on
-- notified. villa_handoffs has no index at all today.
create index if not exists villa_handoffs_notified_idx
  on villa_handoffs (notified, created_at desc);
create index if not exists villa_handoffs_lead_idx
  on villa_handoffs (lead_id);

-- upcomingSiteVisits() orders by created_at desc and the agent filters status.
create index if not exists villa_visits_status_idx
  on villa_site_visits (status, created_at desc);
create index if not exists villa_visits_lead_idx
  on villa_site_visits (lead_id);

-- The insights time-window queries do .gte("created_at") / .lt("created_at")
-- over villa_leads. Only last_contact_at is indexed today.
create index if not exists villa_leads_created_idx
  on villa_leads (created_at desc);

-- Inventory lists units for a project ordered by unit_number, and resolves a
-- unit's villa type. Neither FK is indexed.
create index if not exists villa_units_project_idx
  on villa_units (project_id, unit_number);
create index if not exists villa_units_type_idx
  on villa_units (villa_type_id);

-- Active-only lookups with a name sort, issued on nearly every page through
-- projectsWithTypes() and the knowledge base.
create index if not exists villa_projects_active_idx
  on villa_projects (is_active, name);
create index if not exists villa_types_active_idx
  on villa_types (is_active, name);
create index if not exists villa_types_project_idx
  on villa_types (project_id);

-- Admin asset board: .eq("kind"), .eq("is_current"), .in("project_id"),
-- .eq("villa_type_id"), ordered by created_at desc.
create index if not exists villa_assets_current_idx
  on villa_assets (is_current, kind, created_at desc);
create index if not exists villa_assets_project_idx
  on villa_assets (project_id);
create index if not exists villa_assets_type_idx
  on villa_assets (villa_type_id);

create index if not exists villa_faqs_project_idx
  on villa_faqs (project_id);

create index if not exists villa_objections_lead_idx
  on villa_objections (lead_id);
create index if not exists villa_questions_lead_idx
  on villa_questions (lead_id);

-- Unbounded audit table, written on every tool call, read per conversation.
create index if not exists villa_tool_calls_conv_idx
  on villa_tool_calls (conversation_id, created_at desc);
create index if not exists villa_tool_calls_lead_idx
  on villa_tool_calls (lead_id);

-- -----------------------------------------------------------------------------
-- 0006 tables.
-- -----------------------------------------------------------------------------

do $$
begin
  if to_regclass('public.villa_content_drafts') is not null then
    -- contentDrafts() is a straight "order by created_at desc limit 30".
    -- villa_content_drafts_project_idx leads with project_id and cannot sort.
    execute 'create index if not exists villa_drafts_recent_idx
               on villa_content_drafts (created_at desc)';
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 0009 tables.
-- -----------------------------------------------------------------------------

do $$
begin
  if to_regclass('public.villa_tasks') is not null then
    -- villa_tasks_due_idx covers (status, due_at). These two FKs are the lead
    -- detail panel and the per-member workload query, and are unindexed.
    execute 'create index if not exists villa_tasks_lead_idx on villa_tasks (lead_id)';
    execute 'create index if not exists villa_tasks_assignee_idx on villa_tasks (assigned_to)';
  end if;

  if to_regclass('public.villa_follow_ups') is not null then
    execute 'create index if not exists villa_followups_lead_idx on villa_follow_ups (lead_id)';
    execute 'create index if not exists villa_followups_assignee_idx on villa_follow_ups (assigned_to)';
    -- The cron dispatcher scans for due, not-yet-dispatched follow-ups.
    execute 'create index if not exists villa_followups_pending_idx
               on villa_follow_ups (scheduled_at)
               where dispatched_at is null';
  end if;

  if to_regclass('public.villa_bookings') is not null then
    -- listBookings() orders by created_at desc; villa_bookings_date_idx is on
    -- booking_date and does not serve that sort.
    execute 'create index if not exists villa_bookings_created_idx
               on villa_bookings (created_at desc)';
    execute 'create index if not exists villa_bookings_lead_idx on villa_bookings (lead_id)';
    execute 'create index if not exists villa_bookings_project_idx on villa_bookings (project_id)';
    execute 'create index if not exists villa_bookings_type_idx on villa_bookings (villa_type_id)';
    execute 'create index if not exists villa_bookings_unit_idx on villa_bookings (unit_id)';
    execute 'create index if not exists villa_bookings_assignee_idx on villa_bookings (assigned_to)';
  end if;

  if to_regclass('public.villa_payments') is not null then
    -- listPayments(bookingId) filters booking_id and orders by due_date.
    execute 'create index if not exists villa_payments_booking_idx
               on villa_payments (booking_id, due_date)';
  end if;

  if to_regclass('public.villa_campaigns') is not null then
    execute 'create index if not exists villa_campaigns_created_idx
               on villa_campaigns (created_at desc)';
    execute 'create index if not exists villa_campaigns_project_idx
               on villa_campaigns (project_id)';
  end if;

  if to_regclass('public.villa_automations') is not null then
    -- The trigger dispatcher looks up active automations by trigger_event on
    -- every inbound message, so this one is on the agent's hot path.
    execute 'create index if not exists villa_automations_trigger_idx
               on villa_automations (trigger_event, is_active)';
    execute 'create index if not exists villa_automations_created_idx
               on villa_automations (created_at desc)';
  end if;

  if to_regclass('public.villa_automation_runs') is not null then
    execute 'create index if not exists villa_automation_runs_recent_idx
               on villa_automation_runs (created_at desc)';
    execute 'create index if not exists villa_automation_runs_automation_idx
               on villa_automation_runs (automation_id)';
    execute 'create index if not exists villa_automation_runs_lead_idx
               on villa_automation_runs (lead_id)';
  end if;

  if to_regclass('public.villa_ai_insights') is not null then
    -- listInsights() is .eq("is_dismissed", false).order("created_at", desc).
    execute 'create index if not exists villa_insights_open_idx
               on villa_ai_insights (is_dismissed, created_at desc)';
  end if;

  if to_regclass('public.villa_notifications') is not null then
    execute 'create index if not exists villa_notifications_lead_idx
               on villa_notifications (lead_id)';
  end if;

  if to_regclass('public.villa_team_members') is not null then
    -- listTeamMembers() and the round-robin assignment query.
    execute 'create index if not exists villa_team_active_idx
               on villa_team_members (is_active, name)';
    execute 'create index if not exists villa_team_assignable_idx
               on villa_team_members (accepts_leads)
               where accepts_leads';
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- Deliberately NOT added — already covered, or not worth the write cost.
-- -----------------------------------------------------------------------------
--
-- Already present, do not duplicate:
--   villa_leads (last_contact_at desc)          0001  villa_leads_last_idx
--   villa_leads (lead_temperature, lead_score)  0001  villa_leads_temp_idx
--   villa_leads (source, campaign)              0001  villa_leads_src_idx
--   villa_leads (assigned_to)                   0009  villa_leads_assigned_idx
--   villa_leads (pipeline_stage)                0003  villa_leads_pipeline_idx
--   villa_messages (conversation_id, created_at)0001  villa_msg_conv_idx
--   villa_conversations (lead_id, last_msg)     0001  villa_conv_lead_idx
--   villa_objections (category, created_at)     0001  villa_obj_cat_idx
--   villa_questions (topic, created_at)         0001  villa_q_topic_idx
--   villa_tasks (status, due_at)                0009  villa_tasks_due_idx
--   villa_follow_ups (status, scheduled_at)     0009  villa_followups_due_idx
--   villa_bookings (booking_date desc)          0009  villa_bookings_date_idx
--   villa_activities (lead_id, created_at)      0009  villa_activities_lead_idx
--   villa_activities (created_at desc)          0009  villa_activities_time_idx
--   villa_notifications (is_read, created_at)   0009  villa_notifications_unread_idx
--   villa_touchpoints (lead_id, occurred_at)    0009  villa_touchpoints_lead_idx
--   villa_content_drafts (project_id, ...)      0006  villa_content_drafts_project_idx
--
-- Covered by a unique constraint, which already builds an index:
--   villa_leads (phone), villa_messages (wa_message_id),
--   villa_projects (slug), villa_bookings (booking_number),
--   villa_channel_settings (channel), villa_team_members (email),
--   villa_integrations (provider)
--
-- Skipped on purpose:
--   villa_leads (opted_out) — a two-value boolean read once on the send path;
--     the planner will seq-scan a small table anyway and it costs a write on
--     every lead update.
--   villa_units (status) — the inventory board groups in application code
--     after fetching every unit for a project, so there is no status filter
--     to serve. Revisit if unit counts ever reach five figures.
