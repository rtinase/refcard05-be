#!/usr/bin/env bash
# Setzt die (nicht geheimen) GitHub-Variablen, die die Deploy-Jobs brauchen.
# Geheim sind nur die AWS-Credentials und das DB-Passwort; letzteres bleibt in Secrets Manager.
set -euo pipefail
export AWS_PAGER=""

# shellcheck disable=SC1091
source "$(dirname "$0")/state.env"
OWNER=${GITHUB_OWNER:-rtinase}
RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier refcard05-db \
  --query 'DBInstances[0].Endpoint.Address' --output text)

setvar() { gh variable set "$2" -R "$OWNER/$1" --body "$3" >/dev/null; echo "$1: $2"; }

# Backend
setvar refcard05-be RDS_ENDPOINT "$RDS_ENDPOINT"
setvar refcard05-be S3_BUCKET "$BUCKET"
setvar refcard05-be DB_SECRET_ARN "$SECRET_ARN"
setvar refcard05-be FE_URL "http://${DNS_FE}"
setvar refcard05-be BE_URL "http://${DNS_BE}"
# Frontend (Vite bettet die Backend-URL beim Build ein)
setvar refcard05-fe VITE_API_BASE_URL "http://${DNS_BE}/"
setvar refcard05-fe VITE_IMGS "items"
setvar refcard05-fe FE_URL "http://${DNS_FE}"
