# Themeable notification popup — design

## Problem

`show-notification.ps1` hardcodes every visual choice: the rainbow rim gradient,
the dark card colour, the big unicorn (🦄) background emoji and its gradient, the
per-event label/accent/sound, the needs-input handwave (👋) emoji, and the
done→confetti / needs-input→flag mascot map. Changing the look means editing XAML
literals. We want this driven by a config file with multiple selectable themes.

## Goal

Move the styling into a `settings.json` next to the renderer. Ship 9 themes.
Keep the renderer's geometry, timings, and the Claude block-glyph logo hardcoded
(out of scope). Deleting `settings.json` must reproduce today's exact look.

## Format

**JSON** (`settings.json`), parsed with PowerShell's native `ConvertFrom-Json`.
No third-party module (rules out YAML). Plain JSON, no comments — `ConvertFrom-Json`
only tolerates comments on PS7+ and the renderer must run on Windows PowerShell 5.1.

File location: `<script dir>/settings.json` (resolved via `$PSScriptRoot`).

## Model

Two concepts, split by what they own:

- **theme** — the look shared across all events:
  - `hero` — big background emoji (the 🦄 slot)
  - `gradient` — fills **both** the hero and the indicator emoji (one gradient keeps themes short)
  - `rim` — the spinning border gradient
  - `card` — card background colour
  - `palette` — array of hex colours the fireworks/particle effect cycles through
- **event** (`needs-input`, `done`) — per-event content:
  - `label` — status text
  - `accent` — status text colour
  - `indicator` — an emoji (renders in the right box and waves) **or** the keyword
    `"fireworks"` (renders the particle burst, also the mascot-missing fallback)
  - `mascot` — PNG flipbook folder under `mascots/` (left slot)
  - `sound` — `"exclamation"`, `"asterisk"`, or a path to a `.wav`

Top-level `activeTheme` selects the theme by name, or `"random"` to pick a
different theme on each popup.

### Gradient stop encoding

Each stop is a compact `"#RRGGBB offset"` string (offset 0..1), so a gradient
reads as a scannable ordered list. Parsing: split on whitespace → `(color, offset)`.

## Schema

```json
{
  "activeTheme": "unicorn",
  "events": {
    "needs-input": { "label": "Needs you", "accent": "#FF7A18", "indicator": "👋",        "mascot": "flag",     "sound": "exclamation" },
    "done":        { "label": "Done!",     "accent": "#22C55E", "indicator": "fireworks", "mascot": "confetti", "sound": "asterisk" }
  },
  "themes": {
    "<name>": {
      "hero": "🦄",
      "gradient": ["#hex offset", ...],
      "rim":      ["#hex offset", ...],
      "card": "#hex",
      "palette": ["#hex", ...]
    }
  }
}
```

## Themes

All cards are near-black tuned to the palette. Gradient = hero + indicator fill.
Rim = border. Palette = particle colours. (Colours are a starting point; tune by
eye after first render.)

| Name      | Hero | Mood                                   | Card      |
|-----------|------|----------------------------------------|-----------|
| unicorn   | 🦄   | full rainbow (existing)                | `#18181B` |
| cosmic    | 🚀   | indigo → violet → cyan neon            | `#0B0B1A` |
| ocean     | 🐳   | teal → aqua → blue                     | `#0A1620` |
| sakura    | 🌸   | pastel pink → rose → lilac             | `#1A1620` |
| matrix    | 👾   | black + phosphor green                 | `#050A05` |
| dragon    | 🐉   | ember red → orange → gold              | `#1A0F0A` |
| vaporwave | 🌴   | hot pink → purple → cyan retro         | `#160F1F` |
| robot     | 🤖   | steel → cyan chrome                    | `#0E141B` |
| spooky    | 🎃   | orange → purple → black                | `#100A14` |

