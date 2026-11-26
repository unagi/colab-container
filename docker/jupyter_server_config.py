"""Jupyter Server configuration for local Google Colab runtime (RTX Spark ARM64)."""

import os

c = get_config()  # noqa: F821

# Non-interactive container operation
c.ServerApp.answer_yes = True
c.JupyterApp.answer_yes = True
c.ServerApp.open_browser = False
c.ServerApp.allow_root = True

# Network & port settings (mapped to 127.0.0.1:${COLAB_PORT} by Docker Compose)
c.ServerApp.ip = "0.0.0.0"
c.ServerApp.port = int(os.environ.get("JUPYTER_PORT", "8080"))
c.ServerApp.port_retries = 0
c.ServerApp.root_dir = "/content"
c.ServerApp.trust_xheaders = True

# Google Colab cross-origin & Private Network Access (PNA) support
c.ServerApp.allow_origin_pat = os.environ.get(
    "COLAB_JUPYTER_ALLOW_ORIGIN_PAT",
    r"^https://colab\.(sandbox|research)\.google\.com$",
)
c.ServerApp.allow_credentials = True
c.ServerApp.allow_remote_access = True
c.ServerApp.disable_check_xsrf = True
c.ServerApp.tornado_settings = {
    "headers": {
        "Access-Control-Allow-Private-Network": "true",
    }
}

# Avoid dropping packets when streaming large outputs/plots/tensors (matches official Colab)
c.ZMQChannelsWebsocketConnection.iopub_data_rate_limit = 1e10
c.ZMQChannelsWebsocketConnection.iopub_msg_rate_limit = 10000
c.ZMQChannelsWebsocketConnection.rate_limit_window = 1.0

# Kernel & file manager settings matching official Colab
c.MultiKernelManager.default_kernel_name = "python3"
c.FileContentsManager.allow_hidden = True
c.LargeFileManager.delete_to_trash = False
