-- =============================================================================
-- REAL SITE DATA — Glentree Homes (glentreehomes.in)
--
-- Supplements the placeholder presentation-script seed (0002) with facts
-- fact-checked directly against the developer's live site on 2026-08-18.
-- Pages fetched: Home, About Us, Contact Us, Projects listing, and the
-- dedicated Glentree Serenity project page.
--
-- Ground rule (same as 0002): a field is only touched below if the live site
-- gives it a genuinely new, confirmed value. Where the site is silent on
-- something the placeholder script stated (e.g. per-type villa prices), or
-- the site's value conflicts with a customer-facing commitment the sales
-- team may already be quoting (e.g. expected delivery date), the existing
-- value is left alone — see the comment above each block for the reasoning.
-- Nothing here is invented; anything the site didn't state stays NULL.
--
-- 0001 and 0002 are untouched — this file is purely additive.
--
-- Re-run safety: the villa_projects upserts (sections 1 and 3) are safe to
-- re-run — they key off `slug`. The villa_faqs inserts (section 4) are plain
-- INSERTs with no ON CONFLICT, matching 0002's existing pattern — don't
-- re-run this file against a database it has already been applied to.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Section 1: Glentree Serenity — fill genuinely new fields, touch nothing else
--
-- Fields deliberately NOT touched, and why:
--   * status: site says "Ongoing" (a generic project-listing label); the
--     placeholder's "Under Construction" is at least as specific and isn't
--     contradicted, so there's nothing to gain by overwriting it.
--   * expected_delivery: the site's dedicated project-summary text says
--     "October 2029", but the approved presentation script (0002) says
--     "June 2029 (T&C Apply)" — a 4-month difference on a customer-facing
--     possession date. This is a genuine conflict between two live sources,
--     not the site simply having new information, so per the conservative
--     rule we leave the sales-script value in place rather than silently
--     picking one. Flagging here for a human to reconcile against the
--     current price sheet / RERA filing before either value is trusted.
--   * total_land_acres / total_units: site says "184–185 villas across
--     18–19.5 acres" — a range whose low end matches the existing exact
--     values (184, 18) already in the DB. Not a new fact, nothing to change.
--   * starting_price_inr / price_note: the site's own project page states NO
--     price is published for Glentree Serenity (explicitly called out in the
--     scrape notes as an example of "site is silent, don't touch it"). The
--     placeholder's ₹1.98 Cr++ figure stays as-is.
--   * hmda_permit_no: site states 012013/LO/HMDA/3194/SMD/2024 — identical to
--     the placeholder value. Cross-verified, not changed.
--
-- Fields filled in because the site has a genuinely new, non-conflicting value:
--   * developer: not previously set; site confirms "Glentree Homes".
--   * rera_number / rera_status: rera_number was never set, and rera_status
--     was 'Under Processing'. The live site now states an active TG RERA
--     registration number (P02400010707), so we record the number and move
--     status to 'Registered'.
--   * address_line: not previously set; the site's address for the villa
--     site (Sy 578, Nadergul, Balapur, Hyderabad, Telangana) corroborates —
--     doesn't contradict — the granular survey_no/village/mandal/state
--     fields the placeholder already set, so it's safe to add as a
--     human-readable summary.
--   * amenities: the site's flat amenity list includes several items not
--     itemised anywhere in the presentation-script breakdown (e.g. Pickleball,
--     Cloud kitchen, Pet park, Solar power, Centralized LPG). These are
--     appended as a new key so the detailed clubhouse/park data from the
--     script is preserved untouched, not overwritten.
-- -----------------------------------------------------------------------------
insert into villa_projects (
  slug, name, developer, rera_number, rera_status, address_line, amenities
) values (
  'glentree-serenity',
  'Glentree Serenity',
  'Glentree Homes',
  'P02400010707',
  'Registered',
  'Sy 578, Nadergul Village, Balapur Mandal, Hyderabad, Telangana — about 10 minutes from ORR',
  '{
    "additional_confirmed_live_site": {
      "verified_at": "glentreehomes.in/glentree-serenity (live site, fact-checked 2026-08-18)",
      "items_not_in_presentation_script": [
        "Welcome lounge", "Cloud kitchen", "Basketball court", "Pickleball court",
        "Pet park", "Solar power", "Centralized LPG"
      ],
      "note": "These items appear in the live site amenity list but were not itemised in the original presentation script. Supplementary only — does not replace the detailed clubhouse/park breakdown above."
    }
  }'::jsonb
)
on conflict (slug) do update set
  developer     = excluded.developer,
  rera_number   = excluded.rera_number,
  rera_status   = excluded.rera_status,
  address_line  = excluded.address_line,
  amenities     = villa_projects.amenities || excluded.amenities,
  updated_at    = now();


