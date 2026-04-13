#!/bin/bash
# init_template.sh — Chạy nền sau khi Label Studio khởi động xong.
# Dùng Django ORM tạo project "⬡ Sphere Anomaly Template" nếu chưa tồn tại.
# Idempotent: an toàn khi restart container nhiều lần.

set -euo pipefail

LS_URL="${LABEL_STUDIO_URL:-http://localhost:8080}"
LS_USER="${LABEL_STUDIO_USERNAME:-ai-engineer@localhost}"
LS_PYTHON="/label-studio/.venv/bin/python"
LS_MANAGE_DIR="/label-studio/label_studio"
MAX_WAIT=120
INTERVAL=5

# ────────────────────────────────────────────
# 1. Chờ Label Studio healthy
# ────────────────────────────────────────────
echo "INFO: [init_template] Waiting for Label Studio at ${LS_URL} ..."
elapsed=0
until curl -sf "${LS_URL}/health" | grep -q "UP" 2>/dev/null; do
    if [ "$elapsed" -ge "$MAX_WAIT" ]; then
        echo "ERROR: [init_template] Label Studio did not become ready after ${MAX_WAIT}s. Aborting."
        exit 1
    fi
    sleep "$INTERVAL"
    elapsed=$((elapsed + INTERVAL))
done
echo "INFO: [init_template] Label Studio is ready (${elapsed}s)."

# ────────────────────────────────────────────
# 2. Tạo template project qua Django ORM
# ────────────────────────────────────────────
echo "INFO: [init_template] Seeding template project via Django ORM ..."
cd "$LS_MANAGE_DIR"
DJANGO_SETTINGS_MODULE=core.settings.label_studio "$LS_PYTHON" - <<'PYEOF'
import warnings
warnings.filterwarnings("ignore")

import django
django.setup()

from pathlib import Path
from users.models import User
from projects.models import Project

TEMPLATE_NAME = "⬡ Sphere Anomaly Template"
# Cùng file với COPY template/ → annotation_templates/.../anomaly-polygon/
LABEL_CONFIG_PATH = (
    "/label-studio/label_studio/annotation_templates/"
    "computer-vision/anomaly-polygon/label_config.xml"
)
DESCRIPTION = (
    "Polygon labeling template — water_leak, crack, rust, corrosion, "
    "vegetation, debris, structural_damage. DO NOT DELETE."
)

# Kiểm tra đã tồn tại chưa
if Project.objects.filter(title=TEMPLATE_NAME).exists():
    print(f"INFO: [init_template] '{TEMPLATE_NAME}' already exists. Skipping.")
    exit(0)

# Lấy user đầu tiên (admin / AI engineer)
user = User.objects.order_by("id").first()
if not user:
    print("ERROR: [init_template] No user found in DB. Label Studio may not have initialized yet.")
    exit(1)

# Lấy organization
org = getattr(user, "active_organization", None) or user.organizations.order_by("id").first()
if not org:
    print("ERROR: [init_template] No organization found.")
    exit(1)

# Đọc label config
label_config = Path(LABEL_CONFIG_PATH).read_text()

# Tạo project
project = Project.objects.create(
    title=TEMPLATE_NAME,
    label_config=label_config,
    description=DESCRIPTION,
    created_by=user,
    organization=org,
)
print(f"INFO: [init_template] Done! Created '{TEMPLATE_NAME}' (ID: {project.id}).")
print(f"INFO: [init_template] Open: http://localhost:8080/projects/{project.id}")
PYEOF
