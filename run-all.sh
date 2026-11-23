#!/usr/bin/env bash
# Runs every read-only check and writes one text file per script into ./output.
# Usage: SQLSERVER=localhost SQLUSER=sa SQLPASSWORD='...' DATABASE=YourDb bash run-all.sh
#        (omit SQLUSER/SQLPASSWORD to use Windows/Kerberos auth with -E)
set -euo pipefail
cd "$(dirname "$0")"
SERVER="${SQLSERVER:-localhost}"; DB="${DATABASE:-master}"
AUTH=(-E); [[ -n "${SQLUSER:-}" ]] && AUTH=(-U "$SQLUSER" -P "${SQLPASSWORD:-}")
mkdir -p output
for f in scripts/*.sql; do
  out="output/$(basename "${f%.sql}").txt"
  echo "Running $f -> $out"
  sqlcmd -S "$SERVER" "${AUTH[@]}" -C -d "$DB" -i "$f" -W -s "|" -o "$out"
done
echo "Done. Look for CRITICAL / WARN in output/*.txt"
