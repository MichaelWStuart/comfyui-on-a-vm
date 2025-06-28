#!/bin/bash
set -euo pipefail

# Refresh apt package index
sudo apt update

# Install build tools, DKMS, curl, GCC, make, and headers for the running kernel
sudo apt install -y build-essential dkms curl gcc make linux-headers-$(uname -r)

# Notify and signal reboot to apply kernel updates
echo "Rebooting to apply kernel updates..."
echo "__REBOOT__"
# Reboot the VM
sudo reboot