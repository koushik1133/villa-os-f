# Setup Guide — every account and key this app needs

This guide is written for the business owner, not a developer. Plain English.
Every service has a direct link and step-by-step instructions.

**How to use this file:** you are filling in one file called `.env.local` in the
project folder. It is a plain text file. Each line looks like `NAME=value`. You
paste your keys after the `=` sign, with no quotes and no spaces around the `=`.

**A note on menu names:** company dashboards get redesigned. Where a menu might
have moved, this guide says "look for X" instead of promising an exact path. If
you can't find something, use the search box in that dashboard.

---

## 0. Read this before you open anything from Meta

Meta runs two different developer sites with confusingly similar names. Going to
the wrong one costs people an afternoon, so settle it now.

| Site | What it actually is | Do you need it? |
| --- | --- | --- |
| **https://developers.facebook.com** | The **WhatsApp Cloud API** — real WhatsApp messaging. Free test phone number, no card needed to start. | ✅ **YES.** This is the one. |
| **dev.meta.ai** (also seen as `llama.developer.meta.com`) | Meta's **Llama AI model** API — a paid text-generation service, nothing to do with WhatsApp. It will ask you for billing details. | ❌ **NO.** This app never calls it. |

**The tell:** if a Meta page is asking for a credit card before you have done
anything, you are on the Llama site. Close the tab and go to
**https://developers.facebook.com**.

The AI brain of this app comes from Groq or Anthropic (sections 4 and 5), never
from Meta. Meta is only ever the *delivery pipe* for WhatsApp messages.

---

## 1. Quick summary — everything at a glance

| Variable in `.env.local` | What it's for | Cost | Needed to start? |
| --- | --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Address of your database | Free tier | **Required** |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Public read key for the database | Free tier | In the template, but **not read by the code today** — fill it in anyway |
| `SUPABASE_SERVICE_ROLE_KEY` | Master database key (server only) | Free tier | **Required** |
| `LLM_PROVIDER` | Which AI answers customers: `groq` or `anthropic` | — | **Required** |
| `GROQ_API_KEY` | Free AI, for testing | Free | **Required if** `LLM_PROVIDER=groq` |
| `GROQ_MODEL` | Which Groq model to use | Free | Optional (has a default) |
| `ANTHROPIC_API_KEY` | Paid AI, for real customers | Pay per use | **Required if** `LLM_PROVIDER=anthropic` |
| `ANTHROPIC_MODEL` | Which Claude model to use | — | Optional (has a default) |
| `AGENT_EFFORT` | How hard the AI thinks per reply | — | Optional (default `medium`) |
| `GEMINI_API_KEY` | Writes ad and social copy on `/marketing` | Free tier | Optional |
| `WHATSAPP_PHONE_NUMBER_ID` | Which WhatsApp number sends messages | Free to start | Optional to start |
| `WHATSAPP_BUSINESS_ACCOUNT_ID` | Your WhatsApp Business Account | Free to start | In the template, but **not read by the code today** — keep it noted anyway |
| `WHATSAPP_ACCESS_TOKEN` | Permission to send WhatsApp messages | Free to start | Optional to start |
| `WHATSAPP_VERIFY_TOKEN` | **You invent this.** Proves the webhook is yours | Free | Only with WhatsApp |
| `WHATSAPP_APP_SECRET` | Blocks strangers from faking customer messages | Free | Only with WhatsApp |
| `WHATSAPP_API_VERSION` | Which version of Meta's API to call | Free | Optional (default `v21.0`) |
| `SALES_TEAM_WHATSAPP` | Number that gets hot-lead alerts | Free | Optional |
| `SALES_TEAM_NAME` | Name the AI uses for your sales team | Free | Optional |
| `NEXT_PUBLIC_APP_URL` | Your app's web address | Free | Optional (default localhost) |
| `DASHBOARD_PASSWORD` | **You invent this.** Password for the admin console | Free | Not wired up yet (see section 8) |
| `CRON_SECRET` | **You invent this.** Protects the scheduled follow-up job | Free | **Required before follow-ups work at all** |
| `PROJECT_MAPS_URL` | Google Maps link the AI shares | Free | Optional |
| `BROCHURE_URL` | Public link to the approved brochure PDF | Free | Optional |

Those 23 lines are exactly what `.env.example` contains — no more, no fewer.

**Two rows above say "not read by the code today."** That is deliberate honesty,
not a mistake. `NEXT_PUBLIC_SUPABASE_ANON_KEY` and
`WHATSAPP_BUSINESS_ACCOUNT_ID` sit in the template because they are standard
values you will want on hand, but right now nothing in the app looks them up —
the app reaches Supabase only through the server-side `service_role` key, and it
talks to WhatsApp using the Phone Number ID rather than the Business Account ID.
Fill them in regardless; it costs you nothing and saves a hunt later.

**Only two services are real accounts you must create to get going:**
Supabase, and then either Groq (free) or Anthropic (paid). Everything else can
wait.

---

## 2. Start here — the minimum to run the app today

