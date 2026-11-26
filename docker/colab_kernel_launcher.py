"""Custom IPython kernel launcher setting ZMQ iopub HWM=0 (matching official Colab)."""

from ipykernel import kernelapp
import zmq


class ColabKernelApp(kernelapp.IPKernelApp):
    """Prevents dropping large iopub streams when communicating with Colab."""

    def init_iopub(self, context):
        context.setsockopt(zmq.RCVHWM, 0)
        context.setsockopt(zmq.SNDHWM, 0)
        return super().init_iopub(context)


if __name__ == "__main__":
    ColabKernelApp.launch_instance()
