"""Paints the catch banner, a Roman vexillum, into game/assets/art/ui/banner_*.png.

The gilded eagle, the crossbar's caps and the tassels come from a small vexillum painted whole (banner_raw/banner_a.png).
The crossbar is laid out to the cloth's width with its middle repainted, the tassels' cords are lengthened, and the wide
cloth with its fringe is painted in place with PixelLab over a smoothed enlargement of a wider vexillum (banner_b.png),
seeing the eagle and the bar round it. The tablet the fish lies on is pale marble painted in place on the cloth, set in
a gilded frame with handles drawn in the eagle's own gold; the laurel wreath hung round the eagle's ball for a new fish
is painted on its own in the eagle's style. The result is cut into the parts the game moves apart: the top (eagle and
crossbar), each tassel, the cloth with its fringe, the roll the cloth unfurls from, the tablet and the wreath. A part
already painted is kept.
Usage: python tools/art/make_banner.py [--paint]"""
import subprocess
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RAW = Path(__file__).with_name("banner_raw")
OUT = ROOT / "game" / "assets" / "art" / "ui"
PIXELLAB = Path(__file__).with_name("pixellab.py")

# The finished picture, the cloth's place and size under the bar, and the fringe below it.
W, H = 232, 188
CLOTH = (16, 44, 200, 132)
FRINGE = 12
# Rows of banner_a.png: the eagle's top, the crossbar's top and the cloth's first row under it.
EAGLE_TOP, BAR_TOP, BAR_END = 17, 53, 61
# Columns of banner_a.png: the bar's ends, the staff, and each tassel; a cap is the bar's last 20 columns.
BAR_LEFT, BAR_RIGHT, STAFF = 61, 161, (108, 114)
TASSELS = ((65, 72), (150, 157))
CAP = 20
# Clear columns either side of each tassel's picture, room for it to sway.
SWAY = 3
# The tassels' cords run this many rows longer than in the small vexillum, to hang beside the taller cloth.
LONGER = 26
CORD_ROW = 70
# The tablet with handles (a tabula ansata): its size, each handle's length, its gilded rim, and where it is painted.
PLAQUE = (152, 60)
EAR = 14
RIM = 4
PLAQUE_AT = (40, 80)
# Where PixelLab painted the marble, inside a frame of its own, in the tablet's pixels.
MARBLE = (24, 6, 128, 53)
# The tablet's frame is drawn in the eagle's darkest golds and the cloth's own gold, darkest to lightest.
GOLD = [(71, 42, 31), (112, 58, 26), (150, 82, 30), (183, 104, 36), (208, 129, 43), (225, 152, 56), (238, 180, 80),
        (247, 207, 112), (250, 232, 150)]
# How far a handle reaches above and below the middle, as a share of the tablet's height, where it meets the face and
# at its end: in the guide PixelLab painted over, and in the frame drawn round the marble.
GUIDE_EARS = (0.12, 0.38)
EARS = (0.1, 0.32)

SMALL_PROMPT = ("ancient Roman vexillum banner standard seen straight from the front, symmetrical: at the very top a small "
                "gilded golden eagle with spread wings standing on a gold ball, below it a short wooden staff, then one long "
                "horizontal dark wooden crossbar with gold end caps; from each end of the crossbar a red cord hangs down "
                "ending in a golden tassel; hanging from the crossbar a large square cloth of deep crimson red woven wool "
                "with soft vertical folds and shading, a thin gold border embroidered along its edges, and a gold fringe "
                "along its bottom edge; the middle of the cloth is plain and empty, no letters, no emblem; detailed pixel "
                "art, warm light from the upper left, no outlines")
WIDE_PROMPT = ("ancient Roman vexillum cloth banner seen straight from the front, symmetrical and wide: one long horizontal "
               "dark wooden crossbar across the top of the picture with gold end caps; from each end of the crossbar a red "
               "cord hangs down ending in a golden tassel; hanging from the crossbar a wide cloth of deep crimson red "
               "woven wool, wider than it is tall, filling most of the picture, with soft vertical folds and shading, a "
               "thin gold border embroidered along its edges, and a gold fringe along its bottom edge; the middle of the "
               "cloth is plain and empty, no letters, no emblem; detailed pixel art, warm light from the upper left, no "
               "outlines")
CLOTH_PROMPT = ("deep crimson red woven wool cloth of a Roman vexillum hanging from a dark wooden crossbar, soft vertical "
                "folds with rich shading, fine woven texture, a thin gold embroidered border inset along its edges, a "
                "dense gold fringe of threads along its straight bottom edge; the middle of the cloth is plain and empty, "
                "no letters, no emblem, no outlines")
PLAQUE_PROMPT = ("smooth polished pale cream marble with soft faint veins, framed by a gilded gold moulded rim with bright "
                 "highlights along its top and left and deep shadow along its bottom and right, plain and empty, no "
                 "letters, no outlines")
