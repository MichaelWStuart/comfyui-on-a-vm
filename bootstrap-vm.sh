#!/bin/bash
set -euo pipefail

# Parse and validate arguments
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

# SSH options
SSH_OPTS=(
  -i "$SSH_KEY"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
)

# Wait for VM to come back online after reboot
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

# Run a step script remotely (or locally for run step)
run_step() {
  local script="$1"
  echo "▶️ Running $script..."
  if [ "$script" = "step4_run.sh" ]; then
    bash "./$script" --ip "$VM_IP"
  else
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

# Upload remote scripts
scp "${SSH_OPTS[@]}" step1_os.sh step2_gpu.sh step3_docker.sh step5_nodes.sh "${VM_USER}@${VM_IP}":~/

# Make scripts executable
ssh "${SSH_OPTS[@]}" "${VM_USER}@${VM_IP}" "chmod +x ~/step1_os.sh ~/step2_gpu.sh ~/step3_docker.sh ~/step5_nodes.sh"

# Get HOME inside the container to set globally consistent CONTAINER_HOME
CONTAINER_HOME=$(ssh "${SSH_OPTS[@]}" "${VM_USER}@${VM_IP}" "sudo docker run --rm pytorch/pytorch:2.1.2-cuda12.1-cudnn8-runtime bash -c 'echo \$HOME'")
echo "Detected CONTAINER_HOME: $CONTAINER_HOME"

# Export CONTAINER_HOME to make available to steps
export CONTAINER_HOME

# Run step scripts in order
# run_step step1_os.sh
# run_step step2_gpu.sh
# run_step step3_docker.sh
run_step step4_run.sh
# run_step step5_nodes.sh

echo "✅ All steps complete."