# Cluvo (mobile + web app)

Flutter app for Cluvo — event discovery, registration, and payments (Razorpay).
Same codebase builds for Android/iOS (native Razorpay SDK via `razorpay_flutter`)
and web (Razorpay Checkout.js via `lib/services/razorpay_web.dart`).

## Configuration

All values are compile-time `--dart-define` overrides; sane test-mode defaults
are baked into `lib/config.dart`:

```
SUPABASE_URL
SUPABASE_ANON_KEY
RAZORPAY_KEY_ID
CLOUDINARY_CLOUD_NAME
CLOUDINARY_UPLOAD_PRESET
```

Local run: `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`

## Web build

```
flutter build web --release
```

Deploy output: `build/web` (Vercel: Framework "Other", Install clones the pinned
Flutter SDK, Output Directory `build/web`). `vercel.json` provides SPA rewrites
and no-stale-cache headers for `main.dart.js` / the service worker.

## CI

`.github/workflows/ci.yml` runs `flutter analyze`, `flutter build web --release`,
`flutter test`, and a TruffleHog secret scan. Pinned to Flutter 3.44.0.