You need exactly **two** accounts to see the app working end to end:

1. **Supabase** — the database. Free.
2. **Groq** — the free AI. Free.

That's it. **You do not need WhatsApp to test the AI.**

This is the single most important thing to understand before you spend a day on
Meta's dashboard. The app has a built-in **Simulator** at
`http://localhost:3000/simulator`. It runs *the exact same AI agent* a real
WhatsApp customer would hit — the same instructions, the same knowledge base,
the same writes into your CRM. The only difference is the reply comes back to
your browser instead of going out through WhatsApp.

So the sensible order is:

1. Set up Supabase (section 3).
2. Set up Groq (section 4).
3. Run the database migrations (section 9).
4. Run the app and talk to it in the Simulator.
5. Only once you're happy with how it talks to people, connect WhatsApp
   (section 7) and switch to Anthropic (section 5).

To run the app after filling in your keys:

```bash
npm install
npm run dev
```

Then open `http://localhost:3000`.

If something is missing, the app will show you a friendly setup checklist rather
than an error page. That is by design.

> **Important:** every time you edit `.env.local`, you must stop the app
> (`Ctrl+C` in the terminal) and run `npm run dev` again. The app only reads
> that file when it starts.

---

## 3. Supabase — the database

**What it is:** the place where every lead, conversation, booking and message is
stored. Think of it as your CRM's filing cabinet.

**Does it cost money?** No, for your stage. The free tier is generous and is
enough to run this. One thing to know: on the free plan, Supabase pauses
projects that show low activity over a **7-day period**. "Activity" means
queries actually hitting the database — visiting the dashboard does not count.
If your project ever seems dead, log in and restore it. Supabase documents this
at **https://supabase.com/docs/guides/platform/free-project-pausing**.

### Steps

1. Go to **https://supabase.com** and click **Start your project**. Sign up with
   GitHub or email.
2. Once you're in, click **New project**.
3. Give it a name (for example, `glentree-serenity`), choose a **strong database
   password** and save that password in your password manager. Pick a region
   close to your customers — for India, a Mumbai or Singapore region is a good
   choice.
4. Click **Create new project** and wait 1–2 minutes while it builds.
5. Open your project, then look for **Project Settings** (usually a gear icon at
   the bottom of the left sidebar). Inside it, look for the **API** or **API
   Keys** section.
6. On that page you'll find three things you need:
   - **Project URL** — looks like `https://abcdefghijkl.supabase.co`
   - **anon / public key** — a very long string starting with `eyJ...`
   - **service_role key** — also starts with `eyJ...`, and will be hidden behind
     a "Reveal" or eye icon

### Where to paste them

```
NEXT_PUBLIC_SUPABASE_URL=https://abcdefghijkl.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOi...   ← the anon / public key
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOi...       ← the service_role key
```

### About the service_role key — please read this

The **service_role key is a master key**. Anyone who has it can read, change or
delete every row in your database. It ignores all the security rules you set up.
Treat it exactly like the master key to your office.

Three rules:

- It must **never** appear in anything a customer's browser downloads. In this
  project that means it must never be renamed to start with `NEXT_PUBLIC_`. That
  prefix is a signal to the app that a value is safe to publish. It is not.
- It must **never** be committed to git or pasted into a public place.
- If you ever paste it into a chat, an email, or a support ticket, go back to
  Supabase and **rotate** (regenerate) it. Assume anything you sent is now public.

The `anon` key is different — it is *designed* to be public, and this project's
database has security rules that make it useless on its own. It's fine for it to
be in the browser. As it happens the app doesn't currently read it at all (every
database call happens on the server with the `service_role` key), but paste it in
anyway so it's there when it's needed.

### How to check it worked

Start the app (`npm run dev`) and open `http://localhost:3000/leads`. If Supabase
is connected, you'll see the leads page (probably empty — that's correct, there
are no leads yet). If it isn't connected, you'll see a setup notice telling you
exactly which value is missing.

---

## 4. Groq — free AI, for testing

**What it is:** a company that runs open-source AI models very fast and gives
you a free allowance. This is what you use while you're testing.

**Does it cost money?** No. There's a free tier that doesn't need a card.

### Steps

1. Go to **https://console.groq.com/keys**
2. Sign up or log in (Google sign-in works).
3. Click **Create API Key**, give it a name like `villa-agent`.
4. **Copy the key immediately.** Groq shows it once. If you lose it, delete that
   key and make a new one. It starts with `gsk_`.

### Where to paste it

```
LLM_PROVIDER=groq
GROQ_API_KEY=gsk_...
GROQ_MODEL=openai/gpt-oss-120b
```

`GROQ_MODEL` is which specific AI model to use. The value above is a sensible
default and is currently listed as a production model on Groq. Groq's model list
changes often — if you ever get an error saying the model doesn't exist, check
**https://console.groq.com/docs/models** for the current names.

### Be realistic about the free tier

The free tier's limits are real and you will feel them. For `openai/gpt-oss-120b`
Groq's published free-plan limits are:

