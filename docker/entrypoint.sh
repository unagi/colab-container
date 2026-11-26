#!/usr/bin/env bash
set -euo pipefail

# Detect GPU reliably on both native Linux (/dev/nvidiactl) and WSL2 (/dev/dxg)
if nvidia-smi >/dev/null 2>&1; then
  export COLAB_GPU=1
else
  export COLAB_GPU=0
fi

HOST_PORT="${COLAB_PORT:-9000}"
INTERNAL_PORT="${JUPYTER_PORT:-8080}"

if [[ -n "${COLAB_TOKEN:-}" ]]; then
  TOKEN="${COLAB_TOKEN}"
else
  TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(24))')"
fi

URL="http://127.0.0.1:${HOST_PORT}/?token=${TOKEN}"
printf '%s\n' "${URL}" > /tmp/colab_connect_url
chmod 600 /tmp/colab_connect_url

cat <<EOF
======================================================================
 Google Colab Local Runtime (NVIDIA RTX Spark / ARM64)
----------------------------------------------------------------------
 Working Dir : /content
 GPU Active  : ${COLAB_GPU}
 Connect URL : ${URL}

 Paste the Connect URL into Google Colab:
   Connect -> Connect to a local runtime
======================================================================
EOF

exec jupyter server \
  --config=/etc/jupyter/jupyter_server_config.py \
  --ServerApp.port="${INTERNAL_PORT}" \
  --IdentityProvider.token="${TOKEN}" \
  "$@"
