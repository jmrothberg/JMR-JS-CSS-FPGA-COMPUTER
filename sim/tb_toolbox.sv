module tb_toolbox;
 import jmr_js_vm_pkg::*;
 logic sys_valid=1;
 logic clk=0,rst_n=0,req=0,busy,reply,mreq,mwe,ack=0,fwe;
 logic dirty_clear=0;logic freq,fack=0;logic [18:0] fra;logic [7:0] frd;logic [1199:0] dirty;
 logic [31:0] op=0,a=0,b=0,c=0,result;
 logic [21:0] addr;logic [15:0] wd,rd=0;logic [18:0] fa;logic [7:0] fd;
 byte unsigned arena[0:CSTG_WORDS-1];byte unsigned pixels[0:307199];
 integer delay_left=0,transactions=0;logic pending=0,seen=0;
 integer latency_mode=0,call_cycles=0;logic [18:0] line_tag='1,wc_tag='1;
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
    // Like jmr_sram_model and the DDR3 bridge, a request held through the
    // acknowledgement with a new address is the next transaction.
    seen=0;
    if(held_we)arena[logical_addr(held_addr)]=held_data[7:0];
    if(held_addr>=3565568 && held_addr<3565568+12160)begin
     if(held_we)$fatal(1,"resource write attempted");
     rd=16'hfe37;
    end else rd={8'd0,arena[logical_addr(held_addr)]};
    ack=1;pending=0;
   end else delay_left=delay_left-1;
  end else if(mreq&&!seen)begin
   seen=1;pending=1;held_addr=addr;held_we=mwe;held_data=wd;
   if(latency_mode==0)delay_left=transactions%5;
   else if(latency_mode==1)delay_left=0;
   else begin
    // DDR3 bridge shape: one 8-word read line, 25-clock reads on a miss,
    // writes merged per 8-word block and flushed on a block change.
    delay_left=0;
    if(!mwe && addr[21:3]!=line_tag)begin delay_left=27;line_tag=addr[21:3];end
    if(mwe && addr[21:3]!=wc_tag)begin delay_left=2;wc_tag=addr[21:3];end
    if(mwe && addr[21:3]==line_tag)line_tag='1;
   end
   transactions=transactions+1;
  end
 end
 task automatic call(input integer cmd,aa,bb,cc,expected);
  @(posedge clk);#1;op=32'(cmd);a=32'(aa);b=32'(bb);c=32'(cc);req=1;
  for(integer i=0;i<20000000;i++)begin
   @(posedge clk);#1;
   if(reply)begin
    call_cycles=i+1;
    if(result!=32'(expected))$fatal(1,"op%0d result %h expected %h",cmd,result,expected);
    repeat(3)begin @(posedge clk);#1;if(!reply)$fatal(1,"reply not held");end
    req=0;repeat(3)@(posedge clk);return;
   end
  end
  $fatal(1,"Toolbox timeout");
 endtask
 task automatic put16(input integer p,v);arena[p]=8'(v);arena[p+1]=8'(v>>8);endtask
 task automatic put32(input integer p,v);put16(p,v);put16(p+2,v>>16);endtask
 function automatic integer u16(input integer p);return {arena[p+1],arena[p]};endfunction
 function automatic integer s16(input integer p);return integer'($signed({arena[p+1],arena[p]}));endfunction
 function automatic integer u32(input integer p);return {arena[p+3],arena[p+2],arena[p+1],arena[p]};endfunction
 // Reference for operations 6 and 7: the documented per-pixel semantics,
 // one pixel at a time in the documented order, on copies of both memories.
 byte unsigned ref_arena[0:CSTG_WORDS-1];byte unsigned ref_pix[0:307199];
 function automatic integer clampi(input integer v,lo,hi);return v<lo?lo:v>hi?hi:v;endfunction
 task automatic ref_copy(input integer cmd,sd,dd);
  integer sfb,dfb,base,stride,sx,sy,w,h,cbase,cstride,csw,csh,dx,dy,cx0,cx1,cy0,cy1;
  integer mode,mflag,pflag,mbase,mstride,fg,bg,rev,xx,yy,cx,cy,sa,da;
  byte unsigned pat[0:7];byte unsigned sv,dv,v;
  sfb=arena[sd+2]==2;dfb=arena[dd+2]==2;base=u32(sd+4);stride=u16(sd+8);sx=u16(sd+14);sy=u16(sd+16);
  w=u16(sd+18);h=u16(sd+20);cbase=u32(dd+4);cstride=u16(dd+8);csw=u16(dd+10);csh=u16(dd+12);
  dx=s16(dd+22);dy=s16(dd+24);
  cx0=clampi(s16(dd+26),0,csw);cx1=clampi(s16(dd+26)+u16(dd+30),0,csw);
  cy0=clampi(s16(dd+28),0,csh);cy1=clampi(s16(dd+28)+u16(dd+32),0,csh);
  mode=cmd==7?arena[sd+36]:0;mflag=cmd==7&&arena[sd+37][0];pflag=cmd==7&&arena[sd+37][1];
  mbase=u32(sd+48);mstride=u16(sd+52);fg=arena[sd+34];bg=arena[sd+35];
  for(integer i=0;i<8;i++)pat[i]=arena[sd+40+i];
  rev=sfb==dfb && cbase+dy*cstride+dx>base+sy*stride+sx;
  for(integer k=0;k<w*h;k++)begin
   yy=rev?h-1-k/w:k/w;xx=rev?w-1-k%w:k%w;cx=dx+xx;cy=dy+yy;
   if(cx<cx0||cx>=cx1||cy<cy0||cy>=cy1)continue;
   if(mflag && !ref_arena[mbase+yy*mstride+xx/8][7-xx%8])continue;
   sa=base+(sy+yy)*stride+sx+xx;da=cbase+cy*cstride+cx;
   sv=pflag?(pat[cy%8][7-cx%8]?8'(fg):8'(bg)):sfb?ref_pix[sa]:ref_arena[sa];
   dv=dfb?ref_pix[da]:ref_arena[da];
   case(mode)1:v=dv|sv;2:v=dv^sv;3:v=dv&~sv;4:v=dv&sv;5:v=~dv;default:v=sv;endcase
   if(dfb)ref_pix[da]=v;else ref_arena[da]=v;
  end
 endtask
 task automatic screen_desc(input integer d);
  for(integer i=0;i<64;i++)arena[d+i]=0;
  arena[d]=1;arena[d+1]=8;arena[d+2]=2;arena[d+3]=1;put16(d+8,640);put16(d+10,640);put16(d+12,480);
  put16(d+30,640);put16(d+32,480);
 endtask
 task automatic arena_desc(input integer d,base,stride,ww,hh);
  for(integer i=0;i<64;i++)arena[d+i]=0;
  arena[d]=1;arena[d+1]=8;arena[d+3]=1;put32(d+4,base);put16(d+8,stride);put16(d+10,ww);put16(d+12,hh);
  put16(d+30,ww);put16(d+32,hh);
 endtask
 task automatic sync_ref();
  for(integer i=0;i<CSTG_WORDS;i++)ref_arena[i]=arena[i];
  for(integer i=0;i<307200;i++)ref_pix[i]=pixels[i];
 endtask
 task automatic check_ref(input integer n);
  for(integer i=0;i<CSTG_WORDS;i++)if(arena[i]!=ref_arena[i])$fatal(1,"random copy %0d: arena[%0d]=%0d expected %0d",n,i,arena[i],ref_arena[i]);
  for(integer i=0;i<307200;i++)if(pixels[i]!=ref_pix[i])$fatal(1,"random copy %0d: pixel[%0d]=%0d expected %0d",n,i,pixels[i],ref_pix[i]);
 endtask
 // One valid random request: either surface kind, overlap, clipping,
 // negative placement, every mode, mask and pattern.
 task automatic random_copy(input integer n);
  integer cmd,sfb,dfb,sw,sh,stride,base,sx,sy,w,h,csw,csh,cstride,cbase,mode,fl,ms;
  cmd=6+$urandom%2;sfb=$urandom%2;dfb=$urandom%2;
  if(sfb)begin screen_desc(100);sw=640;sh=480;stride=640;base=0;end
  else begin
   sw=1+$urandom%200;sh=1+$urandom%60;stride=sw+$urandom%8;base=4096+$urandom%(180000-stride*sh);
   arena_desc(100,base,stride,sw,sh);
  end
  sx=$urandom%sw;sy=$urandom%sh;w=1+$urandom%((sw-sx)>48?48:(sw-sx));h=1+$urandom%((sh-sy)>32?32:(sh-sy));
  if($urandom%40==0)w=0;
  put16(114,sx);put16(116,sy);put16(118,w);put16(120,h);
  if(dfb)begin screen_desc(164);csw=640;csh=480;end
  else if(!sfb && $urandom%3==0)begin for(integer i=0;i<64;i++)arena[164+i]=arena[100+i];csw=sw;csh=sh;end
  else begin
   csw=1+$urandom%200;csh=1+$urandom%60;cstride=csw+$urandom%8;cbase=190000+$urandom%(180000-cstride*csh);
   arena_desc(164,cbase,cstride,csw,csh);
  end
  put16(182,w);put16(184,h);
  put16(186,(sfb==dfb && $urandom%2)?sx+int'($urandom%9)-4:int'($urandom%(csw+40))-20);
  put16(188,(sfb==dfb && $urandom%2)?sy+int'($urandom%9)-4:int'($urandom%(csh+40))-20);
  if($urandom%2)begin put16(190,0);put16(192,0);put16(194,csw);put16(196,csh);end
  else begin put16(190,int'($urandom%(csw+20))-10);put16(192,int'($urandom%(csh+20))-10);put16(194,$urandom%(csw+20));put16(196,$urandom%(csh+20));end
  if(cmd==7)begin
   mode=$urandom%6;fl=$urandom%4;arena[136]=8'(mode);arena[137]=8'(fl);
   arena[134]=8'($urandom);arena[135]=8'($urandom);
   for(integer i=0;i<8;i++)arena[140+i]=8'($urandom);
   ms=((w+7)>>3)+$urandom%3;put32(148,2048);put16(152,ms);
   for(integer i=0;i<ms*h;i++)arena[2048+i]=8'($urandom%4==0?8'hff:$urandom);
  end
  for(integer i=0;i<4096;i++)ref_arena[i]=arena[i];
  call(cmd,100,164,0,w*h);
  ref_copy(cmd,100,164);
  check_ref(n);
 endtask
 // Benchmark: one rectangle copy; prints clocks per pixel.
 task automatic bench(input string name,input integer cmd,sfb,dfb,mode,fl,ww,hh);
  if(sfb)begin screen_desc(100);put16(114,8);put16(116,8);end else arena_desc(100,4096,640,640,128);
  if(dfb)begin screen_desc(164);put16(186,200);put16(188,200);end else arena_desc(164,200000,640,640,128);
  put16(118,ww);put16(120,hh);put16(182,ww);put16(184,hh);
  arena[136]=8'(mode);arena[137]=8'(fl);put32(148,2048);put16(152,(ww+7)>>3);
  for(integer i=0;i<((ww+7)>>3)*hh;i++)arena[2048+i]=8'hff;
  call(cmd,100,164,0,ww*hh);
  $display("BENCH latency=%0d %-28s %6d clocks %5.2f clocks/pixel",latency_mode,name,call_cycles,real'(call_cycles)/real'(ww*hh));
 endtask
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
  call(0,0,0,0,69631);
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
  // A stop during the descriptor read or the pixel stream drains and stops.
  for(integer k=0;k<2;k++)begin
   arena_desc(100,4096,640,640,64);put16(118,640);put16(120,64);
   screen_desc(164);put16(182,640);put16(184,64);
   @(posedge clk);#1;op=6;a=100;b=164;c=0;req=1;
   repeat(k==0?20:600)begin @(posedge clk);#1;end
   req=0;repeat(40)begin @(posedge clk);#1;end
   if(busy || mreq || freq)$fatal(1,"copy abort did not drain %0d",k);
  end
  call(2,3000,18,1,1);if(arena[3000]!=18)$fatal(1,"restart after copy abort");
  // Typed little-endian services, across the arena seam.
  call(9,73726,32'h89abcdef,0,4);
  if(arena[73726]!=8'hef||arena[73727]!=8'hcd||arena[73728]!=8'hab||arena[73729]!=8'h89)$fatal(1,"u32 write seam");
  call(8,73726,0,0,32'h89abcdef);
  call(10,73724,32'h04030201,32'h08070605,8);
  for(integer i=0;i<8;i++)if(arena[73724+i]!=i+1)$fatal(1,"pair write seam");
  call(11,73727,16'hbeef,0,2);
  if(arena[73727]!=8'hef||arena[73728]!=8'hbe||arena[73729]!=8'h06)$fatal(1,"u16 write seam");
  call(8,CSTG_WORDS-3,0,0,-1);call(9,CSTG_WORDS-4,1,0,4);call(9,CSTG_WORDS-4,1,1,-1);
  // Descriptors that straddle the arena seam at byte 73728.
  for(integer k=0;k<2;k++)begin
   integer sd,dd;
   sd=k==0?73700:73600;dd=k==0?73800:73700;
   arena_desc(100,2000,8,8,2);put16(118,8);put16(120,2);
   screen_desc(164);put16(182,8);put16(184,2);put16(186,40+k*10);put16(188,30);
   for(integer i=0;i<16;i++)arena[2000+i]=8'(60+i+k);
   for(integer i=0;i<64;i++)begin arena[sd+i]=arena[100+i];arena[dd+i]=arena[164+i];end
   call(6,sd,dd,0,16);
   for(integer j=0;j<2;j++)for(integer i=0;i<8;i++)
    if(pixels[(30+j)*640+40+k*10+i]!=60+j*8+i+k)$fatal(1,"descriptor across arena seam %0d",k);
  end
  // Fill the whole canvas through the copy path, then compare random
  // requests with the reference.
  void'($urandom(96));
  for(integer i=0;i<307200;i++)arena[4096+i]=8'($urandom);
  arena_desc(100,4096,640,640,480);put16(118,640);put16(120,480);
  screen_desc(164);put16(182,640);put16(184,480);
  call(6,100,164,0,307200);
  $display("BENCH latency=%0d %-28s %6d clocks %5.2f clocks/pixel",latency_mode,"op6 arena->screen 640x480",call_cycles,real'(call_cycles)/307200.0);
  for(integer i=0;i<307200;i++)if(pixels[i]!=arena[4096+i])$fatal(1,"full canvas copy %0d",i);
  sync_ref();
  for(integer n=0;n<400;n++)random_copy(n);
  latency_mode=2;
  for(integer n=400;n<500;n++)random_copy(n);
  for(integer lm=1;lm<=2;lm++)begin
   latency_mode=lm;
   bench("op6 arena->screen 64x64",6,0,1,0,0,64,64);
   bench("op6 screen->arena 64x64",6,1,0,0,0,64,64);
   bench("op6 screen->screen 64x64",6,1,1,0,0,64,64);
   bench("op6 arena->arena 64x64",6,0,0,0,0,64,64);
   bench("op7 xor arena->screen 64x64",7,0,1,2,0,64,64);
   bench("op7 mask arena->screen 64x64",7,0,1,0,1,64,64);
   bench("op7 pattern ->screen 64x64",7,0,1,0,2,64,64);
   bench("op6 arena->screen 16x16",6,0,1,0,0,16,16);
  end
  latency_mode=0;
  $display("PASS Toolbox: bitmap copies all four directions, random op6/op7 reference, real BRAM reads, overlap, bounds, arena seam, delayed SRAM, packed blit/pattern");$finish;
 end
endmodule
