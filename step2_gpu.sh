#!/bin/bash
set -euo pipefail

# Install required build tools and kernel headers
sudo apt update
sudo apt install -y build-essential dkms curl linux-headers-$(uname -r) gcc make

# Download the NVIDIA driver installer
DRIVER_URL="https://us.download.nvidia.com/XFree86/Linux-x86_64/570.169/NVIDIA-Linux-x86_64-570.169.run"
DRIVER_FILE="NVIDIA-Linux-x86_64-570.169.run"
curl -O "$DRIVER_URL"
chmod +x "$DRIVER_FILE"

# Switch to multi-user.target to free the GPU for driver installation
sudo systemctl isolate multi-user.target || true

# Run the NVIDIA installer in silent mode with DKMS support
if ! sudo ./"$DRIVER_FILE" --silent --dkms; then
  echo "❌ NVIDIA driver installation failed. Showing last 50 lines of installer log:"
  sudo tail -n 50 /var/log/nvidia-installer.log || echo "⚠️  Log file not found"
  exit 1
fi

# Verify the driver installed correctly
if nvidia-smi; then
  echo "✅ NVIDIA driver installed successfully"
  echo "Rebooting to apply changes..."
  echo '__REBOOT__'
  # Reboot the VM to load the new driver
  sudo reboot
else
  echo "❌ nvidia-smi failed. Driver may not be installed correctly."
  exit 1
fi