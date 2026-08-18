# Generates the algorithm diagrams shipped in doc/.
BG = "#FCFDFF"
INK = "#16202C"
MUTED = "#5A6875"
LINE = "#C8D2DE"
FILL = "#F2F5F9"
ACCENT = "#3B5BDB"
ACCENT_FILL = "#EDF1FF"
ACCENT_LINE = "#B9C6FA"
GOOD = "#0E9F6E"
GOOD_FILL = "#E9F8F1"
BAD = "#E03131"
BAD_FILL = "#FDECEC"
SANS = "Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif"
MONO = "ui-monospace,SFMono-Regular,Menlo,Consolas,'Liberation Mono',monospace"


def esc(t):
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


class Svg:
    def __init__(self, w, h):
        self.w, self.h, self.parts = w, h, []

    def box(self, cx, cy, w, h, lines, fill=FILL, stroke=LINE, rx=14,
            title_size=15, sub_size=12.5, mono=False, title_color=INK):
        x, y = cx - w / 2, cy - h / 2
        self.parts.append(
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{w}" height="{h}" rx="{rx}" '
            f'fill="{fill}" stroke="{stroke}" stroke-width="1.5"/>')
        head, *rest = lines
        total = title_size + 1 + len(rest) * (sub_size + 5)
        ty = cy - total / 2 + title_size
        fam = MONO if mono else SANS
        self.parts.append(
            f'<text x="{cx}" y="{ty:.1f}" text-anchor="middle" font-family="{fam}" '
            f'font-size="{title_size}" font-weight="600" fill="{title_color}">{esc(head)}</text>')
        for i, line in enumerate(rest):
            sy = ty + 6 + (i + 1) * (sub_size + 4)
            self.parts.append(
                f'<text x="{cx}" y="{sy:.1f}" text-anchor="middle" font-family="{MONO}" '
                f'font-size="{sub_size}" fill="{MUTED}">{esc(line)}</text>')

    def diamond(self, cx, cy, w, h, lines, fill=ACCENT_FILL, stroke=ACCENT_LINE):
        pts = f"{cx},{cy-h/2} {cx+w/2},{cy} {cx},{cy+h/2} {cx-w/2},{cy}"
        self.parts.append(
            f'<polygon points="{pts}" fill="{fill}" stroke="{stroke}" stroke-width="1.5"/>')
        total = len(lines) * 19
        ty = cy - total / 2 + 14
        for i, line in enumerate(lines):
            self.parts.append(
                f'<text x="{cx}" y="{ty + i*19:.1f}" text-anchor="middle" '
                f'font-family="{MONO}" font-size="13" fill="{INK}">{esc(line)}</text>')

    def arrow(self, x1, y1, x2, y2, color=ACCENT, dashed=False, marker="a"):
        dash = ' stroke-dasharray="5 5"' if dashed else ""
        self.parts.append(
            f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
            f'stroke="{color}" stroke-width="2"{dash} marker-end="url(#{marker})"/>')

    def elbow(self, x1, y1, x2, y2, color=ACCENT, marker="a"):
        """Down, across, then down into the target."""
        mid = (y1 + y2) / 2
        self.parts.append(
            f'<path d="M {x1:.1f} {y1:.1f} V {mid:.1f} H {x2:.1f} V {y2:.1f}" fill="none" '
            f'stroke="{color}" stroke-width="2" marker-end="url(#{marker})"/>')

    def text(self, x, y, s, size=13, color=MUTED, anchor="middle", weight="500",
             mono=False):
        fam = MONO if mono else SANS
        self.parts.append(
            f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="{fam}" '
            f'font-size="{size}" font-weight="{weight}" fill="{color}">{esc(s)}</text>')

    def render(self, path, preview=None):
        if preview:
            side = max(self.w, self.h)
            pad = (side - self.h) / 2
            body = "".join(self.parts)
            open(preview, "w").write(
                f'<svg xmlns="http://www.w3.org/2000/svg" width="{side}" height="{side}">'
                f'<defs>{self._markers()}</defs>'
                f'<rect width="{side}" height="{side}" fill="{BG}"/>'
                f'<g transform="translate(0,{pad:.0f})">{body}</g></svg>')
        self._render(path)

    def _markers(self):
        return "".join(
            f'<marker id="{i}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" '
            f'markerHeight="6" orient="auto-start-reverse">'
            f'<path d="M 0 0 L 10 5 L 0 10 z" fill="{c}"/></marker>'
            for i, c in (("a", ACCENT), ("g", GOOD), ("r", BAD), ("m", MUTED)))

    def _render(self, path):
        markers = "".join(
            f'<marker id="{i}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" '
            f'markerHeight="6" orient="auto-start-reverse">'
            f'<path d="M 0 0 L 10 5 L 0 10 z" fill="{c}"/></marker>'
            for i, c in (("a", ACCENT), ("g", GOOD), ("r", BAD), ("m", MUTED)))
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" '
               f'viewBox="0 0 {self.w} {self.h}" role="img">'
               f'<defs>{markers}</defs>'
               f'<rect width="{self.w}" height="{self.h}" fill="{BG}"/>'
               + "".join(self.parts) + "</svg>")
        open(path, "w").write(svg)


