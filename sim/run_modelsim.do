# From sim/: do run_modelsim.do

if {[file exists work]} { vdel -lib work -all }
vlib work
file mkdir out

vlog ../rtl/vga_timing.v ../rtl/frame_buffer.v ../rtl/pixel_painter.v ../rtl/vga_core.v \
     ../tb/tb_frame_buffer.v ../tb/tb_vga.v

vsim -voptargs=+acc -onfinish stop work.tb_frame_buffer
add wave /tb_frame_buffer/clk /tb_frame_buffer/re
add wave -radix unsigned /tb_frame_buffer/raddr
add wave -radix hex /tb_frame_buffer/rdata
run -all
quit -sim

vsim -voptargs=+acc -onfinish stop work.tb_vga
add wave -divider "stage 0: counters"
add wave /tb_vga/clk /tb_vga/dut/pix_en
add wave -radix unsigned /tb_vga/dut/x /tb_vga/dut/y
add wave /tb_vga/dut/hsync /tb_vga/dut/vsync /tb_vga/dut/active
add wave -radix unsigned /tb_vga/dut/rd_addr
add wave -divider "stage 1: RAM output"
add wave -radix hex /tb_vga/dut/rd_data
add wave /tb_vga/dut/hsync_d1 /tb_vga/dut/active_d1
add wave -divider "stage 2: pins"
add wave -radix hex /tb_vga/r /tb_vga/g /tb_vga/b
add wave /tb_vga/hs /tb_vga/vs /tb_vga/act
add wave -divider "painter"
add wave /tb_vga/frame_start /tb_vga/dut/u_painter/busy /tb_vga/dut/wr_en
add wave -radix unsigned /tb_vga/dut/wr_addr
run -all

