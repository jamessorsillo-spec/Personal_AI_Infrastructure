#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# DBR Account Decks Review Pipeline — One-Command Deploy Script
###############################################################################

PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="us-east4"
SERVICE_NAME="dbr-review-pipeline"
SERVICE_ACCOUNT_NAME="dbr-review-sa"
SECRET_NAME="claude-api-key"
SCHEDULER_JOB_NAME="dbr-weekly-review"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

command -v gcloud >/dev/null 2>&1 || error "gcloud CLI not found. Install: https://cloud.google.com/sdk/docs/install"

if [[ -z "$PROJECT_ID" ]]; then
    echo ""
    echo "Enter your GCP Project ID (e.g. dbr-review-pipeline-123456):"
    read -r PROJECT_ID
    [[ -z "$PROJECT_ID" ]] && error "Project ID is required."
    IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"
fi

info "Using project: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"

info "Enabling required GCP APIs..."
gcloud services enable \
    run.googleapis.com \
    cloudscheduler.googleapis.com \
    secretmanager.googleapis.com \
    cloudbuild.googleapis.com \
    containerregistry.googleapis.com \
    slides.googleapis.com \
    drive.googleapis.com \
    gmail.googleapis.com \
    iam.googleapis.com \
    --quiet

SA_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
    info "Service account $SA_EMAIL already exists."
else
    info "Creating service account: $SERVICE_ACCOUNT_NAME"
    gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
        --display-name="DBR Review Pipeline SA" \
        --quiet
fi

info "Granting IAM roles to service account..."
for role in \
    roles/secretmanager.secretAccessor \
    roles/run.invoker; do
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SA_EMAIL" \
        --role="$role" \
        --quiet >/dev/null
done

if gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" &>/dev/null; then
    info "Secret '$SECRET_NAME' already exists."
    echo "  To update it: gcloud secrets versions add $SECRET_NAME --data-file=-"
else
    echo ""
    echo "Paste your Claude (Anthropic) API key, then press Enter:"
    read -rs CLAUDE_KEY
    [[ -z "$CLAUDE_KEY" ]] && error "Claude API key is required."
    echo -n "$CLAUDE_KEY" | gcloud secrets create "$SECRET_NAME" \
        --replication-policy="automatic" \
        --data-file=- \
        --quiet
    info "Secret '$SECRET_NAME' created."
fi

info "Building container image via Cloud Build..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
gcloud builds submit "$SCRIPT_DIR" \
    --tag "$IMAGE_NAME" \
    --quiet

info "Deploying to Cloud Run..."
gcloud run deploy "$SERVICE_NAME" \
    --image "$IMAGE_NAME" \
    --region "$REGION" \
    --platform managed \
    --no-allow-unauthenticated \
    --service-account "$SA_EMAIL" \
    --set-env-vars "GCP_PROJECT_ID=$PROJECT_ID" \
    --memory 512Mi \
    --timeout 900 \
    --max-instances 1 \
    --quiet

SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
    --region "$REGION" \
    --format="value(status.url)")
info "Cloud Run service URL: $SERVICE_URL"

info "Setting up Cloud Scheduler (every Friday at 8am ET)..."
gcloud scheduler jobs delete "$SCHEDULER_JOB_NAME" \
    --location="$REGION" --quiet 2>/dev/null || true

gcloud scheduler jobs create http "$SCHEDULER_JOB_NAME" \
    --location="$REGION" \
    --schedule="0 8 * * 5" \
    --time-zone="America/New_York" \
    --http-method=POST \
    --uri="${SERVICE_URL}/" \
    --oidc-service-account-email="$SA_EMAIL" \
    --oidc-token-audience="$SERVICE_URL" \
    --attempt-deadline=900s \
    --quiet

echo ""
echo "============================================================"
info "Deployment complete!"
echo ""
echo "  Cloud Run service:  $SERVICE_URL"
echo "  Scheduler job:      $SCHEDULER_JOB_NAME (Fridays 8am ET)"
echo "  Service account:    $SA_EMAIL"
echo ""
echo "  To test now:"
echo "    gcloud scheduler jobs run $SCHEDULER_JOB_NAME --location=$REGION"
echo ""
echo "  To view logs:"
echo "    gcloud run services logs read $SERVICE_NAME --region=$REGION --limit=50"
echo "============================================================"
