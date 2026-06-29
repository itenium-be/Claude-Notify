#!/usr/bin/env python3
"""Normalize raw mascot frames so the creature is the same torso size and shares
a common feet-baseline + horizontal center across every animation.

Input : mascots_raw/<anim>/frame_*.png  (raw, varying zoom/canvas per clip)
Output: mascots/<anim>/frame_*.png       (uniform canvas, creature anchored)
        mascots/anchor.json              (geometry the WPF popup reads)

The creature body is segmented by its terracotta colour, so confetti specks and
the checkered flag never skew the bbox. Torso widths are hand-measured (legs are
spindly and pose-dependent, so an auto bbox over-counts them).
"""
from PIL import Image
import numpy as np, glob, os, json

# Only the wired (choreographed) clips define the shared canvas + anchor, so adding
# spare clips can never shift the live phases. Extras are fitted into that canvas.
CANVAS_ANIMS = ['looking', 'jump', 'confetti', 'flag', 'walking']
ANIMS = CANVAS_ANIMS + ['gym', 'horizontal-jump']
TORSO = {'looking': 184, 'jump': 101, 'confetti': 93, 'flag': 97, 'walking': 151,
         'gym': 153, 'horizontal-jump': 157}  # core: hand-measured torso; extras: matched to looking body height
TARGET = TORSO['looking']  # scale every clip's torso to the (approved) looking size
SRC, DST = 'mascots_raw', 'mascots'

def body_bbox(im):
    a = np.array(im.convert('RGBA'))
    r, g, b, al = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int), a[..., 3]
    m = (al > 128) & (r > 140) & (r - b > 45) & (r > g) & (g > b) & (g > 60)
    cols = np.where(m.sum(0) > 10)[0]; rows = np.where(m.sum(1) > 10)[0]
    if not len(cols) or not len(rows): return None
    return (cols.min(), rows.min(), cols.max(), rows.max())

data = {}
for d in ANIMS:
    files = sorted(glob.glob(f'{SRC}/{d}/frame_*.png'))
    frames = [Image.open(f).convert('RGBA') for f in files]
    bbs = [body_bbox(im) for im in frames]
    ref = max((bb for bb in bbs if bb), key=lambda bb: bb[3])  # grounded pose = lowest feet
    data[d] = dict(files=files, frames=frames, scale=TARGET / TORSO[d],
                   ref_cx=(ref[0] + ref[2]) / 2.0, ref_y1=ref[3])

# Anchored coords: torso-center x = 0, feet baseline y = 0. Render a set of clips
# onto one canvas sized to their union extent, anchored so the creature lines up.
def render(anims, anchor_path):
    minX = minY = 1e9; maxX = maxY = -1e9
    for d in anims:
        s, cx, y1 = data[d]['scale'], data[d]['ref_cx'], data[d]['ref_y1']
        for im in data[d]['frames']:
            w, h = im.size
            for px, py in [(0, 0), (w, 0), (0, h), (w, h)]:
                X, Y = (px - cx) * s, (py - y1) * s
                minX, maxX = min(minX, X), max(maxX, X)
                minY, maxY = min(minY, Y), max(maxY, Y)
    CW, CH = int(np.ceil(maxX - minX)) + 2, int(np.ceil(maxY - minY)) + 2
    ax, ay = -minX, -minY
    for d in anims:
        s, cx, y1 = data[d]['scale'], data[d]['ref_cx'], data[d]['ref_y1']
        outdir = f'{DST}/{d}'; os.makedirs(outdir, exist_ok=True)
        ox, oy = round(ax - cx * s), round(ay - y1 * s)
        for f, im in zip(data[d]['files'], data[d]['frames']):
            sc = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.NEAREST)
            canvas = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
            canvas.alpha_composite(sc, (ox, oy))
            canvas.save(os.path.join(outdir, os.path.basename(f)))
    cfg = dict(canvasW=CW, canvasH=CH, anchorX=round(ax / CW, 4), anchorY=round(ay / CH, 4))
    os.makedirs(os.path.dirname(anchor_path) or '.', exist_ok=True)
    json.dump(cfg, open(anchor_path, 'w'), indent=2)
    return cfg

# Core clips share one canvas + anchor (the live choreography swaps between them in a
# single Image, so they must line up). Spare clips each get their own canvas so a wide
# pose can't be clipped, with geometry recorded per-dir for if/when they get wired.
print('core:', render(CANVAS_ANIMS, f'{DST}/anchor.json'))
for d in ANIMS:
    if d not in CANVAS_ANIMS:
        print(f'{d}:', render([d], f'{DST}/{d}/anchor.json'))
print('scales:', {d: round(data[d]['scale'], 2) for d in ANIMS})
