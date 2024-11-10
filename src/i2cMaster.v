/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2024-09-27 22:29:56
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2024-11-10 18:59:46
 * @Filename     :
 * @Description  :
*/

/*
! 模块功能: I2C协议主机
? I2C基本概念:
  1.scl, sda默认状态均为高电平
  2.开始条件: scl高电平时, sda的下降沿, 总是由主机控制
  3.停止条件: scl高电平时, sda的上升沿, 总是由主机控制
  4.sda数据变化: 除开始/停止条件外, sda数据变化必须在scl低电平期间进行
  5.应答: 在第9个scl周期低电平期间, sda为0表示应答, 为1表示不应答
  6.I2C通信流程: 开始条件 -> 9个scl -> ... -> 9个scl -> 停止条件
* I2C读写操作说明(适用于EEPROM-ATMEL-AT24C64):
  1.I2C写操作有两种方式: 1.字节写入; 2.页面写入
  2.字节写入流程:
    开始条件
    -> 7位设备地址+1位写控制(主) -> 1位ACK(从) //~ 设备地址写
    -> 第一个8位数据地址(主) -> 1位ACK(从) //~ 写数据地址1
    -> 第二个8位数据地址(主) -> 1位ACK(从) //~ 写数据地址2
    -> 8位数据(主) -> 1位ACK(从) //~ 写数据1
    -> 停止条件
  3.页面写入流程:
    开始条件 -> 设备地址写 -> 写数据地址1 -> 写数据地址2
    -> 第1个8位数据(主) -> 1位ACK(从) //~ 写数据1
    -> 第2个8位数据(主) -> 1位ACK(从) //~ 写数据2
    -> ...
    -> 第n个8位数据(主) -> 1位ACK(从), x最大为32 //~ 写数据n
    -> 停止条件
    最多连续写入32个8bit数据, 数据地址会在EEPROM内部自动增加。
    如果向EEPROM传输超过32个数据字, 数据字地址将会“回滚”, 先前的数据将被覆盖。
  !4.写入总结: 开始 -> 设备地址写 -> 写数据地址1和2 -> 写数据1~n -> 停止
  5.I2C读操作有三种方式: 1.读当前地址; 2.读指定地址; 3.顺序读
  6.读当前地址: 当前地址指的是上次读或写操作期间访问的最后一个地址, 此操作完成后EEPROM内部地址自动加1, 即当前地址加1
    开始条件
    -> 7位设备地址+1位读控制(主) -> 1位ACK(从) //~ 设备地址读
    -> 当前地址8位数据(从) -> NO_ACK(主) //~ 读数据1
    -> 停止条件
  7.读指定地址: 利用写操作, 输入地址, 再发起读当前地址操作实现读指定地址
    开始条件 -> 设备地址写 -> 写数据地址1 -> 写数据地址2
    -> 读当前地址
  8.顺序读: 就是将读当前地址中的读数据1的NO_ACK改为ACK, 即可实现顺序读
    开始条件 -> 设备地址读
    -> 当前地址8位数据(从) -> ACK(主) //~ 读数据1
    -> 下一地址8位数据(从) -> ACK(主) //~ 读数据2
    -> ...
    -> 下n个地址8位数据(从) -> NO_ACK(主) //~ 读数据n
    -> 停止条件
    简单来说, 读数据后ACK, 从机就会继续发送下一地址的数据, 直到NO_ACK
  !9.读出总结:
  ! 1) (读当前地址) 开始 -> 设备地址读 -> 读数据1和n -> 停止
  ! 2) (顺序读) 开始 -> 设备地址写 -> 写数据地址 -> 开始 -> 设备地址读 -> 读数据1和n -> 停止
% 时序要求(适用于EEPROM-ATMEL-AT24C64):
  ~对SCL的要求:
  tF: scl下降时间, 最大值300ns/100kHz, 300ns/400kHz (无需关心, 由硬件满足)
  tR: scl上升时间, 最大值1.0us/100kHz, 0.3us/400kHz (无需关心, 由硬件满足)
  tLOW: scl低电平持续时间, 最小值4.7us/100kHz, 1.2us/400kHz (≥50%周期)
  tHIGH: scl高电平持续时间, 最小值4.0us/100kHz, 0.6us/400kHz (≥40%周期)
  !scl总结: 保持50%占空比即可
  ~对主机sda的要求:
  tSU.STA: 开始条件建立时间, scl上升沿到sda下降沿, 最小值4.7us/100KHz, 0.6us/400kHz
  tHD.STA: 开始条件保持时间, sda下降沿到scl下降沿, 最小值4.0us/100KHz, 0.6us/400kHz
  !开始条件总结: scl高电平需持续2个scl周期, 前0.5周期时, scl=0，sda=1
  !             0.5周期~1周期时, SCL=1，SDA=1
  !             1周期~2周期, SCL=1，SDA=0
  tHD.DAT: 输入数据保持时间, scl下降沿到sda下一个输入数据变化, 最小值0us/100KHz, 0us/400kHz
  tSU.DAT: 输入数据建立时间, sda输入数据变化到scl上升沿, 最小值200ns/100KHz, 100ns/400kHz
  !主机输入数据总结: 在scl低电平中间, 变化sda即可
  tSU.STO: 停止条件建立时间, scl上升沿到sda上升沿时间, 最小值4.7us/100KHz, 0.6us/400kHz
  tBUS: 停止条件持续时间, scl高电平, sda也高电平, 最小值4.7us/100KHz, 1.2us/400kHz
  !停止条件总结: scl高电平需持续一个2个scl周期, 前0.5周期时, scl=0, sda=0,
  !             0.5周期~1周期时, scl=1, sda=0
  !             1周期~2周期时, scl=1, sda=1
  ~对从机sda的要求:
  tAA: 输出数据建立时间, scl下降沿到sda输出数据有效, 最大值4.5us/100kHz, 0.9us/400kHz
  tDH: 输出数据保持时间, scl下降沿到下一个sda输出数据变化, 最小值100ns/100KHz, 50ns/400kHz
  !从机输出数据总结: 主机在scl高电平中间读取sda上的从机数据即可
? 其它I2C协议重点
  1.考虑时钟拉伸, I2C协议支持从机时钟拉伸功能
    如果目标设备即从机, 没有准备好接收数据, 则可以主动拉低SCL, 这时发主机就无法拉高SCL, 传输就此暂停,
    直到目标设备准备好接收, 放弃对SCL的拉低, 这时主机就可以拉高SCL, 传输继续
  2.对于多主机系统, 需考虑时钟同步和仲裁
* 编码思路:
  1.上层模块使用FIFO接口来完全控制I2C主机的读写
  2.FIFO数据结构: 要通信的从机地址 + 读/写指示 + 要读/写的数据地址 + 要写的数据(读操作忽略此字段), 也就是:
    device_addr(7bit) + rd_or_wr_n(1bit)
    + data_addr(8/16/24bit) + i2c_wdata(8bit, 读操作忽略此字段)
    + 8位ctrl_byte(控制字节)
    + 16位clk_freq_div_scl_freq(clk频率与i2c_scl分频比)
  3.当FIFO从空到非空时, 开始一次传输
  4.当一次传输到了最后, 对于写操作, 接收到从机ACK信号, 去读取FIFO, 如果FIFO为空, 则结束传输
    如果FIFO不为空, 判断从机地址和读/写指示, 是否与之前传输一致, 数据地址是否是之前地址+1,
    如果是, 不STOP, 继续写数据;
    如果不满足上述条件, 则STOP, 开始下一次传输
  5.当一次传输到了最后, 对于读操作, 接收完毕从机数据后, 去读取FIFO, 如果FIFO为空, 则结束传输;
    如果FIFO不为空, 判断从机地址和读/写指示, 是否与之前传输一致, 数据地址是否是之前地址+1,
    如果是, 不ACK, 继续读数据;
    如果不满足上述条件, 则ACK + STOP, 开始下一次传输
  6.
*/

