from pathlib import Path
from PIL import Image

src = Path('incoming_meta_assets/infantry_topdown.png')
out = Path('assets/meta_units/sniper_topdown.png')
out.parent.mkdir(parents=True, exist_ok=True)
image = Image.open(src).convert('RGBA')
# The upper-center soldier is isolated from the other four figures and carries a
# long rifle, making it the most appropriate existing Meta AI source for a sniper.
crop = image.crop((620, 0, 1080, 690))
alpha = crop.getchannel('A')
box = alpha.getbbox()
if box is None:
    raise RuntimeError('Selected Meta AI crop has no visible alpha content')
crop = crop.crop(box)
# Keep a modest transparent margin so the billboard does not clip the rifle.
pad = 24
padded = Image.new('RGBA', (crop.width + pad * 2, crop.height + pad * 2), (0, 0, 0, 0))
padded.alpha_composite(crop, (pad, pad))
padded.save(out)
print(f'wrote {out} size={padded.size} bbox={box}')