# ---------------------------------------------------------------- swipe flow
s = Svg(1120, 900)
s.text(560, 48, "SwipeDeck — how one card leaves the deck", size=23, color=INK, weight="700")
s.text(560, 76, "a drag and a controller call take the same exit", size=14)

DRAG_X, CTRL_X, OUT_X = 380, 880, 620

s.box(DRAG_X, 135, 330, 56, ["drag on the top card"], fill=ACCENT_FILL, stroke=ACCENT_LINE)
s.box(CTRL_X, 135, 350, 56, ["controller.swipe(direction)"], fill=ACCENT_FILL,
      stroke=ACCENT_LINE, mono=True)

s.arrow(DRAG_X, 163, DRAG_X, 213)
s.box(DRAG_X, 250, 400, 70,
      ["_drag ValueNotifier += delta",
       "only the transforms and the overlay repaint"], mono=True)
s.arrow(DRAG_X, 285, DRAG_X, 333)

s.diamond(DRAG_X, 400, 430, 130,
          ["distance > threshold", "or", "velocity > velocityThreshold"])

s.parts.append(f'<path d="M 165 400 H 88 V 465" fill="none" stroke="{MUTED}" '
               f'stroke-width="2" marker-end="url(#m)"/>')
s.text(158, 388, "no", size=12.5, color=MUTED, anchor="end")
s.box(88, 505, 156, 80, ["snap back", "Tween(drag → 0)", "curve · duration"])

s.arrow(DRAG_X, 465, DRAG_X, 530)
s.text(DRAG_X + 14, 500, "yes", size=12.5, color=ACCENT, anchor="start")
s.box(DRAG_X, 570, 400, 74,
      ["resolve direction", "dominant axis ∩ allowedDirections"])

s.arrow(CTRL_X, 163, CTRL_X, 530)
s.box(CTRL_X, 570, 360, 74,
      ["direction allowed?", "ignored when not in allowedDirections"])

s.elbow(DRAG_X, 607, OUT_X - 35, 657)
s.elbow(CTRL_X, 607, OUT_X + 35, 657)

s.box(OUT_X, 700, 620, 84,
      ["fly out — Tween(drag → off-deck)",
       "from rest → programmaticCurve · programmaticDuration",
       "released drag → curve · duration"],
      fill=ACCENT_FILL, stroke=ACCENT_LINE)
s.arrow(OUT_X, 742, OUT_X, 782)

s.box(OUT_X, 818, 700, 66,
      ["onSwipe(index, item, direction) · history.push · index++",
       "loop ? index % length : onEnd() once past the last card"],
      fill=GOOD_FILL, stroke="#BFE7D6", title_size=14)

s.box(130, 818, 230, 92,
      ["undo()", "history.pop · index--", "Tween(off-deck → 0)", "onUndo(...)"])
s.arrow(270, 818, 250, 818, color=MUTED, marker="m", dashed=True)

s.render("/Users/mohiuddin/Projects/flutter_swipe_deck/doc/swipe-flow.svg",
         preview="/tmp/prev-swipe.svg")

# ------------------------------------------------------------ pagination flow
p = Svg(1120, 900)
p.text(560, 48, "PagedSwipeDeck — how the deck stays full", size=23, color=INK, weight="700")
p.text(560, 76, "one buffer, one request in flight, a window that never grows", size=14)

