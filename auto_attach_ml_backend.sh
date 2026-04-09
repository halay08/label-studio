#!/bin/bash
# auto_attach_ml_backend.sh
# Keep new UI-created projects connected to ML backend automatically.

set -euo pipefail

LS_URL="${LABEL_STUDIO_URL:-http://localhost:8080}"
ML_BACKEND_URL="${AUTO_ATTACH_ML_BACKEND_URL:-http://sphere-ai-sam-backend:9090}"
ML_BACKEND_TITLE="${AUTO_ATTACH_ML_BACKEND_TITLE:-SphereAI SAM Backend}"
POLL_INTERVAL="${AUTO_ATTACH_POLL_INTERVAL:-5}"
LS_PYTHON="/label-studio/.venv/bin/python"
LS_MANAGE_DIR="/label-studio/label_studio"

if [ -z "${ML_BACKEND_URL}" ]; then
  echo "INFO: [auto_attach_ml_backend] AUTO_ATTACH_ML_BACKEND_URL empty, skipping auto-attach."
  exit 0
fi

echo "INFO: [auto_attach_ml_backend] Waiting for Label Studio at ${LS_URL} ..."
until curl -sf "${LS_URL}/health" | grep -q "UP" 2>/dev/null; do
  sleep 2
done
echo "INFO: [auto_attach_ml_backend] Label Studio is ready. Watching projects..."

cd "$LS_MANAGE_DIR"
while true; do
  DJANGO_SETTINGS_MODULE=core.settings.label_studio \
  AUTO_ATTACH_ML_BACKEND_URL="${ML_BACKEND_URL}" \
  AUTO_ATTACH_ML_BACKEND_TITLE="${ML_BACKEND_TITLE}" \
  "$LS_PYTHON" - <<'PYEOF'
import os
import warnings

warnings.filterwarnings("ignore")

import django

django.setup()

from ml.models import MLBackend
from projects.models import Project

backend_url = os.environ["AUTO_ATTACH_ML_BACKEND_URL"].strip()
backend_title = os.environ["AUTO_ATTACH_ML_BACKEND_TITLE"].strip() or "SphereAI SAM Backend"

if not backend_url:
    raise SystemExit(0)

for project in Project.objects.all().order_by("id"):
    if MLBackend.objects.filter(project=project, url=backend_url).exists():
        continue

    try:
        MLBackend.objects.create(
            project=project,
            title=backend_title,
            url=backend_url,
            is_interactive=True,
            timeout=120,
            state="DI",
        )
        print(
            f"INFO: [auto_attach_ml_backend] Attached '{backend_title}' to "
            f"project '{project.title}' (id={project.id})"
        )
    except Exception as exc:
        print(
            f"WARN: [auto_attach_ml_backend] Failed attach for "
            f"project '{project.title}' (id={project.id}): {exc}"
        )
PYEOF

  sleep "$POLL_INTERVAL"
done