WREATH_PROMPT = ("a small golden laurel wreath, a ring of gilded gold laurel leaves open at the top, tied with a small red "
                 "ribbon at the bottom, seen from the front, the middle of the ring empty, shining gold, lit from the "
                 "upper left, no outlines")


def small():
    return np.asarray(Image.open(RAW / "banner_a.png").convert("RGBA"))


def top(a):
    """The eagle on its staff over a crossbar as long as the picture, its middle carried on from the small one's."""
    out = np.zeros((BAR_END - EAGLE_TOP, W, 4), np.uint8)
    dx = W // 2 - (STAFF[0] + STAFF[1]) // 2
    out[:BAR_TOP - EAGLE_TOP, BAR_LEFT + dx:BAR_RIGHT + 1 + dx] = a[EAGLE_TOP:BAR_TOP, BAR_LEFT:BAR_RIGHT + 1]
    bar = a[BAR_TOP:BAR_END, :]
    y0 = BAR_TOP - EAGLE_TOP
    out[y0:, :CAP] = bar[:, BAR_LEFT:BAR_LEFT + CAP]
    out[y0:, W - CAP:] = bar[:, BAR_RIGHT + 1 - CAP:BAR_RIGHT + 1]
    middle = bar[:, BAR_LEFT + CAP:STAFF[0]]
    for x in range(CAP, W - CAP):
        out[y0:, x] = middle[:, (x - CAP) % middle.shape[1]]
    staff_x = STAFF[0] + dx
    out[y0:, staff_x:staff_x + STAFF[1] - STAFF[0] + 1] = bar[:, STAFF[0]:STAFF[1] + 1]
    return out


def tassel(a, cols):
    """A tassel on its cord, from the bar's last row down, the cord lengthened by repeating one of its rows."""
    piece = a[BAR_END:, cols[0]:cols[1] + 1]
    piece = piece[:np.nonzero(piece[:, :, 3].any(axis=1))[0].max() + 1]
    at = CORD_ROW - BAR_END
    return np.concatenate([piece[:at], np.repeat(piece[at:at + 1], LONGER, axis=0), piece[at:]])


def tassel_columns():
    """Where each tassel hangs in the finished picture: as far in from the bar's end as in the small vexillum."""
    left, right = TASSELS
    return left[0] - BAR_LEFT, W - 1 - (BAR_RIGHT - right[0])


def guide(a):
    """The banner laid out at its full size, the cloth a smoothed enlargement of the wide one as a hint to paint over."""
    out = np.zeros((H, W, 4), np.uint8)
    t = top(a)
    out[:t.shape[0]] = t
    for cols, x in zip(TASSELS, tassel_columns()):
        piece = tassel(a, cols)
        region = out[t.shape[0]:t.shape[0] + piece.shape[0], x:x + piece.shape[1]]
        region[:] = np.where(piece[:, :, 3:] > 0, piece, region)
    wide = Image.open(RAW / "banner_b.png").convert("RGBA")
    cx, cy, cw, ch = CLOTH
    canvas = Image.fromarray(out)
    canvas.alpha_composite(wide.crop((64, 34, 195, 125)).resize((cw, ch), Image.LANCZOS), (cx, cy))
    canvas.alpha_composite(wide.crop((63, 125, 196, 132)).resize((cw, FRINGE), Image.LANCZOS), (cx, cy + ch))
    return canvas


def cloth_mask():
    """The cloth, its fringe and the crossbar's middle, which PixelLab paints."""
    m = Image.new("L", (W, H), 0)
    cx, cy, cw, ch = CLOTH
    m.paste(255, (cx, cy, cx + cw, cy + ch + FRINGE))
    m.paste(255, (CAP, BAR_TOP - EAGLE_TOP + 2, W - CAP, cy))
    return m


def plaque_shape(ears=EARS):
    """The tablet's face and its handles, each handle a dovetail widening from where it meets the face to its end."""
    w, h = PLAQUE
    shape = np.zeros((h, w), bool)
    shape[:, EAR:w - EAR] = True
    for x in range(EAR):
        reach = h * (ears[0] + (ears[1] - ears[0]) * (EAR - x) / EAR)
        for y in range(h):
            if abs(y - (h - 1) / 2.0) <= reach:
                shape[y, x] = shape[y, w - 1 - x] = True
    return shape


def depth_of(shape):
    # The picture's own border is not counted as outside the shape, so it is padded with a row of outside first.
    return cv2.distanceTransform(np.pad(shape, 1).astype(np.uint8), cv2.DIST_C, 3)[1:-1, 1:-1]


