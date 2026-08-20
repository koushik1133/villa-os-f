# Dependency audit

Run 2026-08-19 with `npm audit --audit-level=high`.

```
info 0 | low 0 | moderate 0 | high 3 | critical 0        (153 deps: 74 prod, 44 dev, 59 optional)
```

**Nothing was changed.** All three findings require a Next.js 15 → 16 major
version bump, which is out of scope for a security pass and would risk the
build. Details and the surgical alternative below.

---

## Findings

### 1. `postcss` ≤ 8.5.22 — high

| Advisory | Issue |
|---|---|
| GHSA-qx2v-qp2m-jg93 | XSS via unescaped `</style>` in CSS stringify output |
| GHSA-6g55-p6wh-862q | Arbitrary file read via attacker-controlled `sourceMappingURL` |
| GHSA-fxqj-rqcc-2cmp | Incomplete fix of the above — reads arbitrary `.map` files when `from` is unset |
| GHSA-r28c-9q8g-f849 | Path traversal in previous-source-map auto-loading |

Installed: `next@15.5.23 → postcss@8.4.31` (vulnerable, nested).
Also present: `@tailwindcss/postcss@4.3.3 → postcss@8.5.26` (**not** vulnerable —
this is the current release and the one that actually compiles the app's CSS).

**Exploitability here: low.** Every one of these requires PostCSS to process
*attacker-controlled CSS*. The only stylesheet in this project is
`src/app/globals.css`, which is first-party, and PostCSS runs at build time on
the developer's machine — it is not on any request path. An attacker would
already need commit access, at which point CSS parsing is not the problem.

### 2. `sharp` < 0.35.0 — high

GHSA-f88m-g3jw-g9cj — inherited libvips CVEs: CVE-2026-33327, CVE-2026-33328,
CVE-2026-35590, CVE-2026-35591.

Installed: `next@15.5.23 → sharp@0.34.5` (vulnerable, nested).

**Exploitability here: low, but it is genuinely reachable — worth stating
precisely, because the obvious first assumption is wrong.**

`next/image` is never imported anywhere in `src/`, which makes it tempting to
call sharp dead code. It is not. Next serves the `/_next/image` optimizer
endpoint regardless of whether the app uses the component, and it was confirmed
live against the production build:

```
GET /_next/image?url=%2FGlentree%20Serenity.jpg&w=640&q=75   → 200 image/jpeg   (sharp ran)
GET /_next/image?url=https%3A%2F%2Fexample.com%2Fa.jpg&...   → 400              (rejected)
```

So sharp does execute on request. What saves this is that it can only ever be
pointed at **first-party bytes**:

- Remote URLs are rejected with 400 because no `images.remotePatterns` is
  configured. Do not add one without revisiting this finding.
- There is no upload path in the app. The `formData()` calls across the API
  routes parse scalar form fields (`Object.fromEntries`) — no `File` handling,
  no Supabase Storage writes, no `fs` writes.
- Inbound WhatsApp media is never fetched. `src/lib/whatsapp/types.ts` reads
  `image.caption` / `document.caption` text only; media IDs are never
  downloaded.

The libvips CVEs need a *malicious image* to parse. The only images sharp can
reach are the six marketing JPEGs committed to `public/`. Risk accepted.

---

## Why nothing was fixed

`npm audit fix` without `--force` was dry-run and is a **no-op** — both
vulnerable copies are nested dependencies that `next@15.5.23` pins itself, so
npm cannot lift them:

```
villa-whatsapp-agent
├── @tailwindcss/postcss@4.3.3 → postcss@8.5.26   (already safe)
└── next@15.5.23 ─┬→ postcss@8.4.31               (vulnerable, pinned by next)
                  └→ sharp@0.34.5                 (vulnerable, pinned by next)
```

`next@15.5.23` is already the newest 15.x release, so there is no patch
available on the current major line.

`npm audit fix --force` resolves all three by installing **`next@16.3.1`** — a
major version bump across two majors. Per the brief, major bumps that could
break the build are out of scope, and a Next 15 → 16 migration is a project in
its own right (App Router API changes, async request APIs, caching semantics).
Not attempted.

## Recommended fix (owner: whoever owns `package.json`)

`package.json` is not owned by this pass, so this is a recommendation, not a
change. The surgical option is an npm `overrides` block, which forces the safe
versions without touching the Next major:

```json
"overrides": {
  "postcss": "^8.5.26",
  "sharp": "^0.35.3"
}
```

Caveats before anyone applies this blind:

- `postcss` 8.4.31 → 8.5.26 is a patch/minor move within the same major and is
  low risk.
- `sharp` 0.34.5 → 0.35.3 is a minor bump of a **native** module that Next pins
  deliberately. It may work, but it must be validated with a clean
  `rm -rf node_modules .next && npm install && npm run build`, plus a request to
  `/_next/image` to confirm the optimizer still returns 200.
- Re-run `npm audit --audit-level=high` afterwards and expect 0.

Given both findings are low-exploitability in this application, the honest
recommendation is to schedule the Next 16 upgrade properly rather than rush an
override before launch. Neither issue is a launch blocker; both are well below
the credential-exposure and authentication items in `01-threat-model.md`, which
are.

## Re-check command

```
npm audit --audit-level=high
npm ls postcss sharp --all
```