cell_w, cell_h, left, top = 82, 58, 190, 116
labels = ["✓", "✓", "✓", "✓", "TOP", "", "", "", "", ""]
for i, label in enumerate(labels):
    swiped, is_top = i < 4, i == 4
    fill = FILL if swiped else (ACCENT_FILL if is_top else BG)
    stroke = LINE if swiped else (ACCENT if is_top else ACCENT_LINE)
    x = left + i * cell_w
    p.parts.append(
        f'<rect x="{x}" y="{top}" width="{cell_w-8}" height="{cell_h}" rx="9" fill="{fill}" '
        f'stroke="{stroke}" stroke-width="{2.2 if is_top else 1.5}"/>')
    if label:
        p.text(x + (cell_w - 8) / 2, top + 36, label, size=15,
               color=ACCENT if is_top else MUTED, weight="700")

p.text(left - 16, top + 30, "buffer", size=13.5, color=INK, anchor="end", weight="700")
p.text(left - 16, top + 50, "paginator.items", size=11.5, color=MUTED, anchor="end", mono=True)
p.text(left + 4 * cell_w + 37, top - 14, "cursor = currentIndex", size=12.5, color=ACCENT, mono=True)


def bracket(i1, i2, label, color):
    x1, x2 = left + i1 * cell_w, left + i2 * cell_w - 8
    y = top + cell_h + 10
    p.parts.append(
        f'<path d="M {x1} {y} v 9 H {x2} v -9" fill="none" stroke="{color}" stroke-width="1.5"/>')
    p.text((x1 + x2) / 2, y + 32, label, size=12.5, color=color, mono=True)


bracket(0, 2, "dropped", MUTED)
bracket(2, 4, "keepBehind", MUTED)
bracket(5, 10, "remaining", ACCENT)
p.text(560, 262,
       "the front is trimmed once the buffer passes maxBufferedItems — keepBehind cards stay, so undo still works",
       size=12.5)

p.text(560, 320, "every swipe →  _pump()", size=16.5, color=INK, weight="700", mono=True)
p.parts.append(f'<path d="M 560 334 V 358 H 300 V 386" fill="none" stroke="{ACCENT}" '
               f'stroke-width="2" marker-end="url(#a)"/>')
p.parts.append(f'<path d="M 560 334 V 358 H 820 V 386" fill="none" stroke="{ACCENT}" '
               f'stroke-width="2" marker-end="url(#a)"/>')

p.box(300, 430, 470, 92,
      ["1 · trim   (maxBufferedItems)",
       "drop (cursor − keepBehind) from the front",
       "paginator.trimLeading + controller.trimLeading"], mono=True, title_size=14)
p.box(820, 430, 430, 92,
      ["2 · prefetch   (prefetchThreshold)",
       "remaining ≤ threshold ∧ !loading",
       "∧ hasMore ∧ !error"], mono=True, title_size=14)

p.parts.append(f'<path d="M 820 476 V 512 H 560 V 546" fill="none" stroke="{ACCENT}" '
               f'stroke-width="2" marker-end="url(#a)"/>')
p.box(560, 586, 440, 70,
      ["fetcher(page, cursor)", "one request in flight at a time"],
      fill=ACCENT_FILL, stroke=ACCENT_LINE, mono=True, title_size=15)

for x, marker, color in ((205, "g", GOOD), (560, "m", MUTED), (915, "r", BAD)):
    p.parts.append(f'<path d="M 560 621 V 660 H {x} V 692" fill="none" stroke="{color}" '
                   f'stroke-width="2" marker-end="url(#{marker})"/>')

p.box(205, 748, 340, 112,
      ["items → append", "page++", "cursor = nextCursor", "keep swiping, no wait"],
      fill=GOOD_FILL, stroke="#BFE7D6", mono=True, title_size=14)
p.box(560, 748, 320, 112,
      ["done → onEnd() once", "empty page", "hasMore: false", "page > maxPage"],
      mono=True, title_size=14)
p.box(915, 748, 340, 112,
      ["throws → loop pauses", "errorBuilder(error, retry)", "retry() resumes",
       "the same page"],
      fill=BAD_FILL, stroke="#F5C6C6", mono=True, title_size=14, title_color=BAD)

p.text(560, 862, "maxPage, maxBufferedItems and keepBehind are optional — without them the deck pages until the source says it is done.",
       size=13)

p.render("/Users/mohiuddin/Projects/flutter_swipe_deck/doc/pagination-flow.svg",
         preview="/tmp/prev-pagination.svg")
print("written")
