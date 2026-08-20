import type { NextConfig } from "next";

const isProd = process.env.NODE_ENV === "production";

/**
 * Content-Security-Policy.
 *
 * WHY script-src carries 'unsafe-inline' IN PRODUCTION
 * The App Router streams the RSC payload to the browser as a series of inline
 * `self.__next_f.push(...)` <script> tags (39 of them on the dashboard alone).
 * Their contents change per route and per build, so hashes are not workable,
 * and a nonce has to be minted per request — which only middleware can do.
 * Headers declared here are static, so the honest options are 'unsafe-inline'
 * or a broken app. This is the weakest part of the policy, tracked as T8 in
 * security/01-threat-model.md. middleware.ts now exists, which unblocks the
 * real fix: mint a nonce per request there, switch this to
 * `'nonce-<value>' 'strict-dynamic'`, and drop 'unsafe-inline'.
 * The residual risk is bounded by there being no user-controlled HTML sink in
 * the app today (no dangerouslySetInnerHTML anywhere in src/).
 *
 * WHY style-src carries 'unsafe-inline'
 * Tailwind v4 injects a <style> block and several pages use React `style={{}}`
 * attributes for chart bar widths. CSP nonces do not apply to style
 * *attributes*, so removing this would require rewriting those to classes.
 * Style injection is a far weaker primitive than script injection, so this is
 * an accepted tradeoff rather than an outstanding bug.
 */
function contentSecurityPolicy(): string {
  const directives = [
    "default-src 'self'",
    // See the block comment above before touching this line.
    isProd
      ? "script-src 'self' 'unsafe-inline'"
      : // Dev only: webpack HMR and React Refresh eval their module wrappers.
        "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: blob:",
    "font-src 'self' data:",
    // The browser never talks to Supabase directly — db() is service_role and
    // server-only — so every fetch the client makes is same-origin. In dev the
    // HMR socket needs ws:.
    isProd ? "connect-src 'self'" : "connect-src 'self' ws: wss:",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    // Belt and braces with the X-Frame-Options header below: frame-ancestors
    // is the directive modern browsers actually honour.
    "frame-ancestors 'none'",
  ];

  // Would rewrite http://localhost:3000 to https:// and break local dev.
  if (isProd) directives.push("upgrade-insecure-requests");

  return directives.join("; ");
}

const securityHeaders = [
  { key: "Content-Security-Policy", value: contentSecurityPolicy() },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "X-Frame-Options", value: "DENY" },
  {
    key: "Permissions-Policy",
    // microphone=(self): the /whatsapp voice tester records in-browser; a
    // blanket deny turns getUserMedia into an instant NotAllowedError.
    value: "camera=(), microphone=(self), geolocation=(), payment=()",
  },
  { key: "Cross-Origin-Opener-Policy", value: "same-origin" },
];

const nextConfig: NextConfig = {
  // The WhatsApp webhook needs the raw request body to verify Meta's HMAC
  // signature, so it must never be statically optimised or cached.
  experimental: {
    serverActions: { bodySizeLimit: "2mb" },
  },

  async redirects() {
    // The dashboard lives at /. Everyone types /admin at least once.
    return [{ source: "/admin", destination: "/", permanent: false }];
  },

  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          ...securityHeaders,
          // HSTS is meaningless over plain http and actively harmful in dev:
          // the browser would pin localhost to https for two years. Production
          // only, where the deployment terminates TLS.
          ...(isProd
            ? [
                {
                  key: "Strict-Transport-Security",
                  value: "max-age=63072000; includeSubDomains; preload",
                },
              ]
            : []),
        ],
      },
    ];
  },
};

export default nextConfig;
