from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

src = Path('/home/ubuntu/Theater-of-War-/incoming_meta_assets')
out = src / 'meta_asset_sheet.png'
files = sorted(p for p in src.glob('*.png') if p.name != 'meta_asset_sheet.png' and not p.name.startswith('meta_artillery'))
thumb_w, thumb_h = 220, 190
cols = 4
rows = (len(files) + cols - 1) // cols
sheet = Image.new('RGB', (cols * thumb_w, rows * thumb_h), '#1f252b')
draw = ImageDraw.Draw(sheet)
for i, path in enumerate(files):
    x = (i % cols) * thumb_w
    y = (i // cols) * thumb_h
    try:
        im = Image.open(path).convert('RGBA')
        im.thumbnail((190, 145), Image.Resampling.LANCZOS)
        cx = x + (thumb_w - im.width) // 2
        cy = y + 8
        checker = Image.new('RGB', (im.width, im.height), '#d8d8d8')
        checker.paste(im, mask=im.getchannel('A'))
        sheet.paste(checker, (cx, cy))
        draw.text((x + 8, y + 158), path.stem[:28], fill='white')
        draw.text((x + 8, y + 174), f'{Image.open(path).size[0]}x{Image.open(path).size[1]}', fill='#aeb9c4')
    except Exception as exc:
        draw.text((x + 8, y + 20), f'ERROR {path.name}: {exc}', fill='#ff7777')
sheet.save(out)
print(out)
