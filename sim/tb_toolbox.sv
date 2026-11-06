module tb_toolbox;
 import jmr_js_vm_pkg::*;
 logic sys_valid=1;
 logic clk=0,rst_n=0,req=0,busy,reply,mreq,mwe,ack=0,fwe;
 logic dirty_clear=0;logic freq,fack=0;logic [18:0] fra;logic [7:0] frd;logic [1199:0] dirty;
 logic [31:0] op=0,a=0,b=0,c=0,result;
 logic [21:0] addr;logic [15:0] wd,rd=0;logic [18:0] fa;logic [7:0] fd;
 byte unsigned arena[0:CSTG_WORDS-1];byte unsigned pixels[0:307199];
 integer delay_left=0,transactions=0;logic pending=0,seen=0;
 logic [21:0] held_addr;logic held_we;logic [15:0] held_data;
 always #5 clk=~clk;
 // Exercise the REAL synchronous write-priority BRAM port used by the core.
 jmr_mini_fb canvas(.wr_clk(clk),.rst_n,.we(fwe),.address_we(fwe),.waddr(fa),.wdata(fd),
 .dirty_clear(dirty_clear),.dirty_blocks(dirty),.copy_raddr(19'd0),.copy_rdata(),
 .dump_raddr(fra),.dump_rdata(frd));
 always_ff @(posedge clk)if(!rst_n)fack<=0;else fack<=freq && !fwe;

 jmr_toolbox dut(.clk,.rst_n,.req,.sys_valid,.op,.a,.b,.c,.busy,.reply,.result,
 .sram_req(mreq),.sram_we(mwe),.sram_addr(addr),.sram_wdata(wd),.sram_ack(ack),.sram_rdata(rd),
 .fb_we(fwe),.fb_addr(fa),.fb_data(fd),.fb_req(freq),.fb_raddr(fra),.fb_ack(fack),.fb_rdata(frd));
 function automatic integer logical_addr(input logic [21:0] p);
  if(p>=CSCR_SRAM_BASE && p<CSCR_SRAM_BASE+CSCR_WORDS)return integer'(p-CSCR_SRAM_BASE);
  if(p>=CIMG_SRAM_BASE && p<CIMG_SRAM_BASE+CIMG_WORDS)return CSCR_WORDS+integer'(p-CIMG_SRAM_BASE);
  $fatal(1,"out-of-arena transfer %h",p);return -1;
 endfunction
 always @(negedge clk)begin
  ack=0;
  if(fwe)begin if(fa>=307200)$fatal(1,"framebuffer overflow");pixels[fa]=fd;end
  if(!mreq)seen=0;
  if(pending)begin
   if(!mreq||addr!=held_addr||mwe!=held_we||wd!=held_data)$fatal(1,"unstable SRAM request");
   if(delay_left==0)begin
    if(held_we)arena[logical_addr(held_addr)]=held_data[7:0];
    if(held_addr>=3565568 && held_addr<3565568+12160)begin
     if(held_we)$fatal(1,"resource write attempted");
     rd=16'hfe37;
    end else rd={8'd0,arena[logical_addr(held_addr)]};
    ack=1;pending=0;
   end else delay_left=delay_left-1;
  end else if(mreq&&!seen)begin
   seen=1;pending=1;held_addr=addr;held_we=mwe;held_data=wd;
   delay_left=transactions%5;transactions=transactions+1;
  end
 end
 task automatic call(input integer cmd,aa,bb,cc,expected);
  @(posedge clk);#1;op=32'(cmd);a=32'(aa);b=32'(bb);c=32'(cc);req=1;
  for(integer i=0;i<200000;i++)begin
   @(posedge clk);#1;
   if(reply)begin
    if(result!=32'(expected))$fatal(1,"op%0d result %h expected %h",cmd,result,expected);
    repeat(3)begin @(posedge clk);#1;if(!reply)$fatal(1,"reply not held");end
    req=0;repeat(3)@(posedge clk);return;
   end
  end
  $fatal(1,"Toolbox timeout");
 endtask
 task automatic put16(input integer p,v);arena[p]=8'(v);arena[p+1]=8'(v>>8);endtask
 task automatic descriptor(input integer format,sc,base,stride,ww,hh);
  for(integer i=0;i<64;i++)arena[100+i]=0;
  arena[100]=1;arena[101]=8'(format);arena[103]=8'(sc);
  put16(104,base);put16(106,base>>16);put16(108,stride);put16(110,ww);put16(112,hh);
  put16(118,ww);put16(120,hh);put16(130,640);put16(132,480);arena[134]=255;
  for(integer i=0;i<16;i++)arena[148+i]=8'(i*13);
 endtask
 initial begin
  for(integer i=0;i<CSTG_WORDS;i++)arena[i]=0;
  for(integer i=0;i<307200;i++)pixels[i]=9;
  repeat(4)@(posedge clk);#1;rst_n=1;
  call(0,0,0,0,65599);
  call(5,1,1900,3,3);
  if(arena[1900]!=254 || arena[1901]!=55 || arena[1902]!=254)$fatal(1,"resource byte order");
  call(5,24319,1900,2,-1);
  sys_valid=0;call(5,0,1900,1,-1);sys_valid=1;

  call(2,73720,42,24,24);
  for(integer i=73720;i<73744;i++)if(arena[i]!=42)$fatal(1,"seam fill");
  for(integer i=0;i<64;i++)arena[1000+i]=8'(i);
  call(1,1000,1003,61,61);
  for(integer i=0;i<61;i++)if(arena[1003+i]!=i)$fatal(1,"backward overlap %0d",i);
  call(1,1003,1000,61,61);
  for(integer i=0;i<61;i++)if(arena[1000+i]!=i)$fatal(1,"forward overlap");
  call(1,CSTG_WORDS-1,10,2,-1);call(2,32'hffffffff,22,1,-1);
  call(2,CSTG_WORDS,22,0,0);
  descriptor(1,2,2000,1,8,1);arena[2000]=8'h81;
  put16(122,-1);put16(124,1);
  call(3,100,0,0,8);
  if(pixels[640]!=255||pixels[641]!=0||pixels[640+13]!=255||pixels[640+14]!=255||pixels[15]!=9)$fatal(1,"clipped scaled mono");
  descriptor(4,1,2000,2,4,1);arena[2000]=8'h12;arena[2001]=8'h30;
  arena[102]=1;put16(122,30);put16(124,30);call(3,100,0,0,4);
  if(pixels[19230]!=13||pixels[19231]!=26||pixels[19232]!=39||pixels[19233]!=9)$fatal(1,"palette/transparency");
  descriptor(4,1,2000,2,4,1);arena[134]=5;arena[135]=2;arena[140]=8'ha0;
  call(4,100,0,0,4);if(arena[2000]!=8'h52||arena[2001]!=8'h52)$fatal(1,"pattern packed fill");
  descriptor(8,1,2000,4,4,1);arena[134]=77;arena[140]=255;call(4,100,0,0,4);
  for(integer i=0;i<4;i++)if(arena[2000+i]!=77)$fatal(1,"byte surface fill");
  put16(108,1);call(4,100,0,0,-1);if(arena[2000]!=77)$fatal(1,"invalid descriptor wrote memory");
  // Two 8-bit descriptors; all four source/destination combinations.
  descriptor(8,1,2000,8,8,2);
  for(integer i=0;i<64;i++)arena[164+i]=arena[100+i];
  put16(168,3000);
  for(integer i=0;i<16;i++)arena[2000+i]=8'(20+i);
  call(6,100,164,0,16);
  for(integer j=0;j<2;j++)for(integer i=0;i<8;i++)
   if(arena[3000+j*8+i]!=20+j*8+i)$fatal(1,"arena rectangle");
  // Clear dirty tracking before the first transport write to the real canvas.
  repeat(5)@(posedge clk);#1;dirty_clear=1;
  repeat(2)@(posedge clk);#1;dirty_clear=0;
  // Destination screen (8x2 at 10,20).
  arena[166]=2;put16(168,0);put16(172,640);put16(174,640);put16(176,480);
  put16(186,10);put16(188,20);put16(194,640);put16(196,480);
  call(6,100,164,0,16);
  for(integer j=0;j<2;j++)for(integer i=0;i<8;i++)
   if(pixels[(20+j)*640+10+i]!=20+j*8+i)$fatal(1,"arena to screen");
  if(!dirty[(20*640+10)/256])$fatal(1,"transport write did not mark presentation dirty");
  // Source screen. Capture back into arena across the logical arena seam.
  for(integer i=0;i<64;i++)begin arena[100+i]=arena[164+i];end
  put16(114,10);put16(116,20);
  arena[166]=0;put16(168,73724);put16(170,73724>>16);
  put16(172,8);put16(174,8);put16(176,2);put16(186,0);put16(188,0);
  call(6,100,164,0,16);
  for(integer i=0;i<16;i++)if(arena[73724+i]!=20+i)$fatal(1,"screen read/seam");
  // Same screen, overlapping rectangles, backwards then forwards.
  for(integer i=0;i<64;i++)arena[164+i]=arena[100+i];
  put16(186,12);put16(188,20);call(6,100,164,0,16);
  for(integer j=0;j<2;j++)for(integer i=0;i<8;i++)
   if(pixels[(20+j)*640+12+i]!=20+j*8+i)$fatal(1,"screen overlap reverse");
  put16(114,12);put16(186,10);call(6,100,164,0,16);
  for(integer j=0;j<2;j++)for(integer i=0;i<8;i++)
   if(pixels[(20+j)*640+10+i]!=20+j*8+i)$fatal(1,"screen overlap forward");
  // Invalid destination/mode must leave source screen and arena untouched.
  arena[165]=4;call(6,100,164,0,-1);arena[165]=8;
  call(6,100,164,1,-1);put16(114,639);call(6,100,164,0,-1);
  // Negative destination, independent row clip, and untouched arena canaries.
  descriptor(8,1,2000,8,8,4);put16(114,1);put16(116,1);put16(118,4);put16(120,2);
  for(integer i=0;i<64;i++)arena[164+i]=arena[100+i];
  put16(168,73724);put16(170,73724>>16);put16(186,-1);put16(188,1);
  put16(190,0);put16(192,2);put16(194,2);put16(196,1);
  for(integer i=0;i<32;i++)begin arena[2000+i]=8'(128+i);arena[73724+i]=199;end
  call(6,100,164,0,8);
  for(integer i=0;i<32;i++)if(arena[73724+i]!=(i==16?146:i==17?147:199))$fatal(1,"copy clip/canary %0d",i);
  // Two-dimensional arena overlap, reversed then forward, preserves old rows.
  descriptor(8,1,2000,8,8,4);put16(118,6);put16(120,3);
  for(integer i=0;i<64;i++)arena[164+i]=arena[100+i];
  put16(186,1);put16(188,1);
  for(integer i=0;i<32;i++)arena[2000+i]=8'(i);
  call(6,100,164,0,18);
  for(integer j=0;j<3;j++)for(integer i=0;i<6;i++)
   if(arena[2000+(j+1)*8+i+1]!=j*8+i)$fatal(1,"arena overlap backward rows");
  put16(114,1);put16(116,1);put16(186,0);put16(188,0);call(6,100,164,0,18);
  for(integer j=0;j<3;j++)for(integer i=0;i<6;i++)
   if(arena[2000+j*8+i]!=j*8+i)$fatal(1,"arena overlap forward rows");
  put16(172,9);call(6,100,164,0,-1); // conflicting aliased strides
  // Destination may overwrite the captured descriptor itself.
  descriptor(8,1,2000,64,64,1);
  for(integer i=0;i<64;i++)begin arena[164+i]=arena[100+i];arena[2000+i]=8'(255-i);end
  put16(168,164);call(6,100,164,0,64);
  for(integer i=0;i<64;i++)if(arena[164+i]!=255-i)$fatal(1,"descriptor snapshot");
  // An emergency stop must finish an already accepted transfer, then stop.
  @(posedge clk);#1;op=2;a=3000;b=99;c=100;req=1;
  while(!mreq)begin @(posedge clk);#1;end
  req=0;repeat(20)begin @(posedge clk);#1;end
  if(busy || mreq)$fatal(1,"abort did not drain SRAM");
  call(2,3000,17,1,1);if(arena[3000]!=17)$fatal(1,"restart after abort");
  $display("PASS Toolbox: bitmap copies all four directions, real BRAM reads, overlap, bounds, arena seam, delayed SRAM, packed blit/pattern");$finish;
 end
endmodule
