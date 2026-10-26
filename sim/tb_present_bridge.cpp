#include "Vtb_present_bridge.h"
#include "verilated.h"
#include <vector>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
static Vtb_present_bridge top;
static std::vector<uint16_t> mem(2097152,0xdead);
static uint16_t pending_data[8],pending_mask;
static bool pending=false,reading=false;
static unsigned read_addr=0,delay=0,accepted=0;
static uint32_t rng=0x759da4;
static bool zeros=false;
static uint8_t pixel(unsigned x){return uint8_t(x*29+(x>>7));}
static void fail(const char* s){std::fprintf(stderr,"FAIL %s\n",s);std::exit(1);}
static void tick(){
 top.clk=0;top.eval();
 rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;
 top.app_rdy=(rng&7)>1; top.app_wdf_rdy=((rng>>3)&7)>2;
 top.app_rd_data_valid=reading && delay==0;
 if(top.app_rd_data_valid){
  for(unsigned k=0;k<4;k++)top.app_rd_data[k]=unsigned(mem[read_addr+2*k])|(unsigned(mem[read_addr+2*k+1])<<16);
  reading=false;
 }else if(reading)--delay;
 top.eval();
 if(top.req_o&&top.ack_o&&top.we_o){
  unsigned i=accepted%153600;
  if(top.addr_o!=1480704+i)fail("SRAM write order");
  unsigned want=zeros?0:unsigned(pixel(2*i))|(unsigned(pixel(2*i+1))<<8);
  if(top.data_o!=want)fail("SRAM byte pairing");
  accepted++;
 }
 if(top.app_wdf_wren&&top.app_wdf_rdy){
  if(pending||!top.app_wdf_end)fail("write-data protocol");
  pending=true;pending_mask=top.app_wdf_mask;
  for(unsigned i=0;i<8;i++)pending_data[i]=top.app_wdf_data[i/2]>>((i%2)*16);
 }
 if(top.app_en&&top.app_rdy){
  if(top.app_cmd==0){
   if(!pending)fail("command before accepted write data");
   for(unsigned i=0;i<8;i++){
    unsigned mask=(pending_mask>>(2*i))&3;
    unsigned old=mem[top.app_addr+i],v=pending_data[i];
    if(mask&1)v=(v&0xff00)|(old&255);
    if(mask&2)v=(v&255)|(old&0xff00);
    mem[top.app_addr+i]=v;
   }
   pending=false;
  }else{
   if(reading)fail("multiple outstanding reads");
   reading=true;read_addr=top.app_addr;delay=25;
  }
 }
 top.clk=1;top.eval();
}
static void present(bool clear){
 zeros=clear;unsigned before=accepted;
 top.clear_go=clear;top.swap=!clear;tick();top.clear_go=0;top.swap=0;
 unsigned cycles=0;
 while(top.busy&&cycles++<3000000)tick();
 if(top.busy||accepted-before!=153600)fail("present completion");
 // Force the bridge's final write-combine line to commit, then read it.
 top.flush=1;tick();
 for(unsigned i=0;i<10000&&!top.ack_o;i++)tick();
 if(!top.ack_o)fail("final-line coherence read timeout");
 unsigned want=clear?0:unsigned(pixel(307198))|(unsigned(pixel(307199))<<8);
 if(top.rdata_o!=want)fail("coherent final word");
 top.flush=0;tick();tick();
 for(unsigned i=0;i<153600;i++){
  want=clear?0:unsigned(pixel(2*i))|(unsigned(pixel(2*i+1))<<8);
  if(mem[1480704+i]!=want)fail("MIG memory image mismatch");
 }
 std::printf("present through real bridge: %u clocks\n",cycles);
}
int main(int argc,char**argv){
 Verilated::commandArgs(argc,argv);top.rst_n=0;top.we=0;top.flush=0;top.swap=0;top.clear_go=0;
 tick();tick();top.rst_n=1;top.we=1;
 for(unsigned i=0;i<307200;i++){top.waddr=i;top.wdata=pixel(i);tick();}
 top.we=0;present(false);present(true);present(false);
 std::puts("PASS real DDR3 bridge: 460800 exact words, independent ready stalls, delayed reads, write-combine coherence");
}
