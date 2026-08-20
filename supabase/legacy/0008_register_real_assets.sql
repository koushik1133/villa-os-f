-- =============================================================================
-- Registers the real files in /public as sendable assets so get_assets /
-- send_media can actually deliver them on WhatsApp, instead of the agent
-- saying "I'll have the team send it."
--
-- URLs are relative — the app serves /public at the site root. The webhook
-- and simulator both prefix these with NEXT_PUBLIC_APP_URL when sending, so
-- this works unchanged in dev and once deployed.
--
-- Photos are marked is_ai_generated = true: the project is under construction
-- with delivery years out, so any image showing finished villas is a
-- rendering, not a photograph of the built property. Per spec section 14,
-- the agent must tell a customer this if asked whether it's a real photo.
--
-- Each insert is guarded on url so re-running this migration is a no-op:
-- villa_assets has no unique constraint to hang an ON CONFLICT off.
-- =============================================================================

insert into villa_assets (project_id, kind, title, description, url, mime_type, is_ai_generated)
select id, 'brochure', 'Glentree Serenity — Full Brochure',
  'Full glossy brochure: community overview, five themed parks, both clubhouses, all six villa-type spec sheets, specifications.',
  '/SERENITY%20%20Brochure.pdf', 'application/pdf', false
from villa_projects where slug = 'glentree-serenity'
  and not exists (select 1 from villa_assets a where a.url = '/SERENITY%20%20Brochure.pdf');

insert into villa_assets (project_id, kind, title, description, url, mime_type, is_ai_generated)
select id, 'brochure', 'Glentree Serenity — Mini Brochure',
  'Condensed landscape-format brochure, plus the full unit-by-unit area statement table (all 185 villa numbers, plot area, chargeable area, saleable area, facing).',
  '/SERENITY%20mini%20Brochure.pdf', 'application/pdf', false
from villa_projects where slug = 'glentree-serenity'
  and not exists (select 1 from villa_assets a where a.url = '/SERENITY%20mini%20Brochure.pdf');

insert into villa_assets (project_id, kind, title, description, url, mime_type, is_ai_generated)
select id, 'master_plan', 'Glentree Serenity — Site Layout',
  'Master site plan showing plot grid, internal roads, clubhouse location, and HMDA/RERA permit numbers.',
  '/Serenity%20Layout.pdf', 'application/pdf', false
from villa_projects where slug = 'glentree-serenity'
  and not exists (select 1 from villa_assets a where a.url = '/Serenity%20Layout.pdf');

insert into villa_assets (project_id, kind, title, description, url, mime_type, is_ai_generated)
select id, 'other', 'Glentree Homes — Sales Presentation',
  'Internal sales presentation script covering project overview, location, amenities, specifications, connectivity, and closing questions. Reference material, not customer-facing collateral.',
  '/Glentree%20Homes%20Presentation.pdf', 'application/pdf', false
from villa_projects where slug = 'glentree-serenity'
  and not exists (select 1 from villa_assets a where a.url = '/Glentree%20Homes%20Presentation.pdf');

insert into villa_assets (project_id, kind, title, description, url, mime_type, is_ai_generated)
select id, 'image', 'Aerial masterplan rendering',
  'Conceptual aerial rendering of the completed community — not a live photograph. Project is under construction.',
  '/Glentree%20Serenity.jpg', 'image/jpeg', true
from villa_projects where slug = 'glentree-serenity'
  and not exists (select 1 from villa_assets a where a.url = '/Glentree%20Serenity.jpg');

insert into villa_assets (project_id, kind, title, description, url, mime_type, is_ai_generated)
select id, 'image', 'Villa rendering 2', 'Conceptual rendering, not a live photograph.',
  '/Glentree%20Serenity%20(2).jpg', 'image/jpeg', true
from villa_projects where slug = 'glentree-serenity'
  and not exists (select 1 from villa_assets a where a.url = '/Glentree%20Serenity%20(2).jpg');

insert into villa_assets (project_id, kind, title, description, url, mime_type, is_ai_generated)
select id, 'image', 'Villa rendering 3', 'Conceptual rendering, not a live photograph.',
  '/Glentree%20Serenity%20(3).jpg', 'image/jpeg', true
from villa_projects where slug = 'glentree-serenity'
  and not exists (select 1 from villa_assets a where a.url = '/Glentree%20Serenity%20(3).jpg');

insert into villa_assets (project_id, kind, title, description, url, mime_type, is_ai_generated)
select id, 'image', 'Villa rendering 4', 'Conceptual rendering, not a live photograph.',
  '/Glentree%20Serenity%20(4).jpg', 'image/jpeg', true
from villa_projects where slug = 'glentree-serenity'
  and not exists (select 1 from villa_assets a where a.url = '/Glentree%20Serenity%20(4).jpg');

insert into villa_assets (project_id, kind, title, description, url, mime_type, is_ai_generated)
select id, 'image', 'Villa rendering 5', 'Conceptual rendering, not a live photograph.',
  '/Glentree%20Serenity%20(5).jpg', 'image/jpeg', true
from villa_projects where slug = 'glentree-serenity'
  and not exists (select 1 from villa_assets a where a.url = '/Glentree%20Serenity%20(5).jpg');

insert into villa_assets (project_id, kind, title, description, url, mime_type, is_ai_generated)
select id, 'image', 'Villa rendering 6', 'Conceptual rendering, not a live photograph.',
  '/Glentree%20Serenity%20(6).jpg', 'image/jpeg', true
from villa_projects where slug = 'glentree-serenity'
  and not exists (select 1 from villa_assets a where a.url = '/Glentree%20Serenity%20(6).jpg');