```json
"unicorn": {
  "hero": "🦄",
  "gradient": ["#FF5F6D 0", "#FFC371 0.28", "#3CFFB0 0.5", "#36D1DC 0.72", "#A56BFF 1"],
  "rim": ["#7C3AED 0", "#2563EB 0.17", "#06B6D4 0.34", "#22C55E 0.5", "#EAB308 0.67", "#F97316 0.84", "#EC4899 1"],
  "card": "#18181B",
  "palette": ["#FF5F6D", "#FFC371", "#FFD93D", "#3CFFB0", "#36D1DC", "#A56BFF", "#EC4899"]
},
"cosmic": {
  "hero": "🚀",
  "gradient": ["#3A1C71 0", "#5B2A86 0.3", "#7B2FF7 0.55", "#2C7DFA 0.8", "#22D3EE 1"],
  "rim": ["#1E1B4B 0", "#4338CA 0.25", "#7C3AED 0.5", "#2563EB 0.75", "#06B6D4 1"],
  "card": "#0B0B1A",
  "palette": ["#A78BFA", "#7C3AED", "#22D3EE", "#2563EB", "#E879F9", "#F0ABFC"]
},
"ocean": {
  "hero": "🐳",
  "gradient": ["#0EA5E9 0", "#22D3EE 0.3", "#2DD4BF 0.6", "#14B8A6 0.8", "#0891B2 1"],
  "rim": ["#0C4A6E 0", "#0369A1 0.25", "#0891B2 0.5", "#06B6D4 0.75", "#14B8A6 1"],
  "card": "#0A1620",
  "palette": ["#7DD3FC", "#22D3EE", "#2DD4BF", "#5EEAD4", "#38BDF8"]
},
"sakura": {
  "hero": "🌸",
  "gradient": ["#FF8FB1 0", "#FFB7C5 0.3", "#FBC2EB 0.6", "#E0AAFF 0.85", "#C8A2FF 1"],
  "rim": ["#DB2777 0", "#EC4899 0.25", "#F472B6 0.5", "#E879F9 0.75", "#C084FC 1"],
  "card": "#1A1620",
  "palette": ["#FBCFE8", "#F9A8D4", "#F472B6", "#E9D5FF", "#C4B5FD"]
},
"matrix": {
  "hero": "👾",
  "gradient": ["#00FF41 0", "#22C55E 0.35", "#16A34A 0.6", "#00C853 0.8", "#39FF14 1"],
  "rim": ["#052E16 0", "#14532D 0.25", "#16A34A 0.5", "#22C55E 0.75", "#4ADE80 1"],
  "card": "#050A05",
  "palette": ["#39FF14", "#22C55E", "#4ADE80", "#86EFAC", "#00FF41"]
},
"dragon": {
  "hero": "🐉",
  "gradient": ["#7F1D1D 0", "#DC2626 0.3", "#F97316 0.6", "#FBBF24 0.85", "#FDE047 1"],
  "rim": ["#450A0A 0", "#991B1B 0.25", "#DC2626 0.5", "#EA580C 0.75", "#F59E0B 1"],
  "card": "#1A0F0A",
  "palette": ["#FCA5A5", "#F87171", "#FB923C", "#FBBF24", "#FDE047"]
},
"vaporwave": {
  "hero": "🌴",
  "gradient": ["#FF6AD5 0", "#C774E8 0.3", "#AD8CFF 0.55", "#8795E8 0.8", "#94D0FF 1"],
  "rim": ["#FF71CE 0", "#B967FF 0.25", "#01CDFE 0.5", "#05FFA1 0.75", "#FFFB96 1"],
  "card": "#160F1F",
  "palette": ["#FF6AD5", "#C774E8", "#AD8CFF", "#8795E8", "#94D0FF"]
},
"robot": {
  "hero": "🤖",
  "gradient": ["#94A3B8 0", "#64748B 0.3", "#38BDF8 0.6", "#0EA5E9 0.8", "#22D3EE 1"],
  "rim": ["#1E293B 0", "#334155 0.25", "#475569 0.5", "#0EA5E9 0.75", "#38BDF8 1"],
  "card": "#0E141B",
  "palette": ["#CBD5E1", "#94A3B8", "#38BDF8", "#22D3EE", "#7DD3FC"]
},
"spooky": {
  "hero": "🎃",
  "gradient": ["#F97316 0", "#EA580C 0.3", "#7C2D12 0.55", "#6B21A8 0.8", "#4C1D95 1"],
  "rim": ["#7C2D12 0", "#9A3412 0.25", "#EA580C 0.5", "#6B21A8 0.75", "#4C1D95 1"],
  "card": "#100A14",
  "palette": ["#FB923C", "#F97316", "#A855F7", "#7C3AED", "#FDE047"]
}
```