-- -----------------------------------------------------------------------------
-- Section 2: Villa types — bedroom/price ambiguity re-checked, still unresolved
--
-- 0002 left `bedrooms` and `price_inr` NULL on every villa_types row because
-- the presentation script gives plot size + facing but never states which
-- plot size is 3 BHK vs 4 BHK, or a per-type price. The live site's own
-- configuration data has the identical gap: it confirms the project offers
-- "3 BHK & 4 BHK" and plot sizes "200, 267, or 300 sq. yards", but explicitly
-- does NOT state which plot size maps to which bedroom count, and publishes
-- no price at all. Since the site doesn't resolve the ambiguity, no UPDATE
-- is made here — the existing verification_note on villa_types stands.
-- -----------------------------------------------------------------------------


-- -----------------------------------------------------------------------------
-- Section 3: Sibling projects found on the live site
--
-- Glentree Serenity is the only villa product; Glentree Onyx and Halcyon Fuji
-- are apartment projects, and Silverleaf/Green Park/Pharma County are
-- completed open-plots projects. All are the same developer's real, current
-- projects, so they're recorded here (per instructions) even though this
-- agent's primary job is selling Serenity — mainly so the agent can answer
-- "do you have other projects?" honestly instead of having no knowledge of
-- them at all.
--
-- villa_projects has no per-row `verification_note` column (unlike
-- villa_types), so unconfirmed fields are simply left NULL here, consistent
-- with 0001's rule that a NULL is itself the "unverified" signal.
-- -----------------------------------------------------------------------------
insert into villa_projects (
  slug, name, developer, status, address_line, village, state, pincode,
  rera_number, rera_status, total_land_acres, total_units, configurations,
  starting_price_inr, price_note, positioning, usps
) values
  (
    'glentree-onyx', 'Glentree Onyx', 'Glentree Homes', 'Ongoing',
    'RTC Cross Road, Zamistanpur, Hyderabad', null, 'Telangana', '500020',
    'P02500010245', 'Registered', null, null,
    array['3 BHK', '3.5 BHK', '4 BHK'],
    18300000,
    'Published starting price on site: ₹1.83–1.89 Cr. This is for apartments, not villas — Glentree Onyx is a separate project from Glentree Serenity, built by the same developer. Final price confirmed by the sales team.',
    'High-rise apartment project (not villas) at RTC Cross Road, Zamistanpur, Hyderabad — a separate project from the villa community Glentree Serenity, built by the same developer, Glentree Homes. 3, 3.5 & 4 BHK configurations, 50+ amenities across a 34,000 sq. ft. amenity zone.',
    '["Same developer as Glentree Serenity, different product type (apartments)", "50+ amenities", "34,000 sq. ft. dedicated amenity zone", "Starting price ₹1.83–1.89 Cr (published)"]'::jsonb
  ),
  (
    'halcyon-fuji', 'Halcyon Fuji', 'Glentree Homes', 'Ongoing',
    'Jubilee Hills, Hyderabad', null, 'Telangana', null,
    'P02500005860', 'Registered', null, 75,
    array['4 BHK', '5 BHK'],
    null,
    'No price published on the site. Ultra-luxury apartments, 7,504–10,121 sq. ft. built-up each, one home per floor with a private lift. Co-developed with partner RealPlus Homes (sales@realplushomes.com / +91 9121850111); Glentree Homes sales team also reachable at sales@glentreehomes.in.',
    'Ultra-luxury apartment project (not villas) at Jubilee Hills, Hyderabad, developed jointly by Glentree Homes and partner RealPlus Homes. 75 exclusive homes, 4 & 5 BHK, 7,504–10,121 sq. ft. built-up each, one home per floor with a private lift.',
    '["Joint development: Glentree Homes + RealPlus Homes", "Only 75 exclusive homes", "One home per floor with private lift", "4 & 5 BHK, 7,504–10,121 sq. ft. built-up"]'::jsonb
  ),
  (
    'glentree-silverleaf', 'Glentree Silverleaf', 'Glentree Homes', 'Completed',
    null, 'Shadnagar', 'Telangana', null,
    null, null, 7.35, null, null,
    null,
    'No price published on the site for this completed plots project.',
    'Completed open/residential plots project at Shadnagar, Telangana — 7.35 acres. Stated as HMDA/DTCP-approved in general site copy; no specific RERA or approval number shown on the pages fetched.',
    '[]'::jsonb
  ),
  (
    'glentree-greenpark', 'Glentree Green Park', 'Glentree Homes', 'Completed',
    null, 'Kalwakurthy Town', 'Telangana', null,
    null, null, 26.9, null, null,
    null,
    'No price published on the site for this completed plots project.',
    'Completed open-plots project at Kalwakurthy Town, Telangana — 26.9 acres. Stated as HMDA/DTCP-approved in general site copy; no specific RERA or approval number shown on the pages fetched.',
    '[]'::jsonb
  ),
  (
    'glentree-pharmacounty', 'Glentree Pharma County', 'Glentree Homes', 'Completed',
    null, 'Nandiwanaparthy', 'Telangana', null,
    null, null, 36, null, null,
    null,
    'No price published on the site for this completed plots project.',
    'Completed open-plots project at Nandiwanaparthy Village, Telangana — 36 acres. Site also references a "Pharma County II" phase; no details on it were captured. Stated as HMDA/DTCP-approved in general site copy; no specific RERA or approval number shown on the pages fetched.',
    '[]'::jsonb
  )