| Limit | Value |
| --- | --- |
| Requests per minute | 30 |
| **Tokens per minute** | **8,000** |
| Requests per day | 1,000 |
| Tokens per day | 200,000 |

A "token" is about three-quarters of a word, and both the question and the answer
count. Because this agent sends a large knowledge base with every message, that
8,000-per-minute ceiling is the one that bites. You will see:

- Replies that take **40 to 180 seconds** instead of a couple of seconds.
- Occasional outright failures when you hit the per-minute cap.
- A hard stop after about 1,000 messages in a day.

That is completely fine for you testing in the Simulator. It is **not** fine for
a real customer sitting on WhatsApp wondering why nobody replied. Before real
customers, switch to Anthropic (section 5).

These limits are set per organisation, not per person, and Groq changes them.
The live numbers are at **https://console.groq.com/docs/rate-limits**, and your
own account's limits are shown at **https://console.groq.com/settings/limits** —
trust those over this document.

### How to check it worked

Open `http://localhost:3000/simulator`, type "Hi" and send it. Be patient — on
the free tier the first reply can take over a minute. If you get a reply, Groq is
working.

---

## 5. Anthropic — the production AI

**What it is:** the company that makes Claude, the AI this app was built around.
This is the quality level you want in front of paying customers.

**Does it cost money?** Yes. It's pay-per-use: you add credit up front and it
draws down as messages are handled. There is no free tier. See section 11 for
rough costs.

### Steps

1. Go to **https://platform.claude.com** and create an account. (The older
   address `console.anthropic.com` still works — it now redirects here. If a
   colleague sends you the old link, it's the same place.)
2. Look for **Billing** (or **Plans & Billing**) and add credit. A small amount
   is enough to start — you're paying per message, not a subscription.
3. Look for **API Keys** (usually under Settings) and click **Create Key**.
4. Name it something like `villa-whatsapp-prod`.
5. **Copy it immediately** — it's shown once. It starts with `sk-ant-api03-`.

### Where to paste it

```
LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-api03-...
ANTHROPIC_MODEL=claude-opus-4-8
AGENT_EFFORT=medium
```

Changing `LLM_PROVIDER` from `groq` to `anthropic` is the single switch that
moves the agent from test mode to production mode. Nothing else changes.

`ANTHROPIC_MODEL` is the model the agent runs on. `claude-opus-4-8` is what the
project ships with and it still works, but Anthropic has since released newer
models and now lists this one as legacy. You do not have to touch it. If you
want the current model, check
**https://platform.claude.com/docs/en/about-claude/models/overview** and change
that one line — nothing else in the app depends on the name.

`AGENT_EFFORT` controls how hard the AI thinks before replying:

- `low` — fastest and cheapest. Fine for simple "what's the address" traffic.
- `medium` — the recommended default for sales conversations.
- `high` — deepest reasoning, slower replies, costs more.

> **Small technical note, in case someone else runs this app:** if `LLM_PROVIDER`
> is left blank entirely, the app assumes `anthropic`. So don't delete the line —
> set it to `groq` explicitly while testing.

### How to check it worked

Set `LLM_PROVIDER=anthropic`, restart the app, and send a message in the
Simulator. Replies should come back in a few seconds instead of a minute. Then
check your Anthropic console — usage should appear there.

---

## 6. Google Gemini — marketing copy (optional)

**What it is:** Google's AI. Here it does exactly one job: writing ad and social
media copy on the `/marketing` page, using your real project details.

**Does it cost money?** There is a free tier with daily limits. For occasional
copy generation, free is usually enough. Check Google's current pricing before
relying on it heavily.

**Is it required?** No. Without a key, the marketing page still works — it just
falls back to a fixed template. The copy is more generic, but nothing breaks and
nothing is invented.

### Steps

1. Go to **https://aistudio.google.com/apikey**
2. Sign in with a Google account.
3. Click **Create API key**. You may be asked to pick or create a Google Cloud
   project — accept the default it offers.
4. Copy the key.

### Where to paste it

```
GEMINI_API_KEY=AIza...
```

### How to check it worked

Open `http://localhost:3000/marketing` and generate a piece of content. The
result is labelled to show whether it came from the AI or from the built-in
fallback template. If it says it was AI-generated, your key is working.

---

## 7. WhatsApp Cloud API (Meta) — the messaging channel

This is the section people get wrong most often, so read the first part
carefully.

### First: make sure you are on the right Meta site

This is the same warning as section 0, repeated because it is the single most
expensive mistake in this whole document.

| | |
| --- | --- |
| **dev.meta.ai** | Meta's **Llama AI model** API. A paid text-generation service. It asks for billing details. **This is NOT what you want.** This app does not use it at all. |
| **developers.facebook.com** | The **WhatsApp Cloud API** — actual WhatsApp messaging. **This is what you want.** |

If a page is asking you for a credit card before you can do anything, you are
almost certainly on the wrong one. Close it and go to
**https://developers.facebook.com**.

