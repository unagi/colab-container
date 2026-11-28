#!/usr/bin/env bash
set -euo pipefail

# Clear any stale connection URL left from a previous run of this stopped container
rm -f /tmp/colab_connect_url /tmp/colab_connect_url.tmp

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
printf '%s\n' "${URL}" > /tmp/colab_connect_url.tmp
chmod 600 /tmp/colab_connect_url.tmp
mv -f /tmp/colab_connect_url.tmp /tmp/colab_connect_url

CONTENT_FSTYPE="$(awk '$2 == "/content" { fs = $3 } END { print fs }' /proc/mounts 2>/dev/null || true)"
CONTENT_WARN=""
if [[ "${CONTENT_FSTYPE}" == "tmpfs" ]]; then
  CONTENT_WARN="WARNING: /content is mounted on tmpfs (WSL2 bind-mount race). Run: make down && make up"
fi

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
if [[ -n "${CONTENT_WARN}" ]]; then
  printf '\n[!] %s\n\n' "${CONTENT_WARN}" >&2
fi

exec jupyter server \
  --config=/etc/jupyter/jupyter_server_config.py \
  --ServerApp.port="${INTERNAL_PORT}" \
  --IdentityProvider.token="${TOKEN}" \
  "$@"
