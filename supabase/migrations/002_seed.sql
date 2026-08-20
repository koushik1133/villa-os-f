-- =============================================================================
-- VillaOS — Glentree Serenity knowledge base.
--
-- Run AFTER 001_schema.sql. Safely re-runnable (every insert upserts or guards).
--
-- SOURCES. Every value here is transcribed from approved collateral:
--   - the customer sales presentation (Glentree Homes Presentation.pdf)
--   - the full and mini brochures (SERENITY Brochure.pdf, SERENITY mini Brochure.pdf)
--   - the site layout (Serenity Layout.pdf)
--   - the live site glentreehomes.in
-- Nothing is inferred. Where the sources are silent the column stays NULL and
-- carries a verification_note — the AI agent treats NULL as "not approved to
-- state" and defers to a human rather than guessing. That unverified state is
-- a deliberate feature of this system, not missing data.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Tenant. "Glentree Villas LLP" is the registered entity printed in the
-- brochure footer; "Glentree Homes" is the trading brand on the website.
-- -----------------------------------------------------------------------------
insert into villa_tenant (org_name, legal_entity, currency, timezone, primary_phone, primary_email, address, website)
select 'Glentree Homes', 'Glentree Villas LLP', 'INR', 'Asia/Kolkata',
       '+91 96466 44644', 'sales@glentreehomes.in',
       'H.No 8-2-293/82/A/1130 & 1130/1, Plot No. 1130, Ground Floor, Shreya Towers, Jubilee Hills, Road No. 36, Hyderabad – 500033',
       'https://glentreehomes.in'
where not exists (select 1 from villa_tenant);


