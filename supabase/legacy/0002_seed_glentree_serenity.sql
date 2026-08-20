-- =============================================================================
-- Seed: GLENTREE SERENITY
--
-- Every value here is transcribed from the approved customer presentation
-- script. Nothing is inferred or embellished.
--
-- Where the script does not state a fact, the column is left NULL and a
-- `verification_note` explains why. The agent treats NULL as "unverified" and
-- routes the question to a human rather than guessing (spec section 28).
--
-- Re-running this file is safe: it upserts on the project slug.
-- =============================================================================

insert into villa_projects (
  slug, name, status, expected_delivery,
  survey_no, village, mandal, district, state, pincode,
  hmda_permit_no, hmda_permit_date, rera_status,
  total_land_acres, total_units, configurations,
  starting_price_inr, price_note,
  positioning, usps, amenities, specifications, sustainability,
  connectivity, social_infrastructure, financing_partners
) values (
  'glentree-serenity',
  'Glentree Serenity',
  'Under Construction',
  'June 2029 (T&C Apply)',

  'Survey No. 578', 'Nadergul', 'Balapur', 'Rangareddy', 'Telangana', '501510',

  '012013/LO/HMDA/3194/SMD/2024', '09-Oct-2025', 'Under Processing',

  18, 184,
  array['3 BHK + Home Theatre', '4 BHK + Home Theatre'],

  19800000,
  '₹1.98 Cr++ onwards. This is the published starting price. Final price depends on villa size, facing and plot, and is confirmed by the sales team.',

  'A premium gated triplex villa community at Nadergul, South Hyderabad — low-density, Vastu-compliant, with 50+ amenities and strong connectivity to the ORR, Adibatla IT hub and the international airport.',

  -- USPs (slide 6 + underground infrastructure slide)
  '[
    "One of the first premium gated villa communities in the region",
    "18-acre low-density development with only 184 villas",
    "184 premium triplex villas, Vastu-compliant",
    "42,345+ SFT across two clubhouses",
    "50+ lifestyle amenities",
    "5 themed parks across approximately 5 acres",
    "Wide HMDA access roads: 150 ft, 120 ft and 60 ft",
    "Fully underground utility network — no overhead cabling",
    "Dedicated parking for every villa",
    "100% DG power backup",
    "Hydro-pneumatic water supply system",
    "CCTV surveillance across common areas",
    "Fiber-to-home connectivity",
    "Internal home lift provision in villas",
    "VRV air conditioning provision",
    "EV charging enabled community",
    "Smart IoT water metering",
    "Targeting IGBC Gold certification",
    "Positioned near the starting zone of the Future City development corridor"
  ]'::jsonb,

  -- Amenities (slides 7.1, 8, 9, 9.1)
  '{
    "clubhouse": {
      "total_area_sft": "42,345+",
      "count": 2,
      "clubhouse_1_sports_and_fitness": [
        "Modern gymnasium", "Badminton courts", "Squash courts",
        "Volleyball court", "Fitness zones", "Outdoor sports areas"
      ],
      "clubhouse_2_leisure_and_social": [
        "Recreational lounges", "Indoor games", "Multipurpose hall",
        "Community spaces", "Entertainment zones", "Social gathering areas"
      ]
    },
    "sports_and_fitness": [
      "Gymnasium", "Swimming pool", "Tennis court", "Squash court",
      "Volleyball court", "Cricket pitch", "Half basketball court",
      "Outdoor fitness area", "Yoga deck", "Aerobics studio", "Skating track"
    ],
    "family_and_recreation": [
      "Amphitheatre", "Celebration lawn", "Party lawn", "Gaming zone",
      "Library", "Creche", "Co-working space", "Guest rooms",
      "Salon and spa", "Banquet hall"
    ],
    "kids_and_seniors": [
      "Kids play area", "Toddler zone", "Senior citizen plaza",
      "Swing lawns", "Seating zones"
    ],
    "themed_parks": {
      "total_acres": 5,
      "count": 5,
      "parks": [
        {"name": "Sahavas", "theme": "The Social Park", "features": ["Community interaction spaces", "Celebration lawns", "Seating plazas", "Gathering areas"]},
        {"name": "Veer Garden", "theme": "The Sports Park", "features": ["Outdoor fitness zones", "Sports and activity areas", "Walking and jogging pathways"]},
        {"name": "Aranya", "theme": "The Forest Park", "features": ["Dense tree plantation", "Natural green buffers", "Forest-themed landscaping", "Nature-inspired relaxation zones"]},
        {"name": "Ekaanth", "theme": "The Serene Garden", "features": ["Meditation lawns", "Yoga spaces", "Quiet seating areas"]},
        {"name": "Ananda Vana", "theme": "The Wellness Garden", "features": ["Wellness landscaping", "Walking trails", "Senior citizen friendly spaces", "Health and rejuvenation zones"]}
      ]
    },
    "green_and_open_spaces": [
      "Walking pathways", "Dense plantation areas", "Meditation lawn",
      "Celebration lawns", "Yoga spaces", "Water features", "Pergolas", "Seating plazas"
    ]
  }'::jsonb,

  -- Specifications (slides 7, 10, 11)
  '{
    "structure": ["RCC framed structure", "Designed to withstand wind and seismic loads"],
    "walls": ["8-inch external solid block walls", "4-inch internal solid block walls"],
    "doors_and_windows": [
      "Premium main door with biometric lock", "Designer internal doors",
      "UPVC windows", "Laminated glass", "Mosquito mesh"
    ],
    "flooring": [
      "Premium vitrified tiles", "Wooden flooring in master bedroom",
      "Anti-skid tiles in bathrooms"
    ],
    "paint": ["Premium acrylic emulsion interiors", "Weather-proof exterior finish"],
    "underground_infrastructure": [
      "Underground electrical cabling", "Underground drainage network",
      "Underground sewage lines", "Underground water distribution system",
      "Underground fiber internet connectivity", "Dedicated storm water drainage",
      "Concealed service corridors"
    ],
    "smart_and_future_ready": [
      "Internal home lift provision", "VRV air conditioning provision",
      "Fiber-to-home connectivity", "Intercom facility", "DTH provision",
      "IoT-based water metering", "EV charging ready infrastructure"
    ],
    "security": ["Gated community", "CCTV surveillance", "Controlled access"],
    "utilities": ["100% power backup", "Treated water supply", "Hydro-pneumatic water system"],
    "access_roads": ["150 ft HMDA road", "120 ft HMDA road", "60 ft HMDA road"]
  }'::jsonb,

  -- Sustainability (slide 12)
  '{
    "target_certification": "IGBC Gold Rating (Proposed — not yet awarded)",
    "features": [
      "Water Treatment Plant (WTP)", "Sewage Treatment Plant (STP)",
      "Rainwater harvesting", "Water recycling systems",
      "Efficient plumbing fixtures", "Smart IoT water meters",
      "EV charging enabled parking", "Enhanced natural ventilation",
      "Daylight optimization"
    ]
  }'::jsonb,

  -- Connectivity (slide 13). Distances are approximate and stated as ranges;
  -- travel TIME is deliberately absent — the agent must not invent it.
  '[
    {"place": "Outer Ring Road (ORR)", "distance_km": "6-8"},
    {"place": "Adibatla IT Hub",       "distance_km": "8-10"},
    {"place": "Tata Aerospace SEZ",    "distance_km": "8-10"},
    {"place": "Rajiv Gandhi International Airport", "distance_km": "20-24"},
    {"place": "LB Nagar",              "distance_km": "14-16"}
  ]'::jsonb,

  -- Social infrastructure (slide 14)
  '{
    "schools": ["Sri Sri Academy", "Delhi Public School", "Aga Khan Academy", "Narayana Schools", "Chaitanya Institutions"],
    "hospitals": ["Apollo Hospitals", "Kamineni Hospitals", "Yashoda Hospitals", "Ozone Hospitals"],
    "growth_drivers": ["Future City development", "Adibatla IT expansion", "Aerospace and SEZ growth", "Airport corridor development", "ORR connectivity"]
  }'::jsonb,

  array[
    'HDFC Bank', 'ICICI Bank', 'State Bank of India (SBI)',
    'Bajaj Housing Finance', 'Axis Bank', 'LIC Housing Finance',
    'IDFC First Bank', 'PNB Housing Finance'
  ]
)
on conflict (slug) do update set
  name              = excluded.name,
  status            = excluded.status,
  expected_delivery = excluded.expected_delivery,
  usps              = excluded.usps,
  amenities         = excluded.amenities,
  specifications    = excluded.specifications,
  sustainability    = excluded.sustainability,
  connectivity      = excluded.connectivity,
  social_infrastructure = excluded.social_infrastructure,
  updated_at        = now();


