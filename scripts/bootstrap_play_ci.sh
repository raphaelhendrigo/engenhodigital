#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GCP_PROJECT_ID=""
PLAY_JSON_PATH=""
GITHUB_OWNER=""
GITHUB_REPO=""

KEYSTORE_REL="keystore/engenho-digital-upload.jks"
ALIAS="engenho_digital_upload"
DNAME="CN=Engenho Digital,O=Engenho Digital,C=BR"
VALIDITY_DAYS="10000"

usage() {
  cat <<'USAGE'
Bootstrap Google Play CI/CD for this repo (Buildozer AAB + Fastlane supply) using GitHub Actions.

Preferred mode: keyless auth via Workload Identity Federation (WIF) + GitHub OIDC.
Fallback mode: service account JSON secret (PLAY_SERVICE_ACCOUNT_JSON).

Usage:
  ./scripts/bootstrap_play_ci.sh --gcp-project <PROJECT_ID>
  ./scripts/bootstrap_play_ci.sh --play-json <path-to-service-account.json>

Optional:
  --github-owner <owner>   Override GitHub owner (auto-detected from origin by default)
  --github-repo <repo>     Override GitHub repo  (auto-detected from origin by default)

USAGE
}

while [ "${1:-}" != "" ]; do
  case "$1" in
    --gcp-project)
      GCP_PROJECT_ID="${2:-}"; shift 2 ;;
    --play-json)
      PLAY_JSON_PATH="${2:-}"; shift 2 ;;
    --github-owner)
      GITHUB_OWNER="${2:-}"; shift 2 ;;
    --github-repo)
      GITHUB_REPO="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2 ;;
  esac
done

cd "$REPO_ROOT"

if ! command -v git >/dev/null 2>&1; then
  echo "git not found. Install Git and retry." >&2
  exit 1
fi

origin="$(git remote get-url origin 2>/dev/null || true)"
if [ -z "$origin" ]; then
  echo "Could not read git remote 'origin'." >&2
  exit 1
fi

if [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_REPO" ]; then
  if [[ "$origin" =~ github\.com[:/]+([^/]+)/([^/.]+)(\.git)?$ ]]; then
    GITHUB_OWNER="${GITHUB_OWNER:-${BASH_REMATCH[1]}}"
    GITHUB_REPO="${GITHUB_REPO:-${BASH_REMATCH[2]}}"
  else
    echo "Could not parse GitHub owner/repo from origin URL: $origin" >&2
    exit 1
  fi
fi

REPO_FULL="${GITHUB_OWNER}/${GITHUB_REPO}"
echo "Repo: $REPO_FULL"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh not found. Install GitHub CLI and retry: https://cli.github.com/" >&2
  exit 1
fi

if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "GitHub CLI not authenticated. Starting: gh auth login" >&2
  gh auth login
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found. Install Python 3 and retry." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found. Install Docker and retry." >&2
  exit 1
fi

keystore_pass="$(python3 - <<'PY'
import base64, os
import secrets
raw = secrets.token_bytes(48)
s = base64.b64encode(raw).decode("ascii")
print("".join([c for c in s if c.isalnum()])[:48])
PY
)"
key_pass="$(python3 - <<'PY'
import base64
import secrets
raw = secrets.token_bytes(48)
s = base64.b64encode(raw).decode("ascii")
print("".join([c for c in s if c.isalnum()])[:48])
PY
)"

keystore_abs="$REPO_ROOT/$KEYSTORE_REL"
keystore_dir="$(dirname "$keystore_abs")"
keystore_file="$(basename "$keystore_abs")"
cert_abs="$keystore_dir/$(basename "${keystore_file%.jks}")-cert.pem"
cred_abs="$keystore_dir/$(basename "${keystore_file%.jks}").credentials.local.txt"

mkdir -p "$keystore_dir"

echo "Generating upload keystore (Docker + keytool)..."
image="eclipse-temurin:17-jdk"
docker pull "$image" >/dev/null

docker run --rm \
  -v "${keystore_dir}:/out" \
  "$image" \
  keytool -genkeypair \
    -storetype JKS \
    -keystore "/out/${keystore_file}" \
    -storepass "$keystore_pass" \
    -alias "$ALIAS" \
    -keypass "$key_pass" \
    -dname "$DNAME" \
    -keyalg RSA \
    -keysize 2048 \
    -validity "$VALIDITY_DAYS" >/dev/null

docker run --rm \
  -v "${keystore_dir}:/out" \
  "$image" \
  keytool -export -rfc \
    -alias "$ALIAS" \
    -keystore "/out/${keystore_file}" \
    -storepass "$keystore_pass" \
    -file "/out/$(basename "$cert_abs")" >/dev/null

if [ ! -f "$keystore_abs" ]; then
  echo "Keystore not created: $keystore_abs" >&2
  exit 1
fi
if [ ! -f "$cert_abs" ]; then
  echo "Upload certificate not created: $cert_abs" >&2
  exit 1
fi

cat >"$cred_abs" <<EOF
ANDROID_KEYSTORE_PATH=$keystore_abs
ANDROID_KEYSTORE_PASSWORD=$keystore_pass
ANDROID_KEY_ALIAS=$ALIAS
ANDROID_KEY_PASSWORD=$key_pass
EOF

keystore_b64="$(python3 - <<PY
import base64
from pathlib import Path
p=Path(r"$keystore_abs")
print(base64.b64encode(p.read_bytes()).decode("ascii"))
PY
)"