-- -----------------------------------------------------------------------------
-- Project
--
-- Columns left NULL on purpose, because no approved source states them:
--   phase, launch_date          — no phasing or launch date published
--   latitude, longitude         — the brochure gives a QR map link, not coords
--   max_price_inr               — only a starting price is published
--   cover_image, gallery        — the /public JPGs are registered as assets
--                                 below; wiring one as the project cover is a
--                                 marketing choice, not a fact, so it is left
--                                 for the team to set in the admin UI. The
--                                 project pages fall back to a gradient.
-- -----------------------------------------------------------------------------
insert into villa_projects (
  slug, name, developer, status, expected_delivery,
  address_line, survey_no, village, mandal, district, state, pincode,
  hmda_permit_no, hmda_permit_date, rera_number, rera_status,
  total_land_acres, total_units, configurations,
  starting_price_inr, price_per_sft_inr, pricing, price_note, positioning,
  usps, amenities, specifications, sustainability, connectivity,
  social_infrastructure, financing_partners
) values (
  'glentree-serenity', 'Glentree Serenity', 'Glentree Villas LLP',
  'Under Construction',
  -- Two official documents say June 2029; the website has shown October 2029.
  -- The documents win, and the conflict is disclosed to the customer by the
  -- "I have seen a different possession date" FAQ further down rather than
  -- being quietly resolved here.
  'June 2029 (T&C Apply)',
  'Sy. No. 578, Nadergul Village, Balapur Mandal, Ranga Reddy, Hyderabad',
  'Survey No. 578', 'Nadergul', 'Balapur', 'Rangareddy', 'Telangana', '501510',
  '012013/LO/HMDA/3194/SMD/2024', '09-Oct-2025', 'P02400010707', 'Registered',
  -- Marketed as 184. The mini-brochure's unit table actually numbers to 185;
  -- unreconciled, so the marketed figure is what the agent quotes.
  18, 184,
  array['3 BHK + Home Theatre', '4 BHK + Home Theatre'],
  -- Lowest base = smallest villa at the current rate: 2836 sft × ₹7,700.
  -- This is BASE ONLY. Amenities, corpus, maintenance, legal and GST are extra,
  -- and any facing/corner premium is on top of that.
  21837200,
  7700,

  '{
    "rate_per_sft_inr": 7700,
    "rate_basis": "saleable / built-up area",
    "offer": {
      "name": "Pre-launch rate",
      "rate_per_sft_inr": 7700,
      "limit": "First 20 customers only",
      "conditions": "Limited pre-launch opportunity, subject to villa availability."
    },
    "payment_schedule_note": "Stage 2 on the price sheet reads 20 percent including the initial amount, so it is CUMULATIVE with the 5 percent booking advance rather than additional to it. Read incrementally the printed figures total 105 percent; treating stage 2 as cumulative gives 100 percent. The percent field below is the incremental amount actually due at each stage; percent_on_sheet is the figure as printed.",
    "payment_schedule": [
      {"stage": 1, "milestone": "Booking advance", "percent": 5, "percent_on_sheet": 5},
      {"stage": 2, "milestone": "At Agreement, or 30 days from booking, whichever is earlier", "percent": 15, "percent_on_sheet": 20, "note": "Sheet shows 20% including the 5% booking advance, so 15% is the further amount due."},
      {"stage": 3, "milestone": "On completion of footings", "percent": 20, "percent_on_sheet": 20},
      {"stage": 4, "milestone": "On completion of 1st floor slab", "percent": 15, "percent_on_sheet": 15},
      {"stage": 5, "milestone": "On completion of 2nd floor slab", "percent": 15, "percent_on_sheet": 15},
      {"stage": 6, "milestone": "On completion of brickwork and plastering", "percent": 15, "percent_on_sheet": 15},
      {"stage": 7, "milestone": "On completion of flooring", "percent": 10, "percent_on_sheet": 10},
      {"stage": 8, "milestone": "Handing over", "percent": 5, "percent_on_sheet": 5}
    ],
    "premium_charges": [
      {"name": "Amenities charges",           "amount_inr": 300,    "unit": "per sft"},
      {"name": "Charges for extra land",      "amount_inr": 60000,  "unit": "per sq yd"},
      {"name": "East facing",                 "amount_inr": 750000, "unit": "one-time"},
      {"name": "Corner plot",                 "amount_inr": 750000, "unit": "one-time"},
      {"name": "North-east corner",           "amount_inr": 1500000,"unit": "one-time"},
      {"name": "Park / clubhouse facing",     "amount_inr": 500000, "unit": "one-time"},
      {"name": "Corpus fund",                 "amount_inr": 500000, "unit": "one-time"},
      {"name": "Maintenance",                 "amount_inr": 350,    "unit": "per sft, covers 2 years"},
      {"name": "Legal and documentation",     "amount_inr": 25000,  "unit": "one-time"},
      {"name": "GST",                         "percent": 5,         "unit": "on applicable value"}
    ],
    "excluded_from_base": [
      "GST at 5%",
      "Registration and stamp duty (as per government rates at the time of registration)",
      "Amenities charges",
      "Corpus fund",
      "Maintenance",
      "Legal and documentation charges",
      "Facing, corner and park-facing premiums where applicable"
    ],
    "disclaimer": "Prices are subject to change without prior notice. T&C apply. The villa-wise total is confirmed on the official cost sheet before booking."
  }'::jsonb,

  'Current pre-launch rate is ₹7,700 per sft on saleable area, for the first 20 customers only. The base villa price is rate × area; amenities (₹300/sft), corpus (₹5 L), maintenance (₹3.50/sft for 2 years), legal (₹25,000) and GST at 5% are additional, as are facing, corner and park-facing premiums where they apply. Registration and stamp duty are at government rates. The exact villa-wise total comes from the official cost sheet. Prices are subject to change without notice.',
  'A premium gated triplex villa community at Nadergul, South Hyderabad — 184 villas across 18 acres, Vastu-compliant, with two clubhouses, five themed parks and direct access to the ORR, Adibatla IT hub and the international airport.',

  '[
    "One of the first premium gated villa communities in this region",
    "18-acre low-density development with only 184 triplex villas",
    "Two clubhouses totalling 42,345+ SFT — Club Serene and Veranda Pavilion",
    "Five themed parks across approximately 5 acres",
    "83,000+ Sq. Ft. of green space",
    "85+ curated amenities for all age groups",
    "Dedicated cycling track",
    "Wide HMDA access roads: 150 ft, 120 ft and 60 ft",
    "Fully underground utility network — no overhead cabling",
    "Dedicated parking for every villa",
    "100% DG power backup",
    "Hydro-pneumatic water supply",
    "CCTV surveillance across common areas",
    "Fiber-to-home connectivity",
    "Internal home lift provision",
    "VRV air conditioning provision",
    "EV charging enabled community",
    "Smart IoT water metering",
    "Targeting IGBC Gold certification",
    "Positioned near the starting zone of the Future City corridor"
  ]'::jsonb,

  '{
    "clubhouse": {
      "total_area_sft": "42,345+",
      "count": 2,
      "club_serene_sft": "29,479",
      "club_serene": ["Triple-height entrance lobby", "Guest lounge", "Banquet hall", "Cafe (provision)", "Covered terrace", "Gymnasium", "Yoga and aerobics studio", "Salon and spa", "Swimming pool", "Poolside deck", "Barbeque terrace", "Indoor kids play area", "Gaming zone", "Library", "Creche", "Co-working area", "Guest house suites (3)"],
      "veranda_pavilion_sft": "12,866",
      "veranda_pavilion": ["Double-height entrance lobby", "Gym / multipurpose hall", "Badminton courts (2)", "Squash court", "Indoor games area", "Board games zone"]
    },
    "sports_and_fitness": ["Gymnasium", "Swimming pool", "Tennis court", "Squash court", "Volleyball court", "Cricket pitch", "Half basketball court", "Pickleball", "Outdoor fitness area", "Yoga deck", "Aerobics studio", "Skating track", "Cycling track"],
    "family_and_recreation": ["Amphitheatre", "Celebration lawn", "Party lawn", "Gaming zone", "Library", "Creche", "Co-working space", "Guest rooms", "Salon and spa", "Banquet hall", "Cloud kitchen"],
    "kids_and_seniors": ["Kids play area", "Toddler zone", "Senior citizen plaza", "Swing lawns", "Seating zones", "Pet park"],
    "themed_parks": {
      "total_acres": 5,
      "green_space_sft": "83,000+",
      "parks": [
        {"name": "Sahavas", "theme": "The Social Park", "features": ["Community interaction spaces", "Celebration lawns", "Seating plazas"]},
        {"name": "Veer Garden", "theme": "The Sports Park", "features": ["Outdoor fitness zones", "Sports and activity areas", "Walking and jogging pathways"]},
        {"name": "Aranya", "theme": "The Forest Park", "features": ["Dense tree plantation", "Natural green buffers", "Forest-themed landscaping"]},
        {"name": "Ekaanth", "theme": "The Serene Garden", "features": ["Meditation lawns", "Yoga spaces", "Quiet seating areas"]},
        {"name": "Ananda Vana", "theme": "The Wellness Garden", "features": ["Wellness landscaping", "Walking trails", "Senior citizen friendly spaces"]}
      ]
    },
    "green_and_open_spaces": ["Walking pathways", "Dense plantation areas", "Meditation lawn", "Celebration lawns", "Yoga spaces", "Water features", "Pergolas", "Seating plazas"]
  }'::jsonb,

  '{
    "structure": ["RCC framed structure", "Designed to withstand wind and seismic loads"],
    "walls": ["8-inch external solid block walls", "4-inch internal solid block walls", "Double coat cement plaster, smooth finish"],
    "doors_and_windows": ["Teak wood main door frame with veneer shutter, melamine polish, premium hardware", "Biometric lock on main door", "Hardwood internal door frames with designer shutters", "UPVC French doors with toughened glass", "UPVC windows with mosquito mesh provision"],
    "flooring": ["800x800mm double-charged vitrified tiles in living, dining, kitchen and bedrooms", "Wooden finish flooring in home theatre", "600x1200mm glazed vitrified wall tiles and anti-skid flooring in toilets", "Granite staircase", "Anti-skid vitrified tiles in sit-out and balconies", "Paver tiles or natural stone in parking and setbacks"],
    "kitchen": ["Granite platform with stainless steel sink", "Electrical points for refrigerator, microwave, mixer, chimney and water purifier", "Municipal, softener and domestic water provision"],
    "bathrooms": ["Wall-hung EWC (Jaquar/Grohe or equivalent) with concealed flush", "Wash basin (Grohe/Jaquar or equivalent)", "Single-lever hot and cold diverter with shower", "Geyser provision in all bathrooms"],
    "electrical": ["3-phase supply per villa", "Concealed copper wiring (Finolex/Polycab/Havells or equivalent)", "Designer modular switches (Legrand/Havells or equivalent)", "Air conditioning provision in all rooms"],
    "paint": ["Two coats acrylic emulsion over putty internally", "Texture and weatherproof exterior emulsion"],
    "underground_infrastructure": ["Underground electrical cabling", "Underground drainage network", "Underground sewage lines", "Underground water distribution", "Underground fiber internet", "Dedicated storm water drainage", "Concealed service corridors"],
    "smart_and_future_ready": ["Internal home lift provision (hydraulic lift shaft provided)", "VRV air conditioning provision", "Fiber-to-home connectivity", "Intercom facility connecting security", "DTH provision", "IoT-based water metering", "EV charging ready infrastructure"],
    "security": ["Gated community with compound wall", "Round-the-clock security", "CCTV surveillance in common areas", "Controlled access"],
    "utilities": ["100% power backup through acoustic DG sets (excluding ACs and geysers)", "Treated water supply", "Hydro-pneumatic water system"],
    "access_roads": ["150 ft HMDA road", "120 ft HMDA road", "60 ft HMDA road"]
  }'::jsonb,

  '{
    "target_certification": "IGBC Gold Rating (Proposed — not yet awarded)",
    "features": ["Water Treatment Plant (WTP)", "Sewage Treatment Plant (STP) with treated water reused for landscaping", "Rainwater harvesting as per norms", "Water recycling systems", "Efficient plumbing fixtures", "Smart IoT water meters", "Solar power", "EV charging enabled parking", "Enhanced natural ventilation", "Daylight optimization"]
  }'::jsonb,

  -- Drive times as published in the brochure. The agent must always add that
  -- actual travel time varies with traffic.
  '[
    {"place": "TSIIC Aerospace SEZ", "minutes": "5"},
    {"place": "DPS Nadergul", "minutes": "5"},
    {"place": "MVSR Engineering College", "minutes": "5"},
    {"place": "Spoorthy Engineering College", "minutes": "10"},
    {"place": "Apollo Clinics (Diagnostics)", "minutes": "10"},
    {"place": "Adibatla IT Hub", "minutes": "12"},
    {"place": "TCS Adibatla", "minutes": "12"},
    {"place": "Narayana Institutions", "minutes": "15"},
    {"place": "Sri Chaitanya Institutions", "minutes": "15"},
    {"place": "Wonderla", "minutes": "16"},
    {"place": "Government Hospital", "minutes": "18"},
    {"place": "Foxconn (KK Park)", "minutes": "20"},
    {"place": "Fab City", "minutes": "23"},
    {"place": "Rajiv Gandhi International Airport", "minutes": "24"},
    {"place": "Karmanghat", "minutes": "24"},
    {"place": "DRDO", "minutes": "24"},
    {"place": "Owaisi Hospital", "minutes": "24"},
    {"place": "Velocity International School", "minutes": "27"},
    {"place": "Sri Sri Academy", "minutes": "27"},
    {"place": "LB Nagar", "minutes": "28"},
    {"place": "Kamineni Hospital", "minutes": "29"},
    {"place": "Rainbow Children''s Hospital", "minutes": "29"},
    {"place": "Aga Khan Academy", "minutes": "30"},
    {"place": "GMR School of Business", "minutes": "30"},
    {"place": "Ramoji Film City", "minutes": "30"},
    {"place": "Statue of Equality", "minutes": "38"},
    {"place": "Yashoda Hospital", "minutes": "39"},
    {"place": "Nehru Zoological Park", "minutes": "42"},
    {"place": "Future City", "minutes": "45"}
  ]'::jsonb,

  '{
    "schools": ["Delhi Public School Nadergul", "MVSR Engineering College", "Narayana Institutions", "Sri Chaitanya Institutions", "Sri Sri Academy", "Aga Khan Academy", "Velocity International School", "GMR School of Business"],
    "hospitals": ["Apollo Clinics", "Kamineni Hospital", "Yashoda Hospital", "Rainbow Children''s Hospital", "Owaisi Hospital"],
    "growth_drivers": ["Future City development", "Adibatla IT expansion", "Aerospace and SEZ growth", "Airport corridor development", "ORR connectivity", "Proposed Bullet Train Hub", "Greenfield Road"]
  }'::jsonb,

  array['HDFC Bank','ICICI Bank','State Bank of India (SBI)','Bajaj Housing Finance','Axis Bank','LIC Housing Finance','IDFC First Bank','PNB Housing Finance']
)
on conflict (slug) do update set
  name = excluded.name, developer = excluded.developer, status = excluded.status,
  expected_delivery = excluded.expected_delivery, rera_number = excluded.rera_number,
  rera_status = excluded.rera_status, starting_price_inr = excluded.starting_price_inr,
  price_note = excluded.price_note, positioning = excluded.positioning,
  usps = excluded.usps, amenities = excluded.amenities,
  specifications = excluded.specifications, sustainability = excluded.sustainability,
  connectivity = excluded.connectivity, social_infrastructure = excluded.social_infrastructure,
  financing_partners = excluded.financing_partners, updated_at = now();


