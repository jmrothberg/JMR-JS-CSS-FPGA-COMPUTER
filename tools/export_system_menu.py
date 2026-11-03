"""Generate the physical/software keyboard mapping and bitmap glyph selectors."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from functional_model.system_menu import KEYS,key_value,SHIP
from functional_model.desktop import FONT
from functional_model.system_window import WINDOW_LABELS
out=['// Generated from functional_model/system_menu.py.','package jmr_system_menu_pkg;']
out+=['function automatic logic [7:0] key_code(input integer i,input logic shifted);begin case(i)']
for i,(_,code,plain,upper) in enumerate(KEYS):
 expr=f'(shifted?8\'d{code+2}:8\'d{code})' if i>=68 else f"8'd{code}"
 out.append(f'{i}:key_code={expr};')
out+=['default:key_code=0;endcase end endfunction']
out+=['function automatic logic [7:0] key_text(input integer i,input logic shifted,caps);begin case(i)']
for i,(_,code,plain,upper) in enumerate(KEYS):
 condition='(shifted^caps)' if 65<=code<=90 else 'shifted'
 out.append(f"{i}:key_text={condition}?8'd{upper}:8'd{plain};")
out+=['default:key_text=0;endcase end endfunction']
# Return {valid, ASCII glyph, x column inside glyph}; one registered font read.
out+=['function automatic logic [11:0] ui_glyph(input integer i,pos,input logic shifted);begin ui_glyph=0;case(i)']
def glyph_expr(text):
 clauses=[];x=0
 for char in text:
  advance=FONT[char]['advance'];clauses.append(f"if(pos>={x} && pos<{x+advance})ui_glyph={{1'b1,7'd{ord(char)},4'(pos-{x})}};");x+=advance
 return ''.join(clauses)
for i,(legend,code,plain,upper) in enumerate(KEYS):
 a=legend;b=legend
 if plain>=32 and plain<127 and not 65<=code<=90 and len(legend)==1:b=chr(upper)
 if i>=68:b='F'+str(code+2-111)
 if a==b:out.append(f'{i}:begin {glyph_expr(a)} end')
 else:out.append(f'{i}:begin if(shifted)begin {glyph_expr(b)} end else begin {glyph_expr(a)} end end')
for i,text in [(70,''),(71,'Quit'),(72,'Keyboard'),(73,'X'),(74,'Hold keys'),(75,'About'),(76,'About Enterprise'),(77,'HTML / JavaScript computer'),(78,'Native mouse and keyboard'),(79,'Memory: 8 MiB'),(80,'OK')]:out.append(f'{i}:begin {glyph_expr(text)} end')
for i,label in WINDOW_LABELS.items():out.append(f'{i}:begin {glyph_expr(label)} end')
out+=['default:;endcase end endfunction']
out+=['function automatic logic [27:0] enterprise_row(input integer row);begin case(row)']
for i,bits in enumerate(SHIP['rows']):out.append(f"{i}:enterprise_row=28'h{bits:07x};")
out+=['default:enterprise_row=0;endcase end endfunction','endpackage']
(ROOT/'rtl/engines/jmr_system_menu_pkg.sv').write_text('\n'.join(out)+'\n')
