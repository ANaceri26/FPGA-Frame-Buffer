# vga_framebuffer.sdc - timing constraints

# One clock: the 50 MHz oscillator (20 ns period). The 25 MHz pixel rate is a
# clock ENABLE inside the design, not a second clock, so nothing else to declare.
create_clock -name clk50 -period 20.000 [get_ports MAX10_CLK1_50]
derive_clock_uncertainty

# Switches and the reset button are asynchronous and go through synchronisers.
set_false_path -from [get_ports {KEY[*] SW[*]}]
set_false_path -to   [get_ports {LEDR[*]}]

# The VGA pins are driven straight from flip-flops, all clocked by the same
# edge, so they change together. The monitor has no clock input (it rebuilds
# timing from hsync), so there is no setup/hold relationship to constrain.
set_false_path -to [get_ports {VGA_R[*] VGA_G[*] VGA_B[*] VGA_HS VGA_VS}]