-- -----------------------------------------------------------------------------
-- Villa types
--
-- The script gives plot size, facing and built-up area for six variants, and
-- separately says the project offers "3 BHK + Home Theatre" and
-- "4 BHK + Home Theatre". It does NOT say which plot size maps to which
-- bedroom count. So `bedrooms` and `price_inr` stay NULL — the agent will
-- offer to have the sales team confirm rather than assume.
-- Fill these in once you have the approved price sheet.
-- -----------------------------------------------------------------------------
insert into villa_types (
  project_id, name, plot_area_sqyd, built_up_sft, facing,
  bedrooms, floors, has_home_theatre, price_inr, verification_note
)
select p.id, v.name, v.plot, v.sft, v.facing,
       null, 3, true, null,
       'Bedroom configuration and per-type price are not stated in the approved presentation. The project offers 3 BHK + Home Theatre and 4 BHK + Home Theatre; the sales team confirms which applies to this size and the current price.'
from villa_projects p
cross join (values
  ('200 Sq. Yards — East Facing', 200, 2876, 'East'),
  ('200 Sq. Yards — West Facing', 200, 2836, 'West'),
  ('267 Sq. Yards — East Facing', 267, 3715, 'East'),
  ('267 Sq. Yards — West Facing', 267, 3685, 'West'),
  ('300 Sq. Yards — East Facing', 300, 4286, 'East'),
  ('300 Sq. Yards — West Facing', 300, 4276, 'West')
) as v(name, plot, sft, facing)
where p.slug = 'glentree-serenity'
on conflict (project_id, name) do update set
  built_up_sft = excluded.built_up_sft,
  facing       = excluded.facing;


