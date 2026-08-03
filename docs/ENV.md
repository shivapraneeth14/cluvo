# Environment Configuration — Cluvo Flutter (mobile + web)

## Permanent rule

> Never introduce environment-specific defaults or hardcoded configuration
> into source code. All environment-specific values must be supplied through
> build-time environment variables or deployment secrets. Any future
> integration (payments, maps, analytics, storage, notifications, AI
> providers, etc.) must follow this architecture.

`lib/config.dart` has **no environment default by design** — every build must
explicitly pass `--dart-define` values, or the app will refuse to start
(`AppConfig.ensureConfigured()` throws a clear `StateError`). This is
intentional and must never be changed back to a default value. It is enforced
permanently by `scripts/check-env-hygiene.sh` (CI job `env-hygiene`) and the
fail-fast test in `test/widget_test.dart`.

The selected environment is **never** derived from source code, branch, or
merge history — only from build-time configuration.

## Environment variables

| Variable | Required | Notes |
|---|---|---|
| `SUPABASE_URL` | Yes | `https://<ref>.supabase.co` |
| `SUPABASE_ANON_KEY` | Yes | anon / publishable client key |
| `CLOUDINARY_CLOUD_NAME` | Yes | image uploads |
| `CLOUDINARY_UPLOAD_PRESET` | Yes | image uploads |
| `RAZORPAY_KEY_ID` | Optional | payments; app degrades gracefully when absent (web payments intentionally disabled) |

## Build commands (single source of truth)

### Local dev (TEST)
```
./scripts/run.sh              # TEST environment (default)
./scripts/run.sh prod         # PROD environment
./scripts/run.sh test emulator-5554   # TEST on a specific device (emulator, chrome, macos, …)
./scripts/switch-supabase.sh test|prod   # prints the exact command
```
The Android Studio run config (`main_dart.xml`, gitignored) is preconfigured
with TEST defines; a fresh clone must use `scripts/run.sh` (or add the defines
to the run config) — an unconfigured run shows the fail-fast error by design.

**Android Studio staleness:** AS loads `.idea/runConfigurations/main_dart.xml`
once at project open and caches it in memory — edits to the XML while the IDE
is running are ignored. If Run ever launches without defines (fail-fast
screen), fix it in the IDE: Run → Edit Configurations → "main.dart" → set
"Additional run args" to the TEST defines → Apply (UI edits persist to both
memory and disk). Never add defaults to source as a workaround.

Equivalent raw command (TEST):
```
flutter run \
  --dart-define=SUPABASE_URL=https://ofvfasdgdwkehdcjugnf.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<TEST anon key> \
  --dart-define=CLOUDINARY_CLOUD_NAME=djz0pypu1 \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=cluvo_preset
```

### Production release build (Play Store / App Store) — REQUIRED COMMAND
Never run `flutter build ...` without defines. This is the only sanctioned
production release command:

```
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://vdxspyumkvwawmqwfkzr.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_phag39UwA63y44O1703IkA_Ky6ebjwV \
  --dart-define=CLOUDINARY_CLOUD_NAME=djz0pypu1 \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=cluvo_preset
```
(For iOS: `flutter build ipa --release` with the same defines. Add
`--dart-define=RAZORPAY_KEY_ID=<PROD key>` only when mobile payments are
enabled for a release.)

### Production web (Vercel)
Deployed automatically from `main`. Vercel project env vars (`SUPABASE_URL`,
`SUPABASE_ANON_KEY`, `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_UPLOAD_PRESET` —
PROD values for Production scope, TEST values for Preview scope) are read by
the build entrypoint `scripts/vercel-build.sh` (referenced by the Vercel
Build Command) and mapped to `--dart-define`. No values live in source.

## CI/CD

- `build-web` job passes per-branch defines: `main` → `SUPABASE_URL_PROD` /
  `SUPABASE_ANON_KEY_PROD` secrets, `dev` → `_TEST` secrets.
- `test` job runs without defines — the fail-fast test proves the app refuses
  to start when configuration is missing.
- `env-hygiene` job fails the build if any hardcoded env value or
  `defaultValue` is introduced.

## Adding a future integration (Maps, Firebase, Analytics, AI, …)

1. Add `static const x = String.fromEnvironment('X');` to `lib/config.dart`
   (no default value).
2. Add `X` to `missingRequired()` if the app must refuse to start without it
   (or handle absence gracefully in the feature code if optional).
3. Extend `scripts/run.sh` and this file with the value.
4. Add the provider's key pattern to `scripts/check-env-hygiene.sh`.
5. Add the secret/define at every injection point (CI secrets, Vercel env).
