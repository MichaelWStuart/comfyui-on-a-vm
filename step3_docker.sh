#!/bin/bash
set -euo pipefail

# ─── Docker & NVIDIA Toolkit Setup ─────────────────────────────────────────────

sudo rm -f /etc/apt/sources.list.d/*nvidia*.list
sudo sed -i '/nvidia.github.io/d' /etc/apt/sources.list
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor | \
  sudo tee /etc/apt/keyrings/docker.gpg > /dev/null

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor | \
  sudo tee /etc/apt/keyrings/nvidia-container-toolkit.gpg > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/nvidia-container-toolkit.gpg] \
  https://nvidia.github.io/libnvidia-container/stable/deb/$(dpkg --print-architecture) /" | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null

sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
sudo systemctl is-active --quiet docker

sudo docker run --rm --gpus all nvidia/cuda:12.2.2-runtime-ubuntu22.04 nvidia-smi

# ─── ComfyUI Container Launch & CLI Install ─────────────────────────────

echo "####################################################################"
echo "# Pulling PyTorch CUDA image (~10GB).                               #"
echo "####################################################################"

sudo docker pull pytorch/pytorch:2.1.2-cuda12.1-cudnn8-runtime

CONTAINER_NAME="comfy_default"

if sudo docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "Stopping and removing existing container: ${CONTAINER_NAME}"
  sudo docker stop "$CONTAINER_NAME"
  sudo docker rm "$CONTAINER_NAME"
fi

echo "CONTAINER_NAME=$CONTAINER_NAME" > "$HOME/container.env"

sudo docker run -d --gpus all \
  --name "$CONTAINER_NAME" \
  -p 8188:8188 \
  --restart unless-stopped \
  pytorch/pytorch:2.1.2-cuda12.1-cudnn8-runtime sleep infinity

# ─── Install comfy-cli & ComfyUI in venv inside container ──────────────────────

sudo docker exec "$CONTAINER_NAME" bash -c "
  export DEBIAN_FRONTEND=noninteractive
  apt update
  apt install -y python3 python3-pip python3-venv git curl expect

  python3 -m venv /root/comfy-venv
  source /root/comfy-venv/bin/activate

  pip install --upgrade pip
  pip install comfy-cli

  # Automate comfy install
  cat > /tmp/comfy_install.expect <<EOF
#!/usr/bin/expect -f
spawn comfy install
expect \"Do you agree to enable tracking*\" { send \"N\r\" }
expect \"What GPU do you have*\" { send \"nvidia\r\" }
expect \"Install from https://github.com/comfyanonymous/ComfyUI to */ComfyUI*\" { send \"y\r\" }
expect eof
EOF

  chmod +x /tmp/comfy_install.expect
  expect /tmp/comfy_install.expect
  rm /tmp/comfy_install.expect

  # Install ComfyUI dependencies
  cd /root/comfy/ComfyUI
  pip install -r requirements.txt

  # Set comfy default path
  comfy set-default /root/comfy/ComfyUI

  cd /root/comfy/ComfyUI/custom_nodes
  git clone https://github.com/ltdrdata/ComfyUI-Manager.git || (cd ComfyUI-Manager && git pull)
  cd ComfyUI-Manager
  pip install -r requirements.txt || true

  deactivate
"

# ─── Final Verification ─────────────────────────────────────────────────

sudo docker exec "$CONTAINER_NAME" bash -c "
  source /root/comfy-venv/bin/activate
  python3 -c 'import torch; print(\"torch.cuda.is_available:\", torch.cuda.is_available())'
  deactivate
"

echo "✅ Docker + ComfyUI + Comfy CLI setup complete"