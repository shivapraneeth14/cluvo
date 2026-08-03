#!/usr/bin/env bash
# check-env-hygiene.sh — permanent CI regression check.
#
# Fails if any hardcoded environment value or environment default is
# introduced into compiled source (lib/). Environment values must be injected
# ONLY at build time (--dart-define from scripts/run.sh, CI secrets, Vercel
# env vars). scripts/ is the approved injection point and is intentionally
# not scanned.
#
# Usage: ./scripts/check-env-hygiene.sh
set -euo pipefail
cd "$(dirname "$0")/.."

SCAN_DIR="lib"
FAILURES=0

fail() {
  echo "FAIL [env-hygiene] $1" >&2
  FAILURES=1
}

# 1. String.fromEnvironment(... defaultValue: ...) — banned env defaults.
if rg -n 'defaultValue\s*:' "$SCAN_DIR" -g '*.dart' 2>/dev/null; then
  fail "String.fromEnvironment defaultValue found — env defaults are banned (see docs/ENV.md)."
fi

# 2. String.fromEnvironment outside lib/config.dart.
if rg -l 'String\.fromEnvironment' "$SCAN_DIR" -g '*.dart' 2>/dev/null \
  | rg -v '^lib/config\.dart$'; then
  fail "String.fromEnvironment used outside lib/config.dart."
fi

# 3. Hardcoded Supabase project URLs.
if rg -n '[a-z0-9]{20}\.supabase\.co|https://[a-z0-9-]+\.supabase\.co' "$SCAN_DIR" -g '*.dart' 2>/dev/null; then
  fail "Hardcoded Supabase URL found."
fi

# 4. Supabase publishable keys.
if rg -n 'sb_publishable_[A-Za-z0-9_]+' "$SCAN_DIR" -g '*.dart' 2>/dev/null; then
  fail "Hardcoded Supabase publishable key found."
fi

# 5. Hardcoded JWTs (Supabase anon keys, service tokens, etc.).
if rg -n 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}' "$SCAN_DIR" -g '*.dart' 2>/dev/null; then
  fail "Hardcoded JWT found."
fi

# 6. Payment keys (Razorpay test/live).
if rg -n 'rzp_(test|live)_[A-Za-z0-9]+' "$SCAN_DIR" -g '*.dart' 2>/dev/null; then
  fail "Hardcoded Razorpay key found."
fi

# 7. Common API key patterns (future integrations: Maps, Firebase, Stripe,
#    AWS, OpenAI-style, etc. — add new provider patterns here as needed).
if rg -n \
  -e 'AIza[0-9A-Za-z_-]{20,}' \
  -e 'pk_(live|test)_[A-Za-z0-9]+' \
  -e 'sk_(live|test)_[A-Za-z0-9]+' \
  -e 'sk-[A-Za-z0-9]{20,}' \
  -e 'AKIA[0-9A-Z]{16}' \
  -e 'SG\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}' \
  "$SCAN_DIR" -g '*.dart' 2>/dev/null; then
  fail "Potential hardcoded API key found."
fi

if [[ "$FAILURES" -ne 0 ]]; then
  echo "env-hygiene FAILED: remove the flagged values; inject them via build-time defines instead." >&2
  exit 1
fi

echo "env-hygiene OK: no hardcoded environment values or defaults in $SCAN_DIR."