-- -----------------------------------------------------------------------------
-- Villa types.
--
-- The brochure's per-type spec sheets resolve the plot-size → bedroom mapping
-- that the presentation alone left ambiguous: 200 sq yd = 3 BHK,
-- 267 sq yd = 4 BHK, 300 sq yd = 4 BHK + maid room. Built-up areas match the
-- presentation exactly, which corroborates the mapping.
--
-- price_inr is now the BASE price only: built_up_sft × ₹7,700 pre-launch rate,
-- computed rather than hardcoded so it stays consistent if the rate changes.
-- It excludes amenities, corpus, maintenance, legal, GST, registration and any
-- facing/corner premium. The verification_note says so on every row, because a
-- buyer told "₹2.18 Cr" who then sees a ₹2.6 Cr cost sheet is a complaint.
--
-- NULL by design: carpet_area_sft and bathrooms (the brochure gives only gross
-- built-up per floor and never a bathroom count) and floor_plan_url (per-type
-- plans live inside the brochure PDF, not as separate files).
-- -----------------------------------------------------------------------------
insert into villa_types (project_id, name, plot_area_sqyd, built_up_sft, facing, bedrooms, floors, has_home_theatre, has_maid_room, price_inr, verification_note)
select p.id, v.name, v.plot, v.sft, v.facing, v.beds, 3, true, v.maid,
  (v.sft * p.price_per_sft_inr)::bigint,
  'Base price only, at the ₹7,700/sft pre-launch rate (first 20 customers). Excludes amenities ₹300/sft, corpus ₹5 L, maintenance ₹3.50/sft for 2 years, legal ₹25,000, GST 5%, registration and stamp duty, and any east-facing, corner, north-east-corner or park-facing premium. The official cost sheet gives the villa-wise total.'
