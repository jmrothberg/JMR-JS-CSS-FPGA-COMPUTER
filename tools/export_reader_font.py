"""Compile the existing Chicago bitmap font into the reader's sprite atlas."""
from pathlib import Path
import json,base64,io
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def reader_font():
    glyphs=json.loads((ROOT/'assets/desktop/chicago-12.json').read_text())['glyphs']
    atlas=Image.new('RGBA',(512,128))
    advances=[]
    for code in range(128):
        glyph=glyphs.get(chr(code),glyphs['?']);advances.append(glyph['advance'])
        for colour,rgb in enumerate(((0,0,0,255),(0,85,238,255))):
            for y,row in enumerate(glyph['rows']):
                for x,bit in enumerate(row):
                    if bit=='1':atlas.putpixel(((code%32)*16+x+glyph['offset'],colour*64+(code//32)*16+y),rgb)
    output=io.BytesIO();atlas.save(output,format='PNG')
    (ROOT/'assets/desktop/chicago-reader.png').write_bytes(output.getvalue())
    return advances,'data:image/png;base64,'+base64.b64encode(output.getvalue()).decode()
if __name__=='__main__':
    advances,uri=reader_font()
    path=ROOT/'storage/READ.HTML';source=path.read_text()
    start=source.index('// BEGIN CHICAGO FONT');end=source.index('// END CHICAGO FONT',start)
    block='// BEGIN CHICAGO FONT\nvar ADV='+json.dumps(advances,separators=(',',':'))+';\nvar fontImage=new Image();\nfontImage.src="'+uri+'";\n'
    path.write_text(source[:start]+block+source[end:])
