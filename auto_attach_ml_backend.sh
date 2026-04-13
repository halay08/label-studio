#!/bin/bash
# auto_attach_ml_backend.sh
# Keep new UI-created projects connected to ML backend automatically.

set -euo pipefail

LS_URL="${LABEL_STUDIO_URL:-http://localhost:8080}"
ML_BACKEND_URL="${AUTO_ATTACH_ML_BACKEND_URL:-http://sphere-ai-sam-backend:9090}"
ML_BACKEND_TITLE="${AUTO_ATTACH_ML_BACKEND_TITLE:-ML Backend}"
POLL_INTERVAL="${AUTO_ATTACH_POLL_INTERVAL:-5}"
# When true, also turn on Annotation settings: use predictions to pre-label + load predictions on task open.
AUTO_ATTACH_ENABLE_PRELABELING="${AUTO_ATTACH_ENABLE_PRELABELING:-true}"
# Label Studio uses fast_first(ml_backends.all()) — nhiều backend thì có thể gọi nhầm cái cũ.
AUTO_ATTACH_EXCLUSIVE_ML_BACKENDS="${AUTO_ATTACH_EXCLUSIVE_ML_BACKENDS:-true}"
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
  AUTO_ATTACH_ENABLE_PRELABELING="${AUTO_ATTACH_ENABLE_PRELABELING}" \
  AUTO_ATTACH_EXCLUSIVE_ML_BACKENDS="${AUTO_ATTACH_EXCLUSIVE_ML_BACKENDS}" \
  "$LS_PYTHON" - <<'PYEOF'
import os
import warnings

warnings.filterwarnings("ignore")

import django

django.setup()

from ml.models import MLBackend
from projects.models import Project


def _strip_env_quotes(value: str) -> str:
    s = value.strip()
    if len(s) >= 2 and s[0] == s[-1] and s[0] in "\"'":
        s = s[1:-1].strip()
    return s


backend_url = _strip_env_quotes(os.environ["AUTO_ATTACH_ML_BACKEND_URL"])
backend_title = _strip_env_quotes(os.environ["AUTO_ATTACH_ML_BACKEND_TITLE"]) or "ML Backend"
enable_prelabel = os.environ.get("AUTO_ATTACH_ENABLE_PRELABELING", "true").lower() in (
    "1",
    "true",
    "yes",
)
exclusive_ml = os.environ.get("AUTO_ATTACH_EXCLUSIVE_ML_BACKENDS", "true").lower() in (
    "1",
    "true",
    "yes",
)

if not backend_url:
    raise SystemExit(0)

for project in Project.objects.all().order_by("id"):
    if exclusive_ml:
        others = MLBackend.objects.filter(project=project).exclude(url=backend_url)
        if others.exists():
            n = others.count()
            others.delete()
            print(
                f"INFO: [auto_attach_ml_backend] Removed {n} other ML backend(s) on "
                f"project '{project.title}' (id={project.id}) so predict uses {backend_url!r}"
            )

    # Hai row cùng URL (LS UI hiện 2 tab) → fast_first() có thể chọn row title sai → không retrieve predictions.
    same_url_qs = MLBackend.objects.filter(project=project, url=backend_url).order_by("id")
    same_url = list(same_url_qs)
    if len(same_url) > 1:
        keep = same_url[0]
        MLBackend.objects.filter(project=project, url=backend_url).exclude(pk=keep.pk).delete()
        print(
            f"INFO: [auto_attach_ml_backend] Deduped {len(same_url) - 1} duplicate ML backend(s) "
            f"with same URL on project '{project.title}' (id={project.id}), kept id={keep.pk}"
        )

    mlb = MLBackend.objects.filter(project=project, url=backend_url).first()
    if mlb is None:
        try:
            MLBackend.objects.create(
                project=project,
                title=backend_title,
                url=backend_url,
                is_interactive=True,
                timeout=120,
                state="DI",
                auto_update=False,
            )
            print(
                f"INFO: [auto_attach_ml_backend] Attached '{backend_title}' to "
                f"project '{project.title}' (id={project.id})"
            )
            mlb = MLBackend.objects.get(project=project, url=backend_url)
        except Exception as exc:
            print(
                f"WARN: [auto_attach_ml_backend] Failed attach for "
                f"project '{project.title}' (id={project.id}): {exc}"
            )
            continue
    else:
        # LS: ml_backend_in_model_version chỉ True khi có row MLBackend với title == project.model_version.
        # auto_update=True (default) ghi đè MLBackend.model_version từ /setup → UI dễ hiện thêm "tab" sam3-...
        update_fields = []
        if mlb.title != backend_title:
            mlb.title = backend_title
            update_fields.append("title")
        if getattr(mlb, "auto_update", True):
            mlb.auto_update = False
            update_fields.append("auto_update")
        if update_fields:
            mlb.save(update_fields=update_fields)
            print(
                f"INFO: [auto_attach_ml_backend] Synced ML backend on project '{project.title}' "
                f"(id={project.id}): {', '.join(update_fields)} → title={backend_title!r}, auto_update=False"
            )

    has_backend = mlb is not None

    if not enable_prelabel or not has_backend:
        continue

    # Label Studio only calls the ML backend when project.model_version == ml_backend.title
    # (see Project.should_retrieve_predictions in label-studio/projects/models.py).
    try:
        to_update = []
        if not getattr(project, "show_collab_predictions", False):
            project.show_collab_predictions = True
            to_update.append("show_collab_predictions")
        if not getattr(project, "evaluate_predictions_automatically", False):
            project.evaluate_predictions_automatically = True
            to_update.append("evaluate_predictions_automatically")
        current_mv = getattr(project, "model_version", None) or ""
        if current_mv != backend_title:
            project.model_version = backend_title
            to_update.append("model_version")
        if to_update:
            project.save(update_fields=to_update)
            print(
                f"INFO: [auto_attach_ml_backend] Enabled prelabel settings on "
                f"project '{project.title}' (id={project.id}): {', '.join(to_update)}"
            )
    except Exception as exc:
        print(
            f"WARN: [auto_attach_ml_backend] Failed prelabel settings for "
            f"project '{project.title}' (id={project.id}): {exc}"
        )
PYEOF

  sleep "$POLL_INTERVAL"
done

