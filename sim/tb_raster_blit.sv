// Blit walk of jmr_raster_engine against a memory with either one-clock
// acknowledgements or the DDR3 bridge shape (one 8-word line, 25-clock
// reads). Prints every framebuffer write and the clocks of each blit, so
// two engine versions can be compared write for write.
//   +latency=0|1  +seed=N  +count=N
module tb_raster_blit;
 logic clk=0,rst_n=0,go=0;
 logic [1:0] mode=1;
 logic signed [11:0] dx,dy;logic [9:0] w,h;
 logic [15:0] sx,sy,qx,rxr,qy,ryr,stride;logic [22:0] sbase;logic aset,flip_x,flip_y;
 logic busy,fb_we,sram_req,sram_ack=0;logic [18:0] fb_waddr;logic [9:0] fb_x,fb_y;
 logic [7:0] fb_wdata;logic [21:0] sram_addr;logic [15:0] sram_rdata=0;
 logic [15:0] mem[0:4194303];
 integer latency=0,delay=0,seed=1,count=200,total=0;logic pending=0;logic [18:0] line='1;
 integer fd;
 always #5 clk=~clk;
 jmr_raster_engine dut(.clk,.rst_n,.go,.mode,.dx,.dy,.w,.h,.color(8'd0),.sx,.sy,.qx,.rxr,.qy,.ryr,
  .sbase,.stride,.aset,.flip_x,.flip_y,.busy,.fb_we,.fb_waddr,.fb_x,.fb_y,.fb_wdata,
  .sram_req,.sram_addr,.sram_rdata,.sram_ack);
 // Same port contract as jmr_sram_model: a request seen while ack is low
 // is served; ack is high for one clock.
 always_ff @(posedge clk)begin
  sram_ack<=0;
  if(pending)begin
   if(delay==0)begin sram_rdata<=mem[sram_addr];sram_ack<=1;pending<=0;end
   else delay<=delay-1;
  end else if(sram_req && !sram_ack)begin
   pending<=1;
   if(latency==1 && sram_addr[21:3]!=line)begin delay<=27;line<=sram_addr[21:3];end
   else delay<=0;
  end
 end
 always @(posedge clk)if(fb_we)$fdisplay(fd,"W %0d %0d",fb_waddr,fb_wdata);
 task automatic blit(input integer sw,sh);
  integer c;
  qx=w?16'(sw/w):0;rxr=w?16'(sw%w):0;qy=h?16'(sh/h):0;ryr=h?16'(sh%h):0;
  @(posedge clk);go<=1;
  c=0;
  while(!busy && c<8)begin @(posedge clk);c++;end
  go<=0;
  while(busy)begin @(posedge clk);c++;if(c>4000000)$fatal(1,"blit timeout");end
  $fdisplay(fd,"B %0d",c);total+=c;
 endtask
 initial begin
  string out;
  void'($value$plusargs("latency=%d",latency));
  void'($value$plusargs("seed=%d",seed));
  void'($value$plusargs("count=%d",count));
  if(!$value$plusargs("out=%s",out))out="blit.log";
  fd=$fopen(out,"w");
  void'($urandom(seed));
  for(integer i=0;i<2097152;i++)mem[i]=($urandom%4==0)?16'(($urandom%8)<<8):16'($urandom);
  for(integer i=2097152;i<4194304;i++)mem[i]=mem[i-2097152];
  repeat(4)@(posedge clk);rst_n=1;
  // DNKF-like: 15x16 sheet cells drawn at 50x50, 20x22 at 50x50, 1:1 sprites.
  for(integer n=0;n<count;n++)begin
   integer sw,sh;
   aset=n%5!=4;flip_x=$urandom%4==0;flip_y=$urandom%8==0;
   case(n%4)
    0:begin sw=15;sh=16;w=50;h=50;end
    1:begin sw=20;sh=22;w=50;h=50;end
    2:begin sw=1+$urandom%40;sh=1+$urandom%40;w=sw;h=sh;end
    default:begin sw=1+$urandom%64;sh=1+$urandom%48;w=10'(1+$urandom%96);h=10'(1+$urandom%80);end
   endcase
   stride=16'(sw+$urandom%300);sx=16'($urandom%(stride-sw+1));sy=16'($urandom%64);
   sbase=aset?23'(1000+$urandom%2000000):23'($urandom%200000);
   dx=12'($signed($urandom%760)-60);dy=12'($signed($urandom%600)-60);
   blit(sw,sh);
  end
  // Degenerate shapes: one pixel, one column, one row.
  aset=1;flip_x=0;flip_y=0;stride=64;sx=3;sy=2;sbase=5001;dx=10;dy=10;
  w=1;h=1;blit(1,1);w=1;h=40;blit(1,13);w=40;h=1;blit(13,1);w=0;h=5;blit(1,1);
  $fdisplay(fd,"TOTAL %0d",total);
  $display("TOTAL latency=%0d clocks=%0d",latency,total);
  $fclose(fd);$finish;
 end
endmodule
