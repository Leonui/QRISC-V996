//-----------------------------------------------------------------
// axi4_ram.v —— 行为级 AXI4 burst RAM(承接 soc 的 mem_* 主口)。
// 复用 tb_rtl 里已验证能启动 Linux 的 burst FSM(支持 INCR/WRAP/FIXED)。
// 自己从 +IMAGE plusarg 读取 hex 装入(make_hex.py 生成的字寻址镜像)。
//-----------------------------------------------------------------
module axi4_ram
#(
     parameter [31:0] MEM_BASE  = 32'h80000000
    ,parameter [31:0] MEM_SIZE  = 32'h02400000     // 36 MB(32MB 内核 RAM + 顶部 4MB 虚拟磁盘 @0x82000000)
)
(
     input           clk_i
    ,input           rst_i
    // AXI4 slave(soc.mem_* 主口接进来)
    ,input           awvalid_i
    ,input  [ 31:0]  awaddr_i
    ,input  [  3:0]  awid_i
    ,input  [  7:0]  awlen_i
    ,input  [  1:0]  awburst_i
    ,input           wvalid_i
    ,input  [ 31:0]  wdata_i
    ,input  [  3:0]  wstrb_i
    ,input           wlast_i
    ,input           bready_i
    ,input           arvalid_i
    ,input  [ 31:0]  araddr_i
    ,input  [  3:0]  arid_i
    ,input  [  7:0]  arlen_i
    ,input  [  1:0]  arburst_i
    ,input           rready_i
    ,output          awready_o
    ,output          wready_o
    ,output          bvalid_o
    ,output [  1:0]  bresp_o
    ,output [  3:0]  bid_o
    ,output          arready_o
    ,output          rvalid_o
    ,output [ 31:0]  rdata_o
    ,output [  1:0]  rresp_o
    ,output [  3:0]  rid_o
    ,output          rlast_o
);

localparam MEM_WORDS = MEM_SIZE / 4;
reg [31:0] mem [0:MEM_WORDS-1];

function [31:0] mem_rd;
    input [31:0] a;
    begin
        if (a >= MEM_BASE && a < (MEM_BASE + MEM_SIZE))
            mem_rd = mem[(a - MEM_BASE) >> 2];
        else
            mem_rd = 32'h0;
    end
endfunction

function [31:0] next_addr;
    input [31:0] addr; input [1:0] burst; input [7:0] len;
    reg [31:0] mask;
    begin
        mask = ((len + 1) << 2) - 1;
        case (burst)
            2'b10:   next_addr = (addr & ~mask) | ((addr + 4) & mask); // WRAP
            2'b01:   next_addr = addr + 4;                            // INCR
            default: next_addr = addr;                               // FIXED
        endcase
    end
endfunction

//------------- 读通道 -------------
localparam R_IDLE = 1'b0, R_READ = 1'b1;
reg        rstate;
reg [31:0] rd_addr;
reg [7:0]  rd_len, rd_cnt;
reg [3:0]  rd_id;
reg [1:0]  rd_burst;

always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin rstate <= R_IDLE; rd_cnt <= 0; end
    else case (rstate)
        R_IDLE: if (arvalid_i) begin
            rd_addr <= araddr_i & 32'hFFFFFFFC; rd_len <= arlen_i;
            rd_id <= arid_i; rd_burst <= arburst_i; rd_cnt <= 0; rstate <= R_READ;
        end
        R_READ: if (rready_i) begin
            if (rd_cnt == rd_len) rstate <= R_IDLE;
            else begin rd_addr <= next_addr(rd_addr, rd_burst, rd_len); rd_cnt <= rd_cnt + 1; end
        end
    endcase
end
assign arready_o = (rstate == R_IDLE);
assign rvalid_o  = (rstate == R_READ);
assign rdata_o   = mem_rd(rd_addr);
assign rlast_o   = (rd_cnt == rd_len);
assign rid_o     = rd_id;
assign rresp_o   = 2'b00;

//------------- 写通道 -------------
localparam W_IDLE = 2'd0, W_DATA = 2'd1, W_RESP = 2'd2;
reg [1:0]  wstate;
reg [31:0] wr_addr;
reg [7:0]  wr_len;
reg [3:0]  wr_id;
reg [1:0]  wr_burst;
integer    bi;

always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) wstate <= W_IDLE;
    else case (wstate)
        W_IDLE: if (awvalid_i) begin
            wr_addr <= awaddr_i & 32'hFFFFFFFC; wr_len <= awlen_i;
            wr_id <= awid_i; wr_burst <= awburst_i; wstate <= W_DATA;
        end
        W_DATA: if (wvalid_i) begin
            if (wr_addr >= MEM_BASE && wr_addr < (MEM_BASE + MEM_SIZE))
                for (bi = 0; bi < 4; bi = bi + 1)
                    if (wstrb_i[bi])
                        mem[(wr_addr - MEM_BASE) >> 2][bi*8 +: 8] <= wdata_i[bi*8 +: 8];
            wr_addr <= next_addr(wr_addr, wr_burst, wr_len);
            if (wlast_i) wstate <= W_RESP;
        end
        W_RESP: if (bready_i) wstate <= W_IDLE;
    endcase
end
assign awready_o = (wstate == W_IDLE);
assign wready_o  = (wstate == W_DATA);
assign bvalid_o  = (wstate == W_RESP);
assign bid_o     = wr_id;
assign bresp_o   = 2'b00;

//------------- 镜像加载 -------------
integer    i;
reg [1023:0] image_path;
reg [1023:0] disk_path;
initial begin
    for (i = 0; i < MEM_WORDS; i = i + 1) mem[i] = 32'h0;
    if (!$value$plusargs("IMAGE=%s", image_path)) image_path = "image.hex";
    $readmemh(image_path, mem);
    $display("[axi4_ram] loaded %0s into DRAM @0x%08x (%0d MB)", image_path, MEM_BASE, MEM_SIZE>>20);
    // 虚拟磁盘:落在内核 RAM 之上的顶部区域(磁盘 hex 自带 @词偏移),与内核镜像同一片 mem。
    // 改程序只重建这块 disk.hex + 重载仿真,无需重建内核。
    if ($value$plusargs("DISK=%s", disk_path)) begin
        $readmemh(disk_path, mem);
        $display("[axi4_ram] loaded disk %0s (programs cpio @ top of DRAM)", disk_path);
    end
end

endmodule
