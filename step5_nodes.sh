#!/bin/bash
set -euo pipefail

if [ -f /home/user/container.env ]; then
    source /home/user/container.env
else
    echo "❌ container.env file not found. Did step 3 complete successfully?"
    exit 1
fi

: "${CONTAINER_NAME:?CONTAINER_NAME must be set}"

# Ensure dependencies inside the container
sudo docker exec "$CONTAINER_NAME" bash -c "
    apt update && apt install -y curl jq
"

# Your list of missing node names
node=(

)

for node in "${nodes[@]}"; do
    sudo docker exec "$CONTAINER_NAME" bash -c "
        REGISTRY_JSON=\"\$HOME/comfy/ComfyUI/user/default/ComfyUI-Manager/cache/custom-node-list.json\"
        url=\$(jq -r --arg node \"\$node\" '
            .. | objects | select(has(\"description\")) | select(.description | test(\$node)) | .files[0]
        ' \"\$REGISTRY_JSON\" | head -n1)
        if [ -n \"\$url\" ]; then
            echo Downloading \$node from \"\$url\"
            curl -L \"\$url\" -o \"\$HOME/comfy/ComfyUI/custom_nodes/\${node}.py\"
        else
            echo \"⚠️  Could not find \$node in registry\"
        fi
    "
done
