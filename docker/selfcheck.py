#!/usr/bin/env python3
"""Self-check script verifying GPU, PyTorch sm_121, constraints, and Colab extensions."""

import importlib.metadata as md
from pathlib import Path
import shutil
import sys
import time


def check(label: str, fn):
    try:
        res = fn()
        print(f"[PASS] {label}: {res}")
        return True
    except Exception as exc:
        print(f"[FAIL] {label}: {exc}", file=sys.stderr)
        return False


def main() -> int:
    ok = True

    def check_torch_cuda():
        import torch

        assert torch.cuda.is_available(), "torch.cuda.is_available() is False"
        name = torch.cuda.get_device_name(0)
        cap = torch.cuda.get_device_capability(0)
        vram_gib = torch.cuda.get_device_properties(0).total_memory / (1024**3)
        a = torch.randn(2048, 2048, device="cuda", dtype=torch.bfloat16)
        b = torch.randn(2048, 2048, device="cuda", dtype=torch.bfloat16)
        torch.cuda.synchronize()
        t0 = time.perf_counter()
        c = a @ b
        torch.cuda.synchronize()
        ms = (time.perf_counter() - t0) * 1000
        assert not torch.isnan(c).any(), "NaN in GPU matmul"
        return (
            f"torch={torch.__version__}, cuda={torch.version.cuda}, "
            f"device={name}, cap={cap}, vram={vram_gib:.2f}GiB, bf16_2048={ms:.1f}ms"
        )

    def check_constraints():
        p = Path("/etc/pip/constraint.txt")
        text = p.read_text(encoding="utf-8")
        assert "torch==" in text, "torch not pinned in /etc/pip/constraint.txt"
        return f"pinned {len([l for l in text.splitlines() if l and not l.startswith('#')])} packages"

    def check_colab_extension():
        import google.colab
        from google.colab._serverextension import _resource_monitor

        gpus = _resource_monitor.get_gpu_stats()
        assert len(gpus) >= 1, "No GPU reported by colab resource monitor"
        return f"google.colab={google.colab.__version__}, gpu_monitor={gpus[0].name}"

    def check_ipython_extension():
        from IPython.terminal.embed import InteractiveShellEmbed

        ip = InteractiveShellEmbed()
        import google.colab

        google.colab.load_ipython_extension(ip)
        return "google.colab IPython extension loaded"

    def check_packages():
        pkgs = [
            "jupyter_server",
            "ipywidgets",
            "anywidget",
            "seaborn",
            "scikit-learn",
            "plotly",
            "uv",
            "debugpy",
        ]
        found = [f"{p}=={md.version(p)}" for p in pkgs]
        return ", ".join(found)

    def check_workspace_mount():
        fstype = "unknown"
        for line in Path("/proc/mounts").read_text(encoding="utf-8").splitlines():
            parts = line.split()
            if len(parts) >= 3 and parts[1] == "/content":
                fstype = parts[2]
        usage = shutil.disk_usage("/content")
        free_gib = usage.free / (1024**3)
        total_gib = usage.total / (1024**3)
        assert fstype != "tmpfs", (
            f"/content is mounted on tmpfs ({free_gib:.1f}GiB free). "
            "WSL2 bind-mount race detected; run `make down && make up` from WSL2."
        )
        return f"fstype={fstype}, free={free_gib:.1f}GiB/{total_gib:.1f}GiB"

    ok &= check("PyTorch & CUDA GPU", check_torch_cuda)
    ok &= check("NGC Package Constraints", check_constraints)
    ok &= check("Colab Server Extension & GPU Monitor", check_colab_extension)
    ok &= check("Colab IPython Extension", check_ipython_extension)
    ok &= check("Core Packages", check_packages)
    ok &= check("Workspace Mount (/content)", check_workspace_mount)

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
