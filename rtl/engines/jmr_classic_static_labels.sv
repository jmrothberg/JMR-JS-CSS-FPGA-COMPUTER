// Beam-ordered, read-only system captions. A single half-BRAM ROM supplies
// current/next character records; no parallel character or pixel comparisons.
module jmr_classic_static_labels (
 input logic pixel_clk,rst_n,
 input logic [7:0] label_id,
 input logic signed [11:0] read_pos,
 input logic [9:0] beam_y,
 output logic [11:0] read_glyph
);
 import jmr_classic_ui_pkg::*;
 (* rom_style="block" *) logic [10:0] records [0:1023];
 initial $readmemh("classic_static.hex",records);
 logic [7:0] previous_id;
 logic [9:0] previous_y,row_base,memory_addr;
 logic signed [11:0] previous_pos,pos_q;
 logic [6:0] current_index,current_count,fetch_index;
 logic [10:0] current_record,next_record,memory_data;
 logic [9:0] current_start;
 wire [9:0] current_end=current_start+{6'd0,current_record[10:7]};
 logic current_valid,next_valid;
 logic [1:0] fetch_phase;
 wire [16:0] layout=classic_static_layout(label_id);
 wire new_line=label_id!=previous_id || beam_y!=previous_y || read_pos<previous_pos;
 wire fetched_next=fetch_phase==2 && fetch_index!=0;
 wire available_next=next_valid || fetched_next;
 wire [10:0] available_record=next_valid?next_record:memory_data;
 always_ff @(posedge pixel_clk)memory_data<=records[memory_addr];
 always_ff @(posedge pixel_clk)begin
  if(!rst_n)begin
   previous_id<=0;previous_y<=1023;previous_pos<=0;pos_q<=0;row_base<=0;memory_addr<=0;
   current_index<=0;current_count<=0;fetch_index<=0;current_record<=0;next_record<=0;
   current_valid<=0;next_valid<=0;fetch_phase<=0;current_start<=0;
  end else begin
   previous_id<=label_id;previous_y<=beam_y;previous_pos<=read_pos;pos_q<=read_pos;
   if(new_line)begin
    row_base<=layout[9:0];memory_addr<=layout[9:0];fetch_index<=0;fetch_phase<=1;
    current_index<=0;current_count<=layout[16:10];current_valid<=0;next_valid<=0;current_start<=0;
   end else begin
    if(fetch_phase==1)fetch_phase<=2;
    else if(fetch_phase==2)begin
     fetch_phase<=0;
     if(fetch_index==0)begin
      current_record<=memory_data;current_valid<=current_count!=0;current_index<=0;
      if(current_count>1)begin memory_addr<=row_base+1'b1;fetch_index<=1;fetch_phase<=1;end
     end else begin next_record<=memory_data;next_valid<=1;end
    end
    if(current_valid && read_pos>=0 && read_pos>=12'({2'd0,current_end}) && available_next && current_index+1'b1<current_count)begin
     current_start<=current_end;current_record<=available_record;current_index<=current_index+1'b1;next_valid<=0;
     if(current_index+7'd2<current_count)begin memory_addr<=row_base+10'(current_index)+10'd2;fetch_index<=current_index+7'd2;fetch_phase<=1;end
     else fetch_phase<=0;
    end
   end
  end
 end
 always_comb begin
  logic [10:0] record;
  logic [9:0] start_pos,end_pos;
  record=current_record;start_pos=current_start;
  if(current_valid && pos_q>=0 && pos_q>=12'({2'd0,current_end}) && available_next && current_index+1'b1<current_count)begin
   record=available_record;start_pos=current_end;
  end
  end_pos=start_pos+{6'd0,record[10:7]};
  read_glyph=0;
  if(current_valid && record[6:0]!=0 && pos_q>=0 && pos_q>=12'({2'd0,start_pos}) && pos_q<12'({2'd0,end_pos}))
   read_glyph={1'b1,record[6:0],4'(pos_q-12'({2'd0,start_pos}))};
 end
endmodule
