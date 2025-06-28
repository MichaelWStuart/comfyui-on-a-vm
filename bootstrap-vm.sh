#!/bin/bash
set -euo pipefail

# Usage helper
usage() {
  echo "Usage: $0 --ip <VM_IP>"
  exit 1
}

# Require exactly one argument: --ip <VM_IP>
if [ "$#" -ne 2 ] || [ "$1" != "--ip" ]; then
  usage
fi
VM_IP="$2"
VM_USER="user"
SSH_KEY="$HOME/.ssh/id_ed25519"

# SSH options: use your ed25519 key, skip host prompts, suppress warnings
SSH_OPTS=(
  -i "$SSH_KEY"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
)

# Wait for the VM to come back online after a reboot
wait_for_ssh() {
  echo -n "Waiting for VM to come back online"
  for _ in $(seq 1 60); do
    sleep 5
    if ssh "${SSH_OPTS[@]}" "${VM_USER}@${VM_IP}" 'echo OK' &>/dev/null; then
      echo " — VM online."
      return
    fi
    echo -n "."
  done
  echo " timed out."
  exit 1
}

# Run a step script: remotely for steps 1–4, locally for step5
run_step() {
  local script="$1"
  echo "▶️  Running $script..."
  if [ "$script" = "step5_run.sh" ]; then
    # execute locally
    bash "./$script" --ip "$VM_IP"
  else
    # execute on VM and handle reboots
    set +e
    ssh "${SSH_OPTS[@]}" "${VM_USER}@${VM_IP}" "bash ~/${script}"
    local status=$?
    set -e
    if [ $status -eq 255 ]; then
      echo "🔄 Detected reboot, waiting..."
      wait_for_ssh
    elif [ $status -ne 0 ]; then
      echo "❌ $script failed with exit code $status"
      exit $status
    fi
  fi
}

# Upload remote-only step scripts
scp "${SSH_OPTS[@]}" step1_os.sh step2_gpu.sh step3_docker.sh step4_models.sh "${VM_USER}@${VM_IP}":~/

# Make remote scripts executable
ssh "${SSH_OPTS[@]}" "${VM_USER}@${VM_IP}" \
  "chmod +x ~/step1_os.sh ~/step2_gpu.sh ~/step3_docker.sh ~/step4_models.sh"

# Execute steps in order
run_step step1_os.sh
run_step step2_gpu.sh
run_step step3_docker.sh
run_step step4_models.sh
run_step step5_run.sh

echo "✅ All steps complete. You can now 'ssh ${VM_USER}@${VM_IP}' or access ComfyUI at http://localhost:8188"