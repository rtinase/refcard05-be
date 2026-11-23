#!/usr/bin/env bash
# Überträgt die temporären Learner-Lab-Credentials als GitHub Secrets in beide Repos.
# Muss bei JEDER neuen Lab-Session erneut ausgeführt werden (Tokens laufen nach ca. 4 h ab).
#
# Ablauf bei neuer Session:
#   1. Learner Lab starten -> "AWS Details" -> "AWS CLI: Show"
#   2. Die drei Zeilen in ~/.aws/credentials unter [default] einfügen
#   3. ./infra/set-github-secrets.sh
#
# Voraussetzung: gh ist angemeldet (gh auth status). Die Werte werden über stdin übergeben,
# erscheinen also weder in der Prozessliste noch im Shell-Verlauf.
set -euo pipefail

OWNER=${GITHUB_OWNER:-rtinase}
REPOS=("refcard05-fe" "refcard05-be")
CRED_FILE=${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}

# Wert eines Schlüssels aus dem Abschnitt [default] lesen
val() {
  awk -v k="$1" -F= '/^\[/{in_default=($0=="[default]")} in_default && $1==k {sub(/^[^=]*=/,""); print; exit}' "$CRED_FILE"
}

for key in aws_access_key_id aws_secret_access_key aws_session_token; do
  [[ -n "$(val "$key")" ]] || { echo "Fehlt in $CRED_FILE: $key" >&2; exit 1; }
done

# Vorher prüfen, ob die Credentials noch gültig sind
aws sts get-caller-identity --query Arn --output text >/dev/null ||
  { echo "Credentials ungültig oder abgelaufen." >&2; exit 1; }

for repo in "${REPOS[@]}"; do
  printf '%s' "$(val aws_access_key_id)"     | gh secret set AWS_ACCESS_KEY_ID     -R "$OWNER/$repo"
  printf '%s' "$(val aws_secret_access_key)" | gh secret set AWS_SECRET_ACCESS_KEY -R "$OWNER/$repo"
  printf '%s' "$(val aws_session_token)"     | gh secret set AWS_SESSION_TOKEN     -R "$OWNER/$repo"
done

echo "Secrets in ${REPOS[*]} aktualisiert."
