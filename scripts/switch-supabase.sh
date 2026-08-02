#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-}"
if [[ "$ENV_NAME" != "test" && "$ENV_NAME" != "prod" ]]; then
  echo "Usage: ./scripts/switch-supabase.sh <test|prod>" >&2
  exit 1
fi

if [[ "$ENV_NAME" == "test" ]]; then
  URL="https://ofvfasdgdwkehdcjugnf.supabase.co"
  ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9mdmZhc2RnZHdrZWhkY2p1Z25mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU1OTkxNDcsImV4cCI6MjEwMTE3NTE0N30.oaxiWOFClGzO1WqBihmLoZV69soVpfMv6gtUMnMakxY"
else
  URL="https://vdxspyumkvwawmqwfkzr.supabase.co"
  ANON="sb_publishable_phag39UwA63y44O1703IkA_Ky6ebjwV"
fi

echo "Flutter ($ENV_NAME): $URL"
echo
echo "Local run:"
echo "  flutter run -d chrome --dart-define=SUPABASE_URL=$URL --dart-define=SUPABASE_ANON_KEY=$ANON"
echo
echo "Web release build:"
echo "  flutter build web --release --dart-define=SUPABASE_URL=$URL --dart-define=SUPABASE_ANON_KEY=$ANON"
