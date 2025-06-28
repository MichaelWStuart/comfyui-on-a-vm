# ComfyUI VM Bootstrap

Automate provisioning and configuration of a GPU-powered VM to run ComfyUI with zero manual setup—just run a one-line script and it will automatically open a browser tab with the UI for you.

---

## Overview

Provision a near bare-metal Ubuntu VM equipped with a modern NVIDIA GPU (e.g. A6000 or Blackwell) and install everything you need in one command. This script:

* Installs OS packages and kernel headers
* Installs and configures the latest NVIDIA drivers
* Installs Docker Engine and NVIDIA Container Toolkit
* Pulls and configures a PyTorch + ComfyUI Docker container
* Downloads all required ComfyUI models
* Sets up port forwarding so you can access ComfyUI at `http://localhost:8188`

All you need is the VM’s IP address—no additional options or choices. Once the script finishes, it will open your browser to the ComfyUI interface.

---

## Prerequisites

1. **Ubuntu 22.04 VM** with an NVIDIA GPU (provided by your data-center or cloud provider).
2. **SSH key** (e.g. `~/.ssh/id_ed25519`) already registered with the VM.
3. **Public IP address** of the VM.
4. Local machine with `ssh`, `scp`, and `bash` installed.

---

## Quickstart

1. **Clone and prepare scripts**:

   ```bash
   git clone <repo-url> comfyui-vm-bootstrap
   cd comfyui-vm-bootstrap
   chmod +x *.sh
   ```

2. **Run the bootstrap**:

   ```bash
   ./bootstrap-vm.sh --ip <VM_IP>
   ```

   This will install OS packages, GPU drivers, Docker, configure and launch ComfyUI in a Docker container, forward port `8188`, and open your browser at `http://localhost:8188`.

Once complete, you can SSH into your VM at any time:

```bash
ssh user@<VM_IP>
```

---

## Under the Hood

`bootstrap-vm.sh` handles every step automatically:

1. **Uploads** `step1_os.sh` through `step4_models.sh` to the VM via `scp`.

2. **Executes** each step over SSH with automatic reboot handling:

   * `step1_os.sh`: OS updates and reboot
   * `step2_gpu.sh`: NVIDIA driver install and reboot
   * `step3_docker.sh`: Docker & NVIDIA Container Toolkit setup + ComfyUI container creation
   * `step4_models.sh`: Downloads ComfyUI models into the container

3. **Runs** `step5_run.sh` locally to:

   * Launch ComfyUI inside the container
   * Forward port `8188` to your local machine
   * Open your browser to `http://localhost:8188`

---

## Why This Approach

* **Bare-metal performance**: No managed-container overhead, full VRAM and CUDA access.
* **One command**: Minimal user input—just the VM IP, and you’re done.
* **Cost savings**: Rent GPU VMs by the hour at data-center rates.
* **Consistency**: Automated, repeatable setup across multiple VMs.
