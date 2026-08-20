import type { Metadata } from "next";
import { LOGIN_ERRORS } from "@/lib/auth";
import { safePath } from "@/lib/form-post";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Sign in — Villa Sales Agent",
  // Nothing here should ever surface in a search result.
  robots: { index: false, follow: false },
};

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; next?: string }>;
}) {
  const { error, next } = await searchParams;

  // Unknown codes fall back to the generic message rather than rendering the
  // raw query value — see LOGIN_ERRORS. The copy is identical whether the
  // password was wrong or the server has no password set at all.
  const message = error ? (LOGIN_ERRORS[error] ?? LOGIN_ERRORS.invalid) : null;

  return (
    <div className="mx-auto max-w-sm py-10">
      <div className="card">
        <h1 className="text-lg font-semibold tracking-tight">Sign in</h1>
        <p className="mt-1 text-sm text-[--color-muted]">
          This console holds customer names, phone numbers and full WhatsApp transcripts. Enter
          the team password to continue.
        </p>

        {message && (
          <div className="mt-4 rounded-lg border border-[--color-gold-500]/30 bg-[--color-gold-soft] p-3 text-sm text-[--color-gold-300]">
            {message}
          </div>
        )}

        <form action="/api/auth/login" method="POST" className="mt-5 space-y-4">
          <input type="hidden" name="next" value={safePath(next, "/")} />

          <label className="block text-sm">
            <span className="label">Password</span>
            <input
              name="password"
              type="password"
              required
              autoFocus
              autoComplete="current-password"
              className="mt-1 w-full rounded-lg border border-[--color-line] bg-white px-3 py-2 text-sm"
            />
          </label>

          <button
            type="submit"
            className="w-full rounded-lg bg-[--color-gold-500] px-4 py-2 text-sm font-medium text-white hover:bg-[--color-gold-600]"
          >
            Sign in
          </button>
        </form>
      </div>
    </div>
  );
}
