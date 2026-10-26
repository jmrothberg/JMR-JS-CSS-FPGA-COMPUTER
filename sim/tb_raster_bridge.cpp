#include "Vtb_raster_bridge.h"
#include "verilated.h"
#include <vector>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
static Vtb_raster_bridge top;
static std::vector<uint16_t> mem(2097152,0xdead);
static std::vector<uint8_t> pixels(307200);
static bool reading=false;
static unsigned read_addr=0,delay=0;
static uint32_t rng=0x759da4;
static uint8_t pixel(unsigned x){return uint8_t(x*29+(x>>7));}
static void fail(const char* s){std::fprintf(stderr,"FAIL %s\n",s);std::exit(1);}
static void tick(){
 top.clk=0;top.eval();
 rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;
 top.app_rdy=(rng&7)>1;top.app_wdf_rdy=((rng>>3)&7)>2;
 top.app_rd_data_valid=reading&&delay==0;
 if(top.app_rd_data_valid){
  for(unsigned k=0;k<4;k++)top.app_rd_data[k]=unsigned(mem[read_addr+2*k])|(unsigned(mem[read_addr+2*k+1])<<16);
  reading=false;
 }else if(reading)--delay;
 top.eval();
 if(top.fb_we){
  if(top.fb_addr>=pixels.size())fail("framebuffer bounds");
  pixels[top.fb_addr]=top.fb_data;
 }
 if(top.app_wdf_wren)fail("ImageData read caused DDR write");
 if(top.app_en&&top.app_rdy){
  if(top.app_cmd!=1||reading)fail("read protocol");
  reading=true;read_addr=top.app_addr;delay=25;
 }
 top.clk=1;top.eval();
}
static void draw(int dx,int dy,unsigned w,unsigned h,unsigned source,bool fx=false,bool fy=false){
 std::fill(pixels.begin(),pixels.end(),0xa7);
 auto want=pixels;
 for(unsigned y=0;y<h;y++)for(unsigned x=0;x<w;x++){
  int xx=dx+(fx?w-1-x:x),yy=dy+(fy?h-1-y:y);
  unsigned si=source+y*w+x;
  if(xx>=0&&xx<640&&yy>=0&&yy<480&&si<307200)want[yy*640+xx]=pixel(si);
 }
 top.dx=dx;top.dy=dy;top.w=w;top.h=h;top.source=source;top.flip_x=fx;top.flip_y=fy;
 top.go=1;tick();top.go=0;
 unsigned cycles=0;
 do{tick();if(++cycles>4000000)fail("ImageData completion");}while(top.busy);
 tick();
 if(pixels!=want)fail("ImageData pixel image");
 std::printf("ImageData %ux%u through real bridge: %u clocks\n",w,h,cycles);
}
int main(int argc,char**argv){
 Verilated::commandArgs(argc,argv);
 for(unsigned i=0;i<307200;i++)mem[1789952+i]=0x9e00|pixel(i);
 top.rst_n=0;top.go=0;tick();tick();top.rst_n=1;tick();
 draw(0,0,640,480,0);
 draw(7,11,1,17,37);
 draw(-2,478,7,5,9,true,true);
 draw(16,22,8,3,307198);
 std::puts("PASS ImageData real DDR3 bridge: full image, thin rows, clipping, flips, source cap");
}
