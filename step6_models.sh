#!/usr/bin/env bash
# step6_models.sh – copy models from laptop → VM → Docker container
set -Eeuo pipefail

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

# ── CONFIG ───────────────────────────────────────────────────────────────────
VM_IP="38.224.253.72"
VM_USER="user"
SSH_KEY="$HOME/.ssh/id_ed25519"
CONTAINER_NAME="comfy_default"

REMOTE_TMP_DIR="/home/$VM_USER/tmp_models"
CONTAINER_MODEL_DIR="/root/comfy/ComfyUI/models"

SSH_OPTS=(
  -i "$SSH_KEY"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
)

# ── MODEL LISTS (edit as needed; leave empty () if none) ─────────────────────
declare -a checkpoints=()
declare -a clip_vision=()
declare -a diffusion_models=()
declare -a loras=()
declare -a vae=()
declare -a text_encoders=()

categories=(checkpoints clip_vision diffusion_models loras vae text_encoders)

# ── 1 ▸ copy from laptop → VM ────────────────────────────────────────────────
log "Making sure $REMOTE_TMP_DIR exists on VM…"
ssh "${SSH_OPTS[@]}" "$VM_USER@$VM_IP" "mkdir -p '$REMOTE_TMP_DIR'"

for cat in "${categories[@]}"; do
  # Load the array for this category into files[]
  eval "files=( \"\${${cat}[@]}\" )"
  ((${#files[@]})) || { log "$cat is empty, skipping"; continue; }

  log "$cat – ${#files[@]} file(s)"
  for f in "${files[@]}"; do
    local_path="$HOME/Downloads/$f"
    remote_path="$REMOTE_TMP_DIR/${cat}--$f"

    [[ -f $local_path ]] || { log "  ⚠️  $f not found locally, skipping"; continue; }

    if ssh "${SSH_OPTS[@]}" "$VM_USER@$VM_IP" "[ -f '$remote_path' ]"; then
      log "  ⚠️  $f already on VM, skipping"
      continue
    fi

    log "  📤 $f → VM"
    scp "${SSH_OPTS[@]}" "$local_path" "$VM_USER@$VM_IP:$remote_path"
  done
done

# ── 2 ▸ move from VM tmp → Docker container ─────────────────────────────────
log "Staging files into container $CONTAINER_NAME …"

ssh "${SSH_OPTS[@]}" "$VM_USER@$VM_IP" bash <<'VM'
set -Eeuo pipefail
CONTAINER_NAME="comfy_default"
REMOTE_TMP_DIR="$HOME/tmp_models"
CONTAINER_MODEL_DIR="/root/comfy/ComfyUI/models"

shopt -s nullglob
for staged in "$REMOTE_TMP_DIR"/*--*; do
  fname=$(basename "$staged")
  cat=${fname%%--*}
  real=${fname#*--}
  dest="$CONTAINER_MODEL_DIR/$cat/$real"

  echo "  → $real → $dest"
  if sudo docker exec "$CONTAINER_NAME" test -f "$dest"; then
    echo "    already exists, deleting temp copy"
    rm -f -- "$staged"
    continue
  fi

  sudo docker exec "$CONTAINER_NAME" mkdir -p "$CONTAINER_MODEL_DIR/$cat"
  sudo docker cp -- "$staged" "$CONTAINER_NAME:$dest"
  rm -f -- "$staged"
done
echo "Done staging files."
VM

log "✅ Transfer complete"