from villa_projects p
cross join (values
  ('200 Sq. Yards — East Facing', 200, 2876, 'East', 3, false),
  ('200 Sq. Yards — West Facing', 200, 2836, 'West', 3, false),
  ('267 Sq. Yards — East Facing', 267, 3715, 'East', 4, false),
  ('267 Sq. Yards — West Facing', 267, 3685, 'West', 4, false),
  ('300 Sq. Yards — East Facing', 300, 4286, 'East', 4, true),
  ('300 Sq. Yards — West Facing', 300, 4276, 'West', 4, true)
) as v(name, plot, sft, facing, beds, maid)
where p.slug = 'glentree-serenity'
on conflict (project_id, name) do update set
  built_up_sft = excluded.built_up_sft, bedrooms = excluded.bedrooms,
  has_maid_room = excluded.has_maid_room, price_inr = excluded.price_inr,
  verification_note = excluded.verification_note;


-- -----------------------------------------------------------------------------
-- Assets — the real files in /public.
--
-- The six JPGs show a finished, landscaped community for a project completing
-- in 2029, so they are renderings. is_ai_generated = true makes the agent
-- disclose that if a customer asks whether it is a photograph.
-- `url` is UNIQUE, so `do nothing` makes this idempotent.
-- -----------------------------------------------------------------------------
insert into villa_assets (project_id, kind, title, description, url, mime_type, is_ai_generated, shareable_by_ai)
select p.id, a.kind::villa_asset_kind, a.title, a.descr, a.url, a.mime, a.ai, a.shareable
from villa_projects p
cross join (values
  ('brochure','Glentree Serenity — Full Brochure','Community overview, five themed parks, both clubhouses, all six villa-type spec sheets, full specifications.','/SERENITY%20%20Brochure.pdf','application/pdf',false,true),
  ('brochure','Glentree Serenity — Mini Brochure','Condensed brochure plus the full unit-by-unit area statement (plot area, chargeable area, saleable area, facing).','/SERENITY%20mini%20Brochure.pdf','application/pdf',false,true),
  ('master_plan','Glentree Serenity — Site Layout','Master site plan: plot grid, internal roads, clubhouse location, HMDA and RERA permit numbers.','/Serenity%20Layout.pdf','application/pdf',false,true),
  -- shareable_by_ai = false: this is the internal sales script, not customer
  -- collateral. It stays in the library for the team but the agent must never
  -- send it. This is exactly the admin control the client asked for.
  ('other','Glentree Homes — Sales Presentation','Internal sales presentation. Reference material, not customer-facing collateral.','/Glentree%20Homes%20Presentation.pdf','application/pdf',false,false),
  ('image','Aerial masterplan rendering','Conceptual aerial rendering of the completed community. Not a photograph — the project is under construction.','/Glentree%20Serenity.jpg','image/jpeg',true,true),
  ('image','Villa rendering 2','Conceptual rendering, not a photograph.','/Glentree%20Serenity%20(2).jpg','image/jpeg',true,true),
  ('image','Villa rendering 3','Conceptual rendering, not a photograph.','/Glentree%20Serenity%20(3).jpg','image/jpeg',true,true),
  ('image','Villa rendering 4','Conceptual rendering, not a photograph.','/Glentree%20Serenity%20(4).jpg','image/jpeg',true,true),
  ('image','Villa rendering 5','Conceptual rendering, not a photograph.','/Glentree%20Serenity%20(5).jpg','image/jpeg',true,true),
  ('image','Villa rendering 6','Conceptual rendering, not a photograph.','/Glentree%20Serenity%20(6).jpg','image/jpeg',true,true)
) as a(kind, title, descr, url, mime, ai, shareable)
where p.slug = 'glentree-serenity'
on conflict (url) do nothing;


