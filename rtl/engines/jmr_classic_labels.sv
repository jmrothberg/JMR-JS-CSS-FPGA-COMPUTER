// UI records use one block RAM. The beam walks in order;
// the current and next character need pixel-clock registers, not 64 RAM ports.
(* use_dsp="no" *) module jmr_classic_labels(
 input logic clk,rst_n,clear,pixel_clk,
 input logic record_we,
 input logic [5:0] record_row,record_col,
 input logic [26:0] record_data,
 input logic length_we,
 input logic [5:0] length_row,
 input logic [6:0] length_data,
 input logic [5:0] read_row,
 input logic signed [11:0] read_pos,
 input logic [9:0] beam_y,
 output logic [11:0] read_glyph
);
 import jmr_classic_ui_pkg::*;
 function automatic logic [6:0] capacity(input logic [5:0] r);
  if(r>=32 && r<56)capacity=24;
  else if(r>=6 && r<=12)capacity=12;
  else case(r)0,3:capacity=64;1:capacity=16;2:capacity=32;4:capacity=12;default:capacity=0;endcase
 endfunction
 function automatic logic [9:0] base(input logic [5:0] r);
  if(classic_fixed_length(r)!=0)base=classic_fixed_base(r);
  else if(r>=32 && r<56)base=10'd272+10'(r-6'd32)*10'd24;
  else if(r>=6 && r<=12)base=10'd188+10'(r-6'd6)*10'd12;
  else case(r)0:base=0;1:base=64;2:base=80;3:base=112;4:base=176;default:base=0;endcase
 endfunction
 (* ram_style="block" *) logic [26:0] records [0:1023];
 (* ram_style="distributed" *) logic [6:0] lengths [0:63];
 initial $readmemh("classic_records.hex",records);
 logic [63:0] valid_rows;
 logic [9:0] memory_addr;
 logic [26:0] memory_data;
 logic [6:0] length_rdata;
 wire [9:0] write_addr=base(record_row)+{4'd0,record_col};
 always_ff @(posedge clk)if(record_we && {1'b0,record_col}<capacity(record_row))records[write_addr]<=record_data;
 always_ff @(posedge pixel_clk)memory_data<=records[memory_addr];
 always_ff @(posedge clk)if(length_we)lengths[length_row]<=length_data;
 always_ff @(posedge clk)begin
  if(!rst_n || clear)valid_rows<=0;
  else if(length_we)valid_rows[length_row]<=1;
 end
 always_ff @(posedge pixel_clk)length_rdata<=classic_fixed_length(read_row)!=0?classic_fixed_length(read_row):valid_rows[read_row]?lengths[read_row]:7'd0;
 logic [5:0] previous_row;
 logic [9:0] previous_y,row_base;
 logic signed [11:0] previous_pos,pos_q;
 logic [6:0] current_index,current_count,fetch_index;
 logic [26:0] current_record,next_record;
 logic current_valid,next_valid;
 logic [1:0] fetch_phase;
 wire new_line=read_row!=previous_row || beam_y!=previous_y || read_pos<previous_pos;
 wire fetched_next=fetch_phase==2 && fetch_index!=0;
 wire available_next=next_valid || fetched_next;
 wire [26:0] available_record=next_valid?next_record:memory_data;
 always_ff @(posedge pixel_clk)begin
  if(!rst_n)begin
   previous_row<=63;previous_y<=1023;previous_pos<=0;pos_q<=0;row_base<=0;memory_addr<=0;
   current_index<=0;current_count<=0;fetch_index<=0;current_record<=0;next_record<=0;
   current_valid<=0;next_valid<=0;fetch_phase<=0;
  end else begin
   previous_pos<=read_pos;previous_row<=read_row;previous_y<=beam_y;pos_q<=read_pos;
   if(new_line)begin
    row_base<=base(read_row);memory_addr<=base(read_row);fetch_index<=0;fetch_phase<=1;
    current_index<=0;current_count<=0;current_valid<=0;next_valid<=0;
   end else begin
    if(fetch_phase==1)fetch_phase<=2;
    else if(fetch_phase==2)begin
     fetch_phase<=0;
     if(fetch_index==0)begin
      current_record<=memory_data;current_count<=length_rdata;current_valid<=length_rdata!=0;current_index<=0;
      if(length_rdata>1)begin memory_addr<=row_base+1'b1;fetch_index<=1;fetch_phase<=1;end
     end else begin next_record<=memory_data;next_valid<=1;end
    end
    // Read the next word before the previous glyph finishes. Directly using
    // a completing read also supports the font's narrowest two-pixel advance.
    if(current_valid && read_pos>=0 && read_pos>=12'({2'd0,current_record[26:17]}) && available_next && current_index+1'b1<current_count)begin
     current_record<=available_record;current_index<=current_index+1'b1;next_valid<=0;
     if(current_index+7'd2<current_count)begin memory_addr<=row_base+10'(current_index)+10'd2;fetch_index<=current_index+7'd2;fetch_phase<=1;end
     else fetch_phase<=0;
    end
   end
  end
 end
 always_comb begin
  logic [26:0] record;
  logic valid;
  record=current_record;valid=current_valid;
  if(current_valid && pos_q>=0 && pos_q>=12'({2'd0,current_record[26:17]}) && available_next && current_index+1'b1<current_count)record=available_record;
  read_glyph=0;
  if(valid && record[6:0]!=0 && pos_q>=0 && pos_q>=12'({2'd0,record[16:7]}) && pos_q<12'({2'd0,record[26:17]}))
   read_glyph={1'b1,record[6:0],4'(pos_q-12'({2'd0,record[16:7]}))};
 end
endmodule