def plaque_guide(painted):
    """The tablet drawn roughly in place on the cloth: a gold rim lit from the upper left round a pale cream face."""
    shape = plaque_shape(GUIDE_EARS)
    depth = depth_of(shape)
    h, w = shape.shape
    art = np.zeros((h, w, 4), np.uint8)
    ink = {"l": (252, 232, 160), "g": (236, 196, 96), "d": (176, 126, 52)}
    for y in range(h):
        for x in range(w):
            if not shape[y, x]:
                continue
            if depth[y, x] > RIM:
                art[y, x] = (*np.round(np.array((242, 232, 210)) - (y / h) * np.array((18, 22, 30))).astype(int), 255)
                continue
            lit = (y - RIM < 0 or not shape[y - RIM, x]) or (x - RIM < 0 or not shape[y, x - RIM])
            art[y, x] = (*ink["l" if lit else "d"], 255) if depth[y, x] <= 1 or depth[y, x] >= RIM else (*ink["g"], 255)
    out = painted.copy()
    out.alpha_composite(Image.fromarray(art), PLAQUE_AT)
    m = Image.new("L", (W, H), 0)
    m.paste(Image.fromarray(shape.astype(np.uint8) * 255), PLAQUE_AT)
    return out, m


def marble(painted):
    """The painted marble carried out a few pixels to the frame's inner edge, its own edges mirrored."""
    x0, y0, x1, y1 = MARBLE
    w, h = PLAQUE
    face = np.ascontiguousarray(painted[y0:y1, x0:x1])
    grown = cv2.copyMakeBorder(face, y0 - RIM, (h - RIM) - y1, x0 - EAR - RIM, (w - EAR - RIM) - x1, cv2.BORDER_REFLECT)
    out = np.zeros((h, w, 4), np.uint8)
    out[RIM:h - RIM, EAR + RIM:w - EAR - RIM] = grown
    return out


def handle_tone(shape, x, y):
    """A handle is a gold wedge: its upper face catches the light, its lower face is in shadow, and its end faces the
    side it points to."""
    h, w = shape.shape
    left = x < EAR
    rows = np.nonzero(shape[:, x])[0]
    sides = {"top": y - rows.min(), "bottom": rows.max() - y, "end": x if left else w - 1 - x}
    side = min(sides, key=sides.get)
    if sides[side] == 0:
        return {"top": 5, "bottom": 1, "end": 3 if left else 1}[side]
    if side == "top":
        return 8 if sides[side] == 1 else 7
    if side == "bottom":
        return 3
    return 6 if left else 4


def framed(face_art):
    """The marble face inside a gilded moulding, with handles of solid gold, lit from the upper left: the moulding runs
    from a dark outer edge over a bright ridge to a groove beside the face, shadowed along the top and left."""
    shape = plaque_shape()
    h, w = shape.shape
    depth = depth_of(shape)
    soft = cv2.GaussianBlur(np.pad(shape, 4).astype(np.float32), (9, 9), 2.0)[4:-4, 4:-4]
    gy, gx = np.gradient(soft)
    # The slope of the blurred shape rises inward, so it is positive along the edges that face the upper left.
    facing = gx + gy
    face = np.zeros_like(shape)
    face[RIM:h - RIM, EAR + RIM:w - EAR - RIM] = True
    out = np.zeros((h, w, 4), np.uint8)
    out[face] = face_art[face]
    for y in range(h):
        for x in range(w):
            if not shape[y, x] or face[y, x]:
                continue
            d = int(depth[y, x])
            lit, dark = facing[y, x] > 0.02, facing[y, x] < -0.02
            beside = [(y + dy, x + dx) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if 0 <= y + dy < h and 0 <= x + dx < w]
            if x < EAR or x >= w - EAR:
                tone = handle_tone(shape, x, y)
            elif any(face[p] for p in beside):
                tone = 2 if (y + 1 < h and face[y + 1, x]) or (x + 1 < w and face[y, x + 1]) else 6
            elif d == 1:
                tone = 3 if lit else (1 if dark else 2)
            elif d == 2:
                tone = 8 if lit else (4 if dark else 6)
            else:
                tone = 6 if lit else (3 if dark else 5)
            out[y, x] = (*GOLD[tone], 255)
    shade = np.ones((h, w), np.float32)
    shade[RIM, :] *= 0.82
    shade[RIM + 1, :] *= 0.92
    shade[:, EAR + RIM] *= 0.86
    out[face, :3] = (out[face, :3] * shade[face, None]).astype(np.uint8)
    return out


def roll(cloth):
    """The cloth still rolled up: a band of its own colours shaded as a cylinder lit from above."""
    band = cloth[20:21, :, :].astype(float)
    shades = [1.3, 1.12, 1.0, 0.86, 0.68, 0.5]
    return np.concatenate([np.clip(band * (s, s, s, 1.0), 0, 255) for s in shades]).astype(np.uint8)