echo "Setting GitHub Actions secrets (Android signing)..."
cat <<EOF | gh secret set -f - -R "$REPO_FULL" >/dev/null
ANDROID_KEYSTORE_BASE64=$keystore_b64
ANDROID_KEYSTORE_PASSWORD=$keystore_pass
ANDROID_KEY_ALIAS=$ALIAS
ANDROID_KEY_PASSWORD=$key_pass
ANDROID_KEY_ALIAS_PASSWORD=$key_pass
EOF

if [ -n "$GCP_PROJECT_ID" ]; then
  if ! command -v gcloud >/dev/null 2>&1; then
    echo "gcloud not found. Install Google Cloud SDK and retry: https://cloud.google.com/sdk/docs/install" >&2
    exit 1
  fi

  if ! gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>/dev/null | grep -q .; then
    echo "gcloud not authenticated. Starting: gcloud auth login" >&2
    gcloud auth login
  fi
  gcloud config set project "$GCP_PROJECT_ID" >/dev/null

  project_number="$(gcloud projects describe "$GCP_PROJECT_ID" --format="value(projectNumber)")"
  if [ -z "$project_number" ]; then
    echo "Could not resolve projectNumber for project: $GCP_PROJECT_ID" >&2
    exit 1
  fi

  echo "Enabling Android Publisher API (androidpublisher.googleapis.com)..."
  gcloud services enable androidpublisher.googleapis.com --project "$GCP_PROJECT_ID" >/dev/null

  sa_id="gh-play-publisher"
  sa_email="${sa_id}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

  if ! gcloud iam service-accounts describe "$sa_email" --project "$GCP_PROJECT_ID" >/dev/null 2>&1; then
    gcloud iam service-accounts create "$sa_id" --project "$GCP_PROJECT_ID" --display-name "GitHub Play Publisher" >/dev/null
  fi

  pool_id="gh-${GITHUB_REPO,,}"
  pool_id="${pool_id//[^a-z0-9-]/-}"
  pool_id="${pool_id:0:32}"
  provider_id="github"

  if ! gcloud iam workload-identity-pools describe "$pool_id" --project "$GCP_PROJECT_ID" --location global >/dev/null 2>&1; then
    pool_display="GitHub ${GITHUB_REPO}"
    if [ "${#pool_display}" -gt 32 ]; then
      pool_display="${pool_display:0:32}"
    fi
    gcloud iam workload-identity-pools create "$pool_id" \
      --project "$GCP_PROJECT_ID" \
      --location global \
      --display-name "$pool_display" >/dev/null
  fi

  if ! gcloud iam workload-identity-pools providers describe "$provider_id" \
    --project "$GCP_PROJECT_ID" \
    --location global \
    --workload-identity-pool "$pool_id" >/dev/null 2>&1; then
    gcloud iam workload-identity-pools providers create-oidc "$provider_id" \
      --project "$GCP_PROJECT_ID" \
      --location global \
      --workload-identity-pool "$pool_id" \
      --display-name "GitHub OIDC" \
      --issuer-uri "https://token.actions.githubusercontent.com" \
      --attribute-mapping "google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref,attribute.actor=assertion.actor" \
      --attribute-condition "assertion.repository=='${REPO_FULL}'" >/dev/null
  fi

  member="principalSet://iam.googleapis.com/projects/${project_number}/locations/global/workloadIdentityPools/${pool_id}/attribute.repository/${REPO_FULL}"
  gcloud iam service-accounts add-iam-policy-binding "$sa_email" \
    --project "$GCP_PROJECT_ID" \
    --role "roles/iam.workloadIdentityUser" \
    --member "$member" >/dev/null

  provider_resource="projects/${project_number}/locations/global/workloadIdentityPools/${pool_id}/providers/${provider_id}"

  echo "Setting GitHub Actions variables (WIF)..."
  cat <<EOF | gh variable set -f - -R "$REPO_FULL" >/dev/null
GCP_WORKLOAD_IDENTITY_PROVIDER=$provider_resource
GCP_SERVICE_ACCOUNT_EMAIL=$sa_email
EOF
elif [ -n "$PLAY_JSON_PATH" ]; then
  if [ ! -f "$PLAY_JSON_PATH" ]; then
    echo "Service account JSON not found: $PLAY_JSON_PATH" >&2
    exit 1
  fi
  echo "Setting PLAY_SERVICE_ACCOUNT_JSON (fallback mode)..."
  gh secret set PLAY_SERVICE_ACCOUNT_JSON -R "$REPO_FULL" < "$PLAY_JSON_PATH" >/dev/null
else
  echo "Play auth not configured yet." >&2
  echo "Preferred: re-run with --gcp-project <PROJECT_ID> to provision WIF (keyless)." >&2
  echo "Fallback:  re-run with --play-json <path-to-json> to set PLAY_SERVICE_ACCOUNT_JSON." >&2
fi

echo ""
echo "Files generated (keep these OUT of git):"
echo "- Keystore: $keystore_abs"
echo "- Upload cert (PEM): $cert_abs"
echo "- Local credentials (gitignored): $cred_abs"

echo ""
echo "Release command:"
echo "  git tag vX.Y.Z; git push origin vX.Y.Z"

echo ""
echo "ONE-TIME SETUP (Play Console) - inevitable UI steps:"
echo "1) Create the app (if not created yet): https://play.google.com/console"
echo "2) Enable Play App Signing (Setup -> App integrity). If asked for upload key cert, select:"
echo "   $cert_abs"
echo "3) Link a Google Cloud project (Developer account -> API access): https://play.google.com/console/developers/api-access"
if [ -n "${GCP_PROJECT_ID:-}" ]; then
  echo "4) Grant access to the service account in Play Console (API access -> Service accounts -> Grant access):"
  echo "   ${sa_email}"
fi
echo "5) Complete required forms (Store listing, Data safety, Content rating, etc.) before first release."
