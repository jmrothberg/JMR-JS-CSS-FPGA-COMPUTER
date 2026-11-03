// Generated from functional_model/system_menu.py.
package jmr_system_menu_pkg;
function automatic logic [7:0] key_code(input integer i,input logic shifted);begin case(i)
0:key_code=8'd27;
1:key_code=8'd49;
2:key_code=8'd50;
3:key_code=8'd51;
4:key_code=8'd52;
5:key_code=8'd53;
6:key_code=8'd54;
7:key_code=8'd55;
8:key_code=8'd56;
9:key_code=8'd57;
10:key_code=8'd48;
11:key_code=8'd189;
12:key_code=8'd187;
13:key_code=8'd8;
14:key_code=8'd9;
15:key_code=8'd81;
16:key_code=8'd87;
17:key_code=8'd69;
18:key_code=8'd82;
19:key_code=8'd84;
20:key_code=8'd89;
21:key_code=8'd85;
22:key_code=8'd73;
23:key_code=8'd79;
24:key_code=8'd80;
25:key_code=8'd219;
26:key_code=8'd221;
27:key_code=8'd220;
28:key_code=8'd20;
29:key_code=8'd65;
30:key_code=8'd83;
31:key_code=8'd68;
32:key_code=8'd70;
33:key_code=8'd71;
34:key_code=8'd72;
35:key_code=8'd74;
36:key_code=8'd75;
37:key_code=8'd76;
38:key_code=8'd186;
39:key_code=8'd222;
40:key_code=8'd13;
41:key_code=8'd46;
42:key_code=8'd16;
43:key_code=8'd90;
44:key_code=8'd88;
45:key_code=8'd67;
46:key_code=8'd86;
47:key_code=8'd66;
48:key_code=8'd78;
49:key_code=8'd77;
50:key_code=8'd188;
51:key_code=8'd190;
52:key_code=8'd191;
53:key_code=8'd38;
54:key_code=8'd17;
55:key_code=8'd18;
56:key_code=8'd32;
57:key_code=8'd37;
58:key_code=8'd40;
59:key_code=8'd39;
60:key_code=8'd112;
61:key_code=8'd113;
62:key_code=8'd114;
63:key_code=8'd115;
64:key_code=8'd116;
65:key_code=8'd117;
66:key_code=8'd118;
67:key_code=8'd119;
68:key_code=(shifted?8'd122:8'd120);
69:key_code=(shifted?8'd123:8'd121);
default:key_code=0;endcase end endfunction
function automatic logic [7:0] key_text(input integer i,input logic shifted,caps);begin case(i)
0:key_text=shifted?8'd27:8'd27;
1:key_text=shifted?8'd33:8'd49;
2:key_text=shifted?8'd64:8'd50;
3:key_text=shifted?8'd35:8'd51;
4:key_text=shifted?8'd36:8'd52;
5:key_text=shifted?8'd37:8'd53;
6:key_text=shifted?8'd94:8'd54;
7:key_text=shifted?8'd38:8'd55;
8:key_text=shifted?8'd42:8'd56;
9:key_text=shifted?8'd40:8'd57;
10:key_text=shifted?8'd41:8'd48;
11:key_text=shifted?8'd95:8'd45;
12:key_text=shifted?8'd43:8'd61;
13:key_text=shifted?8'd8:8'd8;
14:key_text=shifted?8'd9:8'd9;
15:key_text=(shifted^caps)?8'd81:8'd113;
16:key_text=(shifted^caps)?8'd87:8'd119;
17:key_text=(shifted^caps)?8'd69:8'd101;
18:key_text=(shifted^caps)?8'd82:8'd114;
19:key_text=(shifted^caps)?8'd84:8'd116;
20:key_text=(shifted^caps)?8'd89:8'd121;
21:key_text=(shifted^caps)?8'd85:8'd117;
22:key_text=(shifted^caps)?8'd73:8'd105;
23:key_text=(shifted^caps)?8'd79:8'd111;
24:key_text=(shifted^caps)?8'd80:8'd112;
25:key_text=shifted?8'd123:8'd91;
26:key_text=shifted?8'd125:8'd93;
27:key_text=shifted?8'd124:8'd92;
28:key_text=shifted?8'd0:8'd0;
29:key_text=(shifted^caps)?8'd65:8'd97;
30:key_text=(shifted^caps)?8'd83:8'd115;
31:key_text=(shifted^caps)?8'd68:8'd100;
32:key_text=(shifted^caps)?8'd70:8'd102;
33:key_text=(shifted^caps)?8'd71:8'd103;
34:key_text=(shifted^caps)?8'd72:8'd104;
35:key_text=(shifted^caps)?8'd74:8'd106;
36:key_text=(shifted^caps)?8'd75:8'd107;
37:key_text=(shifted^caps)?8'd76:8'd108;
38:key_text=shifted?8'd58:8'd59;
39:key_text=shifted?8'd34:8'd39;
40:key_text=shifted?8'd13:8'd13;
41:key_text=shifted?8'd127:8'd127;
42:key_text=shifted?8'd0:8'd0;
43:key_text=(shifted^caps)?8'd90:8'd122;
44:key_text=(shifted^caps)?8'd88:8'd120;
45:key_text=(shifted^caps)?8'd67:8'd99;
46:key_text=(shifted^caps)?8'd86:8'd118;
47:key_text=(shifted^caps)?8'd66:8'd98;
48:key_text=(shifted^caps)?8'd78:8'd110;
49:key_text=(shifted^caps)?8'd77:8'd109;
50:key_text=shifted?8'd60:8'd44;
51:key_text=shifted?8'd62:8'd46;
52:key_text=shifted?8'd63:8'd47;
53:key_text=shifted?8'd0:8'd0;
54:key_text=shifted?8'd0:8'd0;
55:key_text=shifted?8'd0:8'd0;
56:key_text=shifted?8'd32:8'd32;
57:key_text=shifted?8'd17:8'd17;
58:key_text=shifted?8'd0:8'd0;
59:key_text=shifted?8'd18:8'd18;
60:key_text=shifted?8'd0:8'd0;
61:key_text=shifted?8'd0:8'd0;
62:key_text=shifted?8'd0:8'd0;
63:key_text=shifted?8'd0:8'd0;
64:key_text=shifted?8'd0:8'd0;
65:key_text=shifted?8'd0:8'd0;
66:key_text=shifted?8'd0:8'd0;
67:key_text=shifted?8'd0:8'd0;
68:key_text=shifted?8'd0:8'd0;
69:key_text=shifted?8'd0:8'd0;
default:key_text=0;endcase end endfunction
function automatic logic [11:0] ui_glyph(input integer i,pos,input logic shifted);begin ui_glyph=0;case(i)
0:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd69,4'(pos-0)};if(pos>=7 && pos<14)ui_glyph={1'b1,7'd115,4'(pos-7)};if(pos>=14 && pos<21)ui_glyph={1'b1,7'd99,4'(pos-14)}; end
1:begin if(shifted)begin if(pos>=0 && pos<6)ui_glyph={1'b1,7'd33,4'(pos-0)}; end else begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd49,4'(pos-0)}; end end
2:begin if(shifted)begin if(pos>=0 && pos<11)ui_glyph={1'b1,7'd64,4'(pos-0)}; end else begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd50,4'(pos-0)}; end end
3:begin if(shifted)begin if(pos>=0 && pos<10)ui_glyph={1'b1,7'd35,4'(pos-0)}; end else begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd51,4'(pos-0)}; end end
4:begin if(shifted)begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd36,4'(pos-0)}; end else begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd52,4'(pos-0)}; end end
5:begin if(shifted)begin if(pos>=0 && pos<11)ui_glyph={1'b1,7'd37,4'(pos-0)}; end else begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd53,4'(pos-0)}; end end
6:begin if(shifted)begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd94,4'(pos-0)}; end else begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd54,4'(pos-0)}; end end
7:begin if(shifted)begin if(pos>=0 && pos<10)ui_glyph={1'b1,7'd38,4'(pos-0)}; end else begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd55,4'(pos-0)}; end end
8:begin if(shifted)begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd42,4'(pos-0)}; end else begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd56,4'(pos-0)}; end end
9:begin if(shifted)begin if(pos>=0 && pos<5)ui_glyph={1'b1,7'd40,4'(pos-0)}; end else begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd57,4'(pos-0)}; end end
10:begin if(shifted)begin if(pos>=0 && pos<5)ui_glyph={1'b1,7'd41,4'(pos-0)}; end else begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd48,4'(pos-0)}; end end
11:begin if(shifted)begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd95,4'(pos-0)}; end else begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd45,4'(pos-0)}; end end
12:begin if(shifted)begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd43,4'(pos-0)}; end else begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd61,4'(pos-0)}; end end
13:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd66,4'(pos-0)};if(pos>=8 && pos<16)ui_glyph={1'b1,7'd97,4'(pos-8)};if(pos>=16 && pos<23)ui_glyph={1'b1,7'd99,4'(pos-16)};if(pos>=23 && pos<31)ui_glyph={1'b1,7'd107,4'(pos-23)}; end
14:begin if(pos>=0 && pos<6)ui_glyph={1'b1,7'd84,4'(pos-0)};if(pos>=6 && pos<14)ui_glyph={1'b1,7'd97,4'(pos-6)};if(pos>=14 && pos<22)ui_glyph={1'b1,7'd98,4'(pos-14)}; end
15:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd81,4'(pos-0)}; end
16:begin if(pos>=0 && pos<12)ui_glyph={1'b1,7'd87,4'(pos-0)}; end
17:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd69,4'(pos-0)}; end
18:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd82,4'(pos-0)}; end
19:begin if(pos>=0 && pos<6)ui_glyph={1'b1,7'd84,4'(pos-0)}; end
20:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd89,4'(pos-0)}; end
21:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd85,4'(pos-0)}; end
22:begin if(pos>=0 && pos<6)ui_glyph={1'b1,7'd73,4'(pos-0)}; end
23:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd79,4'(pos-0)}; end
24:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd80,4'(pos-0)}; end
25:begin if(shifted)begin if(pos>=0 && pos<5)ui_glyph={1'b1,7'd123,4'(pos-0)}; end else begin if(pos>=0 && pos<5)ui_glyph={1'b1,7'd91,4'(pos-0)}; end end
26:begin if(shifted)begin if(pos>=0 && pos<5)ui_glyph={1'b1,7'd125,4'(pos-0)}; end else begin if(pos>=0 && pos<5)ui_glyph={1'b1,7'd93,4'(pos-0)}; end end
27:begin if(shifted)begin if(pos>=0 && pos<5)ui_glyph={1'b1,7'd124,4'(pos-0)}; end else begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd92,4'(pos-0)}; end end
28:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd67,4'(pos-0)};if(pos>=8 && pos<16)ui_glyph={1'b1,7'd97,4'(pos-8)};if(pos>=16 && pos<24)ui_glyph={1'b1,7'd112,4'(pos-16)};if(pos>=24 && pos<31)ui_glyph={1'b1,7'd115,4'(pos-24)}; end
29:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd65,4'(pos-0)}; end
30:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd83,4'(pos-0)}; end
31:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd68,4'(pos-0)}; end
32:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd70,4'(pos-0)}; end
33:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd71,4'(pos-0)}; end
34:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd72,4'(pos-0)}; end
35:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd74,4'(pos-0)}; end
36:begin if(pos>=0 && pos<9)ui_glyph={1'b1,7'd75,4'(pos-0)}; end
37:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd76,4'(pos-0)}; end
38:begin if(shifted)begin if(pos>=0 && pos<4)ui_glyph={1'b1,7'd58,4'(pos-0)}; end else begin if(pos>=0 && pos<4)ui_glyph={1'b1,7'd59,4'(pos-0)}; end end
39:begin if(shifted)begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd34,4'(pos-0)}; end else begin if(pos>=0 && pos<3)ui_glyph={1'b1,7'd39,4'(pos-0)}; end end
40:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd69,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd110,4'(pos-7)};if(pos>=15 && pos<21)ui_glyph={1'b1,7'd116,4'(pos-15)};if(pos>=21 && pos<29)ui_glyph={1'b1,7'd101,4'(pos-21)};if(pos>=29 && pos<35)ui_glyph={1'b1,7'd114,4'(pos-29)}; end
41:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd68,4'(pos-0)};if(pos>=8 && pos<16)ui_glyph={1'b1,7'd101,4'(pos-8)};if(pos>=16 && pos<20)ui_glyph={1'b1,7'd108,4'(pos-16)}; end
42:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd83,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd104,4'(pos-7)};if(pos>=15 && pos<19)ui_glyph={1'b1,7'd105,4'(pos-15)};if(pos>=19 && pos<25)ui_glyph={1'b1,7'd102,4'(pos-19)};if(pos>=25 && pos<31)ui_glyph={1'b1,7'd116,4'(pos-25)}; end
43:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd90,4'(pos-0)}; end
44:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd88,4'(pos-0)}; end
45:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd67,4'(pos-0)}; end
46:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd86,4'(pos-0)}; end
47:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd66,4'(pos-0)}; end
48:begin if(pos>=0 && pos<9)ui_glyph={1'b1,7'd78,4'(pos-0)}; end
49:begin if(pos>=0 && pos<12)ui_glyph={1'b1,7'd77,4'(pos-0)}; end
50:begin if(shifted)begin if(pos>=0 && pos<6)ui_glyph={1'b1,7'd60,4'(pos-0)}; end else begin if(pos>=0 && pos<4)ui_glyph={1'b1,7'd44,4'(pos-0)}; end end
51:begin if(shifted)begin if(pos>=0 && pos<6)ui_glyph={1'b1,7'd62,4'(pos-0)}; end else begin if(pos>=0 && pos<4)ui_glyph={1'b1,7'd46,4'(pos-0)}; end end
52:begin if(shifted)begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd63,4'(pos-0)}; end else begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd47,4'(pos-0)}; end end
53:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd85,4'(pos-0)};if(pos>=8 && pos<16)ui_glyph={1'b1,7'd112,4'(pos-8)}; end
54:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd67,4'(pos-0)};if(pos>=8 && pos<14)ui_glyph={1'b1,7'd116,4'(pos-8)};if(pos>=14 && pos<20)ui_glyph={1'b1,7'd114,4'(pos-14)};if(pos>=20 && pos<24)ui_glyph={1'b1,7'd108,4'(pos-20)}; end
55:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd65,4'(pos-0)};if(pos>=8 && pos<12)ui_glyph={1'b1,7'd108,4'(pos-8)};if(pos>=12 && pos<18)ui_glyph={1'b1,7'd116,4'(pos-12)}; end
56:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd83,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd112,4'(pos-7)};if(pos>=15 && pos<23)ui_glyph={1'b1,7'd97,4'(pos-15)};if(pos>=23 && pos<30)ui_glyph={1'b1,7'd99,4'(pos-23)};if(pos>=30 && pos<38)ui_glyph={1'b1,7'd101,4'(pos-30)}; end
57:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd76,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd101,4'(pos-7)};if(pos>=15 && pos<21)ui_glyph={1'b1,7'd102,4'(pos-15)};if(pos>=21 && pos<27)ui_glyph={1'b1,7'd116,4'(pos-21)}; end
58:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd68,4'(pos-0)};if(pos>=8 && pos<16)ui_glyph={1'b1,7'd111,4'(pos-8)};if(pos>=16 && pos<28)ui_glyph={1'b1,7'd119,4'(pos-16)};if(pos>=28 && pos<36)ui_glyph={1'b1,7'd110,4'(pos-28)}; end
59:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd82,4'(pos-0)};if(pos>=8 && pos<12)ui_glyph={1'b1,7'd105,4'(pos-8)};if(pos>=12 && pos<20)ui_glyph={1'b1,7'd103,4'(pos-12)};if(pos>=20 && pos<28)ui_glyph={1'b1,7'd104,4'(pos-20)};if(pos>=28 && pos<34)ui_glyph={1'b1,7'd116,4'(pos-28)}; end
60:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd70,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd49,4'(pos-7)}; end
61:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd70,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd50,4'(pos-7)}; end
62:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd70,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd51,4'(pos-7)}; end
63:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd70,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd52,4'(pos-7)}; end
64:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd70,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd53,4'(pos-7)}; end
65:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd70,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd54,4'(pos-7)}; end
66:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd70,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd55,4'(pos-7)}; end
67:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd70,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd56,4'(pos-7)}; end
68:begin if(shifted)begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd70,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd49,4'(pos-7)};if(pos>=15 && pos<23)ui_glyph={1'b1,7'd49,4'(pos-15)}; end else begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd70,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd57,4'(pos-7)}; end end
69:begin if(shifted)begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd70,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd49,4'(pos-7)};if(pos>=15 && pos<23)ui_glyph={1'b1,7'd50,4'(pos-15)}; end else begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd70,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd49,4'(pos-7)};if(pos>=15 && pos<23)ui_glyph={1'b1,7'd48,4'(pos-15)}; end end
70:begin  end
71:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd81,4'(pos-0)};if(pos>=8 && pos<16)ui_glyph={1'b1,7'd117,4'(pos-8)};if(pos>=16 && pos<20)ui_glyph={1'b1,7'd105,4'(pos-16)};if(pos>=20 && pos<26)ui_glyph={1'b1,7'd116,4'(pos-20)}; end
72:begin if(pos>=0 && pos<9)ui_glyph={1'b1,7'd75,4'(pos-0)};if(pos>=9 && pos<17)ui_glyph={1'b1,7'd101,4'(pos-9)};if(pos>=17 && pos<25)ui_glyph={1'b1,7'd121,4'(pos-17)};if(pos>=25 && pos<33)ui_glyph={1'b1,7'd98,4'(pos-25)};if(pos>=33 && pos<41)ui_glyph={1'b1,7'd111,4'(pos-33)};if(pos>=41 && pos<49)ui_glyph={1'b1,7'd97,4'(pos-41)};if(pos>=49 && pos<55)ui_glyph={1'b1,7'd114,4'(pos-49)};if(pos>=55 && pos<63)ui_glyph={1'b1,7'd100,4'(pos-55)}; end
73:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd88,4'(pos-0)}; end
74:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd72,4'(pos-0)};if(pos>=8 && pos<16)ui_glyph={1'b1,7'd111,4'(pos-8)};if(pos>=16 && pos<20)ui_glyph={1'b1,7'd108,4'(pos-16)};if(pos>=20 && pos<28)ui_glyph={1'b1,7'd100,4'(pos-20)};if(pos>=28 && pos<32)ui_glyph={1'b1,7'd32,4'(pos-28)};if(pos>=32 && pos<40)ui_glyph={1'b1,7'd107,4'(pos-32)};if(pos>=40 && pos<48)ui_glyph={1'b1,7'd101,4'(pos-40)};if(pos>=48 && pos<56)ui_glyph={1'b1,7'd121,4'(pos-48)};if(pos>=56 && pos<63)ui_glyph={1'b1,7'd115,4'(pos-56)}; end
75:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd65,4'(pos-0)};if(pos>=8 && pos<16)ui_glyph={1'b1,7'd98,4'(pos-8)};if(pos>=16 && pos<24)ui_glyph={1'b1,7'd111,4'(pos-16)};if(pos>=24 && pos<32)ui_glyph={1'b1,7'd117,4'(pos-24)};if(pos>=32 && pos<38)ui_glyph={1'b1,7'd116,4'(pos-32)}; end
76:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd65,4'(pos-0)};if(pos>=8 && pos<16)ui_glyph={1'b1,7'd98,4'(pos-8)};if(pos>=16 && pos<24)ui_glyph={1'b1,7'd111,4'(pos-16)};if(pos>=24 && pos<32)ui_glyph={1'b1,7'd117,4'(pos-24)};if(pos>=32 && pos<38)ui_glyph={1'b1,7'd116,4'(pos-32)};if(pos>=38 && pos<42)ui_glyph={1'b1,7'd32,4'(pos-38)};if(pos>=42 && pos<49)ui_glyph={1'b1,7'd69,4'(pos-42)};if(pos>=49 && pos<57)ui_glyph={1'b1,7'd110,4'(pos-49)};if(pos>=57 && pos<63)ui_glyph={1'b1,7'd116,4'(pos-57)};if(pos>=63 && pos<71)ui_glyph={1'b1,7'd101,4'(pos-63)};if(pos>=71 && pos<77)ui_glyph={1'b1,7'd114,4'(pos-71)};if(pos>=77 && pos<85)ui_glyph={1'b1,7'd112,4'(pos-77)};if(pos>=85 && pos<91)ui_glyph={1'b1,7'd114,4'(pos-85)};if(pos>=91 && pos<95)ui_glyph={1'b1,7'd105,4'(pos-91)};if(pos>=95 && pos<102)ui_glyph={1'b1,7'd115,4'(pos-95)};if(pos>=102 && pos<110)ui_glyph={1'b1,7'd101,4'(pos-102)}; end
77:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd72,4'(pos-0)};if(pos>=8 && pos<14)ui_glyph={1'b1,7'd84,4'(pos-8)};if(pos>=14 && pos<26)ui_glyph={1'b1,7'd77,4'(pos-14)};if(pos>=26 && pos<33)ui_glyph={1'b1,7'd76,4'(pos-26)};if(pos>=33 && pos<37)ui_glyph={1'b1,7'd32,4'(pos-33)};if(pos>=37 && pos<44)ui_glyph={1'b1,7'd47,4'(pos-37)};if(pos>=44 && pos<48)ui_glyph={1'b1,7'd32,4'(pos-44)};if(pos>=48 && pos<55)ui_glyph={1'b1,7'd74,4'(pos-48)};if(pos>=55 && pos<63)ui_glyph={1'b1,7'd97,4'(pos-55)};if(pos>=63 && pos<71)ui_glyph={1'b1,7'd118,4'(pos-63)};if(pos>=71 && pos<79)ui_glyph={1'b1,7'd97,4'(pos-71)};if(pos>=79 && pos<86)ui_glyph={1'b1,7'd83,4'(pos-79)};if(pos>=86 && pos<93)ui_glyph={1'b1,7'd99,4'(pos-86)};if(pos>=93 && pos<99)ui_glyph={1'b1,7'd114,4'(pos-93)};if(pos>=99 && pos<103)ui_glyph={1'b1,7'd105,4'(pos-99)};if(pos>=103 && pos<111)ui_glyph={1'b1,7'd112,4'(pos-103)};if(pos>=111 && pos<117)ui_glyph={1'b1,7'd116,4'(pos-111)};if(pos>=117 && pos<121)ui_glyph={1'b1,7'd32,4'(pos-117)};if(pos>=121 && pos<128)ui_glyph={1'b1,7'd99,4'(pos-121)};if(pos>=128 && pos<136)ui_glyph={1'b1,7'd111,4'(pos-128)};if(pos>=136 && pos<148)ui_glyph={1'b1,7'd109,4'(pos-136)};if(pos>=148 && pos<156)ui_glyph={1'b1,7'd112,4'(pos-148)};if(pos>=156 && pos<164)ui_glyph={1'b1,7'd117,4'(pos-156)};if(pos>=164 && pos<170)ui_glyph={1'b1,7'd116,4'(pos-164)};if(pos>=170 && pos<178)ui_glyph={1'b1,7'd101,4'(pos-170)};if(pos>=178 && pos<184)ui_glyph={1'b1,7'd114,4'(pos-178)}; end
78:begin if(pos>=0 && pos<9)ui_glyph={1'b1,7'd78,4'(pos-0)};if(pos>=9 && pos<17)ui_glyph={1'b1,7'd97,4'(pos-9)};if(pos>=17 && pos<23)ui_glyph={1'b1,7'd116,4'(pos-17)};if(pos>=23 && pos<27)ui_glyph={1'b1,7'd105,4'(pos-23)};if(pos>=27 && pos<35)ui_glyph={1'b1,7'd118,4'(pos-27)};if(pos>=35 && pos<43)ui_glyph={1'b1,7'd101,4'(pos-35)};if(pos>=43 && pos<47)ui_glyph={1'b1,7'd32,4'(pos-43)};if(pos>=47 && pos<59)ui_glyph={1'b1,7'd109,4'(pos-47)};if(pos>=59 && pos<67)ui_glyph={1'b1,7'd111,4'(pos-59)};if(pos>=67 && pos<75)ui_glyph={1'b1,7'd117,4'(pos-67)};if(pos>=75 && pos<82)ui_glyph={1'b1,7'd115,4'(pos-75)};if(pos>=82 && pos<90)ui_glyph={1'b1,7'd101,4'(pos-82)};if(pos>=90 && pos<94)ui_glyph={1'b1,7'd32,4'(pos-90)};if(pos>=94 && pos<102)ui_glyph={1'b1,7'd97,4'(pos-94)};if(pos>=102 && pos<110)ui_glyph={1'b1,7'd110,4'(pos-102)};if(pos>=110 && pos<118)ui_glyph={1'b1,7'd100,4'(pos-110)};if(pos>=118 && pos<122)ui_glyph={1'b1,7'd32,4'(pos-118)};if(pos>=122 && pos<130)ui_glyph={1'b1,7'd107,4'(pos-122)};if(pos>=130 && pos<138)ui_glyph={1'b1,7'd101,4'(pos-130)};if(pos>=138 && pos<146)ui_glyph={1'b1,7'd121,4'(pos-138)};if(pos>=146 && pos<154)ui_glyph={1'b1,7'd98,4'(pos-146)};if(pos>=154 && pos<162)ui_glyph={1'b1,7'd111,4'(pos-154)};if(pos>=162 && pos<170)ui_glyph={1'b1,7'd97,4'(pos-162)};if(pos>=170 && pos<176)ui_glyph={1'b1,7'd114,4'(pos-170)};if(pos>=176 && pos<184)ui_glyph={1'b1,7'd100,4'(pos-176)}; end
79:begin if(pos>=0 && pos<12)ui_glyph={1'b1,7'd77,4'(pos-0)};if(pos>=12 && pos<20)ui_glyph={1'b1,7'd101,4'(pos-12)};if(pos>=20 && pos<32)ui_glyph={1'b1,7'd109,4'(pos-20)};if(pos>=32 && pos<40)ui_glyph={1'b1,7'd111,4'(pos-32)};if(pos>=40 && pos<46)ui_glyph={1'b1,7'd114,4'(pos-40)};if(pos>=46 && pos<54)ui_glyph={1'b1,7'd121,4'(pos-46)};if(pos>=54 && pos<58)ui_glyph={1'b1,7'd58,4'(pos-54)};if(pos>=58 && pos<62)ui_glyph={1'b1,7'd32,4'(pos-58)};if(pos>=62 && pos<70)ui_glyph={1'b1,7'd56,4'(pos-62)};if(pos>=70 && pos<74)ui_glyph={1'b1,7'd32,4'(pos-70)};if(pos>=74 && pos<86)ui_glyph={1'b1,7'd77,4'(pos-74)};if(pos>=86 && pos<90)ui_glyph={1'b1,7'd105,4'(pos-86)};if(pos>=90 && pos<98)ui_glyph={1'b1,7'd66,4'(pos-90)}; end
80:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd79,4'(pos-0)};if(pos>=8 && pos<17)ui_glyph={1'b1,7'd75,4'(pos-8)}; end
81:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd69,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd100,4'(pos-7)};if(pos>=15 && pos<19)ui_glyph={1'b1,7'd105,4'(pos-15)};if(pos>=19 && pos<25)ui_glyph={1'b1,7'd116,4'(pos-19)};if(pos>=25 && pos<33)ui_glyph={1'b1,7'd111,4'(pos-25)};if(pos>=33 && pos<39)ui_glyph={1'b1,7'd114,4'(pos-33)}; end
82:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd82,4'(pos-0)};if(pos>=8 && pos<16)ui_glyph={1'b1,7'd101,4'(pos-8)};if(pos>=16 && pos<24)ui_glyph={1'b1,7'd97,4'(pos-16)};if(pos>=24 && pos<32)ui_glyph={1'b1,7'd100,4'(pos-24)};if(pos>=32 && pos<40)ui_glyph={1'b1,7'd101,4'(pos-32)};if(pos>=40 && pos<46)ui_glyph={1'b1,7'd114,4'(pos-40)}; end
83:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd67,4'(pos-0)};if(pos>=8 && pos<16)ui_glyph={1'b1,7'd111,4'(pos-8)};if(pos>=16 && pos<28)ui_glyph={1'b1,7'd109,4'(pos-16)};if(pos>=28 && pos<36)ui_glyph={1'b1,7'd112,4'(pos-28)};if(pos>=36 && pos<40)ui_glyph={1'b1,7'd105,4'(pos-36)};if(pos>=40 && pos<44)ui_glyph={1'b1,7'd108,4'(pos-40)};if(pos>=44 && pos<52)ui_glyph={1'b1,7'd101,4'(pos-44)};if(pos>=52 && pos<58)ui_glyph={1'b1,7'd114,4'(pos-52)}; end
84:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd85,4'(pos-0)};if(pos>=8 && pos<14)ui_glyph={1'b1,7'd116,4'(pos-8)};if(pos>=14 && pos<18)ui_glyph={1'b1,7'd105,4'(pos-14)};if(pos>=18 && pos<22)ui_glyph={1'b1,7'd108,4'(pos-18)};if(pos>=22 && pos<26)ui_glyph={1'b1,7'd105,4'(pos-22)};if(pos>=26 && pos<32)ui_glyph={1'b1,7'd116,4'(pos-26)};if(pos>=32 && pos<40)ui_glyph={1'b1,7'd121,4'(pos-32)}; end
85:begin if(pos>=0 && pos<9)ui_glyph={1'b1,7'd78,4'(pos-0)};if(pos>=9 && pos<17)ui_glyph={1'b1,7'd111,4'(pos-9)};if(pos>=17 && pos<23)ui_glyph={1'b1,7'd116,4'(pos-17)};if(pos>=23 && pos<31)ui_glyph={1'b1,7'd101,4'(pos-23)}; end
86:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd83,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd121,4'(pos-7)};if(pos>=15 && pos<22)ui_glyph={1'b1,7'd115,4'(pos-15)};if(pos>=22 && pos<28)ui_glyph={1'b1,7'd116,4'(pos-22)};if(pos>=28 && pos<36)ui_glyph={1'b1,7'd101,4'(pos-28)};if(pos>=36 && pos<48)ui_glyph={1'b1,7'd109,4'(pos-36)};if(pos>=48 && pos<52)ui_glyph={1'b1,7'd32,4'(pos-48)};if(pos>=52 && pos<58)ui_glyph={1'b1,7'd84,4'(pos-52)};if(pos>=58 && pos<66)ui_glyph={1'b1,7'd111,4'(pos-58)};if(pos>=66 && pos<74)ui_glyph={1'b1,7'd111,4'(pos-66)};if(pos>=74 && pos<78)ui_glyph={1'b1,7'd108,4'(pos-74)}; end
87:begin if(pos>=0 && pos<6)ui_glyph={1'b1,7'd84,4'(pos-0)};if(pos>=6 && pos<14)ui_glyph={1'b1,7'd101,4'(pos-6)};if(pos>=14 && pos<20)ui_glyph={1'b1,7'd114,4'(pos-14)};if(pos>=20 && pos<32)ui_glyph={1'b1,7'd109,4'(pos-20)};if(pos>=32 && pos<36)ui_glyph={1'b1,7'd105,4'(pos-32)};if(pos>=36 && pos<44)ui_glyph={1'b1,7'd110,4'(pos-36)};if(pos>=44 && pos<52)ui_glyph={1'b1,7'd97,4'(pos-44)};if(pos>=52 && pos<56)ui_glyph={1'b1,7'd108,4'(pos-52)}; end
88:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd83,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd97,4'(pos-7)};if(pos>=15 && pos<23)ui_glyph={1'b1,7'd118,4'(pos-15)};if(pos>=23 && pos<31)ui_glyph={1'b1,7'd101,4'(pos-23)}; end
89:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd67,4'(pos-0)};if(pos>=8 && pos<12)ui_glyph={1'b1,7'd108,4'(pos-8)};if(pos>=12 && pos<16)ui_glyph={1'b1,7'd105,4'(pos-12)};if(pos>=16 && pos<23)ui_glyph={1'b1,7'd99,4'(pos-16)};if(pos>=23 && pos<31)ui_glyph={1'b1,7'd107,4'(pos-23)};if(pos>=31 && pos<35)ui_glyph={1'b1,7'd32,4'(pos-31)};if(pos>=35 && pos<41)ui_glyph={1'b1,7'd116,4'(pos-35)};if(pos>=41 && pos<49)ui_glyph={1'b1,7'd111,4'(pos-41)};if(pos>=49 && pos<53)ui_glyph={1'b1,7'd32,4'(pos-49)};if(pos>=53 && pos<61)ui_glyph={1'b1,7'd112,4'(pos-53)};if(pos>=61 && pos<65)ui_glyph={1'b1,7'd108,4'(pos-61)};if(pos>=65 && pos<73)ui_glyph={1'b1,7'd97,4'(pos-65)};if(pos>=73 && pos<80)ui_glyph={1'b1,7'd99,4'(pos-73)};if(pos>=80 && pos<88)ui_glyph={1'b1,7'd101,4'(pos-80)};if(pos>=88 && pos<92)ui_glyph={1'b1,7'd32,4'(pos-88)};if(pos>=92 && pos<99)ui_glyph={1'b1,7'd99,4'(pos-92)};if(pos>=99 && pos<107)ui_glyph={1'b1,7'd117,4'(pos-99)};if(pos>=107 && pos<113)ui_glyph={1'b1,7'd114,4'(pos-107)};if(pos>=113 && pos<120)ui_glyph={1'b1,7'd115,4'(pos-113)};if(pos>=120 && pos<128)ui_glyph={1'b1,7'd111,4'(pos-120)};if(pos>=128 && pos<134)ui_glyph={1'b1,7'd114,4'(pos-128)}; end
90:begin if(pos>=0 && pos<12)ui_glyph={1'b1,7'd77,4'(pos-0)};if(pos>=12 && pos<20)ui_glyph={1'b1,7'd111,4'(pos-12)};if(pos>=20 && pos<28)ui_glyph={1'b1,7'd100,4'(pos-20)};if(pos>=28 && pos<32)ui_glyph={1'b1,7'd105,4'(pos-28)};if(pos>=32 && pos<38)ui_glyph={1'b1,7'd102,4'(pos-32)};if(pos>=38 && pos<42)ui_glyph={1'b1,7'd105,4'(pos-38)};if(pos>=42 && pos<50)ui_glyph={1'b1,7'd101,4'(pos-42)};if(pos>=50 && pos<58)ui_glyph={1'b1,7'd100,4'(pos-50)}; end
91:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd67,4'(pos-0)};if(pos>=8 && pos<12)ui_glyph={1'b1,7'd108,4'(pos-8)};if(pos>=12 && pos<16)ui_glyph={1'b1,7'd105,4'(pos-12)};if(pos>=16 && pos<23)ui_glyph={1'b1,7'd99,4'(pos-16)};if(pos>=23 && pos<31)ui_glyph={1'b1,7'd107,4'(pos-23)};if(pos>=31 && pos<35)ui_glyph={1'b1,7'd32,4'(pos-31)};if(pos>=35 && pos<43)ui_glyph={1'b1,7'd112,4'(pos-35)};if(pos>=43 && pos<51)ui_glyph={1'b1,7'd97,4'(pos-43)};if(pos>=51 && pos<59)ui_glyph={1'b1,7'd103,4'(pos-51)};if(pos>=59 && pos<67)ui_glyph={1'b1,7'd101,4'(pos-59)};if(pos>=67 && pos<71)ui_glyph={1'b1,7'd32,4'(pos-67)};if(pos>=71 && pos<79)ui_glyph={1'b1,7'd111,4'(pos-71)};if(pos>=79 && pos<85)ui_glyph={1'b1,7'd114,4'(pos-79)};if(pos>=85 && pos<89)ui_glyph={1'b1,7'd32,4'(pos-85)};if(pos>=89 && pos<97)ui_glyph={1'b1,7'd97,4'(pos-89)};if(pos>=97 && pos<103)ui_glyph={1'b1,7'd114,4'(pos-97)};if(pos>=103 && pos<109)ui_glyph={1'b1,7'd114,4'(pos-103)};if(pos>=109 && pos<117)ui_glyph={1'b1,7'd111,4'(pos-109)};if(pos>=117 && pos<129)ui_glyph={1'b1,7'd119,4'(pos-117)};if(pos>=129 && pos<136)ui_glyph={1'b1,7'd115,4'(pos-129)};if(pos>=136 && pos<140)ui_glyph={1'b1,7'd32,4'(pos-136)};if(pos>=140 && pos<146)ui_glyph={1'b1,7'd116,4'(pos-140)};if(pos>=146 && pos<154)ui_glyph={1'b1,7'd111,4'(pos-146)};if(pos>=154 && pos<158)ui_glyph={1'b1,7'd32,4'(pos-154)};if(pos>=158 && pos<165)ui_glyph={1'b1,7'd115,4'(pos-158)};if(pos>=165 && pos<172)ui_glyph={1'b1,7'd99,4'(pos-165)};if(pos>=172 && pos<178)ui_glyph={1'b1,7'd114,4'(pos-172)};if(pos>=178 && pos<186)ui_glyph={1'b1,7'd111,4'(pos-178)};if(pos>=186 && pos<190)ui_glyph={1'b1,7'd108,4'(pos-186)};if(pos>=190 && pos<194)ui_glyph={1'b1,7'd108,4'(pos-190)}; end
92:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd82,4'(pos-0)};if(pos>=8 && pos<16)ui_glyph={1'b1,7'd101,4'(pos-8)};if(pos>=16 && pos<24)ui_glyph={1'b1,7'd97,4'(pos-16)};if(pos>=24 && pos<32)ui_glyph={1'b1,7'd100,4'(pos-24)};if(pos>=32 && pos<36)ui_glyph={1'b1,7'd105,4'(pos-32)};if(pos>=36 && pos<44)ui_glyph={1'b1,7'd110,4'(pos-36)};if(pos>=44 && pos<52)ui_glyph={1'b1,7'd103,4'(pos-44)};if(pos>=52 && pos<56)ui_glyph={1'b1,7'd32,4'(pos-52)};if(pos>=56 && pos<63)ui_glyph={1'b1,7'd115,4'(pos-56)};if(pos>=63 && pos<71)ui_glyph={1'b1,7'd111,4'(pos-63)};if(pos>=71 && pos<79)ui_glyph={1'b1,7'd117,4'(pos-71)};if(pos>=79 && pos<85)ui_glyph={1'b1,7'd114,4'(pos-79)};if(pos>=85 && pos<92)ui_glyph={1'b1,7'd99,4'(pos-85)};if(pos>=92 && pos<100)ui_glyph={1'b1,7'd101,4'(pos-92)};if(pos>=100 && pos<104)ui_glyph={1'b1,7'd32,4'(pos-100)};if(pos>=104 && pos<111)ui_glyph={1'b1,7'd47,4'(pos-104)};if(pos>=111 && pos<115)ui_glyph={1'b1,7'd32,4'(pos-111)};if(pos>=115 && pos<123)ui_glyph={1'b1,7'd97,4'(pos-115)};if(pos>=123 && pos<129)ui_glyph={1'b1,7'd114,4'(pos-123)};if(pos>=129 && pos<135)ui_glyph={1'b1,7'd116,4'(pos-129)};if(pos>=135 && pos<147)ui_glyph={1'b1,7'd119,4'(pos-135)};if(pos>=147 && pos<155)ui_glyph={1'b1,7'd111,4'(pos-147)};if(pos>=155 && pos<161)ui_glyph={1'b1,7'd114,4'(pos-155)};if(pos>=161 && pos<169)ui_glyph={1'b1,7'd107,4'(pos-161)}; end
93:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd67,4'(pos-0)};if(pos>=8 && pos<16)ui_glyph={1'b1,7'd111,4'(pos-8)};if(pos>=16 && pos<28)ui_glyph={1'b1,7'd109,4'(pos-16)};if(pos>=28 && pos<36)ui_glyph={1'b1,7'd112,4'(pos-28)};if(pos>=36 && pos<40)ui_glyph={1'b1,7'd105,4'(pos-36)};if(pos>=40 && pos<44)ui_glyph={1'b1,7'd108,4'(pos-40)};if(pos>=44 && pos<48)ui_glyph={1'b1,7'd105,4'(pos-44)};if(pos>=48 && pos<56)ui_glyph={1'b1,7'd110,4'(pos-48)};if(pos>=56 && pos<64)ui_glyph={1'b1,7'd103,4'(pos-56)}; end
94:begin if(pos>=0 && pos<12)ui_glyph={1'b1,7'd87,4'(pos-0)};if(pos>=12 && pos<18)ui_glyph={1'b1,7'd114,4'(pos-12)};if(pos>=18 && pos<22)ui_glyph={1'b1,7'd105,4'(pos-18)};if(pos>=22 && pos<28)ui_glyph={1'b1,7'd116,4'(pos-22)};if(pos>=28 && pos<32)ui_glyph={1'b1,7'd105,4'(pos-28)};if(pos>=32 && pos<40)ui_glyph={1'b1,7'd110,4'(pos-32)};if(pos>=40 && pos<48)ui_glyph={1'b1,7'd103,4'(pos-40)};if(pos>=48 && pos<52)ui_glyph={1'b1,7'd32,4'(pos-48)};if(pos>=52 && pos<60)ui_glyph={1'b1,7'd112,4'(pos-52)};if(pos>=60 && pos<66)ui_glyph={1'b1,7'd114,4'(pos-60)};if(pos>=66 && pos<74)ui_glyph={1'b1,7'd111,4'(pos-66)};if(pos>=74 && pos<82)ui_glyph={1'b1,7'd103,4'(pos-74)};if(pos>=82 && pos<88)ui_glyph={1'b1,7'd114,4'(pos-82)};if(pos>=88 && pos<96)ui_glyph={1'b1,7'd97,4'(pos-88)};if(pos>=96 && pos<108)ui_glyph={1'b1,7'd109,4'(pos-96)}; end
95:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd70,4'(pos-0)};if(pos>=7 && pos<11)ui_glyph={1'b1,7'd105,4'(pos-7)};if(pos>=11 && pos<15)ui_glyph={1'b1,7'd108,4'(pos-11)};if(pos>=15 && pos<23)ui_glyph={1'b1,7'd101,4'(pos-15)};if(pos>=23 && pos<30)ui_glyph={1'b1,7'd115,4'(pos-23)};if(pos>=30 && pos<34)ui_glyph={1'b1,7'd32,4'(pos-30)};if(pos>=34 && pos<42)ui_glyph={1'b1,7'd111,4'(pos-34)};if(pos>=42 && pos<50)ui_glyph={1'b1,7'd110,4'(pos-42)};if(pos>=50 && pos<54)ui_glyph={1'b1,7'd32,4'(pos-50)};if(pos>=54 && pos<62)ui_glyph={1'b1,7'd100,4'(pos-54)};if(pos>=62 && pos<66)ui_glyph={1'b1,7'd105,4'(pos-62)};if(pos>=66 && pos<73)ui_glyph={1'b1,7'd115,4'(pos-66)};if(pos>=73 && pos<81)ui_glyph={1'b1,7'd107,4'(pos-73)}; end
96:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd83,4'(pos-0)};if(pos>=7 && pos<15)ui_glyph={1'b1,7'd121,4'(pos-7)};if(pos>=15 && pos<22)ui_glyph={1'b1,7'd115,4'(pos-15)};if(pos>=22 && pos<28)ui_glyph={1'b1,7'd116,4'(pos-22)};if(pos>=28 && pos<36)ui_glyph={1'b1,7'd101,4'(pos-28)};if(pos>=36 && pos<48)ui_glyph={1'b1,7'd109,4'(pos-36)};if(pos>=48 && pos<52)ui_glyph={1'b1,7'd32,4'(pos-48)};if(pos>=52 && pos<60)ui_glyph={1'b1,7'd97,4'(pos-52)};if(pos>=60 && pos<68)ui_glyph={1'b1,7'd112,4'(pos-60)};if(pos>=68 && pos<76)ui_glyph={1'b1,7'd112,4'(pos-68)};if(pos>=76 && pos<80)ui_glyph={1'b1,7'd108,4'(pos-76)};if(pos>=80 && pos<84)ui_glyph={1'b1,7'd105,4'(pos-80)};if(pos>=84 && pos<91)ui_glyph={1'b1,7'd99,4'(pos-84)};if(pos>=91 && pos<99)ui_glyph={1'b1,7'd97,4'(pos-91)};if(pos>=99 && pos<105)ui_glyph={1'b1,7'd116,4'(pos-99)};if(pos>=105 && pos<109)ui_glyph={1'b1,7'd105,4'(pos-105)};if(pos>=109 && pos<117)ui_glyph={1'b1,7'd111,4'(pos-109)};if(pos>=117 && pos<125)ui_glyph={1'b1,7'd110,4'(pos-117)}; end
97:begin if(pos>=0 && pos<6)ui_glyph={1'b1,7'd84,4'(pos-0)};if(pos>=6 && pos<14)ui_glyph={1'b1,7'd121,4'(pos-6)};if(pos>=14 && pos<22)ui_glyph={1'b1,7'd112,4'(pos-14)};if(pos>=22 && pos<30)ui_glyph={1'b1,7'd101,4'(pos-22)};if(pos>=30 && pos<34)ui_glyph={1'b1,7'd32,4'(pos-30)};if(pos>=34 && pos<42)ui_glyph={1'b1,7'd97,4'(pos-34)};if(pos>=42 && pos<46)ui_glyph={1'b1,7'd32,4'(pos-42)};if(pos>=46 && pos<53)ui_glyph={1'b1,7'd99,4'(pos-46)};if(pos>=53 && pos<61)ui_glyph={1'b1,7'd111,4'(pos-53)};if(pos>=61 && pos<73)ui_glyph={1'b1,7'd109,4'(pos-61)};if(pos>=73 && pos<85)ui_glyph={1'b1,7'd109,4'(pos-73)};if(pos>=85 && pos<93)ui_glyph={1'b1,7'd97,4'(pos-85)};if(pos>=93 && pos<101)ui_glyph={1'b1,7'd110,4'(pos-93)};if(pos>=101 && pos<109)ui_glyph={1'b1,7'd100,4'(pos-101)}; end
98:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd94,4'(pos-0)}; end
99:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd118,4'(pos-0)}; end
100:begin if(pos>=0 && pos<6)ui_glyph={1'b1,7'd60,4'(pos-0)}; end
101:begin if(pos>=0 && pos<6)ui_glyph={1'b1,7'd62,4'(pos-0)}; end
102:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd67,4'(pos-0)};if(pos>=8 && pos<12)ui_glyph={1'b1,7'd108,4'(pos-8)};if(pos>=12 && pos<20)ui_glyph={1'b1,7'd111,4'(pos-12)};if(pos>=20 && pos<27)ui_glyph={1'b1,7'd115,4'(pos-20)};if(pos>=27 && pos<35)ui_glyph={1'b1,7'd101,4'(pos-27)};if(pos>=35 && pos<39)ui_glyph={1'b1,7'd32,4'(pos-35)};if(pos>=39 && pos<51)ui_glyph={1'b1,7'd119,4'(pos-39)};if(pos>=51 && pos<55)ui_glyph={1'b1,7'd105,4'(pos-51)};if(pos>=55 && pos<63)ui_glyph={1'b1,7'd110,4'(pos-55)};if(pos>=63 && pos<71)ui_glyph={1'b1,7'd100,4'(pos-63)};if(pos>=71 && pos<79)ui_glyph={1'b1,7'd111,4'(pos-71)};if(pos>=79 && pos<91)ui_glyph={1'b1,7'd119,4'(pos-79)};if(pos>=91 && pos<95)ui_glyph={1'b1,7'd32,4'(pos-91)};if(pos>=95 && pos<101)ui_glyph={1'b1,7'd116,4'(pos-95)};if(pos>=101 && pos<109)ui_glyph={1'b1,7'd111,4'(pos-101)};if(pos>=109 && pos<113)ui_glyph={1'b1,7'd32,4'(pos-109)};if(pos>=113 && pos<119)ui_glyph={1'b1,7'd114,4'(pos-113)};if(pos>=119 && pos<127)ui_glyph={1'b1,7'd101,4'(pos-119)};if(pos>=127 && pos<133)ui_glyph={1'b1,7'd116,4'(pos-127)};if(pos>=133 && pos<141)ui_glyph={1'b1,7'd117,4'(pos-133)};if(pos>=141 && pos<147)ui_glyph={1'b1,7'd114,4'(pos-141)};if(pos>=147 && pos<155)ui_glyph={1'b1,7'd110,4'(pos-147)}; end
103:begin if(pos>=0 && pos<8)ui_glyph={1'b1,7'd68,4'(pos-0)};if(pos>=8 && pos<16)ui_glyph={1'b1,7'd101,4'(pos-8)};if(pos>=16 && pos<23)ui_glyph={1'b1,7'd99,4'(pos-16)};if(pos>=23 && pos<31)ui_glyph={1'b1,7'd111,4'(pos-23)};if(pos>=31 && pos<39)ui_glyph={1'b1,7'd100,4'(pos-31)};if(pos>=39 && pos<43)ui_glyph={1'b1,7'd105,4'(pos-39)};if(pos>=43 && pos<51)ui_glyph={1'b1,7'd110,4'(pos-43)};if(pos>=51 && pos<59)ui_glyph={1'b1,7'd103,4'(pos-51)};if(pos>=59 && pos<63)ui_glyph={1'b1,7'd32,4'(pos-59)};if(pos>=63 && pos<71)ui_glyph={1'b1,7'd97,4'(pos-63)};if(pos>=71 && pos<77)ui_glyph={1'b1,7'd114,4'(pos-71)};if(pos>=77 && pos<83)ui_glyph={1'b1,7'd116,4'(pos-77)};if(pos>=83 && pos<95)ui_glyph={1'b1,7'd119,4'(pos-83)};if(pos>=95 && pos<103)ui_glyph={1'b1,7'd111,4'(pos-95)};if(pos>=103 && pos<109)ui_glyph={1'b1,7'd114,4'(pos-103)};if(pos>=109 && pos<117)ui_glyph={1'b1,7'd107,4'(pos-109)}; end
104:begin if(pos>=0 && pos<7)ui_glyph={1'b1,7'd76,4'(pos-0)};if(pos>=7 && pos<11)ui_glyph={1'b1,7'd105,4'(pos-7)};if(pos>=11 && pos<19)ui_glyph={1'b1,7'd110,4'(pos-11)};if(pos>=19 && pos<27)ui_glyph={1'b1,7'd107,4'(pos-19)};if(pos>=27 && pos<31)ui_glyph={1'b1,7'd105,4'(pos-27)};if(pos>=31 && pos<39)ui_glyph={1'b1,7'd110,4'(pos-31)};if(pos>=39 && pos<47)ui_glyph={1'b1,7'd103,4'(pos-39)}; end
default:;endcase end endfunction
function automatic logic [27:0] enterprise_row(input integer row);begin case(row)
0:enterprise_row=28'hfffc0c0;
1:enterprise_row=28'hfffdffe;
2:enterprise_row=28'h01c3fff;
3:enterprise_row=28'h00e7c40;
4:enterprise_row=28'h003f800;
5:enterprise_row=28'h01ffc00;
6:enterprise_row=28'h00ffc00;
7:enterprise_row=28'h001f800;
default:enterprise_row=0;endcase end endfunction
endpackage
