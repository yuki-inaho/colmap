# SPDX-License-Identifier: BSD-3-Clause

import os
import sqlite3
from pathlib import Path

import numpy as np
import pytest
from PIL import Image, ImageFilter


@pytest.mark.skipif(
    os.environ.get("PYCOLMAP_TEST_ONNX") != "1",
    reason="set PYCOLMAP_TEST_ONNX=1 to run the ONNX model download smoke test",
)
def test_aliked_lightglue_end_to_end(tmp_path: Path) -> None:
    import pycolmap

    images = tmp_path / "images"
    images.mkdir()
    pixels = np.random.default_rng(42).integers(
        0, 256, size=(256, 256, 3), dtype=np.uint8
    )
    image = Image.fromarray(pixels).filter(ImageFilter.GaussianBlur(2))
    image.save(images / "one.png")
    image.save(images / "two.png")

    extraction = pycolmap.FeatureExtractionOptions()
    extraction.type = pycolmap.FeatureExtractorType.ALIKED_N16ROT
    extraction.num_threads = 1
    extraction.aliked.max_num_features = 512
    extraction.aliked.min_score = 0.05
    matching = pycolmap.FeatureMatchingOptions()
    matching.type = pycolmap.FeatureMatcherType.ALIKED_LIGHTGLUE
    matching.num_threads = 1
    matching.skip_geometric_verification = True
    device = (
        pycolmap.Device.cuda
        if os.environ.get("PYCOLMAP_TEST_DEVICE") == "cuda"
        else pycolmap.Device.cpu
    )
    database_path = tmp_path / "database.db"
    pycolmap.extract_features(
        database_path, images, extraction_options=extraction, device=device
    )
    pycolmap.match_exhaustive(
        database_path, matching_options=matching, device=device
    )
    with sqlite3.connect(database_path) as database:
        assert (
            database.execute(
                "SELECT count(*) FROM keypoints WHERE rows > 0"
            ).fetchone()[0]
            == 2
        )
        assert (
            database.execute(
                "SELECT coalesce(sum(rows), 0) FROM matches"
            ).fetchone()[0]
            > 0
        )
