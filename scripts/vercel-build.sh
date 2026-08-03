#!/usr/bin/env bash
# Vercel build entrypoint (referenced by the Vercel project's Build Command:
#   bash scripts/vercel-build.sh
# so the full command stays under Vercel's 256-char limit and versioned in git).
#
# PERMANENT RULE (docs/ENV.md): environment values come ONLY from build-time
# injection. SUPABASE_* come from Vercel project env vars; CLOUDINARY_* are
# also Vercel env vars (identical in both environments, injected per project).
# No value is hardcoded here and none lives in source code.
set -euo pipefail

flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=CLOUDINARY_CLOUD_NAME="$CLOUDINARY_CLOUD_NAME" \
  --dart-define=CLOUDINARY_UPLOAD_PRESET="$CLOUDINARY_UPLOAD_PRESET"
