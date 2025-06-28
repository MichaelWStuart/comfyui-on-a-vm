#!/bin/bash
set -euo pipefail

# ─── Refresh & install build tools ─────────────────────────────────────────────
sudo apt update
sudo apt install -y \
  build-essential \
  dkms \
  curl \
  gcc \
  make \
  linux-headers-$(uname -r)

# ─── Add ComfyUI container shortcuts to ~/.bashrc ───────────────────────────────
cat << 'EOF' >> "$HOME/.bashrc"

# ── ComfyUI Docker container shortcuts ─────────────────────────────────────────
# Assumes ~/container.env defines CONTAINER_NAME
if [ -f "$HOME/container.env" ]; then
  alias ui-start='source "$HOME/container.env" && \
    sudo docker exec -d "$CONTAINER_NAME" \
      python3 /workspace/ComfyUI/main.py --listen 0.0.0.0 --port 8188'
  alias cd-doc='source "$HOME/container.env" && \
    sudo docker exec -it "$CONTAINER_NAME" bash'
fi
EOF

# ─── Notify & reboot to apply kernel updates ────────────────────────────────────
echo "Rebooting to apply kernel updates..."
echo "__REBOOT__"
sudo reboot