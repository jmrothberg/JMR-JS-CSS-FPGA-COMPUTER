// Generic synchronous file services for ordinary programs. No catalog, heap or
// file-sized buffer: bytes move through the existing WORK port and SRAM arena.
// req/args stay stable until reply; reply stays high until req is withdrawn.
module jmr_finder_fs (
 input logic clk,rst_n,req,
 input logic [2:0] command,
 input logic [31:0] arg0,arg1,arg2,arg3,
 output logic busy,reply,
 output logic [31:0] result,
 output logic launch,
 output logic [95:0] launch_name,
 output logic [3:0] launch_len,launch_how,
 output logic stor_open,stor_close,stor_dir,stor_next,stor_get,stor_put,stor_delete,stor_rename,
 output logic [7:0] stor_mode,stor_name_len,stor_put_data,
 output logic [15:0] stor_name_addr,
 input logic stor_busy,stor_done,stor_err,stor_missing,stor_eof,
 input logic [7:0] stor_line_len,stor_byte,stor_attr,
 input logic [15:0] stor_date,
 input logic [31:0] stor_file_size,stor_dir_size,
 output logic mem_en,mem_we,
 output logic [15:0] mem_addr,
 output logic [7:0] mem_wdata,
 input logic [7:0] mem_rdata,input logic mem_gnt,
 output logic sram_req,sram_we,
 output logic [21:0] sram_addr,
 output logic [15:0] sram_wdata,
 input logic sram_ack,input logic [15:0] sram_rdata
);
 import jmr_js_vm_pkg::*;
 typedef enum logic [5:0] {IDLE,NAME_READ,NAME_CAPTURE,NAME_STORE,NAME_STORE_WAIT,
 DISPATCH,OPEN,OPEN_WAIT,READ_BYTE,READ_WAIT,WRITE_BYTE,WRITE_WAIT,CLOSE,CLOSE_WAIT,
 REMOVE,REMOVE_WAIT,RENAME,RENAME_WAIT,DIR,DIR_WAIT,NEXT,NEXT_WAIT,CAT_READ,CAT_WAIT,
 CAT_EMIT,HEADER,END_LIST,ARENA_WAIT,ARENA_GAP,DONE,RENAME_DELETE,RENAME_DELETE_WAIT} st_t;
 st_t state,after_arena;
 logic [2:0] cmd;
 logic [31:0] a0,a1,a2,a3,pos,transferred,used,size_q;
 logic [20:0] ptr;
 logic [15:0] count,date_q;
 logic [7:0] attr_q,byte_q;
 logic [95:0] name0,name1;
 logic [3:0] name_len0,name_len1,ni;
 logic second_name,names_equal,had_dot;
 logic [3:0] stem_len,ext_len;
 logic [4:0] emit_i;
 logic [1:0] rename_phase;
 logic [7:0] catalog_name[0:11];
 logic [3:0] catalog_len;
 assign busy=state!=IDLE && state!=DONE;
 function automatic logic legal(input logic [7:0] c);
  case(c)36,37,39,45,95,64,126,96,33,40,41,123,125,94,35,38:legal=1;
   default:legal=(c>=65&&c<=90)||(c>=48&&c<=57);endcase
 endfunction
 task automatic arena_write(input logic [20:0] address,input logic [7:0] value,input st_t ret);
  sram_req<=1;sram_we<=1;sram_addr<=cstg_word(address);sram_wdata<={8'd0,value};
  after_arena<=ret;state<=ARENA_WAIT;
 endtask
 task automatic fail;
  result<=32'hffffffff;state<=DONE;
 endtask
 always_ff @(posedge clk)begin
  if(!rst_n)begin
   state<=IDLE;after_arena<=IDLE;reply<=0;result<=0;launch<=0;launch_name<=0;launch_len<=0;launch_how<=0;
   stor_open<=0;stor_close<=0;stor_dir<=0;stor_next<=0;stor_get<=0;stor_put<=0;stor_delete<=0;stor_rename<=0;
   stor_mode<=73;stor_name_len<=0;stor_name_addr<=16'hb850;stor_put_data<=0;
   mem_en<=0;mem_we<=0;mem_addr<=0;mem_wdata<=0;sram_req<=0;sram_we<=0;sram_addr<=0;sram_wdata<=0;
   cmd<=0;a0<=0;a1<=0;a2<=0;a3<=0;pos<=0;transferred<=0;used<=0;size_q<=0;ptr<=256;count<=0;date_q<=0;attr_q<=0;
   byte_q<=0;name0<=0;name1<=0;name_len0<=0;name_len1<=0;ni<=0;second_name<=0;names_equal<=1;
   had_dot<=0;stem_len<=0;ext_len<=0;emit_i<=0;rename_phase<=0;catalog_len<=0;
  end else begin
   stor_open<=0;stor_close<=0;stor_dir<=0;stor_next<=0;stor_get<=0;stor_put<=0;stor_delete<=0;stor_rename<=0;launch<=0;
   case(state)
    IDLE:if(req && !stor_busy)begin
     cmd<=command;a0<=arg0;a1<=(command==2 && arg1[31])?32'd0:arg1;
     a2<=(command==3 && arg2[31])?32'd0:arg2;a3<=(command==2 && arg3[31])?32'd0:arg3;result<=0;reply<=0;pos<=0;transferred<=0;
     name0<=0;name1<=0;name_len0<=0;name_len1<=0;ni<=0;second_name<=0;names_equal<=1;
     had_dot<=0;stem_len<=0;ext_len<=0;rename_phase<=0;
     if(command==1)begin count<=0;used<=0;ptr<=256;state<=DIR;end
     else if(arg0>=CSTG_WORDS)fail();else state<=NAME_READ;
    end
    NAME_READ:begin
     if((second_name?a1:a0)+{28'd0,ni}>=CSTG_WORDS)fail();
     else begin sram_req<=1;sram_we<=0;sram_addr<=cstg_word(21'((second_name?a1:a0)+{28'd0,ni}));state<=NAME_CAPTURE;end
    end
    NAME_CAPTURE:if(sram_ack)begin
     logic [7:0] c;
     c=sram_rdata[7:0];if(c>=97&&c<=122)c=c-32;
     sram_req<=0;
     if(c==0)begin
      if(ni==0 && cmd==6)begin launch_name<=0;launch_len<=0;launch_how<=8;launch<=1;state<=DONE;end
      else if(ni==0 || stem_len==0 || (had_dot&&ext_len==0))fail();
      else if(cmd==5 && !second_name)begin
       name_len0<=ni;second_name<=1;ni<=0;had_dot<=0;stem_len<=0;ext_len<=0;state<=NAME_READ;
      end else begin
       if(second_name)name_len1<=ni;else name_len0<=ni;
       state<=DISPATCH;
      end
     end else if(ni>=12 || (c==46?(had_dot||stem_len==0):(!legal(c)||(had_dot?ext_len>=3:stem_len>=8))))fail();
     else begin
      if(c==46)had_dot<=1;else if(had_dot)ext_len<=ext_len+1'b1;else stem_len<=stem_len+1'b1;
      if(second_name)begin name1[ni*8+:8]<=c;if(c!=name0[ni*8+:8])names_equal<=0;end
      else name0[ni*8+:8]<=c;
      byte_q<=c;state<=NAME_STORE;
     end
    end
    NAME_STORE:begin mem_en<=1;mem_we<=1;mem_addr<=(second_name?16'hb870:16'hb850)+{12'd0,ni};mem_wdata<=byte_q;state<=NAME_STORE_WAIT;end
    NAME_STORE_WAIT:if(mem_gnt)begin mem_en<=0;mem_we<=0;ni<=ni+1'b1;state<=NAME_READ;end
    DISPATCH:begin
     stor_name_addr<=16'hb850;stor_name_len<={4'd0,name_len0};stor_mode<=73;
     case(cmd)
      2:if(a1[31] || a3[31] || a2>=CSTG_WORDS || a3>CSTG_WORDS-a2)fail();else state<=OPEN;
      3:if(a2[31] || a1>=CSTG_WORDS || a2>CSTG_WORDS-a1)fail();else begin stor_mode<=a3==1?65:79;state<=OPEN;end
      4:state<=REMOVE;
      5:if(names_equal && name_len0==name_len1)state<=DONE;else state<=OPEN;
      6:if(a1>8)fail();else begin launch_name<=name0;launch_len<=name_len0;launch_how<=a1[3:0];launch<=1;state<=DONE;end
      default:fail();
     endcase
    end
    OPEN:if(!stor_busy)begin stor_open<=1;state<=OPEN_WAIT;end
    OPEN_WAIT:if(stor_done)begin
     if(stor_err)fail();
     else if(cmd==5)begin
      if(rename_phase==0)begin rename_phase<=1;state<=CLOSE;end else state<=RENAME;
     end else if(cmd==3)state<=WRITE_BYTE;else state<=READ_BYTE;
    end
    READ_BYTE:if(!stor_busy)begin
     if(transferred>=a3 || pos>=stor_file_size)begin result<=transferred;state<=CLOSE;end
     else begin stor_get<=1;state<=READ_WAIT;end
    end
    READ_WAIT:if(stor_done)begin
     if(stor_err)begin result<=32'hffffffff;state<=CLOSE;end
     else if(stor_eof)begin result<=transferred;state<=CLOSE;end
     else begin
      pos<=pos+1'b1;
      if(pos<a1)state<=READ_BYTE;
      else begin arena_write(21'(a2+transferred),stor_byte,READ_BYTE);transferred<=transferred+1'b1;end
     end
    end
    WRITE_BYTE:if(transferred>=a2)begin result<=transferred;state<=CLOSE;end
     else begin sram_req<=1;sram_we<=0;sram_addr<=cstg_word(21'(a1+transferred));after_arena<=WRITE_WAIT;state<=ARENA_WAIT;end
    WRITE_WAIT:if(!stor_busy)begin stor_put_data<=byte_q;stor_put<=1;state<=REMOVE_WAIT;end
    REMOVE_WAIT:if(stor_done)begin
     if(stor_err && !(cmd==4 && stor_missing))begin result<=32'hffffffff;if(cmd==3)state<=CLOSE;else state<=DONE;end
     else if(cmd==3)begin transferred<=transferred+1'b1;state<=WRITE_BYTE;end
     else state<=DONE;
    end
    REMOVE:if(!stor_busy)begin stor_delete<=1;state<=REMOVE_WAIT;end
    CLOSE:if(!stor_busy)begin stor_close<=1;state<=CLOSE_WAIT;end
    CLOSE_WAIT:if(stor_done)begin
     if(stor_err)fail();
     else if(cmd==5 && rename_phase==1)begin stor_name_addr<=16'hb870;stor_name_len<={4'd0,name_len1};state<=RENAME_DELETE;end
     else state<=DONE;
    end
    RENAME_DELETE:if(!stor_busy)begin stor_delete<=1;state<=RENAME_DELETE_WAIT;end
    RENAME_DELETE_WAIT:if(stor_done)begin
     if(stor_err && !stor_missing)fail();
     else begin rename_phase<=2;stor_name_addr<=16'hb850;stor_name_len<={4'd0,name_len0};state<=OPEN;end
    end
    RENAME:if(!stor_busy)begin stor_name_addr<=16'hb870;stor_name_len<={4'd0,name_len1};state<=RENAME_WAIT;end
    RENAME_WAIT:begin
     // name port is registered before asserting the rename strobe.
     if(rename_phase==2)begin stor_rename<=1;rename_phase<=3;end
     else if(stor_done)begin if(stor_err)fail();else begin result<=0;state<=CLOSE;end end
    end
    DIR:if(!stor_busy)begin stor_dir<=1;state<=DIR_WAIT;end
    DIR_WAIT:if(stor_done)begin if(stor_err)fail();else state<=NEXT;end
    NEXT:if(!stor_busy)begin stor_next<=1;state<=NEXT_WAIT;end
    NEXT_WAIT:if(stor_done)begin
     if(stor_err)fail();else if(stor_eof || ptr+21'd21>=CSTG_WORDS)state<=END_LIST;
     else begin ni<=0;catalog_len<=4'(stor_line_len>12?12:stor_line_len);size_q<=stor_dir_size;date_q<=stor_date;attr_q<=stor_attr;state<=CAT_READ;end
    end
    CAT_READ:begin mem_en<=1;mem_we<=0;mem_addr<=16'hbb00+{12'd0,ni};state<=CAT_WAIT;end
    CAT_WAIT:if(mem_gnt)begin
     mem_en<=0;catalog_name[ni]<=mem_rdata;
     if(ni+1>=catalog_len)begin emit_i<=0;state<=CAT_EMIT;end else begin ni<=ni+1'b1;state<=CAT_READ;end
    end
    CAT_EMIT:begin
     logic [7:0] b;
     b=0;
     if(emit_i==0)b={4'd0,catalog_len};
     else if(emit_i<={1'b0,catalog_len})b=catalog_name[4'(emit_i-1'b1)];
     else case(emit_i-{1'b0,catalog_len})
      1:b=size_q[7:0];2:b=size_q[15:8];3:b=size_q[23:16];4:b=size_q[31:24];
      5:b=date_q[7:0];6:b=date_q[15:8];7:b=attr_q;default:;
     endcase
     ptr<=ptr+1'b1;emit_i<=emit_i+1'b1;
     if(emit_i=={1'b0,catalog_len}+5'd7)begin count<=count+1'b1;used<=used+size_q;arena_write(ptr,b,NEXT);end
     else arena_write(ptr,b,CAT_EMIT);
    end
    END_LIST:begin emit_i<=0;arena_write(ptr,0,HEADER);end
    HEADER:begin
     logic [7:0] b;
     b=0;case(emit_i)0:b=used[7:0];1:b=used[15:8];2:b=used[23:16];3:b=used[31:24];8:b=count[7:0];9:b=count[15:8];default:;endcase
     emit_i<=emit_i+1'b1;
     if(emit_i==9)begin result<={16'd0,count};arena_write(21'd240+{16'd0,emit_i},b,DONE);end
     else arena_write(21'd240+{16'd0,emit_i},b,HEADER);
    end
    ARENA_WAIT:if(sram_ack)begin sram_req<=0;sram_we<=0;byte_q<=sram_rdata[7:0];state<=ARENA_GAP;end
    ARENA_GAP:state<=after_arena;
    DONE:begin reply<=1;if(!req)begin reply<=0;state<=IDLE;end end
    default:fail();
   endcase
  end
 end
endmodule
