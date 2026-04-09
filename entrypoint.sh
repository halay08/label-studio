#!/bin/bash
# entrypoint.sh — Wrapper cho Label Studio container.
# Chạy Label Studio bình thường, sau đó chạy init_template.sh nền để seed template.
set -euo pipefail

# ────────────────────────────────────────────
# Chạy init_template.sh nền sau khi LS ready
# ────────────────────────────────────────────
if [ -f "/label-studio/init_template.sh" ]; then
    bash /label-studio/init_template.sh &
    echo "INFO: [entrypoint] init_template.sh started in background (PID $!)"
fi

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