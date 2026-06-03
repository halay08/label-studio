#!/bin/bash
# entrypoint.sh — Wrapper cho Label Studio container.
set -euo pipefail

# Auto attach ML backend to newly created projects (UI flow)
if [ -f "/label-studio/auto_attach_ml_backend.sh" ]; then
    bash /label-studio/auto_attach_ml_backend.sh &
    echo "INFO: [entrypoint] auto_attach_ml_backend.sh started in background (PID $!)"
fi

# ────────────────────────────────────────────
# Chuyển quyền điều khiển sang Label Studio chính
# Giữ nguyên CMD từ base image
# ────────────────────────────────────────────
exec label-studio "$@"