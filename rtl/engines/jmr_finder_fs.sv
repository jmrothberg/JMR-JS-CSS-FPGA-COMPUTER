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
 input logic [127:0] document_name,
 input logic [4:0] document_name_len,
 input logic document_unnamed,
 input logic [2:0] document_role,
 output logic document_set_name,document_new,
 output logic [95:0] document_new_name,
 output logic [3:0] document_new_len,
 output logic [2:0] document_new_role,
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
 CAT_EMIT,HEADER,END_LIST,ARENA_WAIT,ARENA_GAP,DONE,RENAME_DELETE,RENAME_DELETE_WAIT,DOC_METADATA,DOC_COMMIT} st_t;
 st_t state,after_arena;
 // Same-cycle Moore status: updated alongside every state assignment.
 logic busy_q;
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
 logic catalog_bounded,catalog_more;
 logic [31:0] catalog_end,catalog_seen;
 assign busy=busy_q;
 function automatic logic legal(input logic [7:0] c);
  case(c)36,37,39,45,95,64,126,96,33,40,41,123,125,94,35,38:legal=1;
   default:legal=(c>=65&&c<=90)||(c>=48&&c<=57);endcase
 endfunction
 // The public arguments remain 32 bits. Reject every high bit before using
 // bounded arena arithmetic, so invalid/negative values cannot wrap into SRAM.
 // CSTG_WORDS=380928 fits 19 bits; this removes a 32-bit subtract/compare
 // chain from DISPATCH without adding a service cycle.
 function automatic logic arena_span_valid(input logic [31:0] base, length);
  arena_span_valid = !(|base[31:19]) && !(|length[31:19]) &&
                     base[18:0] < 19'(CSTG_WORDS) &&
                     length[18:0] <= (19'(CSTG_WORDS) - base[18:0]);
 endfunction
 task automatic arena_write(input logic [20:0] address,input logic [7:0] value,input st_t ret);
  sram_req<=1;sram_we<=1;sram_addr<=cstg_word(address);sram_wdata<={8'd0,value};
  after_arena<=ret;begin state<=ARENA_WAIT;busy_q<=1'b1;end 
 endtask
 task automatic fail;
  result<=32'hffffffff;begin state<=DONE;busy_q<=1'b0;end 
 endtask
 always_ff @(posedge clk)begin
  if(!rst_n)begin
   catalog_bounded<=0;catalog_more<=0;catalog_end<=0;catalog_seen<=0;
   document_set_name<=0;document_new<=0;document_new_name<=0;document_new_len<=0;document_new_role<=1;
   begin state<=IDLE;busy_q<=1'b0;end after_arena<=IDLE;reply<=0;result<=0;launch<=0;launch_name<=0;launch_len<=0;launch_how<=0;
   stor_open<=0;stor_close<=0;stor_dir<=0;stor_next<=0;stor_get<=0;stor_put<=0;stor_delete<=0;stor_rename<=0;
   stor_mode<=73;stor_name_len<=0;stor_name_addr<=16'hb850;stor_put_data<=0;
   mem_en<=0;mem_we<=0;mem_addr<=0;mem_wdata<=0;sram_req<=0;sram_we<=0;sram_addr<=0;sram_wdata<=0;
   cmd<=0;a0<=0;a1<=0;a2<=0;a3<=0;pos<=0;transferred<=0;used<=0;size_q<=0;ptr<=256;count<=0;date_q<=0;attr_q<=0;
   byte_q<=0;name0<=0;name1<=0;name_len0<=0;name_len1<=0;ni<=0;second_name<=0;names_equal<=1;
   had_dot<=0;stem_len<=0;ext_len<=0;emit_i<=0;rename_phase<=0;catalog_len<=0;
  end else begin
   document_set_name<=0;document_new<=0;
   stor_open<=0;stor_close<=0;stor_dir<=0;stor_next<=0;stor_get<=0;stor_put<=0;stor_delete<=0;stor_rename<=0;launch<=0;
   // A stopped application cannot rename a later document. Drain an accepted
   // arena beat before abandoning only the raw document service; FAT ops retain
   // their existing close/drain protocol.
   if(cmd==0 && state!=IDLE && state!=DONE && !req)begin
    if(!sram_req || sram_ack)begin sram_req<=0;sram_we<=0;result<=32'hffffffff;begin state<=DONE;busy_q<=1'b0;end end
   end else case(state)
    IDLE:if(req && !stor_busy)begin
     cmd<=command;a0<=arg0;a1<=(command==2 && arg1[31])?32'd0:arg1;
     a2<=(command==3 && arg2[31])?32'd0:arg2;a3<=(command==2 && arg3[31])?32'd0:arg3;result<=0;reply<=0;pos<=0;transferred<=0;
     name0<=0;name1<=0;name_len0<=0;name_len1<=0;ni<=0;second_name<=0;names_equal<=1;
     had_dot<=0;stem_len<=0;ext_len<=0;rename_phase<=0;
     if(command==0)begin
      if(arg0==0 && arg1<=CSTG_WORDS-20)begin emit_i<=0;begin state<=DOC_METADATA;busy_q<=1'b1;end end
      else if((arg2==1 || arg2==5) && arg0==1 && arg1<CSTG_WORDS)begin state<=NAME_READ;busy_q<=1'b1;end 
      else if((arg2==1 || arg2==5) && arg0==2)begin document_new_role<=arg2[2:0];document_new<=1;begin state<=DOC_COMMIT;busy_q<=1'b1;end end
      else fail();
     end else if(command==1)begin
      count<=0;used<=0;catalog_seen<=0;catalog_more<=0;catalog_bounded<=arg0!=0;
      if(arg0==0)begin ptr<=256;catalog_end<=CSTG_WORDS;begin state<=DIR;busy_q<=1'b1;end end
      else if(arg1<37 || !arena_span_valid(arg0,arg1))fail();
      else begin ptr<=21'(arg0+16);catalog_end<=arg0+arg1;begin state<=DIR;busy_q<=1'b1;end end
     end
     else if(arg0>=CSTG_WORDS)fail();else begin state<=NAME_READ;busy_q<=1'b1;end 
    end
    NAME_READ:begin
     if((cmd==0?a1:second_name?a1:a0)+{28'd0,ni}>=CSTG_WORDS)fail();
     else begin sram_req<=1;sram_we<=0;sram_addr<=cstg_word(21'((cmd==0?a1:second_name?a1:a0)+{28'd0,ni}));begin state<=NAME_CAPTURE;busy_q<=1'b1;end end
    end
    NAME_CAPTURE:if(sram_ack)begin
     logic [7:0] c;
     c=sram_rdata[7:0];if(c>=97&&c<=122)c=c-32;
     sram_req<=0;
     if(c==0)begin
      if(ni==0 && cmd==6)begin launch_name<=0;launch_len<=0;launch_how<=8;launch<=1;begin state<=DONE;busy_q<=1'b0;end end
      else if(ni==0 || stem_len==0 || (had_dot&&ext_len==0))fail();
      else if(cmd==5 && !second_name)begin
       name_len0<=ni;second_name<=1;ni<=0;had_dot<=0;stem_len<=0;ext_len<=0;begin state<=NAME_READ;busy_q<=1'b1;end 
      end else begin
       if(second_name)name_len1<=ni;else name_len0<=ni;
       begin state<=DISPATCH;busy_q<=1'b1;end 
      end
     end else if(ni>=12 || (c==46?(had_dot||stem_len==0):(!legal(c)||(had_dot?ext_len>=3:stem_len>=8))))fail();
     else begin
      if(c==46)had_dot<=1;else if(had_dot)ext_len<=ext_len+1'b1;else stem_len<=stem_len+1'b1;
      if(second_name)begin name1[ni*8+:8]<=c;if(c!=name0[ni*8+:8])names_equal<=0;end
      else name0[ni*8+:8]<=c;
      byte_q<=c;
      if(cmd==0)begin ni<=ni+1'b1;begin state<=NAME_READ;busy_q<=1'b1;end end else begin state<=NAME_STORE;busy_q<=1'b1;end 
     end
    end
    NAME_STORE:begin mem_en<=1;mem_we<=1;mem_addr<=(second_name?16'hb870:16'hb850)+{12'd0,ni};mem_wdata<=byte_q;begin state<=NAME_STORE_WAIT;busy_q<=1'b1;end end
    NAME_STORE_WAIT:if(mem_gnt)begin mem_en<=0;mem_we<=0;ni<=ni+1'b1;begin state<=NAME_READ;busy_q<=1'b1;end end
    DISPATCH:begin
     stor_name_addr<=16'hb850;stor_name_len<={4'd0,name_len0};stor_mode<=73;
     case(cmd)
      0:begin
       document_new_role<=a2[2:0];document_new_name<=name0;document_new_len<=name_len0;
       if(!had_dot)begin
        document_new_name[name_len0*8+:32]<=a2==5?32'h00534a2e:32'h4d54482e;
        document_new_len<=name_len0+(a2==5?4'd3:4'd4);
       end
       document_set_name<=1;begin state<=DOC_COMMIT;busy_q<=1'b1;end 
      end
      2:if(a1[31] || !arena_span_valid(a2,a3))fail();else begin state<=OPEN;busy_q<=1'b1;end 
      3:if(!arena_span_valid(a1,a2))fail();else begin stor_mode<=a3==1?65:79;begin state<=OPEN;busy_q<=1'b1;end end
      4:begin state<=REMOVE;busy_q<=1'b1;end 
      5:if(names_equal && name_len0==name_len1)begin state<=DONE;busy_q<=1'b0;end else begin state<=OPEN;busy_q<=1'b1;end 
      6:if(a1>8)fail();else begin launch_name<=name0;launch_len<=name_len0;launch_how<=a1[3:0];launch<=1;begin state<=DONE;busy_q<=1'b0;end end
      default:fail();
     endcase
    end
    DOC_METADATA:begin
     if(emit_i==20)begin state<=DONE;busy_q<=1'b0;end 
     else begin
      arena_write(21'(a1+{27'd0,emit_i}),emit_i<16?(emit_i<document_name_len?document_name[emit_i*8+:8]:8'd0):emit_i==16?{3'd0,document_name_len}:emit_i==17?{7'd0,document_unnamed}:emit_i==18?{5'd0,document_role}:8'd0,DOC_METADATA);
      emit_i<=emit_i+1'b1;
     end
    end
    DOC_COMMIT:begin state<=DONE;busy_q<=1'b0;end 
    OPEN:if(!stor_busy)begin stor_open<=1;begin state<=OPEN_WAIT;busy_q<=1'b1;end end
    OPEN_WAIT:if(stor_done)begin
     if(stor_err)fail();
     else if(cmd==5)begin
      if(rename_phase==0)begin rename_phase<=1;begin state<=CLOSE;busy_q<=1'b1;end end else begin state<=RENAME;busy_q<=1'b1;end 
     end else if(cmd==3)begin state<=WRITE_BYTE;busy_q<=1'b1;end else begin state<=READ_BYTE;busy_q<=1'b1;end 
    end
    READ_BYTE:if(!stor_busy)begin
     if(transferred>=a3 || pos>=stor_file_size)begin result<=transferred;begin state<=CLOSE;busy_q<=1'b1;end end
     else begin stor_get<=1;begin state<=READ_WAIT;busy_q<=1'b1;end end
    end
    READ_WAIT:if(stor_done)begin
     if(stor_err)begin result<=32'hffffffff;begin state<=CLOSE;busy_q<=1'b1;end end
     else if(stor_eof)begin result<=transferred;begin state<=CLOSE;busy_q<=1'b1;end end
     else begin
      pos<=pos+1'b1;
      if(pos<a1)begin state<=READ_BYTE;busy_q<=1'b1;end 
      else begin arena_write(21'(a2+transferred),stor_byte,READ_BYTE);transferred<=transferred+1'b1;end
     end
    end
    WRITE_BYTE:if(transferred>=a2)begin result<=transferred;begin state<=CLOSE;busy_q<=1'b1;end end
     else begin sram_req<=1;sram_we<=0;sram_addr<=cstg_word(21'(a1+transferred));after_arena<=WRITE_WAIT;begin state<=ARENA_WAIT;busy_q<=1'b1;end end
    WRITE_WAIT:if(!stor_busy)begin stor_put_data<=byte_q;stor_put<=1;begin state<=REMOVE_WAIT;busy_q<=1'b1;end end
    REMOVE_WAIT:if(stor_done)begin
     if(stor_err && !(cmd==4 && stor_missing))begin result<=32'hffffffff;if(cmd==3)begin state<=CLOSE;busy_q<=1'b1;end else begin state<=DONE;busy_q<=1'b0;end end
     else if(cmd==3)begin transferred<=transferred+1'b1;begin state<=WRITE_BYTE;busy_q<=1'b1;end end
     else begin state<=DONE;busy_q<=1'b0;end 
    end
    REMOVE:if(!stor_busy)begin stor_delete<=1;begin state<=REMOVE_WAIT;busy_q<=1'b1;end end
    CLOSE:if(!stor_busy)begin stor_close<=1;begin state<=CLOSE_WAIT;busy_q<=1'b1;end end
    CLOSE_WAIT:if(stor_done)begin
     if(stor_err)fail();
     else if(cmd==5 && rename_phase==1)begin stor_name_addr<=16'hb870;stor_name_len<={4'd0,name_len1};begin state<=RENAME_DELETE;busy_q<=1'b1;end end
     else begin state<=DONE;busy_q<=1'b0;end 
    end
    RENAME_DELETE:if(!stor_busy)begin stor_delete<=1;begin state<=RENAME_DELETE_WAIT;busy_q<=1'b1;end end
    RENAME_DELETE_WAIT:if(stor_done)begin
     if(stor_err && !stor_missing)fail();
     else begin rename_phase<=2;stor_name_addr<=16'hb850;stor_name_len<={4'd0,name_len0};begin state<=OPEN;busy_q<=1'b1;end end
    end
    RENAME:if(!stor_busy)begin stor_name_addr<=16'hb870;stor_name_len<={4'd0,name_len1};begin state<=RENAME_WAIT;busy_q<=1'b1;end end
    RENAME_WAIT:begin
     // name port is registered before asserting the rename strobe.
     if(rename_phase==2)begin stor_rename<=1;rename_phase<=3;end
     else if(stor_done)begin if(stor_err)fail();else begin result<=0;begin state<=CLOSE;busy_q<=1'b1;end end end
    end
    DIR:if(!stor_busy)begin stor_dir<=1;begin state<=DIR_WAIT;busy_q<=1'b1;end end
    DIR_WAIT:if(stor_done)begin if(stor_err)fail();else begin state<=NEXT;busy_q<=1'b1;end end
    NEXT:if(!stor_busy)begin stor_next<=1;begin state<=NEXT_WAIT;busy_q<=1'b1;end end
    NEXT_WAIT:if(stor_done)begin
     if(stor_err)fail();else if(stor_eof)begin state<=END_LIST;busy_q<=1'b1;end 
     else if(catalog_bounded && catalog_seen<a2)begin catalog_seen<=catalog_seen+1'b1;begin state<=NEXT;busy_q<=1'b1;end end
     else if(catalog_bounded ? ({11'd0,ptr}+32'd20>=catalog_end) : (ptr+21'd21>=CSTG_WORDS))begin
      catalog_more<=catalog_bounded;begin state<=END_LIST;busy_q<=1'b1;end 
     end else begin ni<=0;catalog_len<=4'(stor_line_len>12?12:stor_line_len);size_q<=stor_dir_size;date_q<=stor_date;attr_q<=stor_attr;begin state<=CAT_READ;busy_q<=1'b1;end end
    end
    CAT_READ:begin mem_en<=1;mem_we<=0;mem_addr<=16'hbb00+{12'd0,ni};begin state<=CAT_WAIT;busy_q<=1'b1;end end
    CAT_WAIT:if(mem_gnt)begin
     mem_en<=0;catalog_name[ni]<=mem_rdata;
     if(ni+1>=catalog_len)begin emit_i<=0;begin state<=CAT_EMIT;busy_q<=1'b1;end end else begin ni<=ni+1'b1;begin state<=CAT_READ;busy_q<=1'b1;end end
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
     b=0;case(emit_i)0:b=used[7:0];1:b=used[15:8];2:b=used[23:16];3:b=used[31:24];8:b=count[7:0];9:b=count[15:8];10:b={7'd0,catalog_more};
      12,13,14,15:b=8'((a2+{16'd0,count})>>((emit_i-12)*8));default:;endcase
     emit_i<=emit_i+1'b1;
     if(emit_i==(catalog_bounded?15:9))begin result<={16'd0,count};arena_write((catalog_bounded?21'(a0):21'd240)+{16'd0,emit_i},b,DONE);end
     else arena_write((catalog_bounded?21'(a0):21'd240)+{16'd0,emit_i},b,HEADER);
    end
    ARENA_WAIT:if(sram_ack)begin sram_req<=0;sram_we<=0;byte_q<=sram_rdata[7:0];begin state<=ARENA_GAP;busy_q<=1'b1;end end
    ARENA_GAP:begin state<=after_arena;busy_q<=(after_arena!=IDLE && after_arena!=DONE);end 
    DONE:begin reply<=1;if(!req)begin reply<=0;begin state<=IDLE;busy_q<=1'b0;end end end
    default:fail();
   endcase
  end
 end
endmodule
