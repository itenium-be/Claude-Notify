#!/usr/bin/env python3
"""Extract the walk cycle from walk-jumper2.mp4 into mascots_raw/walking/.

The clip is idle -> walk(L->R) -> idle -> jump. Frames 120-179 are five clean
gait cycles (~12 frames each). Each frame is cropped to a fixed Y window (keeps
the natural walk bob) and centered on the body in X (walk-in-place, so the WPF
side controls travel), with the light-gray video background keyed to transparent.

Output feeds normalize-mascots.py like any other raw clip.
"""
from PIL import Image
import numpy as np, subprocess, tempfile, os, glob

MP4 = os.environ.get('WALK_MP4', '../mascot-animations/walk-jumper2.mp4')
START, END = 120, 179            # 1-based, inclusive: 5 gait cycles
W, Y0, Y1 = 300, 355, 600        # crop window (fixed Y preserves the bob)
DST = 'mascots_raw/walking'

def keyed_crop(path):
    a = np.array(Image.open(path).convert('RGB')).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    bright = (r + g + b) / 3; spread = a.max(2) - a.min(2)
    body = (r > 140) & (r - b > 45) & (r > g) & (g > b) & (g > 60)
    bg = (bright > 205) & (spread < 22) & ~body          # gray bg + anti-alias halo
    cols = np.where(body.sum(0) > 8)[0]
    cx = (cols.min() + cols.max()) // 2
    rgba = np.dstack([a.astype(np.uint8), np.where(bg, 0, 255).astype(np.uint8)])
    x0 = cx - W // 2
    return Image.fromarray(rgba, 'RGBA').crop((x0, Y0, x0 + W, Y1))

os.makedirs(DST, exist_ok=True)
for f in glob.glob(f'{DST}/frame_*.png'): os.remove(f)
with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(['ffmpeg', '-v', 'error', '-i', MP4, f'{tmp}/f_%03d.png'], check=True)
    for out, n in enumerate(range(START, END + 1), start=1):
        keyed_crop(f'{tmp}/f_{n:03d}.png').save(f'{DST}/frame_{out:03d}.png')
print(f'wrote {END - START + 1} frames -> {DST}')
