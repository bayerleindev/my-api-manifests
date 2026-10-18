#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARDS_DIR="${SCRIPT_DIR}/dashboards"
OUTPUT_FILE="${SCRIPT_DIR}/kustomization.yaml"
TEMP_FILE="$(mktemp)"

cleanup() {
  rm -f "${TEMP_FILE}"
}
trap cleanup EXIT

DASHBOARD_LIST="$(find "${DASHBOARDS_DIR}" -type f -name '*.json' | LC_ALL=C sort)"

if [[ -z "${DASHBOARD_LIST}" ]]; then
  echo "Nenhum dashboard JSON encontrado em ${DASHBOARDS_DIR}." >&2
  exit 1
fi

dashboard_count=0
while IFS= read -r dashboard; do
  jq empty "${dashboard}" >/dev/null
  dashboard_count=$((dashboard_count + 1))
done <<< "${DASHBOARD_LIST}"

printf '%s\n' \
  'apiVersion: kustomize.config.k8s.io/v1beta1' \
  'kind: Kustomization' \
  '' \
  'namespace: monitoring' \
  '' \
  'generatorOptions:' \
  '  disableNameSuffixHash: true' \
  '  labels:' \
  '    grafana_dashboard: "1"' \
  '' \
  'configMapGenerator:' \
  '  - name: grafana-custom-dashboards' \
  '    files:' > "${TEMP_FILE}"

while IFS= read -r dashboard; do
  relative_path="${dashboard#"${SCRIPT_DIR}/"}"
  printf '      - %s\n' "${relative_path}" >> "${TEMP_FILE}"
done <<< "${DASHBOARD_LIST}"

mv "${TEMP_FILE}" "${OUTPUT_FILE}"
trap - EXIT

echo "${OUTPUT_FILE} atualizado com ${dashboard_count} dashboard(s)."
