#!/bin/bash
set -euo pipefail

# Update package index and install build tools
sudo apt update
sudo apt install -y \
  build-essential \
  dkms \
  curl \
  gcc \
  make \
  linux-headers-$(uname -r)

# Reboot system to apply kernel updates
echo "Rebooting to apply kernel updates..."
echo "__REBOOT__"
sudo reboot