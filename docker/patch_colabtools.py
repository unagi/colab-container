"""Minimal compatibility patches for google-colab (colabtools) on NGC PyTorch 26.11."""

from pathlib import Path
import site


def _find_colab_dir() -> Path:
    for sp in site.getsitepackages():
        candidate = Path(sp) / "google" / "colab"
        if candidate.is_dir():
            return candidate
    raise RuntimeError("Could not locate installed google.colab package")


def patch_shell_customizations(colab_dir: Path) -> None:
    """IPython 9.x removed TermColors.Green; fall back to standard ANSI green."""
    path = colab_dir / "_shell_customizations.py"
    src = path.read_text(encoding="utf-8")
    target = "coloransi.TermColors.Green"
    replacement = "getattr(coloransi.TermColors, 'Green', '\\033[0;32m')"
    if replacement in src:
        return
    assert target in src, f"Expected {target!r} in {path}"
    path.write_text(src.replace(target, replacement), encoding="utf-8")
    print(f"Patched {path} (IPython 9 TermColors.Green)")


def patch_ram_utils(colab_dir: Path) -> None:
    """Avoid `ps -q ''` crash when 0 kernels are active and handle jupyter-client 8 PIDs."""
    path = colab_dir / "_serverextension" / "_ram_utils.py"
    src = path.read_text(encoding="utf-8")
    target = """  pids_to_kernel_ids = {
      get_pid(kernel_manager.get_kernel(kernel_id)): kernel_id
      for kernel_id in kernel_manager.list_kernel_ids()
  }
  kernels = {}"""
    replacement = """  pids_to_kernel_ids = {}
  for kernel_id in kernel_manager.list_kernel_ids():
    pid = get_pid(kernel_manager.get_kernel(kernel_id))
    if pid and pid != 'None':
      pids_to_kernel_ids[pid] = kernel_id
  kernels = {}
  if not pids_to_kernel_ids:
    return kernels"""
    if "if not pids_to_kernel_ids:" in src:
        return
    assert target in src, f"Expected pids_to_kernel_ids block in {path}"
    path.write_text(src.replace(target, replacement), encoding="utf-8")
    print(f"Patched {path} (empty kernel list / PID guard)")


def main() -> None:
    colab_dir = _find_colab_dir()
    patch_shell_customizations(colab_dir)
    patch_ram_utils(colab_dir)


if __name__ == "__main__":
    main()
