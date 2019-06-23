# ---- iCE40 UltraPlus Breakout  Board ----

icebsim: icebreaker_tb.vvp icebreaker_fw.hex
	vvp -N $< +firmware=icebreaker_fw.hex

icebsynsim: icebreaker_syn_tb.vvp icebreaker_fw.hex
	vvp -N $< +firmware=icebreaker_fw.hex

icebreaker.json: hdl/icebreaker.v hdl/ice40up5k_spram.v hdl/spimemio.v hdl/simpleuart.v hdl/picosoc.v picorv32/picorv32.v
	yosys -ql icebreaker.log -p 'synth_ice40 -top icebreaker -json icebreaker.json' $^

icebreaker_tb.vvp: hdl/icebreaker_tb.v hdl/icebreaker.v hdl/ice40up5k_spram.v hdl/spimemio.v hdl/simpleuart.v hdl/picosoc.v picorv32/picorv32.v hdl/spiflash.v
	iverilog -s testbench -o $@ $^ `yosys-config --datdir/ice40/cells_sim.v`

icebreaker_syn_tb.vvp: hdl/icebreaker_tb.v hdl/icebreaker_syn.v hdl/spiflash.v
	iverilog -s testbench -o $@ $^ `yosys-config --datdir/ice40/cells_sim.v`

icebreaker_syn.v: icebreaker.json
	yosys -p 'read_json icebreaker.json; write_verilog icebreaker_syn.v'

icebreaker.asc: constr/pinout.pcf icebreaker.json
	nextpnr-ice40 --freq 13 --up5k --asc icebreaker.asc --pcf constr/pinout.pcf --json icebreaker.json

icebreaker.bin: icebreaker.asc
	icetime -d up5k -c 12 -mtr icebreaker.rpt icebreaker.asc
	icepack icebreaker.asc icebreaker.bin

icebprog: icebreaker.bin icebreaker_fw.bin
	iceprog icebreaker.bin
	iceprog -o 1M icebreaker_fw.bin

icebprog_fw: icebreaker_fw.bin
	iceprog -o 1M icebreaker_fw.bin

icebreaker_sections.lds: ./hdl/sections.lds
	riscv32-unknown-elf-cpp -P -DICEBREAKER -o $@ $^

icebreaker_fw.elf: ./src/icebreaker_sections.lds ./src/start.s ./src/firmware.c
	riscv32-unknown-elf-gcc -DICEBREAKER -march=rv32ic -Wl,-Bstatic,-T,./src/icebreaker_sections.lds,--strip-debug -ffreestanding -nostdlib -o icebreaker_fw.elf ./src/start.s ./src/firmware.c

icebreaker_fw.hex: icebreaker_fw.elf
	riscv32-unknown-elf-objcopy -O verilog icebreaker_fw.elf icebreaker_fw.hex

icebreaker_fw.bin: icebreaker_fw.elf
	riscv32-unknown-elf-objcopy -O binary icebreaker_fw.elf icebreaker_fw.bin

# ---- Testbench for SPI Flash Model ----

spiflash_tb: spiflash_tb.vvp firmware.hex
	vvp -N $<

spiflash_tb.vvp: spiflash.v spiflash_tb.v
	iverilog -s testbench -o $@ $^

# ---- ASIC Synthesis Tests ----

cmos.log: spimemio.v simpleuart.v picosoc.v ../picorv32.v
	yosys -l cmos.log -p 'synth -top picosoc; abc -g cmos2; opt -fast; stat' $^

# ---- Clean ----

clean:
	rm -f testbench.vvp testbench.vcd spiflash_tb.vvp spiflash_tb.vcd
	rm -f icebreaker_fw.elf icebreaker_fw.hex icebreaker_fw.bin
	rm -f icebreaker.json icebreaker.log icebreaker.asc icebreaker.rpt icebreaker.bin
	rm -f icebreaker_syn.v icebreaker_syn_tb.vvp icebreaker_tb.vvp

.PHONY: spiflash_tb clean
.PHONY: icebprog icebprog_fw icebsim icebsynsim
