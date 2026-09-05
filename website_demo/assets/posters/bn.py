# -*- coding: utf-8 -*-
"""HarfBuzz-shaped text -> SVG paths, with Bengali/Latin script fallback.

Bengali needs real shaping (conjuncts, reph, matra reordering). cairo's toy text
API can't do it, so every string goes through HarfBuzz here and comes out as
outlines. Side benefit: the SVGs carry no font dependency at all.
"""
import os
import uharfbuzz as hb
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

G = os.path.dirname(os.path.abspath(__file__))
_local_d = f"{G}/fonts/dejavu"
D = _local_d if os.path.isdir(_local_d) else "/usr/share/fonts/truetype/dejavu"

class Face:
    _reg = {}
    def __init__(self, path):
        blob = hb.Blob.from_file_path(path)
        self.face = hb.Face(blob)
        self.hb = hb.Font(self.face)
        self.tt = TTFont(path, lazy=True)
        self.upem = self.tt["head"].unitsPerEm
        self.gs = self.tt.getGlyphSet()
        self.order = self.tt.getGlyphOrder()
        self.cmap = self.tt.getBestCmap()
        self._c = {}
    @classmethod
    def get(cls, path):
        if path not in cls._reg:
            cls._reg[path] = cls(path)
        return cls._reg[path]
    def has(self, ch):
        return ord(ch) in self.cmap
    def path(self, gid):
        if gid not in self._c:
            pen = SVGPathPen(self.gs)
            try:
                self.gs[self.order[gid]].draw(pen)
                self._c[gid] = pen.getCommands()
            except Exception:
                self._c[gid] = ""
        return self._c[gid]

# Latin faces
SANS_B  = f"{D}/DejaVuSans-Bold.ttf"
SANS_R  = f"{D}/DejaVuSans.ttf"
SANS_I  = f"{D}/DejaVuSans-Oblique.ttf"
COND_B  = f"{D}/DejaVuSansCondensed-Bold.ttf"
COND_R  = f"{D}/DejaVuSansCondensed.ttf"
MONO_B  = f"{D}/DejaVuSansMono-Bold.ttf"
MONO_R  = f"{D}/DejaVuSansMono.ttf"
# Bengali faces (Noto Sans Bengali, SIL OFL)
BN_900  = f"{G}/fonts/NotoSansBengali-900.ttf"
BN_700  = f"{G}/fonts/NotoSansBengali-700.ttf"
BN_500  = f"{G}/fonts/NotoSansBengali-500.ttf"
BN_400  = f"{G}/fonts/NotoSansBengali-400.ttf"

# Latin face -> matching Bengali weight
PAIR = {COND_B: BN_900, SANS_B: BN_700, MONO_B: BN_700,
        COND_R: BN_500, SANS_R: BN_400, MONO_R: BN_400, SANS_I: BN_400}

def is_bn(ch):
    o = ord(ch)
    # Bengali block + danda / double danda (U+0964-65, Devanagari block but
    # used by Bengali; DejaVu has no glyph for them, Noto Bengali does)
    return 0x0980 <= o <= 0x09FF or o in (0x0964, 0x0965)

def has_bn(s):
    return any(is_bn(c) for c in s)

def _runs(text, latin, bengali):
    """Split into (substring, Face) runs.

    Bengali chars go to the Bengali face; ASCII punctuation isn't in the Noto
    subset so it falls to Latin. Spaces are neutral and join whichever side is
    Bengali, so DejaVu's wider space never opens a gap mid-sentence.
    """
    bf = Face.get(bengali)
    cls = []
    for ch in text:
        cls.append("s" if ch == " " else ("b" if is_bn(ch) else "l"))
    # resolve neutral spaces from their neighbours
    for i, c in enumerate(cls):
        if c != "s":
            continue
        p = next((cls[j] for j in range(i - 1, -1, -1) if cls[j] != "s"), None)
        n = next((cls[j] for j in range(i + 1, len(cls)) if cls[j] != "s"), None)
        cls[i] = "b" if "b" in (p, n) else "l"
    # a Bengali-classed char the subset lacks falls back to Latin
    cls = [("l" if c == "b" and not bf.has(ch) else c) for ch, c in zip(text, cls)]
    runs, cur, mode = [], "", None
    for ch, c in zip(text, cls):
        if mode is None or c == mode:
            mode = c; cur += ch
        else:
            runs.append((cur, Face.get(bengali if mode == "b" else latin)))
            cur, mode = ch, c
    if cur:
        runs.append((cur, Face.get(bengali if mode == "b" else latin)))
    return runs

def layout(text, size, latin, tracking=0.0):
    """-> (glyphs, advance_width). glyphs = (d, dx, dy, scale)."""
    bengali = PAIR.get(latin, BN_400)
    glyphs, x = [], 0.0
    for run, face in _runs(text, latin, bengali):
        buf = hb.Buffer()
        buf.add_str(run)
        buf.guess_segment_properties()
        hb.shape(face.hb, buf)
        sc = size / face.upem
        for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
            d = face.path(info.codepoint)
            if d:
                glyphs.append((d, x + pos.x_offset * sc, pos.y_offset * sc, sc))
            x += pos.x_advance * sc + tracking
    return glyphs, x

def width(text, size, latin, tracking=0.0):
    return layout(text, size, latin, tracking)[1]

def bfit(text, max_w, start, latin, tracking=0.0, min_size=9):
    s = start
    while s > min_size and width(text, s, latin, tracking) > max_w:
        s -= 1
    return s

def btext(x, y, text, size, fill, latin=SANS_B, anchor="start", tracking=0.0,
          opacity=None):
    """Shaped text as outlines. Baseline at y."""
    glyphs, w = layout(text, size, latin, tracking)
    if anchor == "middle": x -= w / 2
    elif anchor == "end":  x -= w
    o = f' opacity="{opacity}"' if opacity is not None else ""
    parts = [f'<path d="{d}" transform="translate({x+dx:.2f},{y+dy:.2f}) '
             f'scale({sc:.6f},{-sc:.6f})"/>' for d, dx, dy, sc in glyphs]
    return f'<g fill="{fill}"{o}>{"".join(parts)}</g>'

def bline(x, y, text, size, fill, latin=COND_B, max_w=880, anchor="start",
          tracking=0.0, opacity=None):
    """Display line that auto-shrinks to fit max_w."""
    return btext(x, y, text, bfit(text, max_w, size, latin, tracking), fill,
                 latin, anchor, tracking, opacity)