-- -----------------------------------------------------------------------------
-- FAQs — answers drawn verbatim from the presentation.
-- -----------------------------------------------------------------------------
insert into villa_faqs (project_id, question, answer, tags)
select p.id, f.q, f.a, f.tags
from villa_projects p
cross join (values
  ('Is the project approved?',
   'Yes. Glentree Serenity is approved by HMDA under permit number 012013/LO/HMDA/3194/SMD/2024, dated 09-Oct-2025. The RERA registration is currently under processing.',
   array['legal','approvals']),
  ('When is possession?',
   'The expected delivery is June 2029, subject to terms and conditions. The project is currently under construction.',
   array['possession','timeline']),
  ('How many villas are there?',
   'There are 184 premium triplex villas across an 18-acre gated community.',
   array['project','scale']),
  ('What villa sizes are available?',
   'There are three plot sizes — 200, 267 and 300 sq. yards — each available East or West facing. Built-up areas range from 2,836 SFT up to 4,286 SFT.',
   array['sizes','configuration']),
  ('What is the price?',
   'The published starting price is ₹1.98 Cr++ onwards. The final price depends on villa size, facing and plot, so the sales team confirms the current applicable price.',
   array['price']),
  ('Is home loan support available?',
   'Yes. Home loan assistance is offered through leading banks including HDFC, ICICI, SBI, Axis, IDFC First, Bajaj Housing Finance, LIC Housing Finance and PNB Housing Finance. Loan approval is at the bank''s discretion.',
   array['financing','home loan']),
  ('How far is the airport?',
   'Rajiv Gandhi International Airport is approximately 20–24 km away. Actual travel time varies with traffic.',
   array['location','connectivity']),
  ('Are the villas Vastu compliant?',
   'Yes, the villas are Vastu-compliant, with East and West facing options available.',
   array['vastu','configuration']),
  ('What is the clubhouse like?',
   'There are two clubhouses totalling 42,345+ SFT. One is dedicated to sports and fitness (gymnasium, badminton, squash, volleyball, outdoor sports), the other to leisure and social use (lounges, indoor games, multipurpose hall, entertainment and community spaces).',
   array['amenities','clubhouse']),
  ('Is it a green building?',
   'The project is targeting IGBC Gold certification. This is a proposed target and not yet an awarded rating. Sustainability features include a water treatment plant, sewage treatment plant, rainwater harvesting, water recycling, smart IoT water meters and EV-charging-enabled parking.',
   array['sustainability','igbc'])
) as f(q, a, tags)
where p.slug = 'glentree-serenity';