## Rendering changes (`show-notification.ps1`)

1. After param parsing, load config: `$cfg = Get-NotifyConfig $PSScriptRoot`.
   `Get-NotifyConfig` reads `settings.json` if present and merges it over a
   built-in `$DEFAULTS` hashtable (the current hardcoded unicorn theme + both
   events). Missing file / parse error → `$DEFAULTS` unchanged.
2. Resolve `$theme`: `activeTheme`, or a random theme name when `"random"`, or
   `unicorn` when the named theme is absent. Resolve `$ev = events[$Event]` with
   the same field-level fallback to defaults.
3. Build XAML fragments from `$theme`/`$ev`:
   - `New-GradientStops $stops` → `<GradientStop .../>` lines for hero, rim, indicator.
   - hero `<TextBlock Text>` ← `$theme.hero`; rim/hero/indicator brushes ← parsed stops.
   - card `Background` ← `$theme.card`.
   - status text/colour ← `$ev.label` / `$ev.accent`.
   - indicator: emoji → the existing waving `Rectangle`+`OpacityMask` block with
     `$theme.gradient`; `"fireworks"` → the `fx` canvas (particles use `$theme.palette`).
   - `Start-Fireworks` reads `$theme.palette` instead of the literal array.
   - mascot folder ← `$ev.mascot`; sound ← `$ev.sound`.

The block-glyph Claude logo, window size/position, fade/spin/wave timings, and the
mascot flipbook framerate stay hardcoded.

## Components

| Unit                | Responsibility                                                        |
|---------------------|-----------------------------------------------------------------------|
| `settings.json`     | All theme + event data. The only file a user edits to restyle.        |
| `$DEFAULTS`         | In-script fallback identical to today's look; used when config absent. |
| `Get-NotifyConfig`  | Read + parse + merge config over `$DEFAULTS`. Never throws.            |
| `New-GradientStops` | `["#hex off", ...]` → XAML `<GradientStop>` lines.                     |
| XAML build          | Inline theme/event values into the existing layout.                   |

## Error handling

- No `settings.json` → use `$DEFAULTS` (today's look). No error surfaced.
- Malformed JSON → catch, warn to stderr, use `$DEFAULTS`. Popup still shows.
- Unknown `activeTheme` → fall back to `unicorn`.
- Missing event or field → fall back to that field's default.
- Bad gradient stop (no parseable `#hex offset`) → skip that stop; if a gradient
  ends up empty, use the default theme's corresponding gradient.

## Testing / verification

PowerShell + WPF has no unit harness here; verification is layered:

1. **Config parse smoke** — `ConvertFrom-Json` on `settings.json` succeeds and
   yields `activeTheme`, `events`, `themes` (run via `powershell.exe`, assert no throw).
2. **Default-equivalence** — with no `settings.json`, the rendered XAML string for
   `needs-input`/`done` is byte-identical to the pre-change output (capture the
   built `$xaml` behind a `-EmitXaml` debug switch; diff against a golden file).
3. **Per-theme render** — loop the 9 themes through the acceptance command, assert
   exit 0 and no error output for each.
4. **Visual check** — render 2–3 themes for both events, screenshot, eyeball:
   correct hero emoji, rim/card colours, indicator matches theme, mascot intact.

## Acceptance

```
powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(wslpath -w /mnt/c/temp/notify/show-notification.ps1)" \
  -Hwnd 0 -Folder demo -Event needs-input -Seconds 8
```

runs clean (exit 0) for each `activeTheme`, and removing `settings.json` reproduces
the current look exactly.

## Out of scope

Window geometry, timings, the Claude block-glyph logo, the mascot PNG frames
themselves, and per-theme mascot overrides (events keep one mascot folder each).
```
