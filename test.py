#!/bin/env python3

from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib'
lib = vu.add_library("lib")

# Uncomment below for testing pixel driver
#lib.add_source_files("src/vhdl/tb_pixel_driver.vhdl")
#lib.add_source_files("src/vhdl/kb_matrix_ram.vhdl")
#lib.add_source_files("src/vhdl/debugtools.vhdl")
#lib.add_source_files("src/vhdl/mega65kbd_to_matrix.vhdl")
#lib.add_source_files("i2c_slave/rtl/vhdl/*.vhdl")
#lib.add_source_files("src/vhdl/pixel_driver.vhdl")
#lib.add_source_files("src/vhdl/frame_generator.vhdl")
#lib.add_source_files("src/vhdl/ghdl_ram32x1024_sync.vhdl")

# Uncomment below for testing SDRAM controller
#lib.add_source_files("src/vhdl/tb_sdram.vhdl");
#lib.add_source_files("src/vhdl/sdram_controller.vhdl");
#lib.add_source_files("src/vhdl/debugtools.vhdl")
#lib.add_source_files("src/vhdl/cputypes.vhdl")
#lib.add_source_files("src/vhdl/is42s16320f_model.vhdl")

# Uncomment below for testing slow_devices driving SDRAM
#lib.add_source_files("src/vhdl/tb_slow_drives_sdram.vhdl");
#lib.add_source_files("src/vhdl/debugtools.vhdl")
#lib.add_source_files("src/vhdl/cputypes.vhdl")
#lib.add_source_files("src/vhdl/slow_devices.vhdl");
#lib.add_source_files("src/vhdl/expansion_port_controller.vhdl");
#lib.add_source_files("src/vhdl/dummy_opl2.vhdl");
#lib.add_source_files("src/vhdl/sdram_controller.vhdl");
#lib.add_source_files("src/vhdl/is42s16320f_model.vhdl")

# Uncomment below for testing IEC hardware accelerator
lib.add_source_files("src/vhdl/tb_iec_serial.vhdl");
lib.add_source_files("src/vhdl/iec_serial.vhdl");
lib.add_source_files("src/vhdl/debugtools.vhdl")
lib.add_source_files("src/vhdl/cputypes.vhdl")
lib.add_source_files("src/vhdl/victypes.vhdl")
lib.add_source_files("src/vhdl/ghdl_ram8x4096_sync.vhdl")
lib.add_source_files("src/vhdl/internal1541.vhdl")
lib.add_source_files("src/vhdl/dpram8x4096.vhdl")
lib.add_source_files("src/vhdl/driverom.vhdl")
lib.add_source_files("src/vhdl/dummy_cpu6502.vhdl")

vu.set_compile_option("ghdl.a_flags", ["-frelaxed-rules"])
vu.set_compile_option("ghdl.flags", ["-frelaxed-rules"])
vu.set_sim_option("ghdl.elab_flags", ["-frelaxed-rules"])
vu.set_sim_option("ghdl.sim_flags", ["--ieee-asserts=disable"])

# Run vunit function
vu.main()
