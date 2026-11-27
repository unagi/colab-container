# syntax=docker/dockerfile:1.7
ARG BASE_IMAGE=nvcr.io/nvidia/pytorch:26.11-py3
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="colab-rtx-spark" \
      org.opencontainers.image.description="Google Colab local runtime container for NVIDIA RTX Spark (ARM64 / Blackwell sm_121)"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUTF8=1 \
    PIP_ROOT_USER_ACTION=ignore \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    UV_SYSTEM_PYTHON=true \
    UV_BREAK_SYSTEM_PACKAGES=true \
    UV_CONSTRAINT=/etc/pip/constraint.txt \
    COLAB_IMAGE_TYPE=gpu \
    COLAB_RELEASE_TAG=local-rtx-spark-arm64-ngc26.11 \
    COLAB_JUPYTER_ALLOW_ORIGIN_PAT='^https://colab\.(sandbox|research)\.google\.com$' \
    COLAB_REPORT_USAGE_PATHS=/:/content \
    HF_HOME=/root/.cache/huggingface \
    TORCH_HOME=/root/.cache/torch \
    UV_CACHE_DIR=/root/.cache/uv \
    CUDA_CACHE_PATH=/root/.cache/nv \
    CUDA_CACHE_MAXSIZE=2147483648 \
    JUPYTER_PORT=8080

# 1. Install Colab-standard CLI, multimedia, archive, and build utilities.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ffmpeg \
      git \
      git-lfs \
      aria2 \
      sox \
      unzip \
      zstd \
      pigz \
      ccache \
      ninja-build \
      libgl1 \
      libegl1 \
      libglib2.0-0t64 \
    && git lfs install --system \
    && rm -rf /var/lib/apt/lists/*

# 2. Lock NVIDIA-optimized core packages in /etc/pip/constraint.txt so neither
#    build-time installs nor `!pip install` / `!uv pip install` inside Colab
#    can accidentally overwrite the ARM64 CUDA 13.5 / sm_121 builds.
RUN python3 - <<'PY'
import importlib.metadata as md
from pathlib import Path

protected = [
    "torch",
    "torchvision",
    "torch-tensorrt",
    "torchao",
    "torchtitan",
    "numpy",
]
lines = [
    "# Auto-generated at image build time to protect NVIDIA NGC ARM64 builds.",
]
for pkg in protected:
    try:
        ver = md.version(pkg)
    except md.PackageNotFoundError:
        continue
    # Skip local/editable versions that pip constraint files cannot match on PyPI;
    # pin exact version for standard or PEP 440 local versions.
    lines.append(f"{pkg}=={ver}")

Path("/etc/pip/constraint.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(Path("/etc/pip/constraint.txt").read_text(encoding="utf-8"))
PY

# 3. Install Colab Core, general data-science, and stable PyTorch/HF foundation packages (respecting constraints).
RUN pip install --no-cache-dir \
      uv \
      google-auth \
      httplib2 \
      anywidget \
      ipywidgets \
      seaborn \
      scikit-learn \
      opencv-python-headless \
      plotly \
      gdown \
      beautifulsoup4 \
      huggingface-hub \
      hf-xet \
      hf-transfer \
      safetensors \
      einops \
      sentencepiece \
      tokenizers

# 4. Install google-colab (colabtools) without downgrading NGC's Jupyter/IPython/pandas,
#    and apply minimal compatibility patches for IPython 9.x & empty-kernel resource polling.
ARG COLABTOOLS_REF=61495ae0074b1e0cc8a3a970f55bae59ec4b4029
COPY docker/patch_colabtools.py /tmp/patch_colabtools.py
RUN pip install --no-cache-dir --no-deps \
      "git+https://github.com/googlecolab/colabtools.git@${COLABTOOLS_REF}" && \
    python3 /tmp/patch_colabtools.py && \
    rm -f /tmp/patch_colabtools.py

# 5. Install Colab-compatible Jupyter Server, IPython, and Kernel launcher configs.
COPY docker/jupyter_server_config.py /etc/jupyter/jupyter_server_config.py
COPY docker/ipython_config.py /etc/ipython/ipython_config.py
COPY docker/colab_kernel_launcher.py /usr/local/lib/python3.12/dist-packages/colab_kernel_launcher.py
COPY docker/entrypoint.sh /usr/local/bin/colab-entrypoint.sh
COPY docker/selfcheck.py /usr/local/bin/colab-selfcheck

RUN chmod +x /usr/local/bin/colab-entrypoint.sh /usr/local/bin/colab-selfcheck && \
    python3 - <<'PY'
import json
from pathlib import Path
from jupyter_client import kernelspec

spec_path = Path(kernelspec.find_kernel_specs()["python3"]) / "kernel.json"
data = json.loads(spec_path.read_text(encoding="utf-8"))
data["argv"] = [
    "colab_kernel_launcher" if x == "ipykernel_launcher" else x
    for x in data["argv"]
]
spec_path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
print(f"Updated python3 kernelspec: {spec_path}")
print(spec_path.read_text(encoding="utf-8"))
PY

# 6. Prepare Colab-standard working directory (/content) and verify extensions at build time.
RUN mkdir -p /content /root/.cache/huggingface /root/.cache/torch /root/.cache/pip /root/.cache/uv /root/.cache/nv && \
    jupyter server extension list && \
    python3 -c "import torch, google.colab, google.colab._serverextension; print('Build sanity OK:', torch.__version__)"

WORKDIR /content
EXPOSE 8080

ENTRYPOINT ["/opt/nvidia/nvidia_entrypoint.sh"]
CMD ["/usr/local/bin/colab-entrypoint.sh"]