**Does WhatsApp Cloud API cost money to start?** No. You do not need a credit
card to begin. Meta gives you a **free test phone number** the moment you add the
WhatsApp product to your app. That test number can message **up to 5 phone
numbers** that you add yourself as testers, and messages to those 5 numbers are
free. That is plenty to try the whole system with your own phone and your sales
team's phones.

Billing only enters the picture when you move to a real phone number and real
customers (section 7.5). At that point Meta does expect a payment method on the
account. How the charges themselves work is covered in section 11 — and it is
not what most older blog posts say, so read it before you budget.

### 7.1 Getting the test setup (free, takes about 15 minutes)

1. Go to **https://developers.facebook.com** and log in with your Facebook
   account. Any personal Facebook account works.
2. Look for **My Apps** in the top-right, then **Create App**.
3. Meta will ask what you're building. **Look for the WhatsApp option.** Meta has
   changed this screen more than once — it has been a "Business" app type, and
   more recently a "use case" picker. Whatever it looks like when you get there,
   choose the path that explicitly mentions **WhatsApp**. If nothing does, pick
   **Business** / **Other** and add WhatsApp as a product in step 5.
4. Give the app a name (`Glentree Serenity Agent`) and enter your business email.
5. On the app's main page you'll see a list of products you can add. Find
   **WhatsApp** and click **Set up**.
6. Meta will ask you to select or create a **Meta Business Account** (you may see
   it called a **business portfolio**). Create one if you don't have one. This is
   free and doesn't require verification yet.
7. You now land on the **API Setup** page. In the WhatsApp side menu you should
   also see **Quickstart** and **Configuration** — those three are the pages you
   will use. API Setup has almost everything you need:

   - **A test phone number** Meta gives you, free. It appears in a dropdown
     labelled "From".
   - **Phone number ID** — a long number shown right under the test number.
     Copy it.
   - **WhatsApp Business Account ID** — also on this page. Copy it.
   - **Temporary access token** — a long string with a **Copy** button.
     ⚠️ This one **expires within about 24 hours**. It is fine for a first test,
     but you will need a permanent one (section 7.5) before anything real.

8. Still on that page, find the **To** field with an **Add phone number** or
   **Manage phone number list** option. **Add your own WhatsApp number here.**
   Meta will send you a verification code on WhatsApp — enter it. You can add up
   to 5 numbers this way. The test number can only message these numbers.

### 7.2 The App Secret

**What it is:** a password that only you and Meta know. Every message Meta sends
to your app is stamped with a signature made using this secret. Your app checks
that stamp.

**Why it matters:** your webhook address is a public URL on the internet. Without
this check, anyone who discovers that URL could send your app fake customer
messages. They could make your AI reply to people, fill your CRM with junk, and
run up your Anthropic bill. With the check in place, anything not genuinely from
Meta is rejected instantly.

**Where to find it:** in your app's dashboard, look for the app's own settings
rather than the WhatsApp product settings — it has been called **App settings →
Basic** and just **Basic settings**. Look for a field labelled **App secret**
with a **Show** button next to it. Click it, enter your Facebook password, and
copy the value.

### 7.3 Where to paste it all

```
WHATSAPP_PHONE_NUMBER_ID=123456789012345
WHATSAPP_BUSINESS_ACCOUNT_ID=987654321098765
WHATSAPP_ACCESS_TOKEN=EAAG...
WHATSAPP_VERIFY_TOKEN=<a random string you invent — see section 8>
WHATSAPP_APP_SECRET=<from your app's Basic settings>
WHATSAPP_API_VERSION=v21.0
```

Four of those six are what the app actually uses to send and receive:
`WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_VERIFY_TOKEN` and
`WHATSAPP_APP_SECRET`. All four must be filled in before the app considers
WhatsApp configured — three out of four is the same as zero.

`WHATSAPP_BUSINESS_ACCOUNT_ID` is not read by the code today. Record it anyway:
you need it to find your account in WhatsApp Manager and to submit message
templates.

Leave `WHATSAPP_API_VERSION` alone unless Meta announces that `v21.0` is being
retired.

### 7.4 Connecting the webhook

A **webhook** is just a web address Meta calls whenever a customer messages you.
For this app that address is `/api/whatsapp`.

You cannot point Meta at `localhost` — Meta's servers can't reach your laptop.
So you either deploy the app first (section 10) or use a tunnelling tool. If
you're not sure, just deploy first; it's simpler.

1. In your Meta app, go to **WhatsApp → Configuration**.
2. Next to **Webhook**, click **Edit**.
3. **Callback URL:** `https://your-domain.com/api/whatsapp`
4. **Verify token:** the exact same string you put in `WHATSAPP_VERIFY_TOKEN`.
   Character for character.
5. Click **Verify and save**. Meta immediately calls your URL to check it. If
   the token matches, it saves. If you get an error here, 95% of the time the
   token doesn't match, or the app wasn't restarted after you edited
   `.env.local`, or the app isn't deployed yet.
