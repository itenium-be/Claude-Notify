#!/usr/bin/env python3
"""Extract clips from walk-jumper2.mp4 into mascots_raw/<name>/.

The source is idle -> walk(L->R) -> idle -> horizontal jump(L->R). Both useful
segments travel across the frame, so each is cropped to a fixed Y window (keeps
the natural vertical motion: walk bob / jump arc) and centered on the body in X
(in-place, so the WPF side controls travel). The light-gray video background is
keyed to transparent. Output feeds normalize-mascots.py like any other raw clip.
"""
from PIL import Image
import numpy as np, subprocess, tempfile, os, glob

MP4 = os.environ.get('WALK_MP4', '../mascot-animations/walk-jumper2.mp4')
SEGMENTS = {
    # name              start  end   W    y0   y1     (1-based frames, inclusive)
    'walking':         dict(start=120, end=179, W=300, y0=355, y1=600),  # 5 gait cycles
    'horizontal-jump': dict(start=286, end=310, W=360, y0=220, y1=600),  # takeoff -> land
}

def keyed_crop(path, W, y0, y1):
    a = np.array(Image.open(path).convert('RGB')).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    bright = (r + g + b) / 3; spread = a.max(2) - a.min(2)
    body = (r > 140) & (r - b > 45) & (r > g) & (g > b) & (g > 60)
    bg = (bright > 205) & (spread < 22) & ~body          # gray bg + anti-alias halo
    cols = np.where(body.sum(0) > 8)[0]
    cx = (cols.min() + cols.max()) // 2
    rgba = np.dstack([a.astype(np.uint8), np.where(bg, 0, 255).astype(np.uint8)])
    x0 = cx - W // 2
    return Image.fromarray(rgba, 'RGBA').crop((x0, y0, x0 + W, y1))

with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(['ffmpeg', '-v', 'error', '-i', MP4, f'{tmp}/f_%03d.png'], check=True)
    for name, s in SEGMENTS.items():
        dst = f'mascots_raw/{name}'
        os.makedirs(dst, exist_ok=True)
        for f in glob.glob(f'{dst}/frame_*.png'): os.remove(f)
        for out, n in enumerate(range(s['start'], s['end'] + 1), start=1):
            keyed_crop(f'{tmp}/f_{n:03d}.png', s['W'], s['y0'], s['y1']).save(f'{dst}/frame_{out:03d}.png')
        print(f"wrote {s['end'] - s['start'] + 1} frames -> {dst}")
