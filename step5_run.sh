#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 --ip <VM_IP>"
  exit 1
}
if [ "$#" -ne 2 ] || [ "$1" != "--ip" ]; then
  usage
fi
VM_IP="$2"
VM_USER="user"
SSH_KEY="$HOME/.ssh/id_ed25519"

SSH_OPTS=(
  -i "$SSH_KEY"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
)

# 1) Check local port 8188 before doing anything
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8188 | grep -q '^2'; then
  echo "✅ ComfyUI is already running and responding on http://localhost:8188"
else
  # 2) Get container name
  CONTAINER_NAME=$(ssh "${SSH_OPTS[@]}" "${VM_USER}@${VM_IP}" '
    source ~/container.env
    echo "$CONTAINER_NAME"
  ')

  # 3) Start ComfyUI if not yet running
  echo "🚀 Launching ComfyUI inside container $CONTAINER_NAME..."
  ssh "${SSH_OPTS[@]}" "${VM_USER}@${VM_IP}" \
    "sudo docker exec -d $CONTAINER_NAME \
     python3 /workspace/ComfyUI/main.py --listen 0.0.0.0 --port 8188" || true

  # 4) Establish SSH tunnel if not already up
  if ! pgrep -f "ssh .* -L 8188:localhost:8188" >/dev/null; then
    echo "🔗 Opening SSH tunnel (localhost:8188 → ${VM_IP}:8188)..."
    ssh "${SSH_OPTS[@]}" -fN -L 8188:localhost:8188 "${VM_USER}@${VM_IP}"
  else
    echo "🔗 SSH tunnel already exists"
  fi

  # 5) Wait for HTTP 200 on localhost:8188
  echo -n "⏳ Waiting for ComfyUI to become available"
  for i in $(seq 1 24); do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8188 | grep -q '^2'; then
      echo " — up!"
      break
    fi
    echo -n "."
    sleep 5
  done
fi

# 6) Open browser (only once)
if ! pgrep -f "open http://localhost:8188|xdg-open http://localhost:8188" >/dev/null; then
  echo "🌐 Opening your browser to http://localhost:8188"
  if command -v open &>/dev/null; then
    open "http://localhost:8188"
  elif command -v xdg-open &>/dev/null; then
    xdg-open "http://localhost:8188"
  else
    echo "Please navigate your browser to http://localhost:8188"
  fi
else
  echo "🌐 Browser already opened"
fi