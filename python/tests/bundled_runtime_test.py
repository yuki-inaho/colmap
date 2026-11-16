# SPDX-License-Identifier: BSD-3-Clause

import importlib.util
import sys
import types
from pathlib import Path

import pytest


@pytest.mark.parametrize("cuda_major", [0, 12, 13])
def test_prepare_runtime_preloads_bundled_libraries(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, cuda_major: int
) -> None:
    package_name = "_pycolmap_runtime_test"
    package = types.ModuleType(package_name)
    package.__path__ = [str(tmp_path)]
    monkeypatch.setitem(sys.modules, package_name, package)
    config = types.ModuleType(f"{package_name}._build_config")
    config.CUDA_MAJOR = cuda_major  # type: ignore[attr-defined]
    monkeypatch.setitem(sys.modules, config.__name__, config)
    spec = importlib.util.spec_from_file_location(
        f"{package_name}._runtime",
        Path(__file__).parents[1] / "pycolmap" / "_runtime.py",
    )
    assert spec is not None and spec.loader is not None
    runtime = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runtime)
    runtime.__file__ = str(tmp_path / "_runtime.py")
    monkeypatch.setattr(runtime.platform, "system", lambda: "Linux")

    library_root = tmp_path / "cuda"
    (library_root / "lib").mkdir(parents=True)
    for name in (
        "libcudart.so.12",
        "libcudart.so.13",
        "libcudnn_graph.so.9",
        "libcudnn_ops.so.9",
        "libcudnn_engines_runtime_compiled.so.9",
        "libcudnn.so.9",
    ):
        (library_root / "lib" / name).touch()
    ort_dir = tmp_path / "_ort"
    ort_dir.mkdir()
    (ort_dir / "libonnxruntime.so.1").touch()
    monkeypatch.setattr(
        runtime.importlib,
        "import_module",
        lambda name: types.SimpleNamespace(__path__=[str(library_root)]),
    )
    loaded: list[tuple[str, int]] = []
    monkeypatch.setattr(
        runtime.ctypes,
        "CDLL",
        lambda name, mode: loaded.append((Path(name).name, mode)),
    )

    runtime.prepare_runtime()

    assert loaded[-1] == ("libonnxruntime.so.1", runtime.ctypes.RTLD_GLOBAL)
    cuda_libraries = [
        name for name, _ in loaded if name.startswith("libcudart")
    ]
    assert cuda_libraries == (
        [f"libcudart.so.{cuda_major}"] if cuda_major else []
    )
    cudnn_libraries = [
        name for name, _ in loaded if name.startswith("libcudnn")
    ]
    assert cudnn_libraries == (
        [
            "libcudnn_graph.so.9",
            "libcudnn_ops.so.9",
            "libcudnn_engines_runtime_compiled.so.9",
            "libcudnn.so.9",
        ]
        if cuda_major
        else []
    )
