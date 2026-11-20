# FPGA VGA Frame Buffer

640x480 VGA output from a DE10-Lite (MAX 10). Pictures are drawn into a 320x240, 12-bit color frame buffer in block RAM, and the display logic reads it out and scales each pixel 2x2.

## Design

| File | Role |
|---|---|
| `rtl/vga_timing.v` | 640x480 sync generator, 25 MHz pixel enable from the 50 MHz clock |
| `rtl/frame_buffer.v` | dual-port block RAM, 76,800 x 12 bits |
| `rtl/pixel_painter.v` | redraws the frame during vertical blanking, 4 picture modes |
| `rtl/vga_core.v` | ties it together and delays sync to match the RAM read latency |
| `rtl/de10_lite_top.v` | board pins, reset and switch synchronizers |

| | Visible | Front porch | Sync | Back porch | Total |
|---|---|---|---|---|---|
| Horizontal (pixels) | 640 | 16 | 96 | 48 | 800 |
| Vertical (lines) | 480 | 10 | 2 | 33 | 525 |

25 MHz / 800 / 525 = 59.52 Hz. Both syncs are active low.

## Controls

| Control | Function |
|---|---|
| SW1:SW0 | 00 test card, 01 gradient, 10 bouncing box, 11 checkerboard |
| SW9 | freeze the current frame |
| KEY0 | reset |
| LEDR0 | toggles every 30 frames |

## Simulation

`tb/tb_vga.v` acts like a monitor: it rebuilds the screen from hsync/vsync and checks every visible pixel of the test card, plus the animation and freeze. The test card's 1-pixel border makes a one-pixel shift fail the test.

```sh
sh sim/run_icarus.sh                       # Icarus Verilog
python sim/ppm2png.py sim/out/frame_testcard.ppm
```

ModelSim: `do run_modelsim.do` from `sim/`.

## Build

Open `quartus/vga_framebuffer.qpf` in Quartus and compile.
