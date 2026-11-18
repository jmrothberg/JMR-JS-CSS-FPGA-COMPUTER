// Burst-8 mailbox interface, 16-bit word addresses, complete 64 MiB.
// Aligned 8-word bursts cannot cross the 0x1000000-word die boundary.
// CR1 writes broadcast to both dies; ID0 and CR1 are read on EACH die.
module jmr_hyperram_bus #(parameter POWER_CYCLES=12500,parameter READ_WORDS=8,
 parameter [24:0] BIST_LAST=25'h1fffff8)(
 input wire clk,ck90,ref200,rst_n,
 input wire command_toggle,command_write,
 input wire [24:0] command_addr,input wire [127:0] command_data,
 input wire [15:0] command_mask,
 output reg done_toggle,output reg [511:0] result,
 output reg ready,output reg fault,
 output wire HR_CK_P_SRC,HR_CK_N_SRC,HR_RESET_N,
 output wire HR_CS_N,inout wire [7:0] HR_DQ,inout wire HR_RWDS);
 localparam POWER=0,IDLE=1,SETUP=2,CA=3,LATENCY=4,WRITE=5,READ=6,STOP=7,RECOVER=8;
 reg [3:0] state;
 reg [15:0] timer;
 reg [5:0] cycle;
 reg [3:0] step;
 reg writing,registers;
 reg [47:0] ca_word;
 reg [127:0] data_q;
 reg [15:0] mask_q;
 reg [5:0] words;
 reg [24:0] bist_addr;
 reg seen;
 (* ASYNC_REG="TRUE" *) reg [1:0] command_sync;
 (* ASYNC_REG="TRUE" *) reg [1:0] delay_sync;
 wire [511:0] rx_data;wire [5:0] rx_count;wire delay_ready;
 reg [1:0] count_ready;
 wire finished_read=rx_count==words;
 wire active=state==CA || state==LATENCY || state==WRITE || state==READ;
 wire drive_dq=state==CA || state==WRITE;
 wire [15:0] tx_word=state==CA ? ca_word[47-cycle*16-:16] : data_q[cycle*16+:16];
 jmr_hyperram_phy phy(.clk(clk),.ck90(ck90),.ref200(ref200),.rst_n(rst_n),
  .active(active),.drive_dq(drive_dq),.drive_mask(state==WRITE && !registers),
  .clear_rx(!(state==LATENCY && cycle>=9) && state!=READ && state!=STOP && state!=RECOVER),
  .tx_word(tx_word),.tx_mask({mask_q[cycle*2+1],mask_q[cycle*2]}),
  .rx_data(rx_data),.rx_count(rx_count),.delay_ready(delay_ready),
  .HR_CK_P_SRC(HR_CK_P_SRC),.HR_CK_N_SRC(HR_CK_N_SRC),.HR_DQ(HR_DQ),.HR_RWDS(HR_RWDS));
 assign HR_RESET_N=rst_n && (state!=POWER || timer>25);
 assign HR_CS_N=state==POWER || state==IDLE || state==RECOVER;
 function automatic [47:0] ca(input bit wr,regspace,input [24:0] a);
  // CA[45]=1 linear burst; CA[37:16]=address[24:3].
  ca={~wr,regspace,1'b1,7'b0,a[24:3],13'b0,a[2:0]};
 endfunction
 function automatic [127:0] pattern(input [24:0] a,input bit invert);
  reg [24:0] word_address;
  for(integer i=0;i<8;i=i+1)begin
   word_address=a+25'(i);
   pattern[i*16+:16]=16'ha5c3 ^ word_address[15:0] ^ {7'b0,word_address[24:16]} ^ {16{invert}};
  end
 endfunction
 task automatic start(input bit wr,regspace,input [24:0] a,
                      input [127:0] d,input [15:0] m,input [5:0] n);
  begin writing<=wr;registers<=regspace;ca_word<=ca(wr,regspace,a);
   data_q<=d;mask_q<=m;words<=n;state<=SETUP;cycle<=0;timer<=0;end
 endtask
 // Controller advances half a cycle before the TX ODDR loads. Enables are
 // registered alongside that ODDR, retaining the last falling-edge byte.
 always @(negedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=POWER;timer<=0;cycle<=0;step<=0;writing<=0;registers<=0;
   ca_word<=0;data_q<=0;mask_q<=0;words<=0;seen<=0;command_sync<=0;bist_addr<=0;
   delay_sync<=0;count_ready<=0;done_toggle<=0;result<=0;ready<=0;fault<=0;
  end else begin
   command_sync<={command_sync[0],command_toggle};
   delay_sync<={delay_sync[0],delay_ready};
   count_ready<={count_ready[0],finished_read};
   case(state)
    POWER:if(timer<POWER_CYCLES)timer<=timer+1'b1;
     else if(delay_sync[1])begin step<=0;state<=IDLE;end
    IDLE:begin
     if(!fault)begin
      case(step)
       0:start(1,1,25'h801,128'hff81,0,1);
       1:start(0,1,0,0,0,1);
       2:start(0,1,25'h1000000,0,0,1);
       3:start(0,1,25'h801,0,0,1);
       4:start(0,1,25'h1000801,0,0,1);
       5,7:start(1,0,bist_addr,pattern(bist_addr,step==7),0,8);
       6,8:start(0,0,bist_addr,0,0,8);
       default:begin
        ready<=1;
        if(command_sync[1]!=seen)begin
         seen<=command_sync[1];
         start(command_write,0,command_addr,command_data,command_mask,command_write?8:READ_WORDS);
        end
       end
      endcase
     end
    end
    SETUP:begin cycle<=0;state<=CA;end
    CA:if(cycle==2)begin
     cycle<=0;timer<=0;
     if(registers && writing)state<=WRITE;else state<=LATENCY;
    end else cycle<=cycle+1'b1;
    // Default LC=7, fixed 2x latency. Data starts at CK cycle 17;
    // CA occupies cycles 1..3, followed by 13 latency cycles.
    LATENCY:if(cycle==12)begin cycle<=0;state<=writing?WRITE:READ;end
     else cycle<=cycle+1'b1;
    WRITE:if(cycle==words-1)begin state<=STOP;cycle<=0;end else cycle<=cycle+1'b1;
    // Stop CK on the exact last requested word. Synchronizing a received
    // counter before stopping would clock extra words across die boundaries.
    READ:if(cycle==words-1)begin state<=STOP;cycle<=0;end else cycle<=cycle+1'b1;
    // Hold CS while the source-synchronous mailbox settles, snapshot the
    // final I/O-register word, THEN release CS. RWDS may float after release.
    STOP:if(cycle==3)begin
     if(!writing)begin
      result<=rx_data;
      if(rx_count!==words)begin fault<=1;ready<=0;end
     end
     state<=RECOVER;cycle<=0;
    end else cycle<=cycle+1'b1;
    RECOVER:if(cycle==1)begin
     if(step<5)begin
      if((step==1 && result[15:0]!==16'h0f86) ||
         (step==2 && result[15:0]!==16'h4f86) ||
         ((step==3 || step==4) && result[15:0]!==16'hff81))fault<=1;
      step<=step+1'b1;
     end else if(step<9)begin
      if((step==6 || step==8) && result[127:0]!==pattern(bist_addr,step==8))begin fault<=1;ready<=0;end
      if(bist_addr==BIST_LAST)begin bist_addr<=0;step<=step+1'b1;end
      else bist_addr<=bist_addr+25'd8;
     end else done_toggle<=seen;
     state<=IDLE;cycle<=0;
    end else cycle<=cycle+1'b1;
    default:state<=POWER;
   endcase
  end
 end
endmodule
