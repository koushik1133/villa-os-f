-- =============================================================================
-- Facts transcribed from the actual approved collateral in /public:
--   Serenity Layout.pdf, Glentree Homes Presentation.pdf,
--   SERENITY Brochure.pdf, SERENITY mini Brochure.pdf
--
-- These are printed/official documents, a step more authoritative than the
-- live website scrape in 0005. Every value below is transcribed verbatim —
-- nothing inferred. See OPEN-QUESTIONS.md for what these documents did NOT
-- resolve (pricing table, payment schedule, corner-unit rates, etc).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- RESOLVES the open question from 0002: which plot size is 3BHK vs 4BHK.
-- The brochure's per-type spec sheets (pages 11-16) state this explicitly,
-- and built-up-sft figures match the DB exactly, confirming correct mapping.
-- -----------------------------------------------------------------------------
update villa_types set
  bedrooms = 3,
  verification_note = null
where project_id = (select id from villa_projects where slug = 'glentree-serenity')
  and name in ('200 Sq. Yards — East Facing', '200 Sq. Yards — West Facing');

update villa_types set
  bedrooms = 4,
  verification_note = null
where project_id = (select id from villa_projects where slug = 'glentree-serenity')
  and name in ('267 Sq. Yards — East Facing', '267 Sq. Yards — West Facing');

update villa_types set
  bedrooms = 4,
  verification_note = 'Brochure lists this as "4 BHK + Maid Room" — one extra room beyond the standard 4 BHK layout.'
where project_id = (select id from villa_projects where slug = 'glentree-serenity')
  and name in ('300 Sq. Yards — East Facing', '300 Sq. Yards — West Facing');


-- -----------------------------------------------------------------------------
-- Connectivity — the brochure gives real drive-time minutes to ~25 named
-- places, far richer than the live-site km-only estimates in 0005. Minutes
-- are the developer's own published figures (still caveat travel varies).
-- -----------------------------------------------------------------------------
update villa_projects set
  connectivity = '[
    {"place": "Adibatla IT Hub", "minutes": "12"},
    {"place": "TCS Adibatla", "minutes": "12"},
    {"place": "TSIIC Aerospace SEZ", "minutes": "5"},
    {"place": "Karmanghat", "minutes": "24"},
    {"place": "Rajiv Gandhi International Airport", "minutes": "24"},
    {"place": "LB Nagar", "minutes": "28"},
    {"place": "DPS Nadergul", "minutes": "5"},
    {"place": "MVSR Engineering College", "minutes": "5"},
    {"place": "Spoorthy Engineering College", "minutes": "10"},
    {"place": "Narayana Institutions", "minutes": "15"},
    {"place": "Sri Chaitanya Institutions", "minutes": "15"},
    {"place": "Velocity International School", "minutes": "27"},
    {"place": "Sri Sri Academy", "minutes": "27"},
    {"place": "Aga Khan Academy", "minutes": "30"},
    {"place": "GMR School of Business", "minutes": "30"},
    {"place": "Foxconn (KK Park)", "minutes": "20"},
    {"place": "Fab City", "minutes": "23"},
    {"place": "DRDO", "minutes": "24"},
    {"place": "Future City", "minutes": "45"},
    {"place": "Apollo Clinics (Diagnostics)", "minutes": "10"},
    {"place": "Government Hospital", "minutes": "18"},
    {"place": "Owaisi Hospital", "minutes": "24"},
    {"place": "Kamineni Hospital", "minutes": "29"},
    {"place": "Rainbow Children''s Hospital", "minutes": "29"},
    {"place": "Yashoda Hospital", "minutes": "39"},
    {"place": "Wonderla", "minutes": "16"},
    {"place": "Ramoji Film City", "minutes": "30"},
    {"place": "Statue of Equality", "minutes": "38"},
    {"place": "Nehru Zoological Park", "minutes": "42"}
  ]'::jsonb
where slug = 'glentree-serenity';

-- -----------------------------------------------------------------------------
-- Confirmed contact number (brochure footer, printed) — the same number the
-- live site showed, now doubly confirmed. Legal entity name is new: the
-- registered developer is "Glentree Villas LLP", distinct from the
-- "Glentree Homes" brand name already stored in `developer`.
-- -----------------------------------------------------------------------------
update villa_projects set
  amenities = amenities || jsonb_build_object(
    'confirmed_from_brochure', jsonb_build_object(
      'legal_entity', 'Glentree Villas LLP',
      'corporate_office', 'H.No 8-2-293/82/A/1130 & 1130/1, Plot No. 1130, Ground Floor, Shreya Towers, Jubilee Hills, Road No. 36, Hyderabad – 500033',
      'confirmed_phone', '96466 44644',
      'confirmed_email', 'sales@glentreehomes.in',
      'cycling_track', true,
      'clubhouse_1_club_serene_sft', '29,479',
      'clubhouse_2_veranda_pavilion_sft', '12,866',
      'green_space_sft', '83,000+',
      'amenity_count', '85+',
      -- Brochure literally titles the two clubhouses "Club Serene" and
      -- "Veranda Pavilion" — more specific than the generic "Clubhouse 1/2"
      -- names already in the seeded amenities block.
      'note', 'Villa numbering in the unit-area-statement table runs 1-185, one more than the marketed "184 villas" — not reconciled, do not state either count with confidence beyond what the brochure headline says (184).'
    )
  )
where slug = 'glentree-serenity';

-- -----------------------------------------------------------------------------
-- FAQ: corner/premium units are priced differently — flag this so the agent
-- never quotes a standard price for a customer asking about a corner unit.
-- -----------------------------------------------------------------------------
insert into villa_faqs (project_id, question, answer, tags)
select id,
  'What about corner villas or non-standard facing units?',
  'Some villas — particularly corner units with North-East, North-West, South-East or South-West facing — have extra chargeable plot area beyond the standard 200/267/300 sq. yard sizes, and a different saleable area. I don''t have a confirmed rate for this extra chargeable area, so I''ll have the sales team confirm pricing for corner or non-standard-facing units specifically.',
  array['pricing', 'corner unit', 'facing']
from villa_projects where slug = 'glentree-serenity';
