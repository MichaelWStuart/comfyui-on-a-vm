#!/bin/bash
set -euo pipefail

# Load the ComfyUI container name
source /home/user/container.env

# Base models path inside the container
BASE_DIR="/workspace/ComfyUI/models"

# ─── Define the lists ────────────────────────────────────────────────────────────

vae=(
  "wan_2.1_vae.safetensors|https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors?download=true"
)

clip_vision=(
  "clip_vision_h.safetensors|https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors?download=true"
)

text_encoders=(
  "umt5_xxl_fp8_e4m3fn_scaled.safetensors|https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors?download=true"
)

diffusion_models=(
  "wan2.1_i2v_480p_14B_fp16.safetensors|https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_i2v_480p_14B_fp16.safetensors?download=true"
)

# ─── Download helper with idempotency ────────────────────────────────────────────

download_list() {
  local subdir="$1"
  local -n entries="$2"

  for pair in "${entries[@]}"; do
    local filename="${pair%%|*}"
    local url="${pair#*|}"
    local target="$BASE_DIR/$subdir/$filename"

    # Skip if file already exists
    if sudo docker exec "$CONTAINER_NAME" test -f "$target"; then
      echo "⚠️  Skipping existing $subdir/$filename"
      continue
    fi

    echo "📥 Downloading ${filename} into ${subdir}/"
    sudo docker exec "$CONTAINER_NAME" \
      curl -fL "$url" -o "$target"
  done
}

# ─── Execute downloads ──────────────────────────────────────────────────────────

download_list vae vae
download_list clip_vision clip_vision
download_list text_encoders text_encoders
download_list diffusion_models diffusion_models

echo "✅ Models updated in their respective subdirectories under ${BASE_DIR}"