6. Below that, find **Webhook fields** and click **Manage**. Subscribe to
   **`messages`**. Without this, Meta verifies your URL but never actually sends
   you anything.

### 7.5 Going live to real customers

The test number is fine for trying things out, but it can only ever message 5
people you've pre-approved. To message real customers you need four things, and
one of them takes days:

0. **A payment method on the account.** Meta expects a card on file before a real
   business number sends real messages. Adding it does not mean you get charged
   immediately — see section 11 for what is actually billable, which is less
   than most people expect. But the card does have to be there.

1. **Meta Business verification.** Meta needs to confirm your business is real.
   Look for your **business settings** (this lives in Meta Business Suite, not in
   the developer app dashboard) and then **Business info** / **Security Centre**,
   where there will be an option to start verification. You'll need documents
   like a business registration certificate and a utility bill or bank statement
   showing the business address. **Budget several business days to a couple of
   weeks.** Start it early. Do not plan a launch date assuming it's instant.

2. **A real phone number.** In **WhatsApp → API Setup**, add a phone number you
   own. It must not currently be registered on the normal WhatsApp or WhatsApp
   Business app — if it is, delete that account first (you lose its chat history).
   A common approach is to buy a fresh SIM just for this. Once added, this
   number's Phone Number ID replaces the test one in `WHATSAPP_PHONE_NUMBER_ID`.

3. **A permanent access token.** The 24-hour token from API Setup will expire
   and your agent will silently stop replying. To get a permanent one, go to your
   **business settings** in Meta Business Suite and look for **Users → System
   users**:
   - Create a system user, give it the **Admin** role.
   - Look for **Add assets**, select your app and your WhatsApp Business Account,
     and give it full control.
   - Look for **Generate new token**, choose your app, set expiry to **Never**,
     and tick the permissions **`whatsapp_business_messaging`** and
     **`whatsapp_business_management`**.
   - Copy the token. **It's shown once.** Put it in `WHATSAPP_ACCESS_TOKEN`.

You'll also need **message templates** approved by Meta for any message you send
to a customer who hasn't written to you in the last 24 hours. That's a WhatsApp
rule, not an app limitation. You submit templates in **WhatsApp Manager** and
approval usually takes minutes to hours.

This matters more than it sounds, because it is exactly what the automatic
follow-up job runs into. See section 8 (`CRON_SECRET`) for how this app handles
it: it will only ever send an approved template, and flags anything else for a
human rather than firing off free text that Meta would reject.

### How to check it worked

From one of your tester phones, send a WhatsApp message to the test number. You
should get a reply from the AI. Check `http://localhost:3000/leads` (or your
deployed site) — a new lead should have appeared with that conversation.

---

## 8. The three passwords you invent yourself

`WHATSAPP_VERIFY_TOKEN`, `CRON_SECRET` and `DASHBOARD_PASSWORD` are **not
obtained from any website**. There is no signup page. You make them up.

People waste hours hunting for these on Meta's dashboard. Don't. Just generate
them.

### Generate a strong one

Open your terminal and run this once for each:

```bash
openssl rand -hex 32
```

That prints a 64-character random string. Copy it. Run the command again for the
next one — **use a different value for each**. This command already exists on
Mac and Linux; nothing to install.

Example of what it prints (do not use this one — generate your own):

```
7f3c9a1e5b8d4206ef2a9c7b1d5308e4a6f9c2b7d0e3a5f8c1b4d7e0a3f6c9b2
```

### What each one does

**`WHATSAPP_VERIFY_TOKEN`** — a shared password between you and Meta. You put
the same string in two places: in `.env.local`, and in the Meta webhook setup
screen. When Meta first calls your webhook, it sends this string, and your app
checks it matches. It proves to Meta that you actually control that URL. It is
used once, at setup.

**`CRON_SECRET`** — protects the scheduled follow-up job at
`/api/cron/follow-ups`. A "cron" is just a timer that calls a web address on a
schedule — here, to send follow-up messages to leads that have come due.

Because that address sits on the public internet, the secret is what stops a
stranger triggering your follow-ups over and over. Your scheduler sends it as an
`Authorization: Bearer <your secret>` header. Specifically:

- **No `CRON_SECRET` set at all** → the route refuses to run and answers `503`.
  It fails closed on purpose: an unprotected follow-up sender is worse than one
  that doesn't run, because anyone who guessed the URL could make your business
  message its own customers.
- **Wrong or missing header** → `401`, nothing is sent.
- **Correct header** → it picks up as many as 50 due follow-ups and works through
  them.

Two things worth knowing about what it then does, because they surprise people:

- **It only ever sends templates Meta has already approved.** A follow-up fires
  hours or days after the customer last wrote, which is outside WhatsApp's
  24-hour window, and outside that window Meta rejects free text. So if a
  follow-up has no approved template attached, the job does *not* invent
  something — it marks the row as needing a human and moves on.
- **It never messages a lead who has opted out**, and it won't double-send if two
  runs overlap.

So a follow-up that shows up as "needs manual action" is the system working
correctly, not failing.

