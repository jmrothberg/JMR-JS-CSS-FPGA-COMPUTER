#include "Vtb_present_bridge.h"
#include "verilated.h"
#include <vector>
#include <cstdint>
#include <cstdio>
#include <cstdlib>

static Vtb_present_bridge top;
static std::vector<uint16_t> mem(4194304,0xdead);
static std::vector<uint8_t> canvas(307200);
static bool reading=false, have_data=false;
static unsigned read_addr=0, delay=0;
static uint32_t data[4], rng=0x75ab948;
static uint16_t mask=0;
static unsigned writes=0;
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
 if(top.req_o&&top.we_o&&top.ack_o)++writes;
 if(top.app_wdf_wren&&top.app_wdf_rdy){
  if(have_data)fail("overlapping write data");
  for(unsigned k=0;k<4;k++)data[k]=top.app_wdf_data[k];
  mask=top.app_wdf_mask;have_data=true;
 }
 if(top.app_en&&top.app_rdy){
  if(top.app_cmd==1){
   if(reading)fail("overlapping reads");
   reading=true;read_addr=top.app_addr;delay=25;
  }else if(top.app_cmd==0){
   if(!have_data)fail("write command without data");
   for(unsigned k=0;k<8;k++){
    uint16_t word=uint16_t(data[k/2]>>((k&1)*16));
    auto &dest=mem[top.app_addr+k];
    if(!(mask&(1u<<(2*k))))dest=(dest&0xff00)|(word&255);
    if(!(mask&(1u<<(2*k+1))))dest=(dest&255)|(word&0xff00);
   }
   have_data=false;
  }else fail("unexpected command");
 }
 top.clk=1;top.eval();
}
static void write(unsigned a,uint8_t value){
 top.we=1;top.waddr=a;top.wdata=value;tick();top.we=0;canvas[a]=value;
}
static uint16_t read(unsigned a){
 top.verify_addr_valid=1;top.verify_addr=a;top.flush=1;
 unsigned clocks=0;
 do{tick();if(++clocks>1000)fail("read completion");}while(!top.ack_o);
 uint16_t value=top.rdata_o;top.flush=0;tick();tick();return value;
}
static void verify(bool clear){
 for(unsigned i=0;i<153600;i++){
  uint16_t expected=clear?0:unsigned(canvas[2*i])|(unsigned(canvas[2*i+1])<<8);
  if(read(3577856+i)!=expected)fail("front pixels through actual DDR bridge");
 }
}
static unsigned present(bool clear=false){
 writes=0;top.swap=!clear;top.clear_go=clear;tick();top.swap=0;top.clear_go=0;
 unsigned clocks=0;
 do{tick();if(++clocks>3000000)fail("present completion");}while(top.busy);
 unsigned accepted=writes;verify(clear);
 std::printf("dirty real DDR: %u writes, %u clocks, all front pixels verified\n",accepted,clocks);
 return accepted;
}
int main(int argc,char**argv){
 Verilated::commandArgs(argc,argv);
 top.rst_n=0;top.swap=0;top.clear_go=0;top.we=0;top.flush=0;top.verify_addr_valid=0;
 tick();tick();top.rst_n=1;tick();
 for(unsigned i=0;i<307200;i++)write(i,uint8_t(i*17+(i>>8)));
 if(present()!=153600)fail("initial copy");
 if(present()!=0)fail("unchanged copy");
 write(1,canvas[1]^7);write(30011,canvas[30011]^19);write(307199,canvas[307199]^32);
 if(present()!=384)fail("sparse block count");
 write(529,canvas[529]^11);
 if(present()!=128)fail("single block count");
 if(present(true)!=153600)fail("clear count");
 if(present()!=153600)fail("restore count");
 std::puts("PASS dirty present real DDR: all 307200 front pixels after every copy, read cache and write-combine coherence");
}
