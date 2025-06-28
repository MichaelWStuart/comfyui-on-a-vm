#!/bin/bash
set -euo pipefail

# ─── Docker & NVIDIA Toolkit Setup ─────────────────────────────────────────────

# Remove old NVIDIA apt sources to avoid conflicts
sudo rm -f /etc/apt/sources.list.d/*nvidia*.list

# Remove leftover NVIDIA repo entries from apt sources
sudo sed -i '/nvidia.github.io/d' /etc/apt/sources.list

# Refresh apt package index
sudo apt update

# Install Docker prerequisites
sudo apt install -y ca-certificates curl gnupg lsb-release

# Ensure the keyrings directory exists
sudo install -m 0755 -d /etc/apt/keyrings

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  gpg --dearmor | \
  sudo tee /etc/apt/keyrings/docker.gpg > /dev/null

# Add the Docker apt repository
echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Refresh, then install Docker engine & tools
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
                    docker-buildx-plugin docker-compose-plugin

# Add NVIDIA Container Toolkit GPG key
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  gpg --dearmor | \
  sudo tee /etc/apt/keyrings/nvidia-container-toolkit.gpg > /dev/null

# Add NVIDIA Container Toolkit repo
echo "deb [signed-by=/etc/apt/keyrings/nvidia-container-toolkit.gpg] \
  https://nvidia.github.io/libnvidia-container/stable/deb/$(dpkg --print-architecture) /" | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null

# Refresh & install NVIDIA Container Toolkit
sudo apt update
sudo apt install -y nvidia-container-toolkit

# Configure Docker to use the NVIDIA runtime by default
sudo nvidia-ctk runtime configure --runtime=docker

# Restart Docker to pick up the new runtime
sudo systemctl restart docker

# Quick check that Docker is active
sudo systemctl is-active --quiet docker

# Verify GPU access in a minimal container
sudo docker run --rm --gpus all nvidia/cuda:12.2.2-runtime-ubuntu22.04 nvidia-smi

# ─── ComfyUI Container Launch & Software Install ───────────────────────────────

# Warn user about long download time
echo "####################################################################"
echo "# WARNING: Pulling the PyTorch CUDA image (~10GB).                  #"
echo "# This can take 10+ minutes depending on your network speed.       #"
echo "# Please do NOT abort or close this terminal during the download.  #"
echo "####################################################################"

# Pre-pull the PyTorch CUDA image
sudo docker pull pytorch/pytorch:2.1.2-cuda12.1-cudnn8-runtime

# Launch the ComfyUI container (detached)
CONTAINER_NAME="comfy_$(openssl rand -hex 4)"
echo "CONTAINER_NAME=$CONTAINER_NAME" > /home/user/container.env
sudo docker run -d --gpus all \
  --name "$CONTAINER_NAME" \
  -p 8188:8188 \
  --restart unless-stopped \
  pytorch/pytorch:2.1.2-cuda12.1-cudnn8-runtime sleep infinity

# Inside the running container: install Python, pip, git, and curl
sudo docker exec "$CONTAINER_NAME" bash -c "\
  apt update && \
  apt install -y python3 python3-pip git curl \
"

# Inside the container: install xformers for efficient attention
sudo docker exec "$CONTAINER_NAME" pip3 install xformers

# Inside the container: clone ComfyUI and install requirements
sudo docker exec "$CONTAINER_NAME" git clone \
  https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
sudo docker exec "$CONTAINER_NAME" pip3 install \
  -r /workspace/ComfyUI/requirements.txt

# Final check: verify torch.cuda availability
sudo docker exec "$CONTAINER_NAME" python3 - <<'PYCODE'
import torch
print("torch.cuda.is_available:", torch.cuda.is_available())
PYCODE

echo "✅ Docker + ComfyUI setup complete"