**`DASHBOARD_PASSWORD`** — the password for the admin console.

*Be aware:* as of this writing the login gate is not yet wired up, so setting
this alone does **not** protect the dashboard. Until it is, do not deploy this
app on a public URL with real customer data in it. If you need it public sooner,
put a password at the hosting layer (Vercel has password protection on some
plans) or keep the deployment private.

### Where to paste them

```
WHATSAPP_VERIFY_TOKEN=7f3c9a1e...   ← must match what you type into Meta
CRON_SECRET=b2e7d4a9...             ← different value
DASHBOARD_PASSWORD=c8a1f5e3...      ← different value again
```

`DASHBOARD_PASSWORD` is the one you'll type by hand, so a shorter memorable
passphrase is acceptable there if you prefer — but make it long and not reused
from anywhere else.

---

## 9. Running the database migrations

A **migration** is a file of database instructions. Running them creates all the
tables your app needs. You run them once, in order, and then you're done.

The files live in the `supabase/migrations/` folder of this project. There are
**9** of them. Run them in **exact numeric order**:

| # | File | What it does |
| --- | --- | --- |
| 1 | `0001_schema.sql` | Creates the core tables: leads, conversations, messages, projects |
| 2 | `0002_seed_glentree_serenity.sql` | Loads the initial Glentree Serenity project data |
| 3 | `0003_production_kanban.sql` | Adds the sales pipeline board — the manual "where is this deal" stage your team drags leads through on `/production` |
| 4 | `0004_content_permissions.sql` | Adds the `/admin` switches: which assets the AI is allowed to send, and which publishing channels are on |
| 5 | `0005_real_glentree_data.sql` | Loads verified project data from the website |
| 6 | `0006_content_drafts.sql` | Adds the marketing content drafts table |
| 7 | `0007_pdf_resolved_facts.sql` | Loads facts transcribed from the approved brochures |
| 8 | `0008_register_real_assets.sql` | Registers the real brochures and floor plans as sendable files |
| 9 | `0009_business_os.sql` | Adds bookings, tasks, follow-ups, payments and the wider business layer |

### Steps

1. Open your project at **https://supabase.com/dashboard**
2. In the left sidebar, click **SQL Editor**.
3. Click **New query**.
4. On your computer, open `supabase/migrations/0001_schema.sql` in any text
   editor. Select all of it (`Cmd+A` / `Ctrl+A`) and copy.
5. Paste it into the Supabase SQL Editor.
6. Click **Run** (or press `Cmd+Enter` / `Ctrl+Enter`).
7. Wait for "Success". If you get an error, stop and read it — do not continue
   to the next file.
8. Clear the editor and repeat steps 4–7 for `0002`, then `0003`, and so on
   through `0009`.

**Do them one at a time.** Don't paste several files together. Each one assumes
the previous ones already ran, and if something fails you want to know exactly
which file it was.

### How to check it worked

In the Supabase sidebar click **Table Editor**. You should see a long list of
tables, all starting with `villa_` — `villa_leads`, `villa_conversations`,
`villa_projects`, `villa_bookings` and so on. If you see them, you're done.

Every table name is prefixed `villa_` on purpose, so this can share a Supabase
project with other things without clashing.

---

## 10. Going live — deployment checklist

The app runs on your laptop during testing. To take real customer messages it
has to live on the internet with a proper HTTPS address, because that's the only
kind of address Meta will send messages to.

### Deploy to Vercel

Vercel is made by the same team as Next.js (the framework this app uses), so it's
the path of least resistance.

> ⚠️ **Budget for the Pro plan, not the free one.** Vercel's free **Hobby** tier
> is restricted to non-commercial, personal use. Vercel defines commercial usage
> broadly — essentially any deployment involved in making money for anyone on the
> project. A sales agent that chases villa buyers is squarely commercial, so
> Hobby is fine while you're testing and **not** a legitimate home for the live
> system. Pro is billed per team member per month. Read the actual terms at
> **https://vercel.com/docs/limits/fair-use-guidelines** and check current
> pricing at **https://vercel.com/pricing**.

1. Put your code in a **private** GitHub repository.
   **Double-check `.env.local` is not in it.** The project's `.gitignore`
   already excludes it, but confirm before pushing.
2. Go to **https://vercel.com** and sign up with GitHub.
3. Click **Add New → Project** and pick your repository.
4. Vercel will detect Next.js automatically. Don't change the build settings.
5. **Before clicking Deploy**, expand **Environment Variables**. Add every
   variable from your `.env.local`, one at a time — name on the left, value on
   the right. This is the step people forget. Your `.env.local` file never gets
   uploaded; Vercel needs its own copy.
6. Click **Deploy**. A couple of minutes later you get a URL like
   `https://your-app.vercel.app`.

### Then, in order

- [ ] Set `NEXT_PUBLIC_APP_URL` in Vercel to your real deployed URL (for example
      `https://your-app.vercel.app`). This is how the AI builds working links to
      brochures. If it still says `localhost`, customers get dead links.
