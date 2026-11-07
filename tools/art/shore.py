"""Gives a row of land a shore where it meets the sea, so its bottom no longer runs ruler straight along its band.

Along the bottom the land is broken into stretches of beach, rocks standing in the water, bushes at the water's edge,
reeds, and plain shore with small coves, every colour taken from the picture itself so the shore carries its haze
and light. Rocks, beaches and reeds reach a few pixels below the old bottom, nearer the viewer. Sea painted along the
bottom of a picture fades into the band instead.
Usage: python tools/art/shore.py IN OUT [--scale=N] [--kinds=beach:2,rocks:3,...] [--seed=N] [--haze=#rrggbb:amount]
"""
import math
import random
import sys

import numpy as np
from PIL import Image

KINDS = {"beach": 2, "rocks": 2, "bushes": 2, "reeds": 0, "plain": 1}
# How far above the picture's bottom land still counts as coming down to the water.
REACH = 16
# Rows of painted sea at the bottom that fade into the band.
MELT = 3


def lum(c):
    return c[..., 0] * 0.3 + c[..., 1] * 0.59 + c[..., 2] * 0.11


def mix(a, b, k):
    return np.asarray(a, float) * (1 - k) + np.asarray(b, float) * k


class Palette:
    """The picture's own colours for each kind of shore, darkest first."""

    def __init__(self, a, haze=None):
        px = a[a[:, :, 3] > 200][:, :3].astype(float)
        low = a[max(0, a.shape[0] - 40):]
        low = low[low[:, :, 3] > 200][:, :3].astype(float)
        mean = px.mean(axis=0)

        def own(c):
            # A colour not found in the picture is hazed as the picture was, then drawn a little toward its average.
            c = np.asarray(c, float)
            if haze:
                c = mix(c, [int(haze[0][i:i + 2], 16) for i in (1, 3, 5)], float(haze[1]))
            return mix(c, mean, 0.15)

        r, g, b = px[:, 0], px[:, 1], px[:, 2]
        self.greens = self._tones(px[(g > r + 4) & (g > b + 4)], own([62, 92, 52]))
        lr, lg, lb = low[:, 0], low[:, 1], low[:, 2]
        sat = low.max(axis=1) - low.min(axis=1)
        stone = low[(sat < 40) & (lg <= lr + 6) & (lum(low) > 60) & (lum(low) < 210)]
        found = self._tones(stone, own([120, 108, 92]), 300)
        self.rocks = [mix(found[0], found[1], 0.2), mix(found[1], found[0], 0.25), found[2]]
        sandy = px[(r >= g) & (g >= b + 15) & (r - b > 40) & (r - b < 100) & (lum(px) > 135) & (lum(px) < 215)]
        sand = np.median(sandy, axis=0) if len(sandy) > 150 else own([210, 186, 136])
        self.sand = [mix(sand, self.rocks[0], 0.3), sand, mix(sand, [255, 248, 228], 0.3)]
        self.dark = np.percentile(px, 6, axis=0)
        self.reeds = [mix(self.greens[0], own([88, 66, 38]), 0.4), self.greens[1], mix(self.greens[2], own([196, 178, 96]), 0.5)]

    @staticmethod
    def _tones(px, fallback, need=30):
        if len(px) < need:
            f = np.asarray(fallback, float)
            return [f * 0.6, f, mix(f, [255, 245, 220], 0.3)]
        order = px[np.argsort(lum(px))]
        return [order[int(len(order) * q)] for q in (0.12, 0.5, 0.88)]


