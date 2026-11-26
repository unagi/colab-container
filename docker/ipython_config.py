"""IPython configuration matching official Google Colab ergonomics."""

c = get_config()  # noqa: F821

# Load google.colab IPython extension (magics, data_table, widgets, output, etc.)
c.InteractiveShellApp.extensions = [
    "google.colab",
]
c.InteractiveShellApp.reraise_ipython_extension_failures = True

# Render matplotlib plots inline by default
c.InteractiveShellApp.matplotlib = "inline"

# Avoid sqlite history file contention warnings inside ephemeral containers
c.HistoryManager.hist_file = ":memory:"

# Suppress noisy default logger warnings matching official Colab startup
c.InteractiveShellApp.exec_lines = [
    '__import__("logging").basicConfig()',
    '__import__("logging").getLogger("google.auth._default").setLevel(40)',
]
