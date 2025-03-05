/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2024-09-29 09:16:21
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2024-11-10 18:21:38
 * @Filename     :
 * @Description  :
*/

/*
! 模块功能: I2C主机测试
! Vivado工程，使用的测试板卡为ZDYZ LHZ_ZYNQ7020_V1, 片上FPGA型号ZYNQ7020
* 思路:
  1.
*/

`default_nettype none

module LHZ_ZYNQ7020_I2C_Master_Top
(
  inout  wire i2c_sda,
  inout  wire i2c_scl,

  input wire fpga_clk // 50MHz
);


//++ 实例化VIO ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
wire clk;
wire vio_out;
vio_0 vio_0_u0 (
  .clk(clk),                // input wire clk
  .probe_out0(vio_out)  // output wire [0 : 0] probe_out0
);
//-- 实例化VIO ------------------------------------------------------------


//++ 时钟与复位 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
wire locked;
localparam CLK_FREQ_MHZ = 10;
clk_wiz_0  clk_wiz_0_u0 (
  .clk_in1  (fpga_clk),
  .locked   (locked  ),
  .clk_out1 (clk     )
);

localparam RSTN_CLK_WIDTH = 3;
reg [RSTN_CLK_WIDTH + 1 : 0] rstn_cnt;
always @(posedge clk) begin // 使用最慢的时钟
  if (locked)
    if (~(&rstn_cnt))
      rstn_cnt <= rstn_cnt + 1'b1;
    else
      rstn_cnt <= rstn_cnt;
  else
    rstn_cnt <= 'd0;
end

/*
  初始为0, locked为高后经过2^RSTN_CLK_WIDTH个clk周期, rstn为1
  再过2^RSTN_CLK_WIDTH个clk周期, rstn为0
  在过2^RSTN_CLK_WIDTH个clk周期后, rstn为1, 后续会保持1
  总的来说, 复位低电平有效持续(2^RSTN_CLK_WIDTH)个clk周期
*/
wire rstn = rstn_cnt[RSTN_CLK_WIDTH] && vio_out;
//-- 时钟与复位 ------------------------------------------------------------


//++ 实例化I2C主机与FIFO模块 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//~ I2C FIFO
(* mark_debug *)reg [55:0] i2c_fifo_din;
(* mark_debug *)wire       i2c_fifo_wr_en;
(* mark_debug *)wire       i2c_fifo_full;

// ~读数据与对应地址输出
wire [6 :0] i2c_device_addr;
wire [15:0] i2c_data_addr; // 读出数据对应的数据地址
wire [7 :0] i2c_wdata;
wire        i2c_wr_data_success;
wire [7 :0] i2c_rdata; // 读出的数据
wire        i2c_rdata_valid; // 读出的数据有效, 高电平有效

wire i2c_sda_i = i2c_sda;
wire i2c_sda_o;
wire i2c_sda_oen;
assign i2c_sda = i2c_sda_oen ? i2c_sda_o : 1'bz;

wire i2c_scl_i = i2c_scl;
wire i2c_scl_o;
wire i2c_scl_oen;
assign i2c_scl = i2c_scl_oen ? i2c_scl_o : 1'bz;

i2cMaster_withFIFO #(
  .CLK_FREQ_MHZ    (CLK_FREQ_MHZ),
  .FIFO_ADDR_WIDTH (            )
) i2cMaster_withFIFO_inst (
  .i2c_fifo_din              (i2c_fifo_din             ),
  .i2c_fifo_wr_en            (i2c_fifo_wr_en           ),
  .i2c_fifo_full             (i2c_fifo_full            ),
  .i2c_device_addr           (i2c_device_addr          ),
  .i2c_data_addr             (i2c_data_addr            ),
  .i2c_wdata                 (i2c_wdata                ),
  .i2c_wr_data_success       (i2c_wr_data_success      ),
  .i2c_rdata                 (i2c_rdata                ),
  .i2c_rdata_valid           (i2c_rdata_valid          ),
  .i2c_sda_i                 (i2c_sda_i                ),
  .i2c_sda_o                 (i2c_sda_o                ),
  .i2c_sda_oen               (i2c_sda_oen              ),
  .i2c_scl_i                 (i2c_scl_i                ),
  .i2c_scl_o                 (i2c_scl_o                ),
  .i2c_scl_oen               (i2c_scl_oen              ),
  .clk                       (clk                      ),
  .rstn                      (rstn                     )
  );
//-- 实例化I2C主机与FIFO模块 ------------------------------------------------------------


//++ I2C读写 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam [6:0] SLAVE_AT24C64_DEVICE_ADDR = 7'b1010_000; // 适用于EEPROM-ATMEL-AT24C64, 100k
localparam [7:0] AT24C64_CTRL_BYTE = 8'b1111_0000; // 16位地址

localparam [6:0] SLAVE_PCF8563_DEVICE_ADDR = 7'b1010_001; // 适用于实时时钟_日历-NXP-PCF8563, 400k
localparam [7:0] PCF8563_CTRL_BYTE = 8'b1101_0000; //8位地址

localparam RD = 1'b1;
localparam WR = 1'b0;
localparam [7:0] wr_data = 8'hAA;

//~ clk频率与i2c_scl频率的比值, 如100MHz/100kHz = 1000, 新的I2C频率会在下一次传输时生效
localparam [15:0] I2C_CLK_FREQ_DIV_SCL_FREQ_100K = CLK_FREQ_MHZ * 1000 / 100;
localparam [15:0] I2C_CLK_FREQ_DIV_SCL_FREQ_400K = CLK_FREQ_MHZ * 1000 / 400;

reg [3:0] din_cnt;
always @(posedge clk) begin
  if (~rstn)
    din_cnt <= 'd0;
  else
    din_cnt <= din_cnt + 1'b1;
end

assign i2c_fifo_wr_en = ~i2c_fifo_full;

always @(posedge clk) begin
  if (~rstn)
    i2c_fifo_din <= {SLAVE_AT24C64_DEVICE_ADDR, RD, 16'h0000, wr_data, I2C_CLK_FREQ_DIV_SCL_FREQ_100K};
  case (din_cnt)
    //~ AT24C64 先写后读
    0 : i2c_fifo_din <= {SLAVE_AT24C64_DEVICE_ADDR, RD, 16'h0001, wr_data+8'd0, AT24C64_CTRL_BYTE
                        , I2C_CLK_FREQ_DIV_SCL_FREQ_100K};
    1 : i2c_fifo_din <= {SLAVE_AT24C64_DEVICE_ADDR, WR, 16'h0000, wr_data+8'd1, AT24C64_CTRL_BYTE
                        , I2C_CLK_FREQ_DIV_SCL_FREQ_100K};
    2 : i2c_fifo_din <= {SLAVE_AT24C64_DEVICE_ADDR, WR, 16'h0001, wr_data+8'd2, AT24C64_CTRL_BYTE
                        , I2C_CLK_FREQ_DIV_SCL_FREQ_100K};
    3 : i2c_fifo_din <= {SLAVE_AT24C64_DEVICE_ADDR, WR, 16'h0002, wr_data+8'd3, AT24C64_CTRL_BYTE
                        , I2C_CLK_FREQ_DIV_SCL_FREQ_100K};
    4 : i2c_fifo_din <= {SLAVE_AT24C64_DEVICE_ADDR, WR, 16'h0003, wr_data+8'd4, AT24C64_CTRL_BYTE
                        , I2C_CLK_FREQ_DIV_SCL_FREQ_100K};
    5 : i2c_fifo_din <= {SLAVE_AT24C64_DEVICE_ADDR, RD, 16'h0000, wr_data+8'd5, AT24C64_CTRL_BYTE
                        , I2C_CLK_FREQ_DIV_SCL_FREQ_100K};
    6 : i2c_fifo_din <= {SLAVE_AT24C64_DEVICE_ADDR, RD, 16'h0001, wr_data+8'd6, AT24C64_CTRL_BYTE
                        , I2C_CLK_FREQ_DIV_SCL_FREQ_100K};
    7 : i2c_fifo_din <= {SLAVE_AT24C64_DEVICE_ADDR, RD, 16'h0002, wr_data+8'd7, AT24C64_CTRL_BYTE
                        , I2C_CLK_FREQ_DIV_SCL_FREQ_100K};
    8 : i2c_fifo_din <= {SLAVE_AT24C64_DEVICE_ADDR, RD, 16'h0003, wr_data+8'd8, AT24C64_CTRL_BYTE
                        , I2C_CLK_FREQ_DIV_SCL_FREQ_100K};
    //~ PCF8563 读取日期和时间
    9 : i2c_fifo_din <= {SLAVE_PCF8563_DEVICE_ADDR, RD, 16'h0000, wr_data+8'd0, PCF8563_CTRL_BYTE
                        , I2C_CLK_FREQ_DIV_SCL_FREQ_400K};
    10: i2c_fifo_din <= {SLAVE_PCF8563_DEVICE_ADDR, RD, 16'h0001, wr_data+8'd1, PCF8563_CTRL_BYTE
                        , I2C_CLK_FREQ_DIV_SCL_FREQ_400K};
    11: i2c_fifo_din <= {SLAVE_PCF8563_DEVICE_ADDR, RD, 16'h0002, wr_data+8'd2, PCF8563_CTRL_BYTE
                        , I2C_CLK_FREQ_DIV_SCL_FREQ_400K};
    12: i2c_fifo_din <= {SLAVE_PCF8563_DEVICE_ADDR, RD, 16'h0003, wr_data+8'd3, PCF8563_CTRL_BYTE
                        , I2C_CLK_FREQ_DIV_SCL_FREQ_400K};
    13: i2c_fifo_din <= {SLAVE_PCF8563_DEVICE_ADDR, RD, 16'h0004, wr_data+8'd4, PCF8563_CTRL_BYTE
                        , I2C_CLK_FREQ_DIV_SCL_FREQ_400K};
    14: i2c_fifo_din <= {SLAVE_PCF8563_DEVICE_ADDR, RD, 16'h0005, wr_data+8'd5, PCF8563_CTRL_BYTE
                        , I2C_CLK_FREQ_DIV_SCL_FREQ_400K};
    15: i2c_fifo_din <= {SLAVE_PCF8563_DEVICE_ADDR, RD, 16'h0006, wr_data+8'd6, PCF8563_CTRL_BYTE
                        , I2C_CLK_FREQ_DIV_SCL_FREQ_400K};
    default: i2c_fifo_din <= {SLAVE_AT24C64_DEVICE_ADDR, RD, 16'h0, wr_data, I2C_CLK_FREQ_DIV_SCL_FREQ_100K};
  endcase
end
//-- I2C读写 ------------------------------------------------------------


endmodule
`resetall