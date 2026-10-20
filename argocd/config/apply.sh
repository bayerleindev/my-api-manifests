#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

kubectl patch configmap argocd-cm \
  --namespace argocd \
  --type merge \
  --patch-file "${script_dir}/argocd-cm.patch.yaml"

kubectl patch configmap argocd-rbac-cm \
  --namespace argocd \
  --type merge \
  --patch-file "${script_dir}/argocd-rbac-cm.patch.yaml"