- [ ] Set `LLM_PROVIDER=anthropic` in Vercel, and make sure `ANTHROPIC_API_KEY`
      is set there too. Do not launch on Groq's free tier — the delays will cost
      you leads.
- [ ] **Redeploy** after changing environment variables. Vercel does not apply
      them to the already-running version. Use **Deployments → ⋯ → Redeploy**.
- [ ] In Meta: **WhatsApp → Configuration → Webhook → Edit**. Set the Callback
      URL to `https://your-app.vercel.app/api/whatsapp` and the verify token to
      your `WHATSAPP_VERIFY_TOKEN`. Save.
- [ ] In Meta: subscribe to the **`messages`** webhook field.
- [ ] Swap the temporary WhatsApp token for the permanent System User token
      (section 7.5), or the agent will stop replying within 24 hours.
- [ ] Complete Meta Business verification and add your real phone number.
- [ ] Set `SALES_TEAM_WHATSAPP` to the number that should receive hot-lead
      alerts — digits only, international format, no `+` and no spaces.
      For India: `919876543210`.
- [ ] Set `CRON_SECRET` in Vercel and schedule the follow-up job (see below).
- [ ] Send yourself a test message on WhatsApp and confirm a lead appears in the
      dashboard.
- [ ] Confirm the dashboard isn't publicly readable (see the warning in
      section 8 about `DASHBOARD_PASSWORD`).

### Scheduling the follow-up job

Nothing calls `/api/cron/follow-ups` on its own. Until you schedule it, follow-ups
sit in the database and never go out. On Vercel this is two small steps.

**1.** Create a file called `vercel.json` in the project folder:

```json
{
  "crons": [{ "path": "/api/cron/follow-ups", "schedule": "0 9 * * *" }]
}
```

That runs it once a day at 09:00. **Cron schedules on Vercel are always in UTC**,
never your local time — `0 9 * * *` is 2:30pm in India, not 9am. Adjust the
numbers accordingly.

**2.** Set `CRON_SECRET` as an environment variable in your Vercel project.

You do not have to wire up the header yourself: when a Vercel project has a
`CRON_SECRET` variable, Vercel automatically sends it as
`Authorization: Bearer <secret>` on every scheduled call, which is exactly what
this route checks for. That's the whole integration.

Two limits to know: on the free **Hobby** plan a cron job can only run **once per
day** (anything more frequent fails the deployment) and it fires at some point
within the hour you asked for. Paid plans run to the minute. Vercel also does not
retry a failed run — check **Settings → Cron Jobs → View Logs** if follow-ups
seem to have gone quiet.

Not on Vercel? Any scheduler works. It just has to make a `GET` request to
`https://your-domain.com/api/cron/follow-ups` with the header
`Authorization: Bearer <your CRON_SECRET>`.

---

## 11. What this will cost

**Please treat every number below as a rough indication, not a quote.** Provider
pricing changes and none of it is under this project's control. The links go to
the official pricing pages — trust those, not this document.