def wreath_art(painted):
    """The wreath trimmed to its leaves, a stray pale pixel in its ribbon given the ribbon's red."""
    a = np.asarray(painted).copy()
    a = a[slice(*bounds(a[:, :, 3] > 0, 0)), slice(*bounds(a[:, :, 3] > 0, 1))]
    h = a.shape[0]
    for y, x in zip(*np.nonzero(a[:, :, 3] > 0)):
        r, g, _ = (int(v) for v in a[y, x, :3])
        if y > h * 0.75 and g > 100 and r - g < 60:
            a[y, x] = a[y, x - 1]
    return a


def bounds(mask, axis):
    hit = np.nonzero(mask.any(axis=1 - axis))[0]
    return hit.min(), hit.max() + 1


def run(args):
    subprocess.run([sys.executable, str(PIXELLAB)] + args, cwd=ROOT, check=True)


def inpaint(image, mask, prompt, out, transparent):
    """Paints the white of `mask` over `image`. Only the cloth, with gaps between its fringe's threads, is painted with a
    see-through background: a part inside the banner painted so comes back as a smaller copy with holes round it."""
    if out.exists():
        return
    image.save(RAW / "work.png")
    mask.save(RAW / "work_mask.png")
    run(["inpaint", str((RAW / "work.png").relative_to(ROOT)), str((RAW / "work_mask.png").relative_to(ROOT)), prompt,
         "--out", str(out.relative_to(ROOT))] + (["--transparent"] if transparent else []))


def proflash(prompt, size, style, style_picture, use, out):
    """Paints a picture on its own in the style of `style_picture`, saved first as `style`."""
    if out.exists():
        return
    style_picture.save(style)
    run(["proflash", prompt, size, "--transparent", "--style", str(style.relative_to(ROOT)), "--style-use", use,
         "--out", str(out.relative_to(ROOT))])


def paint():
    # The small vexillum is painted in the style of the goldsmith's red awning and banner in the town street.
    street = Image.open(ROOT / "game" / "assets" / "art" / "town" / "street.png").convert("RGBA")
    proflash(SMALL_PROMPT, "224x192", RAW / "style.png", street.crop((292, 116, 512, 260)),
             "match this art style, palette, shading and lighting; no outlines", RAW / "banner_a.png")
    a = small()
    proflash(WIDE_PROMPT, "256x176", RAW / "style_a.png", Image.fromarray(a[16:176, 60:164]),
             "match this banner exactly: its art style, palette, cloth, gold and wood, shading and lighting; no outlines",
             RAW / "banner_b.png")
    painted = RAW / "painted.png"
    inpaint(guide(a), cloth_mask(), CLOTH_PROMPT, painted, True)
    inpaint(*plaque_guide(Image.open(painted).convert("RGBA")), PLAQUE_PROMPT, RAW / "plaque.png", False)
    proflash(WREATH_PROMPT, "32x32", RAW / "style_eagle.png", Image.fromarray(a[20:52, 95:127]),
             "match this gilded gold: its palette, shading and lighting; no outlines", RAW / "wreath.png")


def cut():
    a = np.asarray(Image.open(RAW / "painted.png").convert("RGBA")).copy()
    cx, cy, cw, ch = CLOTH
    cloth = a[cy:cy + ch + FRINGE, cx:cx + cw].copy()
    # A few stray near-white pixels among the fringe's threads are dropped.
    stray = (cloth[:, :, :3].min(axis=2) > 200) & (np.arange(cloth.shape[0])[:, None] > ch)
    cloth[stray] = 0
    Image.fromarray(cloth).save(OUT / "banner_cloth.png")
    Image.fromarray(roll(cloth)).save(OUT / "banner_roll.png")
    Image.fromarray(a[:cy]).save(OUT / "banner_top.png")
    for name, x in zip(("left", "right"), tassel_columns()):
        piece = a[cy:, x:x + TASSELS[0][1] - TASSELS[0][0] + 1]
        piece = piece[:np.nonzero(piece[:, :, 3].any(axis=1))[0].max() + 1]
        Image.fromarray(np.pad(piece, ((0, 0), (SWAY, SWAY), (0, 0)))).save(OUT / f"banner_tassel_{name}.png")
    px, py = PLAQUE_AT
    plaque = np.asarray(Image.open(RAW / "plaque.png").convert("RGBA"))[py:py + PLAQUE[1], px:px + PLAQUE[0]]
    Image.fromarray(framed(marble(plaque))).save(OUT / "banner_plaque.png")
    Image.fromarray(wreath_art(Image.open(RAW / "wreath.png").convert("RGBA"))).save(OUT / "banner_wreath.png")


def main():
    RAW.mkdir(exist_ok=True)
    if "--paint" in sys.argv:
        paint()
    cut()


if __name__ == "__main__":
    main()
