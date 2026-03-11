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

# ────────────────────────────────────────────
# Chuyển quyền điều khiển sang Label Studio chính
# Giữ nguyên CMD từ base image
# ────────────────────────────────────────────
exec label-studio "$@"
tem