on conflict (slug) do update set
  name                = excluded.name,
  developer           = excluded.developer,
  status              = excluded.status,
  address_line        = excluded.address_line,
  village             = excluded.village,
  state               = excluded.state,
  pincode             = excluded.pincode,
  rera_number         = excluded.rera_number,
  rera_status         = excluded.rera_status,
  total_land_acres    = excluded.total_land_acres,
  total_units         = excluded.total_units,
  configurations      = excluded.configurations,
  starting_price_inr  = excluded.starting_price_inr,
  price_note          = excluded.price_note,
  positioning         = excluded.positioning,
  usps                = excluded.usps,
  updated_at          = now();


-- -----------------------------------------------------------------------------
-- Section 4: Contact info + clarifying FAQs from the live site
--
-- Plain INSERTs, same non-idempotent pattern as 0002's FAQ block (no unique
-- key exists on villa_faqs to upsert against).
-- -----------------------------------------------------------------------------
insert into villa_faqs (project_id, question, answer, tags)
select p.id, f.q, f.a, f.tags
from villa_projects p
cross join (values
  ('What is the direct contact number and email for Glentree Serenity?',
   'You can reach the Glentree Homes sales team at +91 9133 555 509 (main) or +91 96466 44644 (listed specifically for Glentree Serenity), or by email at sales@glentreehomes.in.',
   array['contact','sales']),
  ('What is the GHMC building permit number for Glentree Serenity?',
   'The live project page lists GHMC Permit 1638/GHMC/SWBP/SEC1/2025. Note: the same number also appears on the site for the Glentree Onyx project, so it may be a template/copy error on the developer''s website — please have the sales team confirm the correct permit number before quoting it as final.',
   array['legal','approvals']),
  ('Is Glentree Serenity the same as Glentree Onyx or Halcyon Fuji?',
   'No. Glentree Serenity is the villa project (premium triplex villas, 3 & 4 BHK) at Nadergul. Glentree Onyx and Halcyon Fuji are separate apartment projects by the same developer, Glentree Homes, at different locations. If you''re looking specifically for villas, Glentree Serenity is the project to consider.',
   array['project','comparison'])
) as f(q, a, tags)
where p.slug = 'glentree-serenity';

-- Company-wide FAQ — not tied to a single project.
insert into villa_faqs (project_id, question, answer, tags)
values (
  null,
  'What is Glentree Homes'' registered office address?',
  'Glentree Homes'' registered/corporate office is at H.No 8-2-293/82/A/1130 & 1130/1, Plot No. 1130, Ground Floor, Shreya Towers, Jubilee Hills, Road No. 36, Hyderabad – 500033.',
  array['company','contact']
);
