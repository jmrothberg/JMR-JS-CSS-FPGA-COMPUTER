"""Generate the physical/software keyboard mapping and bitmap glyph selectors."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from functional_model.system_menu import KEYS,SHIP
from functional_model.desktop import FONT
from functional_model.system_window import WINDOW_LABELS
out=['// Generated from functional_model/system_menu.py.','package jmr_system_menu_pkg;']
# Decode the bounded keyboard grid before the input report register. Balanced
# comparisons avoid division/remainder plus a key lookup in one 100MHz beat.
def grid_column(lo,hi):
 if hi-lo==1:return f"system_key_column=4'd{lo};"
 mid=(lo+hi)//2
 return f"if(x<10'd{12+44*mid})begin {grid_column(lo,mid)} end else begin {grid_column(mid,hi)} end"
out+=['function automatic logic [3:0] system_key_column(input logic [9:0] x);begin '+grid_column(0,14)+' end endfunction']
out+=['''function automatic logic [7:0] system_key_hit(input logic [9:0] x,input logic [8:0] y);
 logic valid_row;logic [6:0] base;
 begin
  valid_row=0;base=0;
  if(y<9'd380)begin
   if(y<9'd347)begin base=0;valid_row=y>=9'd314 && y<9'd343;end
   else begin base=14;valid_row=y<9'd376;end
  end else if(y<9'd446)begin
   if(y<9'd413)begin base=28;valid_row=y<9'd409;end
   else begin base=42;valid_row=y<9'd442;end
  end else begin base=56;valid_row=y<9'd475;end
  system_key_hit={(x>=10'd12 && x<10'd628 && valid_row),7'(base+7'(system_key_column(x)))};
 end
endfunction''']
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
# A grid index is a key, never a window-caption ID. A separate bounded
# selector prevents impossible caption arms from becoming keyboard hardware.
out+=['function automatic logic [11:0] keyboard_glyph(input logic [6:0] i,input logic signed [6:0] pos,input logic shifted);begin keyboard_glyph=0;case(i)']
for i,(legend,code,plain,upper) in enumerate(KEYS):
 a=legend;b=legend
 if plain>=32 and plain<127 and not 65<=code<=90 and len(legend)==1:b=chr(upper)
 if i>=68:b='F'+str(code+2-111)
 a_code=glyph_expr(a).replace('ui_glyph','keyboard_glyph')
 b_code=glyph_expr(b).replace('ui_glyph','keyboard_glyph')
 out.append(f'{i}:begin '+(a_code if a==b else f'if(shifted)begin {b_code} end else begin {a_code} end')+' end')
out+=['default:;endcase end endfunction']
out+=['function automatic logic [11:0] window_glyph(input logic [7:0] i,input logic signed [11:0] pos);begin window_glyph=0;case(i)']
for i,label in WINDOW_LABELS.items():out.append(f'{i}:begin '+glyph_expr(label).replace('ui_glyph','window_glyph')+' end')
out+=['default:;endcase end endfunction']
out+=['function automatic logic [27:0] enterprise_row(input integer row);begin case(row)']
for i,bits in enumerate(SHIP['rows']):out.append(f"{i}:enterprise_row=28'h{bits:07x};")
out+=['default:enterprise_row=0;endcase end endfunction','endpackage']
(ROOT/'rtl/engines/jmr_system_menu_pkg.sv').write_text('\n'.join(out)+'\n')

# A compact label bitmap ROM avoids building a character selector for every
# key at every pixel. Identical labels (including unshifted letters) share data.
key_labels=[];key_label_pairs=[]
for i,(legend,code,plain,upper) in enumerate(KEYS):
    other=legend
    if 32<=plain<127 and not 65<=code<=90 and len(legend)==1:other=chr(upper)
    if i>=68:other='F'+str(code+2-111)
    pair=[]
    for text in (legend,other):
        if text not in key_labels:key_labels.append(text)
        pair.append(key_labels.index(text))
    key_label_pairs.append(pair)
package=ROOT/'rtl/engines/jmr_system_menu_pkg.sv'
source=package.read_text().removesuffix('endpackage\n')
source+='function automatic logic [6:0] key_bitmap_id(input logic [6:0] i,input logic shifted);begin case(i)\n'
for i,(a,b) in enumerate(key_label_pairs):source+=f"{i}:key_bitmap_id=shifted?7'd{b}:7'd{a};\n"
source+='default:key_bitmap_id=0;endcase end endfunction\nendpackage\n';package.write_text(source)
def bitmap_row(text,y,width):
    bits=0;cursor=0
    for c in text:
        g=FONT[c]
        if y<len(g['rows']):
            for col,v in enumerate(g['rows'][y]):
                x=cursor+g['offset']+col
                if v=='1' and 0<=x<width:bits|=1<<(width-1-x)
        cursor+=g['advance']
    return bits
for name,texts,width,depth in [
    ('system_keys',key_labels,40,2048),
    ('system_labels',['Keyboard','X','Hold keys','About','Note','Help','Utility'],64,128),
    ('system_about',['About Enterprise','HTML / JavaScript computer','Native mouse and keyboard','Memory: 8 MiB','OK'],256,128)]:
    words=[bitmap_row(t,y,width) for t in texts for y in range(16)]
    words += [0]*(depth-len(words))
    (ROOT/'vectors'/(name+'.hex')).write_text(''.join(f'{v:0{width//4}x}\n' for v in words))
