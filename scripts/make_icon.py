"""Generate the Hunny app icon: a honey jar with a dipper stick.

Draws at 3x supersampling (3072px) and downscales to 1024 with Lanczos
for smooth edges. Output is flattened to RGB (no alpha) as iOS icons require.
"""
from PIL import Image, ImageDraw, ImageFilter, ImageOps

S = 3
N = 1024
W = N * S


def px(v):
    return round(v * S)


def lerp(c1, c2, t):
    return tuple(round(a + (b - a) * t) for a, b in zip(c1, c2))


def vgrad(w, h, top, bottom):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        d.line([(0, y), (w, y)], fill=lerp(top, bottom, y / max(h - 1, 1)))
    return img


# 1. Background: warm honey-amber vertical gradient
canvas = vgrad(W, W, (0xFF, 0xAF, 0x1F), (0xFA, 0x70, 0x1C))

# 2. Soft light glow, upper-left (centre ~(330, 210))
glow = Image.radial_gradient("L")
if glow.getpixel((0, 0)) > glow.getpixel((128, 128)):
    glow = ImageOps.invert(glow)
gx, gy = px(330), px(210)
G = W + 2 * max(gx, gy)
glow = glow.resize((G, G), Image.Resampling.BILINEAR)
crop = glow.crop((G // 2 - gx, G // 2 - gy, G // 2 - gx + W, G // 2 - gy + W))
canvas.paste((255, 255, 255), (0, 0), crop.point(lambda v: v * 60 // 255))

# 3. Soft shadow under the jar
shadow = Image.new("L", (W, W), 0)
ImageDraw.Draw(shadow).ellipse(
    (px(512 - 230), px(838 - 34), px(512 + 230), px(838 + 34)), fill=92
)
shadow = shadow.filter(ImageFilter.GaussianBlur(px(14)))
canvas.paste((0x7A, 0x2E, 0x00), (0, 0), shadow)

canvas = canvas.convert("RGBA")


def composite_layer(layer):
    global canvas
    canvas = Image.alpha_composite(canvas, layer)


def shape_layer():
    layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    return layer, ImageDraw.Draw(layer)


def paste_gradient(layer, x0, y0, x1, y1, radius, top, bottom, alpha):
    """Rounded-rect region filled with a vertical gradient at given alpha."""
    grad = vgrad(px(x1 - x0), px(y1 - y0), top, bottom)
    mask = Image.new("L", layer.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (px(x0), px(y0), px(x1), px(y1)), radius=px(radius), fill=alpha
    )
    region = mask.crop((px(x0), px(y0), px(x1), px(y1)))
    layer.paste(grad, (px(x0), px(y0)), region)


# 4. Honey dipper (drawn upright with head centre at image centre, then tilted)
D = px(1000)
cx = cy = D // 2
dip = Image.new("RGBA", (D, D), (0, 0, 0, 0))
dd = ImageDraw.Draw(dip)
hx, hy = cx / S, cy / S  # head centre in 1024-scale coords
dd.rounded_rectangle(
    (px(hx - 38), px(hy - 452), px(hx + 38), px(hy - 426)),
    radius=px(13), fill=(0x8A, 0x4E, 0x1D, 255),
)
paste_gradient(dip, hx - 24, hy - 436, hx + 24, hy + 16, 24,
               (0xB0, 0x70, 0x2F), (0x8A, 0x4E, 0x1D), 255)
dd.ellipse((px(hx - 78), px(hy - 28), px(hx + 78), px(hy + 28)), fill=(0x7C, 0x43, 0x18, 255))
dd.ellipse((px(hx - 64), px(hy - 26), px(hx + 64), px(hy + 26)), fill=(0x8A, 0x4E, 0x1D, 255))
dd.ellipse((px(hx - 50), px(hy - 24), px(hx + 50), px(hy + 24)), fill=(0x7C, 0x43, 0x18, 255))
dip = dip.rotate(16, resample=Image.Resampling.BICUBIC, expand=True)
canvas.paste(dip, (px(612) - dip.width // 2, px(540) - dip.height // 2), dip)

# 5. Jar: tinted glass fill, then honey, highlights, and rim outline on top
layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).rounded_rectangle(
    (px(282), px(356), px(742), px(808)), radius=px(64), fill=33
)
layer.paste((255, 255, 255), (0, 0), mask)
composite_layer(layer)

honey = Image.new("RGBA", (W, W), (0, 0, 0, 0))
paste_gradient(honey, 314, 452, 710, 776, 46,
               (0xFF, 0xD9, 0x68), (0xEF, 0x92, 0x0D), 245)
composite_layer(honey)

layer, d = shape_layer()
d.ellipse((px(512 - 198), px(452 - 30), px(512 + 198), px(452 + 30)),
          fill=(0xFF, 0xE7, 0x9A, 255))
composite_layer(layer)

# Submerged dipper head, hinted at low alpha over the honey surface
head = Image.new("RGBA", (D, D), (0, 0, 0, 0))
hd = ImageDraw.Draw(head)
for rx, ry, col in ((78, 28, (0x7C, 0x43, 0x18)),
                    (64, 26, (0x8A, 0x4E, 0x1D)),
                    (50, 24, (0x7C, 0x43, 0x18))):
    hd.ellipse((px(hx - rx), px(hy - ry), px(hx + rx), px(hy + ry)),
               fill=col + (255,))
head = head.rotate(16, resample=Image.Resampling.BICUBIC, expand=True)
head.putalpha(head.getchannel("A").point(lambda v: v * 72 // 255))
canvas.paste(head, (px(612) - head.width // 2, px(540) - head.height // 2), head)

layer, d = shape_layer()
d.rounded_rectangle((px(348), px(492), px(382), px(708)), radius=px(17),
                    fill=(255, 255, 255, 128))
d.ellipse((px(350), px(394), px(382), px(446)), fill=(255, 255, 255, 153))
composite_layer(layer)

layer, d = shape_layer()
d.rounded_rectangle((px(282), px(356), px(742), px(808)), radius=px(64),
                    outline=(255, 255, 255, 192), width=px(16))
composite_layer(layer)

# 6. Downscale, flatten, save
final = canvas.convert("RGB").resize((N, N), Image.Resampling.LANCZOS)
out = "/tmp/pylibs/AppIcon.png"
final.save(out, optimize=True)
print("saved", out, final.size, final.mode)

for name, (x, y) in {
    "top-left bg": (10, 10),
    "bottom-right bg": (1013, 1013),
    "honey": (512, 620),
    "handle top": (491, 150),
    "above jar (bg)": (512, 120),
}.items():
    print(f"{name:18s} {final.getpixel((x, y))}")
