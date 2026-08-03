# Cluvo (mobile + web app)

Flutter app for Cluvo — event discovery, registration, and payments (Razorpay).
Same codebase builds for Android/iOS (native Razorpay SDK via `razorpay_flutter`)
and web (Razorpay Checkout.js via `lib/services/razorpay_web.dart`).

## Configuration

All environment values are compile-time `--dart-define` overrides. There are
**no defaults in source code** — a build without explicit defines refuses to
start. See `docs/ENV.md` for the permanent rule, the full variable inventory,
and the sanctioned release commands.

| Variable | Purpose |
|---|---|
| `SUPABASE_URL` | Supabase project URL (required) |
| `SUPABASE_ANON_KEY` | Supabase anon/publishable key (required) |
| `RAZORPAY_KEY_ID` | Payments (optional; app degrades gracefully) |
| `CLOUDINARY_CLOUD_NAME` | Image uploads (required) |
| `CLOUDINARY_UPLOAD_PRESET` | Image uploads (required) |

Local run (recommended):

```
./scripts/run.sh              # TEST environment
./scripts/run.sh prod         # PROD environment
./scripts/switch-supabase.sh <test|prod>   # prints the exact command
```

## Web build

```
./scripts/run.sh prod   # or the full raw command in docs/ENV.md
```

Deploy output: `build/web` (Vercel: Framework "Other", Install clones the pinned
Flutter SDK, Output Directory `build/web`). `vercel.json` provides SPA rewrites
and no-stale-cache headers for `main.dart.js` / the service worker. Production
env values are injected by Vercel environment variables; previews use
TEST-scoped variables.

## CI

`.github/workflows/ci.yml` runs `flutter analyze`, environment hygiene
(`scripts/check-env-hygiene.sh`), a define-passing `flutter build web --release`
(per-branch TEST/PROD secrets), a define-less `flutter test` (fail-fast guard),
and a TruffleHog secret scan. Pinned to Flutter 3.44.0.
