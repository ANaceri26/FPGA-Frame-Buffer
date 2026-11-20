#!/bin/sh
set -e
cd "$(dirname "$0")"
mkdir -p out

echo "=== frame buffer unit test ==="
iverilog -g2005 -o out/fb.vvp ../rtl/frame_buffer.v ../tb/tb_frame_buffer.v
vvp out/fb.vvp

echo "=== VGA system test ==="
iverilog -g2005 -o out/vga.vvp ../rtl/vga_timing.v ../rtl/frame_buffer.v ../rtl/pixel_painter.v ../rtl/vga_core.v ../tb/tb_vga.v
vvp out/vga.vvp

echo "Frames written to sim/out/*.ppm  (python ppm2png.py out/frame_testcard.ppm to convert)"
