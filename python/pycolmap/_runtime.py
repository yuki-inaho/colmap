# SPDX-License-Identifier: BSD-3-Clause

"""Load bundled ONNX Runtime and pip-installed CUDA libraries on Linux."""

import contextlib
import ctypes
import importlib
import platform
from pathlib import Path

_loaded_libraries: list[ctypes.CDLL] = []


def _load_package_library(module_name: str, filename: str) -> None:
    try:
        module = importlib.import_module(module_name)
    except ImportError:
        return
    if module_file := getattr(module, "__file__", None):
        roots = [Path(module_file).parent]
    else:
        roots = [Path(path) for path in getattr(module, "__path__", ())]
    for root in roots:
        for path in sorted((root / "lib").glob(filename)):
            with contextlib.suppress(OSError):
                _loaded_libraries.append(
                    ctypes.CDLL(str(path), mode=ctypes.RTLD_GLOBAL)
                )
                return


def prepare_runtime() -> None:
    if platform.system() != "Linux":
        return
    try:
        from ._build_config import CUDA_MAJOR
    except ImportError:
        # Source builds without a bundled runtime retain the existing CUDA 12
        # preload behavior.
        CUDA_MAJOR = 12

    if CUDA_MAJOR in (12, 13):
        prefix = "nvidia.cu13" if CUDA_MAJOR == 13 else None
        libraries = [
            ("nvjitlink", f"libnvJitLink.so.{CUDA_MAJOR}"),
            ("cuda_runtime", f"libcudart.so.{CUDA_MAJOR}"),
            ("curand", "libcurand.so.10"),
            ("cublas", f"libcublasLt.so.{CUDA_MAJOR}"),
            ("cublas", f"libcublas.so.{CUDA_MAJOR}"),
            ("cufft", f"libcufft.so.{12 if CUDA_MAJOR == 13 else 11}"),
            ("cuda_nvrtc", f"libnvrtc.so.{CUDA_MAJOR}"),
        ]
        for package, filename in libraries:
            _load_package_library(prefix or f"nvidia.{package}", filename)
        _load_package_library("nvidia.cudnn", "libcudnn.so.9")

    ort_library = Path(__file__).parent / "_ort" / "libonnxruntime.so.1"
    if ort_library.exists():
        _loaded_libraries.append(
            ctypes.CDLL(str(ort_library), mode=ctypes.RTLD_GLOBAL)
        )