-- -----------------------------------------------------------------------------
-- FAQs. villa_faqs has no unique constraint, so each is guarded on question.
-- -----------------------------------------------------------------------------
insert into villa_faqs (project_id, question, answer, tags)
select p.id, f.q, f.a, f.tags
from villa_projects p
cross join (values
  -- ---- Pricing -------------------------------------------------------------
  ('What is the price?',
   'The current pre-launch rate is ₹7,700 per sft on saleable area, and it applies to the first 20 customers only. The base villa price is that rate multiplied by the villa''s area. On top of the base there are amenities charges of ₹300 per sft, a ₹5 lakh corpus fund, maintenance at ₹3.50 per sft covering two years, ₹25,000 legal and documentation, and GST at 5%. Registration and stamp duty are at government rates. If your villa is east-facing, a corner, a north-east corner or park/clubhouse facing, a premium applies as well. The sales team issues an official cost sheet with the exact villa-wise total. Prices are subject to change without notice.',
   array['price','rate','pre-launch']),
  ('What does a 3 BHK cost?',
   'The 3 BHK is the 200 sq. yard villa, 2,836–2,876 sft depending on facing. At the ₹7,700 per sft pre-launch rate that is roughly ₹2.18–2.21 Cr as a base price. Amenities, corpus, maintenance, legal, GST, registration and any facing or corner premium are additional. The sales team confirms the exact total on the cost sheet.',
   array['price','3 bhk','200 sqyd']),
  ('What does a 4 BHK cost?',
   'There are two 4 BHK options. The 267 sq. yard villa is 3,685–3,715 sft, roughly ₹2.84–2.86 Cr base at ₹7,700 per sft. The 300 sq. yard villa, which adds a maid room, is 4,276–4,286 sft, roughly ₹3.29–3.30 Cr base. Both figures are base price only — amenities, corpus, maintenance, legal, GST, registration and any facing or corner premium are additional, and the cost sheet gives the exact total.',
   array['price','4 bhk','267 sqyd','300 sqyd']),
  ('What is the payment schedule?',
   'It is construction-linked, in eight stages. 5% is the booking advance. At agreement — or 30 days from booking, whichever is earlier — you reach 20% in total, which includes that initial 5%. After that: 20% on completion of footings, 15% on the 1st floor slab, 15% on the 2nd floor slab, 15% on brickwork and plastering, 10% on flooring, and the final 5% at handing over.',
   array['payment','schedule','booking']),
  ('What is the booking amount?',
   'The booking advance is 5% of the villa price. A further 20% is due at agreement, or 30 days from booking, whichever comes earlier — and that 20% includes the initial amount.',
   array['booking','payment']),
  ('What are the extra charges on top of the villa price?',
   'Amenities charges ₹300 per sft; corpus fund ₹5 lakh; maintenance ₹3.50 per sft covering two years; legal and documentation ₹25,000; and GST at 5%. Registration and stamp duty are separate, at government rates. Location premiums where applicable: east facing ₹7.5 lakh, corner plot ₹7.5 lakh, north-east corner ₹15 lakh, park or clubhouse facing ₹5 lakh. Extra land beyond the standard plot is ₹60,000 per sq. yard.',
   array['charges','premium','gst']),
  ('What about corner villas or premium locations?',
   'Premiums apply by position: east facing ₹7.5 lakh, corner plot ₹7.5 lakh, north-east corner ₹15 lakh, and park or clubhouse facing ₹5 lakh. Where a villa has land beyond the standard plot size, that extra area is charged at ₹60,000 per sq. yard. The cost sheet for the specific villa shows exactly which of these apply.',
   array['pricing','corner unit','facing','premium']),
  ('Is there any offer running?',
   'Yes — the ₹7,700 per sft rate is a pre-launch price limited to the first 20 customers, and it is subject to villa availability.',
   array['offer','promotion','pre-launch']),
  ('What are the monthly maintenance charges?',
   'Maintenance is charged at ₹3.50 per sft and covers the first two years. The ongoing arrangement after that period will be confirmed based on the final maintenance plan and community facilities, and shared before handover.',
   array['maintenance','charges']),

  -- ---- Configuration -------------------------------------------------------
  ('What villa sizes and configurations are available?',
   'Three plot sizes, each available east or west facing. 200 sq. yards is a 3 BHK at 2,836–2,876 sft. 267 sq. yards is a 4 BHK at 3,685–3,715 sft. 300 sq. yards is a 4 BHK with a maid room at 4,276–4,286 sft. All are triplex villas with a home theatre.',
   array['sizes','configuration','bhk']),
  ('What is the difference between east-facing and west-facing villas?',
   'East-facing villas are traditionally preferred by many buyers — the main entrance gets morning sunlight and it is often considered favourable from a Vastu perspective, and an east-facing premium of ₹7.5 lakh applies. West-facing villas can offer equally good planning, ventilation and natural light depending on the layout. The real advantage comes down to the individual villa''s design, road position, landscaping and surrounding open space.',
   array['facing','vastu','east','west']),
  ('How many villas are there?',
   'Glentree Serenity is marketed as a community of 184 premium triplex villas across 18 acres. The final villa numbering and approved area statement are as per the sanctioned project documentation.',
   array['project','scale']),

  -- ---- Legal and approvals -------------------------------------------------
  ('Is the project RERA approved?',
   'Yes. The RERA registration has already been received. Glentree Serenity is registered under Telangana RERA number P02400010707, and you can verify it at rera.telangana.gov.in.',
   array['legal','approvals','rera']),
  ('What is the HMDA permit number?',
   'The permit number is 012013/LO/HMDA/3194/SMD/2024.',
   array['legal','approvals','hmda']),
  ('Is the land title clear and free from disputes?',
   'The project land title and related legal documentation are subject to legal due diligence, and the relevant title and approval documents can be shared with you as part of that process. I''d encourage you to have them reviewed independently — the sales team can provide the full set.',
   array['legal','title','due diligence']),
  ('Are there any litigation cases on the project?',
   'The project is being developed on the basis of the applicable approvals and documentation, and the relevant legal and title documents are available for you to review as part of due diligence. For anything specific on this, the sales team is the right point of contact.',
   array['legal','litigation']),
  ('Are there penalties for delayed handover?',
   'Provisions relating to delayed handover are governed by the terms of the Agreement for Sale and the applicable RERA regulations. The specific clauses will be in the agreement you review before booking.',
   array['legal','possession','delay']),
  ('Can I resell the villa later?',
   'Resale is subject to the terms of the Agreement for Sale, applicable laws, RERA regulations and the required documentation and clearances.',
   array['resale','legal']),
  ('What is the cancellation or refund policy?',
   'Cancellation and refund terms are governed by the booking terms, the Agreement for Sale and applicable RERA regulations. The exact deductions and process are communicated before booking — I''ll have the sales team share the specifics with you.',
   array['cancellation','refund']),

  -- ---- Timeline and site ---------------------------------------------------
  ('When is possession?',
   'The expected possession timeline is June 2029, subject to the terms and conditions of the Agreement for Sale and applicable regulatory provisions.',
   array['possession','timeline']),
  ('When will the model villa be ready?',
   'The model villa is currently under construction and is expected to be ready for customer viewing within about a month.',
   array['model villa','site visit']),
  ('Can I visit the site now?',
   'Yes — site visits are available now, and you can see the location, the development and construction in progress. The model villa and community areas open for viewing as they are completed; the model villa is expected within about a month.',
   array['site visit','model villa']),
  ('When do registrations start?',
   'Villa registrations commence once all applicable statutory and documentation requirements are complete.',
   array['registration','timeline']),
  ('Who manages the community after handover?',
   'The community will be managed through the project''s maintenance and association structure. The detailed arrangement is communicated before handover.',
   array['maintenance','community','handover']),
  ('Are there extra charges for the clubhouse, gym or sports facilities?',
   'Use of the common amenities is governed by the project''s final terms and community policies. Any additional charges that apply will be communicated clearly — nothing is hidden at handover.',
   array['amenities','clubhouse','charges']),
  ('Is there app-based visitor management?',
   'Visitor management and security systems are planned as part of the community management setup. The final app-based features will be confirmed based on the technology implemented at the project.',
   array['security','technology','amenities']),

  -- ---- Financing -----------------------------------------------------------
  ('Is home loan support available?',
   'Yes. The project has home-loan support from major banks and financial institutions including ICICI Bank, HDFC Bank, State Bank of India and Bajaj Housing Finance, among others. Loan eligibility, documentation and approval always rest with the bank. The finance team will guide you to the most suitable option for your situation.',
   array['financing','home loan','apf']),

  -- ---- Location and amenities ----------------------------------------------
  ('How far is the airport?',
   'Rajiv Gandhi International Airport is about a 24-minute drive. Actual travel time varies with traffic.',
   array['location','connectivity']),
  ('What are the clubhouses like?',
   'There are two, totalling 42,345+ sft. Club Serene at 29,479 sft covers leisure and wellness — swimming pool, gymnasium, salon and spa, banquet hall, library, creche, co-working area and three guest suites. Veranda Pavilion at 12,866 sft covers sport — badminton courts, a squash court, indoor games and a multipurpose hall.',
   array['amenities','clubhouse']),
  ('Is it a green building?',
   'The project targets IGBC Gold certification. That is a stated target rather than an awarded rating. Sustainability features include a water treatment plant, a sewage treatment plant with water reused for landscaping, rainwater harvesting, smart IoT water meters, solar power and EV-charging-enabled parking.',
   array['sustainability','igbc']),

  -- ---- Disclosure ----------------------------------------------------------
  ('Are the images real photographs?',
   'No. The images in the brochure, presentation and marketing material represent the proposed and conceptual development — they are renderings, not photographs of a completed project. Genuine site-progress photographs are shared separately, and you are welcome to visit the site to see the actual construction.',
   array['images','disclosure']),
  ('I have seen a different possession date — which is correct?',
   'The project documents state June 2029, subject to terms and conditions, and that is what we quote. Because possession is a commitment, the sales team confirms the current committed date in writing in the Agreement for Sale before you book.',
   array['possession','timeline','discrepancy']),

  -- ---- Company -------------------------------------------------------------
  ('Who is the developer?',
   'The project is developed by Glentree Villas LLP, trading as Glentree Homes, based in Jubilee Hills, Hyderabad.',
   array['developer','company']),
  ('How do I contact the sales team?',
   'I can arrange for the sales team to call you back — just let me know a convenient time. They can also walk you through the cost sheet, the master layout and a site visit.',
   array['contact','sales']),
  ('Do you have other projects?',
   'Yes. Alongside Glentree Serenity, which is the villa project at Nadergul, Glentree Homes has Glentree Onyx and Halcyon Fuji — both apartment projects rather than villas — and has completed the Silverleaf, Green Park and Pharma County plot developments. I can have the sales team share details on any of those.',
   array['projects','portfolio']),
  ('Is Glentree Serenity the same as Glentree Onyx?',
   'No, they are different projects. Glentree Serenity is the premium triplex villa community at Nadergul. Glentree Onyx is a separate high-rise apartment project at RTC X Roads. If you are looking at villas, Serenity is the one.',
   array['projects','disambiguation'])
) as f(q, a, tags)
where p.slug = 'glentree-serenity'
  and not exists (select 1 from villa_faqs x where x.question = f.q);


-- -----------------------------------------------------------------------------
-- Channels and integrations. Everything starts disconnected — the admin
-- control panel is what turns a channel on, and nothing claims to be
-- connected until its credentials actually exist.
-- -----------------------------------------------------------------------------
insert into villa_channel_settings (channel, label) values
  ('whatsapp',        'WhatsApp'),
  ('instagram',       'Instagram'),
  ('youtube',         'YouTube'),
  ('whatsapp_status', 'WhatsApp Status')
on conflict (channel) do nothing;

insert into villa_integrations (provider, label, category) values
  ('whatsapp_cloud', 'WhatsApp Cloud API', 'messaging'),
  ('instagram',      'Instagram',          'messaging'),
  ('meta_ads',       'Meta Ads',           'advertising'),
  ('google_ads',     'Google Ads',         'advertising'),
  ('youtube',        'YouTube',            'messaging'),
  ('gemini',         'Google Gemini',      'analytics'),
  ('anthropic',      'Anthropic Claude',   'analytics'),
  ('groq',           'Groq',               'analytics'),
  ('supabase',       'Supabase',           'crm')
on conflict (provider) do nothing;
