/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2024-09-14 11:40:11
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2024-11-11 00:28:53
 * @Filename     :
 * @Description  :
*/

/*
! 模块功能: i2cMaster实例化参考
*/


//++ 实例化I2C主机与FIFO模块 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//~ I2C FIFO
reg [55:0] i2c_fifo_din;
wire       i2c_fifo_wr_en;
wire       i2c_fifo_full;

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