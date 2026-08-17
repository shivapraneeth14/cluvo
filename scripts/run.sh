#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-test}"
if [[ "$ENV_NAME" != "test" && "$ENV_NAME" != "prod" ]]; then
  echo "Usage: ./scripts/run.sh [test|prod] [device-id]" >&2
  echo "  device-id: optional flutter -d target (e.g. emulator-5554, chrome, macos)" >&2
  echo "  default: test — run.sh web; emulator runs need the device id or -d" >&2
  exit 1
fi
DEVICE="${2:-}"
if [[ -z "$DEVICE" ]]; then
  DEVICE_FLAGS=()
  shift 1 || true
else
  DEVICE_FLAGS=(-d "$DEVICE")
  shift 2 || true
fi

# Environment values come ONLY from the per-environment define file
# (env.test.json / env.prod.json). Never type values here and never add
# defaults to lib/config.dart — see docs/ENV.md and scripts/check-env-hygiene.sh.
ENV_FILE="env.$ENV_NAME.json"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — copy env.example.json and fill it in" >&2
  exit 1
fi

echo "flutter run ($ENV_NAME${DEVICE:+ / $DEVICE}) using $ENV_FILE ..."
exec flutter run \
  "${DEVICE_FLAGS[@]}" \
  --dart-define-from-file="$ENV_FILE" \
  "$@"
