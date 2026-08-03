#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-test}"
if [[ "$ENV_NAME" != "test" && "$ENV_NAME" != "prod" ]]; then
  echo "Usage: ./scripts/run.sh [test|prod] (default: test)" >&2
  exit 1
fi
shift || true

# NOTE: environment values are injected ONLY here (build time). Never add
# defaults to lib/config.dart — see docs/ENV.md and scripts/check-env-hygiene.sh.
if [[ "$ENV_NAME" == "test" ]]; then
  URL="https://ofvfasdgdwkehdcjugnf.supabase.co"
  ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9mdmZhc2RnZHdrZWhkY2p1Z25mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU1OTkxNDcsImV4cCI6MjEwMTE3NTE0N30.oaxiWOFClGzO1WqBihmLoZV69soVpfMv6gtUMnMakxY"
else
  URL="https://vdxspyumkvwawmqwfkzr.supabase.co"
  ANON="sb_publishable_phag39UwA63y44O1703IkA_Ky6ebjwV"
fi

CLOUD_NAME="djz0pypu1"
UPLOAD_PRESET="cluvo_preset"

echo "flutter run ($ENV_NAME) ..."
exec flutter run \
  --dart-define=SUPABASE_URL=$URL \
  --dart-define=SUPABASE_ANON_KEY=$ANON \
  --dart-define=CLOUDINARY_CLOUD_NAME=$CLOUD_NAME \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=$UPLOAD_PRESET \
  "$@"
