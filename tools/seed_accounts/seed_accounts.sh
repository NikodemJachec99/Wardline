#!/usr/bin/env bash
# Creates the fictional test accounts (issue #18) with their profiles, through
# the Supabase Admin API. SIMULATION ONLY: names are fictional.
#
#   nurse1   Anna Nowak       nurse   INT   Day shift 07:00–19:00
#   nurse2   Marek Kowal      nurse   ER
#   doctor1  Dr Piotr Zając   doctor  INT   08:00–16:00
#   doctor2  Dr Julia Wróbel  doctor  CAR
#   admin    Katarzyna Wilk   admin
#
# Needs curl and jq. Configuration (never commit it; .env.* is git-ignored):
#   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY   local: taken from `supabase status`
#   WARDLINE_PASSWORD                          one password for all accounts, or
#   NURSE1_PASSWORD, NURSE2_PASSWORD, ...      one per account
# Put them in tools/seed_accounts/.env.local or export them. Safe to re-run:
# existing accounts get their password and profile updated.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$here/.env.local" ]; then
  set -a; . "$here/.env.local"; set +a
fi

if [ -z "${SUPABASE_URL:-}" ] && command -v supabase >/dev/null 2>&1; then
  eval "$(supabase status -o env 2>/dev/null | grep -E '^(API_URL|SERVICE_ROLE_KEY)=')"
  SUPABASE_URL="${API_URL:-}"
  SUPABASE_SERVICE_ROLE_KEY="${SERVICE_ROLE_KEY:-}"
fi
: "${SUPABASE_URL:?Set SUPABASE_URL (or run supabase start)}"
: "${SUPABASE_SERVICE_ROLE_KEY:?Set SUPABASE_SERVICE_ROLE_KEY (never put it in the app or the repo)}"
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

key="$SUPABASE_SERVICE_ROLE_KEY"
auth=(-H "apikey: $key" -H "Authorization: Bearer $key" -H "Content-Type: application/json")

# Departments that exist, so home_location never breaks the foreign key.
locations="$(curl -fsS "${auth[@]}" "$SUPABASE_URL/rest/v1/locations?select=id" | jq -r '.[].id')"

accounts=(
  "nurse1|Anna Nowak|nurse|INT|Day shift 07:00–19:00"
  "nurse2|Marek Kowal|nurse|ER|"
  "doctor1|Dr Piotr Zając|doctor|INT|08:00–16:00"
  "doctor2|Dr Julia Wróbel|doctor|CAR|"
  "admin|Katarzyna Wilk|admin||"
)

for row in "${accounts[@]}"; do
  IFS='|' read -r login name role home shift <<<"$row"
  email="$login@wardline.test"
  var="$(echo "$login" | tr '[:lower:]' '[:upper:]')_PASSWORD"
  password="${!var:-${WARDLINE_PASSWORD:-}}"
  if [ -z "$password" ]; then
    echo "Missing $var or WARDLINE_PASSWORD" >&2
    exit 1
  fi

  body="$(jq -n --arg e "$email" --arg p "$password" '{email: $e, password: $p, email_confirm: true}')"
  created="$(curl -sS "${auth[@]}" -X POST "$SUPABASE_URL/auth/v1/admin/users" -d "$body")"
  id="$(jq -r '.id // empty' <<<"$created")"
  if [ -z "$id" ]; then
    # Already registered: find it and reset the password.
    id="$(curl -fsS "${auth[@]}" "$SUPABASE_URL/auth/v1/admin/users?per_page=1000" |
      jq -r --arg e "$email" '.users[] | select(.email == $e) | .id')"
    [ -n "$id" ] || { echo "Could not create $email: $created" >&2; exit 1; }
    curl -fsS "${auth[@]}" -X PUT "$SUPABASE_URL/auth/v1/admin/users/$id" \
      -d "$(jq -n --arg p "$password" '{password: $p}')" >/dev/null
  fi

  if [ -n "$home" ] && ! grep -qx "$home" <<<"$locations"; then
    home=""
  fi
  profile="$(jq -n --arg id "$id" --arg n "$name" --arg r "$role" --arg h "$home" --arg s "$shift" \
    '{id: $id, full_name: $n, role: $r,
      home_location: (if $h == "" then null else $h end),
      shift_label: (if $s == "" then null else $s end)}')"
  curl -fsS "${auth[@]}" -H "Prefer: resolution=merge-duplicates" \
    -X POST "$SUPABASE_URL/rest/v1/profiles?on_conflict=id" -d "$profile" >/dev/null
  echo "ok  $email  ($role${home:+, $home})"
done
