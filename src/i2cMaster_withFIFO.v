/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2024-10-22 10:16:56
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2024-11-09 20:02:05
 * @Filename     :
 * @Description  :
*/

/*
! 模块功能: 将I2CMaster与同步FIFO封装在一起, 外部对I2C从机的读写转换为对此FIFO的写入
* 思路:
  1.
*/

`default_nettype none

module i2cMaster_withFIFO
#(
  parameter CLK_FREQ_MHZ = 100, // 模块时钟频率
  parameter FIFO_ADDR_WIDTH = 4 // FIFO地址位宽, 可取1, 2, 3, ... , 默认为4, 对应深度2**4
)(
  //~ I2C FIFO
  input  wire [55:0] i2c_fifo_din,
  input  wire        i2c_fifo_wr_en,
  output wire        i2c_fifo_full,

  //~ 读/写数据过程指示
  output wire [6 :0] i2c_device_addr,     // 当前正在操作的从机设备地址
  output wire [15:0] i2c_data_addr,       // 当前正在操作的从机数据地址
  output wire [7 :0] i2c_wdata,           // 写入的数据
  output wire        i2c_wr_data_success, // 写入成功, 高电平有效
  output wire [7 :0] i2c_rdata,           // 读出的数据
  output wire        i2c_rdata_valid,     // 读出的数据有效, 高电平有效

  //~ I2C物理接口, 顶层inout信号分解为三个
  input  wire i2c_sda_i,
  output wire i2c_sda_o,
  output wire i2c_sda_oen,
  input  wire i2c_scl_i,
  output wire i2c_scl_o,
  output wire i2c_scl_oen,

  input  wire clk,
  input  wire rstn
);


//++ 实例化同步FIFO ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam FIFO_DATA_WIDTH = 56;
wire [FIFO_DATA_WIDTH-1:0] i2c_fwft_fifo_dout;
wire                       i2c_fwft_fifo_rd_en;
wire                       i2c_fwft_fifo_empty;

syncFIFO #(
  .DATA_WIDTH (FIFO_DATA_WIDTH), // 数据位宽, 可取1, 2, 3, ... , 默认为8
  .ADDR_WIDTH (FIFO_ADDR_WIDTH), // 地址位宽, 可取1, 2, 3, ... , 默认为4, 对应深度2**4
  .RAM_STYLE  ( ), // RAM类型, 可选"block", "distributed"(默认)
  .FWFT_EN    (1)  // 首字直通特性使能, 默认为1, 表示使能首字直通
) syncFIFO_u0 (
  .din          (i2c_fifo_din       ),
  .wr_en        (i2c_fifo_wr_en     ),
  .full         (i2c_fifo_full      ),
  .almost_full  (                   ),
  .dout         (i2c_fwft_fifo_dout ),
  .rd_en        (i2c_fwft_fifo_rd_en),
  .empty        (i2c_fwft_fifo_empty),
  .almost_empty (                   ),
  .clk          (clk                ),
  .rst          (~rstn              )
);
//-- 实例化同步FIFO ------------------------------------------------------------


//++ 实例化I2CMaster ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
i2cMaster #(
  .CLK_FREQ_MHZ(CLK_FREQ_MHZ)
) i2cMaster_u0 (
  .fifo_dout             (i2c_fwft_fifo_dout       ),
  .fifo_rd_en            (i2c_fwft_fifo_rd_en      ),
  .fifo_empty            (i2c_fwft_fifo_empty      ),
  .device_addr           (i2c_device_addr          ),
  .data_addr             (i2c_data_addr            ),
  .wdata                 (i2c_wdata                ),
  .wr_data_success       (i2c_wr_data_success      ),
  .rdata                 (i2c_rdata                ),
  .rdata_valid           (i2c_rdata_valid          ),
  .sda_i                 (i2c_sda_i                ),
  .sda_o                 (i2c_sda_o                ),
  .sda_oen               (i2c_sda_oen              ),
  .scl_i                 (i2c_scl_i                ),
  .scl_o                 (i2c_scl_o                ),
  .scl_oen               (i2c_scl_oen              ),
  .clk                   (clk                      ),
  .rstn                  (rstn                     )
);
//-- 实例化I2CMaster ------------------------------------------------------------


endmodule
`resetall