`default_nettype none

module i2cMaster #(
  parameter CLK_FREQ_MHZ = 100 // 模块时钟频率
)(
  //~ I2C FIFO
  input  wire [55:0] fifo_dout,
  output wire        fifo_rd_en,
  input  wire        fifo_empty,

  //~ 读/写数据过程指示
  output wire [6 :0] device_addr,     // 当前正在操作的从机设备地址
  output wire [15:0] data_addr,       // 当前正在操作的从机数据地址
  output wire [7 :0] wdata,           // 写入的数据
  output wire        wr_data_success, // 写入成功, 高电平有效
  output wire [7 :0] rdata,           // 读出的数据
  output wire        rdata_valid,     // 读出的数据有效, 高电平有效

  //~ I2C物理接口, 顶层inout信号分解为三个
  input  wire sda_i,
  output wire sda_o,
  output wire sda_oen,
  input  wire scl_i,
  output wire scl_o,
  output wire scl_oen,

  input  wire clk,
  input  wire rstn
);


//++ FIFO数据解析 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
assign device_addr = fifo_dout[55 : 49]; // 从机设备地址
wire rd_or_wr_n = fifo_dout[48]; // 读/写指示
assign data_addr = fifo_dout[47 : 32]; // 从机数据地址
assign wdata = fifo_dout[31 : 24]; // FIFO要写入I2C从机的数据

wire [7:0] ctrl_byte = fifo_dout[23 : 16]; // I2C控制字节
wire page_rd_en = ctrl_byte[7]; // 使能页读, 即连续读
wire page_wr_en = ctrl_byte[6]; // 使能页写, 即连续写
/*
  从机数据地址字节数减1, 0表示8位数据地址, 1表示16/17/18位数据地址
  目前I2C器件最大存储空间为2Mbit(型号AT24CM02), 对应数据地址18位, 对应2**18Byte=2**21bit=2Mbit
*/
wire this_slave_data_addr_bytes_minus_1 = ctrl_byte[5];
// 是否从机应答是必须的, 1(默认)表示通信中必须收到从机应答, 0表示不关心从机应答
wire this_slave_ack_is_necessary = ctrl_byte[4];

// clk频率与i2c_scl频率的比值, 如100MHz/100kHz = 1000, 新的I2C频率会在下一次传输时生效
wire [15:0] clk_freq_div_scl_freq = fifo_dout[15:0];
//-- FIFO数据解析 ------------------------------------------------------------


//++ 三段式状态机-状态定义 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
/*
! 写入总结: 开始 -> 设备地址写 -> 写数据地址 -> 写数据1~n -> 停止
! 读出总结:
! 1)开始 -> 设备地址读 -> 读数据1和n -> 停止 (读当前地址)
! 2)开始 -> 设备地址写 -> 写数据地址 -> 开始 -> 设备地址读 -> 读数据1和n -> 停止 (读非当前地址)
*/
//~ 状态定义
localparam IDLE           = 11'd1 << 0; // 空闲态, 'h001
localparam START          = 11'd1 << 1; // 开始条件, 单次传输开始, 'h002
localparam DEVICE_ADDR_WR = 11'd1 << 2; // 从机设备地址+写, 包括等待从机ACK, 'h004
localparam WR_DATA_ADDR   = 11'd1 << 3; // 数据地址, 包括等待从机ACK, 'h008
localparam WR_DATA        = 11'd1 << 4; // 写数据, 包括等待从机ACK, 'h010
localparam DEVICE_ADDR_RD = 11'd1 << 5; // 从机设备地址+读, 包括等待从机ACK, 'h020
localparam RD_DATA        = 11'd1 << 6; // 读数据, 'h040
localparam RD_DATA_ACK    = 11'd1 << 7; // 读数据最后, 应答, 然后继续读, 'h080
localparam RD_DATA_NO_ACK = 11'd1 << 8; // 读数据最后, 不应答, 然后STOP, 'h100
localparam STOP           = 11'd1 << 9; // 停止条件, 单次传输结束, 'h200
localparam SOFT_RESET     = 11'd1 << 10; // i2c软复位, scl出16个10kHz时钟, 'h400

reg [10:0] state;
reg [10:0] next;
//~ 初始态与状态跳转
always @(posedge clk) begin
  if (~rstn)
    state <= IDLE;
  else
    state <= next;
end
//-- 三段式状态机-状态定义 ------------------------------------------------------------


//++ 三段式状态机-状态跳转 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
wire start_end;          // 指示开始条件结束
wire device_addr_wr_end; // 指示设备地址写结束
wire wr_data_addr_end;   // 指示数据地址写结束
wire wr_data_end;        // 指示数据写结束
wire device_addr_rd_end; // 指示设备地址读结束
wire rd_data_end;        // 指示数据读结束
wire rd_data_ack_end;    // 指示数据读应答结束
wire rd_data_no_ack_end; // 指示数据读不应答结束
wire stop_end;           // 指示停止条件结束
reg  receive_ack_no_goto_idle; // 未收到从机的应答, 认为通信中断, 转入IDLE
wire soft_reset_begin; // scl或sda拉低超过30ms, 则判定i2c被锁住了, 或模块复位进行一次解锁
wire soft_reset_end; // SOFT_RESET状态结束


reg [6:0] this_slave_device_addr; //~ 当前从机设备地址
always @(posedge clk) begin
  if (device_addr_wr_end || device_addr_rd_end) // 当前设备地址由设备地址写/读决定
    this_slave_device_addr <= device_addr;
  else
    this_slave_device_addr <= this_slave_device_addr;
end

reg [15:0] this_slave_data_addr; //~ 当前从机内部的数据地址
always @(posedge clk) begin
  if (wr_data_addr_end) // 当前数据地址由写数据地址决定
    this_slave_data_addr <= data_addr;
  else if (fifo_rd_en) // 读出FIFO中数据的同时, 当前从机内部数据地址+1
    this_slave_data_addr <= this_slave_data_addr + 1;
  else
    this_slave_data_addr <= this_slave_data_addr;
end

//~ 只有一种情况转入设备地址读, 即当前FIFO中指示为读操作, 且FIFO中设备地址、数据地址均与要操作的从机地址相同
wire goto_device_addr_rd = rd_or_wr_n
                            && device_addr == this_slave_device_addr
                            && data_addr ==  this_slave_data_addr;

wire continue_wr_data = ~rd_or_wr_n
                        && device_addr == this_slave_device_addr
                        && data_addr == this_slave_data_addr
                        && page_wr_en;

wire continue_rd_data = goto_device_addr_rd && page_rd_en;

//~ 跳转到下一个状态的条件
always @(*) begin
  next = state;
  if (soft_reset_begin)
    next = SOFT_RESET;
  else
    case (state)
      IDLE: if (~fifo_empty)
              next = START;
      START: if (start_end) // 开始条件结束, 根据不同情况转入设备地址读/设备地址读
              if (goto_device_addr_rd)
                next = DEVICE_ADDR_RD;
              else
                next = DEVICE_ADDR_WR;
      DEVICE_ADDR_WR: if (receive_ack_no_goto_idle)
                        next = IDLE;
                      else if (device_addr_wr_end)
                        next = WR_DATA_ADDR;
      WR_DATA_ADDR: if (receive_ack_no_goto_idle)
                      next = IDLE;
                    else if (wr_data_addr_end) // 此操作会改变this_slave_data_addr
                      if (rd_or_wr_n)
                        next = START; // 读操作时, 写设备地址后需转入START
                      else
                        next = WR_DATA;
      WR_DATA:  if (receive_ack_no_goto_idle)
                  next = IDLE;
                // 写数据后, 需读出FIFO中的数据, 使FIFO的dout更新; 且this_slave_data_addr加1
                else if (wr_data_end)
                  if (continue_wr_data)
                    next = WR_DATA;
                  else
                    next = STOP;
      DEVICE_ADDR_RD: if (receive_ack_no_goto_idle)
                        next = IDLE;
                      else if (device_addr_rd_end)
                        next = RD_DATA;
      RD_DATA: if (rd_data_end) // 读数据后, 需读出FIFO中的数据, 使FIFO的dout更新; 且this_slave_data_addr加1
                if (continue_rd_data)
                  next = RD_DATA_ACK;
                else
                  next = RD_DATA_NO_ACK;
      RD_DATA_ACK: if (rd_data_ack_end)
                    next = RD_DATA;
      RD_DATA_NO_ACK: if (rd_data_no_ack_end)
                        next = STOP;
      STOP:   if (stop_end)
                next = IDLE;
      SOFT_RESET: if (soft_reset_end)
                  next = IDLE;
      default: next = IDLE;
    endcase
end
//-- 三段式状态机-状态跳转 ------------------------------------------------------------


//++ 生成scl ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg [15:0] scl_clk_cnt_max; // 控制I2C总线频率
always @(posedge clk) begin
  case (state)
    IDLE: if (clk_freq_div_scl_freq >= 5) // 极限情况, clk为5MHz, I2C为1MHz
            scl_clk_cnt_max <= clk_freq_div_scl_freq - 1;
          else
            scl_clk_cnt_max <= CLK_FREQ_MHZ * 10 - 1; // 100kHz
    SOFT_RESET: scl_clk_cnt_max <= CLK_FREQ_MHZ * 100 - 1; // 10kHz
    default: scl_clk_cnt_max <= scl_clk_cnt_max;
  endcase
end

reg [15:0] scl_clk_cnt;
wire i2c_slave_is_clock_stretching;
always @(posedge clk) begin
  if(i2c_slave_is_clock_stretching) // 时钟拉伸时, 计数值保持不变
    scl_clk_cnt <= scl_clk_cnt;
  else
    case (state)
      IDLE: scl_clk_cnt <= 'd0;
      default: // 除空闲态外的所有状态, scl_clk_cnt的逻辑一样
        if (scl_clk_cnt < scl_clk_cnt_max)
          scl_clk_cnt <= scl_clk_cnt + 1'b1;
        else
          scl_clk_cnt <= 'd0;
    endcase
end

reg [3:0] scl_cnt; // I2C的scl计数
reg scl_oen_reg;
always @(*) begin
  scl_oen_reg <= 1'b0;
  case (state)
    IDLE: scl_oen_reg <= 1'b0;
    START, STOP: if (scl_cnt == 0 && scl_clk_cnt < (scl_clk_cnt_max + 1) * 17 / 32)
            scl_oen_reg <= 1'b1;
    default: if (scl_clk_cnt < (scl_clk_cnt_max + 1) * 17 / 32)
              scl_oen_reg <= 1'b1;
  endcase
end

assign scl_oen = scl_oen_reg;
assign scl_o = 1'b0;

/*
* 指示I2C从机正在进行时钟拉伸, 判断逻辑:
* 当主机释放scl时, scl应被外接上拉电阻拉高，如果此时scl仍保持低电平, 说明从机在进行scl时钟拉伸
*/
assign i2c_slave_is_clock_stretching = (scl_clk_cnt > (scl_clk_cnt_max + 1) * 17 / 32) && (~scl_i);
//-- 生成scl ------------------------------------------------------------


//++ 生成sda ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
always @(posedge clk) begin
  case (state)
    IDLE: scl_cnt <= 'd0;
    START, STOP:
      if (scl_clk_cnt == scl_clk_cnt_max)
        if (scl_cnt == 1)
          scl_cnt <= 'd0;
        else
          scl_cnt <= scl_cnt + 1'b1;
      else
        scl_cnt <= scl_cnt;
    SOFT_RESET:
      if (scl_clk_cnt == scl_clk_cnt_max)
        if (scl_cnt == 15)
          scl_cnt <= 'd0;
        else
          scl_cnt <= scl_cnt + 1'b1;
      else
        scl_cnt <= scl_cnt;
    default:
      if (scl_clk_cnt == scl_clk_cnt_max)
        if (scl_cnt == 8)
          scl_cnt <= 'd0;
        else
          scl_cnt <= scl_cnt + 1'b1;
      else
        scl_cnt <= scl_cnt;
  endcase
end

reg wr_data_addr_byte_cnt;
always @(posedge clk) begin
  if (state == WR_DATA_ADDR)
    if (~this_slave_data_addr_bytes_minus_1)
      wr_data_addr_byte_cnt <= 1'b1;
    else if (scl_cnt == 8 && scl_clk_cnt == scl_clk_cnt_max)
      wr_data_addr_byte_cnt <= wr_data_addr_byte_cnt + 1'b1;
    else
      wr_data_addr_byte_cnt <= wr_data_addr_byte_cnt;
  else
    wr_data_addr_byte_cnt <= 1'b0;
end


wire [7:0] device_addr_and_rw = {device_addr, rd_or_wr_n}; // 设备地址与读写指示

reg sda_oen_reg;
always @(*) begin
  sda_oen_reg <= 1'b0;
  case (state)
    START:  if (scl_cnt == 1)
              sda_oen_reg <= 1'b1;
    DEVICE_ADDR_WR:
      if (scl_clk_cnt >= (scl_clk_cnt_max + 1) / 4)
        if (scl_cnt < 7)
          sda_oen_reg <= ~device_addr[6-scl_cnt];
        else if (scl_cnt == 7)
          sda_oen_reg <= 1'b1;
    WR_DATA_ADDR: if (scl_cnt < 8 && scl_clk_cnt >= (scl_clk_cnt_max + 1) / 4)
                    sda_oen_reg <= ~data_addr[15-wr_data_addr_byte_cnt*8-scl_cnt];
    WR_DATA:  if (scl_cnt < 8 && scl_clk_cnt >= (scl_clk_cnt_max + 1) / 4)
                sda_oen_reg <= ~wdata[7-scl_cnt];
    DEVICE_ADDR_RD: if (scl_cnt < 7 && scl_clk_cnt >= (scl_clk_cnt_max + 1) / 4)
                      sda_oen_reg <= ~device_addr[6-scl_cnt];
    RD_DATA_ACK: if (scl_clk_cnt >= (scl_clk_cnt_max + 1) / 4)
                  sda_oen_reg <= 1'b1;
    STOP: if (scl_cnt == 0 && scl_clk_cnt >= (scl_clk_cnt_max + 1) / 4)
            sda_oen_reg <= 1'b1;
    default: sda_oen_reg <= 1'b0;
  endcase
end

assign sda_oen = sda_oen_reg;
assign sda_o = 1'b0;
//-- 生成sda ------------------------------------------------------------


//++ 每个状态接收ack ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
always @(posedge clk) begin
  if (this_slave_ack_is_necessary)
    case (state)
      DEVICE_ADDR_WR, WR_DATA_ADDR, WR_DATA, DEVICE_ADDR_RD:
        // 3/4周期时, sda为1, 则认为未接收到了ACK
        if (sda_i && scl_cnt == 8 && scl_clk_cnt == (scl_clk_cnt_max + 1) * 3 / 4 )
          receive_ack_no_goto_idle <= 1'b1;
        else
          receive_ack_no_goto_idle <= 1'b0;
      default: receive_ack_no_goto_idle <= 1'b0;
    endcase
  else
    receive_ack_no_goto_idle <= 1'b0;
end
//-- 每个状态接收ack ------------------------------------------------------------


//++ 接收数据 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg [7:0] rdata_reg;
always @(posedge clk) begin
  if (~rstn)
    rdata_reg <= 'd0;
  else
    case (state)
      RD_DATA: if (scl_cnt < 8 && scl_clk_cnt == (scl_clk_cnt_max + 1) * 3 / 4)
                rdata_reg = {rdata_reg[6:0], sda_i};
      default: rdata_reg <= rdata_reg;
    endcase
end

assign rdata = rdata_reg;
//-- 接收数据 ------------------------------------------------------------


//++ 读出FIFO数据 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
/*
  1.当主机写数据完成后读取一次FIFO
  2.当主机读数据完成后读取一次FIFO
  3.读取FIFO需要再写数据成功和读数据有效之后
  3.读取FIFO需要在状态状态判断之前
*/
assign wr_data_success = state == WR_DATA && scl_cnt == 8 && scl_clk_cnt == scl_clk_cnt_max - 2;
assign rdata_valid = state == RD_DATA && scl_cnt == 7 && scl_clk_cnt == scl_clk_cnt_max - 2;

reg fifo_rd_en_reg;
always @(posedge clk) begin
  fifo_rd_en_reg <= wr_data_success || rdata_valid;
end

assign fifo_rd_en = fifo_rd_en_reg;
//-- 读出FIFO数据 ------------------------------------------------------------


//++ 判断I2C被锁住 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// sda或scl保持低电平达到30ms则认为i2c被锁住
localparam SOFT_RESET_CLK_CNT_MAX = CLK_FREQ_MHZ * 1000 * 30; // 30ms
reg [$clog2(SOFT_RESET_CLK_CNT_MAX+1)-1 : 0] sda_soft_reset_clk_cnt;
always @(posedge clk) begin
  if (~rstn)
    sda_soft_reset_clk_cnt <= SOFT_RESET_CLK_CNT_MAX;
  else if (~sda_i && sda_soft_reset_clk_cnt < SOFT_RESET_CLK_CNT_MAX)
    sda_soft_reset_clk_cnt <= sda_soft_reset_clk_cnt + 1'b1;
  else
    sda_soft_reset_clk_cnt <= 'd0;
end

reg [$clog2(SOFT_RESET_CLK_CNT_MAX+1)-1 : 0] scl_soft_reset_clk_cnt;
always @(posedge clk) begin
  if (~rstn)
    scl_soft_reset_clk_cnt <= SOFT_RESET_CLK_CNT_MAX;
  else if (~scl_i && scl_soft_reset_clk_cnt < SOFT_RESET_CLK_CNT_MAX)
    scl_soft_reset_clk_cnt <= scl_soft_reset_clk_cnt + 1'b1;
  else
    scl_soft_reset_clk_cnt <= 'd0;
end

assign soft_reset_begin = sda_soft_reset_clk_cnt == SOFT_RESET_CLK_CNT_MAX
                        || scl_soft_reset_clk_cnt == SOFT_RESET_CLK_CNT_MAX;
//-- 判断I2C被锁住 ------------------------------------------------------------


//++ 生成状态跳转条件 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
assign start_end          = state == START && scl_cnt == 1 && scl_clk_cnt == scl_clk_cnt_max;
assign device_addr_wr_end = state == DEVICE_ADDR_WR && scl_cnt == 8 && scl_clk_cnt == scl_clk_cnt_max;
assign wr_data_addr_end   = state == WR_DATA_ADDR
                            && wr_data_addr_byte_cnt == 1'b1
                            && scl_cnt == 8
                            && scl_clk_cnt == scl_clk_cnt_max;
assign wr_data_end        = state == WR_DATA        && scl_cnt == 8 && scl_clk_cnt == scl_clk_cnt_max;
assign device_addr_rd_end = state == DEVICE_ADDR_RD && scl_cnt == 8 && scl_clk_cnt == scl_clk_cnt_max;
assign rd_data_end        = state == RD_DATA        && scl_cnt == 7 && scl_clk_cnt == scl_clk_cnt_max;
assign rd_data_ack_end    = state == RD_DATA_ACK    && scl_cnt == 8 && scl_clk_cnt == scl_clk_cnt_max;
assign rd_data_no_ack_end = state == RD_DATA_NO_ACK && scl_cnt == 8 && scl_clk_cnt == scl_clk_cnt_max;
assign stop_end           = state == STOP && scl_cnt == 1 && scl_clk_cnt == scl_clk_cnt_max;
assign soft_reset_end     = state == SOFT_RESET     && scl_cnt == 15 && scl_clk_cnt == scl_clk_cnt_max;
//-- 生成状态跳转条件 ------------------------------------------------------------


endmodule
`resetall