| Service | What's known | Rough monthly reality |
| --- | --- | --- |
| **Supabase** | Free tier exists, with limits on database size and bandwidth. Paid plans start above that. [Pricing](https://supabase.com/pricing) | ₹0 for a long time. You would need a lot of leads to outgrow the free tier. |
| **Groq** | Free tier exists with per-minute and per-day rate limits. Groq retired its standalone pricing page; rates now live in the docs. [Model list and rates](https://console.groq.com/docs/models) | ₹0. Testing only. |
| **Google Gemini** | Free tier exists with daily limits. [Pricing](https://ai.google.dev/gemini-api/docs/pricing) | ₹0 for occasional marketing copy. |
| **Anthropic** | Pay-per-use, priced per million tokens. No free tier. [Pricing](https://platform.claude.com/docs/en/about-claude/pricing) | **Estimate:** a few rupees per customer conversation. See the note below. |
| **WhatsApp Cloud API** | Charged **per message**, not per conversation, and only for certain message types. See the note below — this changed and most guides online are out of date. [Pricing](https://developers.facebook.com/documentation/business-messaging/whatsapp/pricing) | ₹0 at test volumes. Costs begin at scale. |
| **Vercel** | Free Hobby tier is non-commercial only; commercial use requires Pro. [Pricing](https://vercel.com/pricing) | ₹0 while testing, then a per-seat monthly fee. |

### About WhatsApp charges — this is not what old guides say

If you research this online you will find a lot of confident writing about "1,000
free conversations a month" and "charged per 24-hour conversation window." **That
model is retired.** Meta replaced conversation-based pricing with **per-message
pricing on 1 July 2025**, and made **service conversations free for all
businesses on 1 November 2024**. There is no longer a monthly free-conversation
allowance, because most of what this app does is now simply not billable.

What that means in practice for an agent like this one:

- **Every reply the AI sends to a customer who messaged you first is free.**
  Non-template messages inside the 24-hour customer service window are not
  charged. This is the overwhelming majority of what this app sends.
- **Marketing templates are always charged.**
- **Utility and authentication templates are charged only when sent outside an
  open customer service window** — inside one, they're free.

So the cost driver is not conversation volume, it's how many *template* messages
you push out — which in this app means follow-ups (section 8). Rates vary by
country and category; the official table is linked in the row above.

### About the Anthropic estimate

This is the only cost that scales with how well the agent is doing its job, so
it's worth understanding.

You are charged for text going in and text coming out. This agent sends a large
knowledge base with every message so it never invents facts about your property
— that's the whole design — which means the "text going in" is substantial.

The app uses **prompt caching** to blunt this: the unchanging part (instructions
plus knowledge base) is cached on Anthropic's side, and cached text is billed at
a fraction of the normal rate. This is a big saving and it's already built in.

**My estimate:** on the order of a few rupees for a typical multi-message
conversation. That is an estimate, clearly labelled as one. It could be lower
with `AGENT_EFFORT=low` and higher with `high` or with very long conversations.

**What to actually do:** put a small amount of credit in your Anthropic account.
Run 20 or 30 real conversations. Look at what it actually cost you. Divide.
Now you have a real number for *your* traffic instead of someone's guess. Set a
spending limit in the Anthropic console while you're there.

---

## 12. Security rules — the short version

These are not optional, and none of them are hard.

1. **Never commit `.env.local` to git.** It's already in `.gitignore`. Before
   your first push, run `git status` and confirm it does not appear.

2. **Never put a secret in a `NEXT_PUBLIC_` variable.** In Next.js, that prefix
   means "bundle this into the code every visitor downloads." It is meant only
   for genuinely public values like your site URL and the Supabase anon key.
   `SUPABASE_SERVICE_ROLE_KEY`, `ANTHROPIC_API_KEY`, `GROQ_API_KEY`,
   `GEMINI_API_KEY`, `WHATSAPP_ACCESS_TOKEN` and `WHATSAPP_APP_SECRET` must
   never be renamed with that prefix.

3. **Rotate anything you've shared.** If a key went into a WhatsApp message, an
   email, a screenshot, a support ticket, or an AI chat window — assume it is
   compromised and regenerate it. Every provider above lets you delete a key and
   issue a new one in under a minute. It is far cheaper than the alternative.

4. **Use a private GitHub repository.** This is business code with your project
   data in it.

5. **One key per purpose.** Separate keys for testing and production. If one
   leaks, you kill it without taking your live agent down.

6. **`.env.example` is a template, not a place for real values.** It is meant to
   be committed to git, so it should contain only `<placeholder>` text. If you
   ever find a real key sitting in it, rotate that key immediately and replace
   the value with a placeholder.

   > ⚠️ **Check this now.** The `.env.example` in this project currently
   > contains what look like real, working values for `GROQ_API_KEY`,
   > `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` and
   > `SUPABASE_SERVICE_ROLE_KEY`. If that file has ever been pushed to git,
   > **rotate all four** — especially the service_role key — and replace the
   > values in `.env.example` with `<placeholders>`.

7. **The dashboard has no login yet.** See section 8. Don't put it on a public
   URL with real customer data until that's done.

---

## 13. When something doesn't work

| What you see | Almost always this |
| --- | --- |
| "Missing environment variable X" | The line isn't in `.env.local`, or it still has the `<placeholder>` angle brackets around it. Remove the brackets. |
| Changed a key, nothing happened | You didn't restart. `Ctrl+C`, then `npm run dev`. On Vercel, you must redeploy. |
| Setup checklist instead of the page | That's the app telling you what's missing. Read what it lists. |
| Simulator replies take forever | Groq free tier. Expected. Switch to Anthropic to confirm. |
| Meta webhook verification fails | The verify token doesn't match exactly, or the app isn't deployed and reachable at that URL yet. |
| WhatsApp worked yesterday, dead today | Your 24-hour temporary token expired. Get a permanent System User token (section 7.5). |
| Webhook verified but no messages arrive | You didn't subscribe to the `messages` field in Webhook fields. |
| Dashboard pages are empty | There's genuinely no data yet. This app never invents numbers to fill a screen. Create a lead in the Simulator and look again. |
| Supabase suddenly unreachable | Free-tier project paused after 7 days of no database activity. Log in and restore it. |
| Follow-up job returns `503` with a message about `CRON_SECRET` | You haven't set `CRON_SECRET`. It refuses to run unprotected by design. Generate one and set it. |
| Follow-up job returns `503` about `villa_follow_ups` | Migration `0009` hasn't been run. See section 9. |
| Follow-up job returns `401` | The `Authorization: Bearer <secret>` header doesn't match `CRON_SECRET`. On Vercel, confirm the variable is set on the project and redeploy. |
| Follow-ups never send, no errors | Nothing is calling the job. Schedule it — see "Scheduling the follow-up job" in section 10. |
| Follow-ups say "needs manual action" | Usually no approved Meta template is attached, so free text would be rejected outside the 24-hour window. Working as designed — see section 8. |
