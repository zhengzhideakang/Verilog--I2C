/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2024-10-23 11:01:37
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2024-11-10 17:13:22
 * @Filename     :
 * @Description  :
*/

/*
! 模块功能: I2C主机testbench
* 思路:
  1.
*/

`default_nettype none

module i2cMaster_withFIFO_tb ();

timeunit 1ns;
timeprecision 10ps;

//++ 实例化待测模块 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam CLK_FREQ_MHZ = 50;

logic [55:0] i2c_fifo_din;
logic        i2c_fifo_wr_en;
logic        i2c_fifo_full;
logic [6 :0] i2c_device_addr;
logic [15:0] i2c_data_addr;
logic [7 :0] i2c_wdata;
logic        i2c_wr_data_success;
logic [7 :0] i2c_rdata;
logic        i2c_rdata_valid;
logic i2c_sda_i;
logic i2c_sda_o;
logic i2c_sda_oen;
logic i2c_scl_i;
logic i2c_scl_o;
logic i2c_scl_oen;
logic clk;
logic rstn;

wire sda = i2c_sda_oen ? i2c_sda_o : 1'bz;
assign i2c_sda_i = sda;
wire scl = i2c_scl_oen ? i2c_scl_o : 1'b1;
assign i2c_scl_i = scl;

pullup(sda);

i2cMaster_withFIFO #(
  .CLK_FREQ_MHZ (CLK_FREQ_MHZ)
) i2cMaster_withFIFO_inst (.*);
//-- 实例化待测模块 ------------------------------------------------------------


//++ 实例化不同容量的EEPROM ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
`define AT24CM02
//`define AT24CM01
//`define AT24C512C
//`define AT24C64C
//`define AT24C02A

`ifdef AT24C02D
AT24C02D  AT24C02D_inst(
  .SDA (sda),
  .SCL (scl),
  .WP  (0  )
);
logic [6:0] slave_device_addr = 7'b1010_100;
logic [7:0] ctrl_byte = 8'b1101_0000;
`endif

`ifdef AT24C64D
AT24C64D  AT24C64D_inst(
  .SDA (sda),
  .SCL (scl),
  .WP  (0  )
);
logic [6:0] slave_device_addr = 7'b1010_111;
logic [7:0] ctrl_byte = 8'b1111_0000;
`endif

`ifdef AT24C512C
AT24C512C  AT24C512C_inst(
  .SDA (sda),
  .SCL (scl),
  .WP  (0  )
);
logic [6:0] slave_device_addr = 7'b1010_011;
logic [7:0] ctrl_byte = 8'b1111_0000;
`endif

`ifdef AT24CM01
AT24CM01  AT24CM01_inst(
  .SDA (sda),
  .SCL (scl),
  .WP  (0  )
);
logic [6:0] slave_device_addr = {6'b1010_00, 1'b1};
logic [7:0] ctrl_byte = 8'b1111_0000;
`endif

`ifdef AT24CM02
AT24CM02  AT24CM02_inst(
  .SDA (sda),
  .SCL (scl),
  .WP  (0  )
);
logic [6:0] slave_device_addr = {6'b1010_00, 1'b0};
logic [7:0] ctrl_byte = 8'b1111_0000;
`endif
//-- 实例化不同容量的EEPROM ------------------------------------------------------------


//++ 生成时钟 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam CLKT = 10; // 10对应100MHz
initial begin
  clk = 0;
  forever #(CLKT / 2) clk = ~clk;
end
//-- 生成时钟 ------------------------------------------------------------


//++ 测试流程 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
logic [15:0] wr_addr = 16'h0555;
logic [7 :0] wr_data = 8'hAA;
logic rd_bit = 1'b1;
logic wr_bit = 1'b0;
logic [15:0] i2c_clk_freq_div_scl_freq_100k = 1000;
logic [15:0] i2c_clk_freq_div_scl_freq_400k = 1000 / 4;
logic [15:0] i2c_clk_freq_div_scl_freq_1000k = 1000 / 10;

initial begin
  rstn = 0;
  i2c_fifo_wr_en = 0;
  #(CLKT * 10) rstn = 1;
  #(CLKT*10.8)
  i2c_fifo_din = {slave_device_addr, wr_bit, wr_addr, wr_data, ctrl_byte, i2c_clk_freq_div_scl_freq_100k};
  i2c_fifo_wr_en = ~i2c_fifo_full;
  #(CLKT*1); i2c_fifo_wr_en = 0;
  #(CLKT*1);
  i2c_fifo_din = {slave_device_addr, wr_bit, wr_addr+16'd1, wr_data+1'b1, ctrl_byte, i2c_clk_freq_div_scl_freq_100k};
  i2c_fifo_wr_en = ~i2c_fifo_full;
  #(CLKT*1) i2c_fifo_wr_en = 0;
  #(CLKT*1);
  i2c_fifo_din = {slave_device_addr, rd_bit, wr_addr, wr_data, ctrl_byte, i2c_clk_freq_div_scl_freq_1000k};
  i2c_fifo_wr_en = ~i2c_fifo_full;
  #(CLKT*1) i2c_fifo_wr_en = 0;
  #(CLKT*1);
  i2c_fifo_din = {slave_device_addr, rd_bit, wr_addr+16'd1, wr_data, ctrl_byte, i2c_clk_freq_div_scl_freq_1000k};
  i2c_fifo_wr_en = ~i2c_fifo_full;
  #(CLKT*1) i2c_fifo_wr_en = 0;
  #(CLKT*1) wait(i2c_rdata_valid);
  #(CLKT * 2) wait(i2c_rdata_valid);
  #(CLKT * 30000);
  $stop;
end
//-- 测试流程 ------------------------------------------------------------


endmodule
`resetall