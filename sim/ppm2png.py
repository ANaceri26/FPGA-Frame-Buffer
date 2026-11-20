#!/usr/bin/env python3
"""ppm2png.py - convert the testbench's PPM frame dumps to PNG (needs Pillow).

    pip install pillow
    python ppm2png.py out/frame_testcard.ppm
"""
import sys
from PIL import Image

for path in sys.argv[1:]:
    tokens = open(path).read().split()
    assert tokens[0] == "P3", "not a text PPM"
    w, h = int(tokens[1]), int(tokens[2])
    data = bytes(int(t) for t in tokens[4:4 + 3 * w * h])
    out = path.rsplit(".", 1)[0] + ".png"
    Image.frombytes("RGB", (w, h), data).save(out)
    print(out)
