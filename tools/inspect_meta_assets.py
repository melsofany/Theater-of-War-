from pathlib import Path
from PIL import Image

root = Path('/home/ubuntu/Theater-of-War-/incoming_meta_assets')
for path in sorted(root.glob('*.png')):
    with Image.open(path) as im:
        rgba = im.convert('RGBA')
        alpha = rgba.getchannel('A')
        amin, amax = alpha.getextrema()
        transparent = sum(1 for v in alpha.getdata() if v < 255)
        total = im.width * im.height
        print(f'{path.name}\t{im.size[0]}x{im.size[1]}\tmode={im.mode}\talpha={amin}-{amax}\tpartial_or_transparent={transparent/total:.3f}')