class Shore:
    def __init__(self, a, scale, kinds, seed, haze=None):
        self.rng = random.Random(seed)
        self.s = scale
        self.kinds = kinds
        w = a.shape[1]
        rows = np.where((a[:, :, 3] > 16).any(axis=1))[0]
        a = a[:rows[-1] + 1] if rows.size else a
        self.base = a.shape[0] - 1
        self.drop = scale + 1
        self.a = np.zeros((a.shape[0] + self.drop, w, 4), np.float64)
        self.a[:a.shape[0]] = a
        self.pal = Palette(a.astype(np.uint8), haze)
        self.water = self.melt(self.base)
        self.orig = self.a.copy()
        solid = self.a[:, :, 3] > 200
        has = solid.any(axis=0)
        self.bottom = np.where(has, self.a.shape[0] - 1 - np.argmax(solid[::-1], axis=0), -1)
        self.heights = np.where(has, self.bottom + 1 - np.argmax(solid, axis=0), 0)

    def melt(self, base):
        """Sea painted along the picture's bottom fades into the band over its last rows instead of ending on a line.
        Returns the columns where it was found, which get no shore of their own."""
        px = self.a[base - MELT:base + 1]
        r, g, b, al = px[:, :, 0], px[:, :, 1], px[:, :, 2], px[:, :, 3]
        wet = (al > 200) & (b > r + 6) & (b >= g - 12) & (lum(px) < 160)
        cols = wet[-1] & wet[0]
        for k in range(MELT + 1):
            row = base - k
            keep = 0.2 + 0.8 * k / (MELT + 1)
            self.a[row, cols & wet[MELT - k], 3] *= keep
        return cols

    def put(self, x, y, colour):
        h, w = self.a.shape[:2]
        if 0 <= x < w and 0 <= y < h:
            self.a[y, x, :3] = colour
            self.a[y, x, 3] = 255

    def runs(self):
        """Stretches where the land comes down to the water at much the same height, each with its own waterline,
        leaving room at each end so the ends of the land stay low."""
        out, x, w = [], 0, len(self.bottom)
        low = self.a.shape[0] - 1 - self.drop - REACH
        while x < w:
            if self.bottom[x] < low or self.water[x]:
                x += 1
                continue
            e = x + 1
            while e < w and self.bottom[e] >= low and not self.water[e] and abs(int(self.bottom[e]) - int(self.bottom[e - 1])) <= 2:
                e += 1
            pad = 3 + 2 * self.s
            if e - x > 2 * pad + 4:
                out.append((x + pad, e - pad, int(self.bottom[x + pad:e - pad].max())))
            x = e
        return out

    def build(self):
        names = [k for k, v in self.kinds.items() if v > 0]
        weights = [self.kinds[k] for k in names]
        last = None
        for x0, x1, base in self.runs():
            self.base = base
            x = x0
            while x < x1:
                n = self.rng.randint(5 + 3 * self.s, 10 + 12 * self.s)
                kind = self.rng.choices(names, weights)[0]
                if kind == last and len(names) > 1:
                    kind = self.rng.choices(names, weights)[0]
                last = kind
                e = min(x1, x + n)
                if e > x and self.heights[x:e].min() >= self.drop + 3:
                    getattr(self, kind)(x, e)
                else:
                    self.plain(x, e)
                x = e
        return np.clip(self.a, 0, 255).astype(np.uint8)

    def plain(self, x0, x1):
        """A wet dark line along the water and now and then a small cove where the water reaches in a pixel."""
        cove = self.rng.random() < 0.6
        c0 = self.rng.randint(x0, max(x0, x1 - 4))
        c1 = c0 + self.rng.randint(3, 4 + 3 * self.s)
        for x in range(x0, x1):
            y = int(self.bottom[x])
            if cove and c0 <= x < c1 and self.heights[x] > 6:
                self.a[y, x, 3] = 0
                y -= 1
            self.a[y, x, :3] = mix(self.a[y, x, :3], self.pal.dark, 0.35)

    def wave(self, n, period):
        """A smooth random line n long, between 0 and 1, rising and falling about every period pixels."""
        knots = [self.rng.random() for _ in range(n // max(1, period) + 3)]
        out = []
        for i in range(n):
            f = i / max(1, period)
            k, t = int(f), f - int(f)
            t = (1 - math.cos(t * math.pi)) / 2
            out.append(knots[k] * (1 - t) + knots[k + 1] * t)
        return out

    def beach(self, x0, x1):
        """A strip of sand along the water, its top edge wandering, its waterline a pixel nearer than the land."""
        n = x1 - x0
        top = min(self.s + 1, 3)
        line = self.wave(n, 4 + 2 * self.s)
        nearer = self.wave(n, 6 + 3 * self.s)
        for i, x in enumerate(range(x0, x1)):
            u = i / max(1, n - 1)
            ends = min(1.0, min(u, 1 - u) * 5)
            t = max(1, round((0.6 + line[i] * (top - 0.6)) * ends ** 0.5))
            low = self.base + (1 if nearer[i] > 0.35 and ends > 0.5 else 0)
            for j, y in enumerate(range(low - t, low + 1)):
                if y == low:
                    c = self.pal.sand[0] if self.rng.random() < 0.7 else self.pal.sand[1]
                elif j == 0:
                    c = self.pal.sand[2] if self.rng.random() < 0.8 else self.pal.sand[1]
                else:
                    c = mix(self.pal.sand[1], self.pal.sand[2 if self.rng.random() < 0.3 else 0], 0.25)
                self.put(x, y, c)

    def rocks(self, x0, x1):
        """Rounded rocks standing in the water in front of the land, lit from the upper left."""
        x = x0 + self.rng.randint(0, 3)
        while x < x1 - 2:
            w = self.rng.randint(2 + self.s, 3 + 3 * self.s)
            h = self.rng.randint(1 + self.s, 2 + 2 * self.s)
            sink = self.rng.randint(0, self.drop)
            self.rock(x, w, h, self.base + sink)
            if self.rng.random() < 0.5:
                self.rock(x + w - 1, max(2, w // 2), max(1, h // 2), self.base + min(self.drop, sink + 1))
            x += w + self.rng.randint(-1, 2 + 3 * self.s)

    def local(self, x0, x1, tones):
        """Tones half the picture's stone and half the land just behind, so a rock takes the colour of its shore."""
        near = self.orig[max(0, self.base - 10):self.base + 1, max(0, x0):x1]
        near = near[near[:, :, 3] > 200][:, :3]
        if len(near) < 8:
            return tones
        order = near[np.argsort(lum(near))]
        return [mix(t, order[int(len(order) * q)], 0.5) for t, q in zip(tones, (0.15, 0.5, 0.85))]

    def rock(self, x0, w, h, yb):
        dark, mid, light = self.local(x0, x0 + w, self.pal.rocks)
        for i in range(w):
            u = (i + 0.5) / w * 2 - 1
            ht = max(1, round(h * (1 - u * u) ** 0.45 + self.rng.choice((0, 0, -1))))
            for j in range(ht):
                k = ht - 1 - j
                if j == 0:
                    c = mix(dark, self.pal.dark, 0.45)
                elif k == 0:
                    c = light if u < 0.3 else mid
                elif k == 1 and u < -0.2:
                    c = mix(light, mid, 0.5)
                elif u > 0.4 or j == 1:
                    c = dark
                else:
                    c = mid
                self.put(x0 + i, yb - j, mix(c, mid, self.rng.random() * 0.12))

    def bushes(self, x0, x1):
        """Bushes crowding down to the water, overlapping one another."""
        x = x0 + self.rng.randint(0, 2)
        while x < x1 - 3:
            w = self.rng.randint(3 + self.s, 4 + 3 * self.s)
            self.canopy(x, self.base + self.rng.randint(0, 1), w, self.rng.randint(2 + self.s, 2 + 2 * self.s))
            x += w - self.rng.randint(1, 2) + (self.rng.randint(0, 6 * self.s) if self.rng.random() < 0.3 else 0)

    def canopy(self, x0, yb, w, h):
        dark, mid, light = self.pal.greens
        bumps = [(self.rng.uniform(0.15, 0.85), self.rng.uniform(0.7, 1.0)) for _ in range(2)] + [(0.5, 0.8)]
        for i in range(w):
            u = (i + 0.5) / w
            ht = max(1, round(h * max((1 - ((u - c) * 2.2) ** 2) * s for c, s in bumps)))
            for j in range(ht):
                k = ht - 1 - j
                if j == 0:
                    c = mix(dark, self.pal.dark, 0.4)
                elif k == 0:
                    c = light if u < 0.7 else mid
                elif k == 1:
                    c = mid if u < 0.8 else dark
                else:
                    c = dark if self.rng.random() < 0.75 else mid
                self.put(x0 + i, yb - j, c)

    def reeds(self, x0, x1):
        """Clumps of reeds rising out of the shallows, tallest in the middle and leaning outward."""
        x = x0 + self.rng.randint(0, 3)
        while x < x1 - 2:
            width = self.rng.randint(3, 3 + 2 * self.s)
            tall = self.rng.randint(2 + self.s, 2 + 2 * self.s)
            yb = self.base + self.rng.randint(0, 1)
            for i in range(width):
                u = (i + 0.5) / width * 2 - 1
                if self.rng.random() < 0.25:
                    continue
                hgt = max(2, round(tall * (1 - 0.5 * abs(u)) + self.rng.choice((-1, 0, 0, 1))))
                lean = (1 if u > 0.3 else -1 if u < -0.3 else 0) if self.rng.random() < 0.7 else 0
                for j in range(hgt):
                    c = self.pal.reeds[0] if j < hgt * 0.4 else (self.pal.reeds[2] if j == hgt - 1 else self.pal.reeds[1])
                    self.put(x + i + (lean if j >= hgt * 0.6 else 0), yb - j, c)
            x += width + self.rng.randint(1, 3 + 3 * self.s)


def shore(im: Image.Image, scale: int, kinds: dict, seed: int, haze=None) -> Image.Image:
    a = np.array(im.convert("RGBA"))
    return Image.fromarray(Shore(a, scale, {**{k: 0 for k in KINDS}, **kinds}, seed, haze).build())


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    kinds = dict((k, float(v)) for k, v in (p.split(":") for p in opts["kinds"].split(","))) if "kinds" in opts else KINDS
    haze = opts["haze"].split(":") if "haze" in opts else None
    shore(Image.open(args[0]), int(opts.get("scale", 2)), kinds, int(opts.get("seed", 1)), haze).save(args[1])
    print("shored", args[1])
