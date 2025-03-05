# LHZ_ZYNQ7020_I2C-master_PIN.xdc
# 代码压缩与烧写速度
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

# 时钟与复位 50MHz
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports fpga_clk]

# EEPROM(ATMEL-AT24C64) Audio(凌云逻辑-WM8960) I2C
set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVCMOS33} [get_ports i2c_scl]
set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVCMOS33} [get_ports i2c_sda]

