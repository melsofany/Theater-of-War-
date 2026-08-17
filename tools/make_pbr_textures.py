from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1] / "assets" / "textures" / "terrain"
ROOT.mkdir(parents=True, exist_ok=True)
SIZE = 512
rng = np.random.default_rng(42)

def noise(scale=1.0, blur=0):
    arr = rng.random((SIZE, SIZE)).astype(np.float32)
    img = Image.fromarray(np.uint8(arr * 255), "L")
    if blur:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    return (np.asarray(img).astype(np.float32) / 255.0) * scale

def save_rgb(name, base, variation, roughness=0.8):
    n = noise(variation, 2)
    rgb = np.clip(base[None, None, :] + n[:, :, None] - variation / 2, 0, 1)
    Image.fromarray(np.uint8(rgb * 255), "RGB").save(ROOT / f"{name}.png")
    lum = rgb.mean(axis=2)
    gy, gx = np.gradient(lum)
    normal = np.dstack((0.5 - gx * 2.5, 0.5 - gy * 2.5, np.ones_like(lum)))
    normal = np.clip(normal, 0, 1)
    Image.fromarray(np.uint8(normal * 255), "RGB").save(ROOT / f"{name}_normal.png")
    rough = np.clip(roughness + (noise(0.15, 3) - 0.075), 0, 1)
    Image.fromarray(np.uint8(rough * 255), "L").save(ROOT / f"{name}_roughness.png")

save_rgb("grass", np.array([0.22, 0.34, 0.12]), 0.16, 0.92)
save_rgb("dirt", np.array([0.34, 0.23, 0.13]), 0.14, 0.96)
save_rgb("rock", np.array([0.28, 0.30, 0.29]), 0.18, 0.86)
save_rgb("road", np.array([0.08, 0.075, 0.065]), 0.08, 0.98)

# Water uses a blue albedo and a gently undulating normal map.
water = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
water[:, :, :] = np.array([0.04, 0.20, 0.34])
water += noise(0.08, 5)[:, :, None]
Image.fromarray(np.uint8(np.clip(water, 0, 1) * 255), "RGB").save(ROOT / "water.png")
wave = noise(0.12, 1)
gy, gx = np.gradient(wave)
normal = np.dstack((0.5 - gx * 2.0, 0.5 - gy * 2.0, np.ones_like(wave)))
Image.fromarray(np.uint8(np.clip(normal, 0, 1) * 255), "RGB").save(ROOT / "water_normal.png")
Image.fromarray(np.uint8(np.full((SIZE, SIZE), 35)), "L").save(ROOT / "water_roughness.png")
print("Generated PBR textures in", ROOT)
