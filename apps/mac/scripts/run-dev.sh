#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
export WORKERFLOW_REPO="${WORKERFLOW_REPO:-$ROOT}"
export WORKERFLOW_SHOW_PANEL_ON_LAUNCH="${WORKERFLOW_SHOW_PANEL_ON_LAUNCH:-1}"

cd "$ROOT"
exec swift run --package-path apps/mac WorkerflowMac
