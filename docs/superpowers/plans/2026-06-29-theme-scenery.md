# Theme Scenery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a config-driven, animated per-theme scenery layer and ship the first scene — ocean → drifting waves — without changing the look of any theme that opts out.

**Architecture:** A theme gains an optional `scene` object in `settings.json`. `Resolve-Theme` passes it through. `New-NotificationBox` emits a `scene` Canvas inside the card (only when a scene exists) as the first child, so it paints behind the hero watermark while content stays on top. The orchestrator dot-sources scene renderers, resolves scene colours from the theme gradient, and dispatches by `kind` from a `Loaded` handler. The `waves` renderer builds layered sine-wave `Path`s (geometry from a pure, unit-tested helper) and scrolls each horizontally for a seamless parallax loop.

**Tech Stack:** Windows PowerShell 5.1, WPF, WSL interop (`powershell.exe`, `wslpath`), `jq`.

---

## File Structure

| Path                                | Responsibility                                                        |
|-------------------------------------|----------------------------------------------------------------------|
| `notify-lib.ps1`                    | `Resolve-Theme` passes `scene` through (pure, unit-tested)            |
| `lib/scene-waves.ps1`               | NEW — `New-WavePathData` (pure geometry) + `Start-Waves` (WPF render) |
| `lib/notification-box.ps1`          | conditional `scene` Canvas; expose `$box.Scene`                       |
| `show-notification.ps1`             | dot-source scene lib; resolve scene cfg; dispatch by `kind`           |
| `settings.json`                     | add `scene` to the `ocean` theme                                      |
| `settings.schema.json`              | add `scene` definition (editor metadata)                             |
| `tests/notify-lib.Tests.ps1`        | scene passthrough assertions                                          |
| `tests/scene-waves.Tests.ps1`       | NEW — `New-WavePathData` assertions                                   |
| `tests/scene.Tests.sh`              | NEW — `-EmitXaml` scene-Canvas presence/absence                       |
| `tests/settings.Tests.sh`           | assert `ocean.scene.kind == waves`                                    |

**Test commands used throughout** (run from repo root `/mnt/c/temp/notify`):

```bash
# PowerShell unit tests
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w tests/notify-lib.Tests.ps1)" | tr -d '\r'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w tests/scene-waves.Tests.ps1)" | tr -d '\r'
# Bash tests
bash tests/settings.Tests.sh
bash tests/scene.Tests.sh
bash tests/show-notification.Tests.sh   # golden default-equivalence (must stay green)
```

---

## Task 1: `New-WavePathData` — pure wave geometry helper

**Files:**
- Create: `lib/scene-waves.ps1`
- Test: `tests/scene-waves.Tests.ps1`

- [ ] **Step 1: Write the failing test**

Create `tests/scene-waves.Tests.ps1`:

```powershell
. "$PSScriptRoot\..\lib\scene-waves.ps1"

$script:fail = 0
function Assert-Eq($got, $exp, $msg) {
  if ("$got" -ne "$exp") { Write-Host "FAIL: $msg`n  exp=[$exp]`n  got=[$got]"; $script:fail++ }
  else { Write-Host "ok: $msg" }
}
function Assert-True($cond, $msg) { Assert-Eq ([bool]$cond) $true $msg }

# width=20, period=8, amp=2, top=10.5, bottom=30, step=5 -> samples x=0,5,10,15,20 (5 pts)
$d = New-WavePathData 20 8 2 10.5 30 5

Assert-True ($d.StartsWith('M')) "path starts with M (moveto)"
Assert-True ($d.TrimEnd().EndsWith('Z')) "path is closed with Z"
# 4 crest line segments (pts 2..5) + 2 closing corners = 6 'L ' tokens
Assert-Eq ([regex]::Matches($d, 'L ').Count) 6 "expected line-segment count"
# Invariant decimals: XAML needs '.', NOT the ',' a Belgian (nl-BE) locale would emit
Assert-True ($d.Contains('10.5')) "uses '.' decimal separator"
Assert-True (-not $d.Contains('10,5')) "does not use ',' decimal separator"

# step<=0 is coerced to a safe default (no infinite loop, still produces a path)
$d2 = New-WavePathData 12 6 1 5 20 0
Assert-True ($d2.StartsWith('M')) "step<=0 still yields a path"

if ($script:fail -gt 0) { exit 1 } else { Write-Host "ALL PASS" }
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w tests/scene-waves.Tests.ps1)" | tr -d '\r'`
Expected: FAIL — `New-WavePathData` is not defined (dot-source of an empty/missing file).

- [ ] **Step 3: Write the minimal implementation**

Create `lib/scene-waves.ps1` with the pure helper (renderer added in Task 2):

```powershell
# Scenery renderer: ocean "waves". New-WavePathData is WPF-free + unit-tested;
# Start-Waves (Task 2) consumes it. Dot-sourced by show-notification.ps1.

# Build XAML path geometry for one wave layer: a sine crest closed down to the
# card's bottom edge so it reads as a filled body of water. The path spans $width
# (caller makes it wider than the card by one period) so a -period horizontal
# scroll loops seamlessly. Coordinates are formatted with the invariant culture:
# XAML requires '.' decimals, but a nl-BE locale would otherwise emit ',' and
# Geometry.Parse would choke.
function New-WavePathData([double]$width, [double]$period, [double]$amp, [double]$top, [double]$bottom, [double]$step) {
  $ic = [System.Globalization.CultureInfo]::InvariantCulture
  if ($step -le 0) { $step = 4 }
  if ($period -le 0) { $period = 1 }
  $sb = New-Object System.Text.StringBuilder
  $x = 0.0; $first = $true
  while ($x -le $width) {
    $y = $top + $amp * [Math]::Sin(2 * [Math]::PI * $x / $period)
    $cmd = if ($first) { 'M' } else { 'L' }
    [void]$sb.Append(("{0} {1},{2} " -f $cmd, $x.ToString('0.##', $ic), $y.ToString('0.##', $ic)))
    $first = $false
    $x += $step
  }
  [void]$sb.Append(("L {0},{1} " -f $width.ToString('0.##', $ic), $bottom.ToString('0.##', $ic)))
  [void]$sb.Append(("L 0,{0} Z" -f $bottom.ToString('0.##', $ic)))
  $sb.ToString()
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w tests/scene-waves.Tests.ps1)" | tr -d '\r'`
Expected: `ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add lib/scene-waves.ps1 tests/scene-waves.Tests.ps1
git commit -m "Add wave path geometry helper"
```

---

## Task 2: `Start-Waves` — animated WPF wave renderer

**Files:**
- Modify: `lib/scene-waves.ps1`

No new unit test: `Start-Waves` builds live WPF objects and animations that only
exist under a rendered window. It is exercised by the `-EmitXaml` presence test
(Task 5), the per-theme render check, and the visual check (Task 8). `New-Brush`
is provided by `lib/notification-box.ps1`, dot-sourced before this file at runtime.

- [ ] **Step 1: Append the renderer to `lib/scene-waves.ps1`**

```powershell
# Render + animate the waves into $box.Scene. $cfg: @{ colors=@('#..'); opacity=<0..1>; speed=<num> }.
# Called from a Loaded handler so $box.Card.ActualWidth/Height are known.
function Start-Waves($box, $cfg) {
  $canvas = $box.Scene
  if ($null -eq $canvas) { return }
  $card = $box.Card
  $w = [double]$card.ActualWidth; $h = [double]$card.ActualHeight
  if ($w -le 0 -or $h -le 0) { return }

  $colors = @($cfg.colors); if ($colors.Count -eq 0) { $colors = @('#0EA5E9', '#22D3EE', '#2DD4BF') }
  $opacity = [double]$cfg.opacity; if ($opacity -le 0) { $opacity = 0.22 }
  $speed = [double]$cfg.speed; if ($speed -le 0) { $speed = 1.0 }

  $canvas.Width = $w; $canvas.Height = $h; $canvas.Opacity = $opacity

  # Three layers: back (slow/tall) to front (fast/short) for parallax depth.
  $layers = @(
    @{ amp = 10; period = ($w * 0.90); top = ($h * 0.78); dur = 13 },
    @{ amp = 8;  period = ($w * 0.60); top = ($h * 0.85); dur = 9 },
    @{ amp = 6;  period = ($w * 0.45); top = ($h * 0.92); dur = 6 }
  )
  for ($i = 0; $i -lt $layers.Count; $i++) {
    $L = $layers[$i]
    $pathW = $w + $L.period   # one extra period so the -period scroll never reveals an edge
    $data = New-WavePathData $pathW $L.period $L.amp $L.top $h ([Math]::Max(4.0, $L.period / 24.0))
    $path = New-Object System.Windows.Shapes.Path
    $path.Data = [System.Windows.Media.Geometry]::Parse($data)
    $path.Fill = New-Brush ($colors[$i % $colors.Count])
    $path.Opacity = 0.6   # per-layer translucency, multiplies the canvas opacity
    [System.Windows.Controls.Canvas]::SetLeft($path, 0)
    [System.Windows.Controls.Canvas]::SetTop($path, 0)
    $tt = New-Object System.Windows.Media.TranslateTransform
    $path.RenderTransform = $tt
    $canvas.Children.Add($path) | Out-Null

    $dur = [System.Windows.Duration][TimeSpan]::FromSeconds($L.dur / $speed)
    $anim = New-Object System.Windows.Media.Animation.DoubleAnimation 0, (-$L.period), $dur
    $anim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
    $tt.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $anim)
  }
}
```

- [ ] **Step 2: Re-run the geometry tests (no regression)**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w tests/scene-waves.Tests.ps1)" | tr -d '\r'`
Expected: `ALL PASS` (dot-sourcing the file with the new function still parses).

- [ ] **Step 3: Commit**

```bash
git add lib/scene-waves.ps1
git commit -m "Add animated waves renderer"
```

---

## Task 3: `Resolve-Theme` passes `scene` through

**Files:**
- Modify: `notify-lib.ps1` (function `Resolve-Theme`)
- Test: `tests/notify-lib.Tests.ps1`

- [ ] **Step 1: Add failing tests**

In `tests/notify-lib.Tests.ps1`, after the existing `$missing = Resolve-Theme $cfg 'nope'` block (around line 62), add a scened theme to the fixture and assert passthrough. First extend the fixture `themes` (add `scene` to `ocean`):

Change the fixture `ocean` line to include a scene:

```powershell
    ocean   = [pscustomobject]@{ hero = '🐳'; gradient = @('#0EA5E9 0', '#0891B2 1'); rim = @('#0C4A6E 0', '#14B8A6 1'); card = '#0A1620'; scene = [pscustomobject]@{ kind = 'waves' } }
```

Then add assertions after the `$missing` assertion:

```powershell
Assert-Eq (Resolve-Theme $cfg 'ocean').scene.kind 'waves' "resolve theme scene passthrough"
Assert-Eq ([string](Resolve-Theme $cfg 'unicorn').scene) '' "theme without scene -> null/empty"
Assert-Eq ([string](Resolve-Theme $cfg 'nope').scene) '' "unknown theme -> no scene"
```

- [ ] **Step 2: Run to verify it fails**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w tests/notify-lib.Tests.ps1)" | tr -d '\r'`
Expected: FAIL on `resolve theme scene passthrough` (the resolved hashtable has no `scene` key → empty).

- [ ] **Step 3: Implement — add `scene` to the returned hashtable**

In `notify-lib.ps1`, `Resolve-Theme`, add a `scene` entry (no default — absence is meaningful):

```powershell
function Resolve-Theme($cfg, [string]$name) {
  $def = (Get-NotifyDefaults).themes.unicorn
  $t = Get-Prop (Get-Prop $cfg 'themes') $name
  @{
    hero     = (Coalesce (Get-Prop $t 'hero')     $def.hero)
    gradient = @(Coalesce (Get-Prop $t 'gradient') $def.gradient)
    rim      = @(Coalesce (Get-Prop $t 'rim')      $def.rim)
    card     = (Coalesce (Get-Prop $t 'card')     $def.card)
    scene    = (Get-Prop $t 'scene')
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w tests/notify-lib.Tests.ps1)" | tr -d '\r'`
Expected: `ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add notify-lib.ps1 tests/notify-lib.Tests.ps1
git commit -m "Pass theme scene config through Resolve-Theme"
```

---

## Task 4: Conditional `scene` Canvas in `New-NotificationBox`

**Files:**
- Modify: `lib/notification-box.ps1`

Verified by Task 5's `-EmitXaml` test and by the golden default-equivalence test
(`tests/show-notification.Tests.sh`) which must stay byte-identical (the default
theme has no scene, so `$sceneBlock` is empty and the emitted XAML is unchanged).

- [ ] **Step 1: Build the conditional scene fragment**

In `New-NotificationBox`, after the `$indicatorBlock` if/elseif/else block and
before `$xaml = @"...`, add:

```powershell
  # Scenery Canvas is emitted ONLY when the theme opts in, so themes without a
  # scene render byte-identical XAML (keeps the golden default-equivalence test green).
  # Inserted as the card grid's first child: equal ZIndex -> document order paints
  # it behind the hero watermark; the content StackPanel (ZIndex 1) stays on top.
  if ($Theme.scene -and (Get-Prop $Theme.scene 'kind')) {
    $sceneBlock = '<Canvas x:Name="scene" Panel.ZIndex="0" ClipToBounds="True"/>'
  } else {
    $sceneBlock = ''
  }
```

- [ ] **Step 2: Inject the fragment as the card grid's first child**

In the XAML here-string, the card `<Grid>` currently opens directly into the
`<!-- Big rainbow unicorn ... -->` Rectangle. Insert `$sceneBlock` right after the
card grid's `<Grid>` open tag:

```xml
      <Border x:Name="card" CornerRadius="21" Margin="3" Background="$($Theme.card)" ClipToBounds="True">
        <Grid>
          $sceneBlock
          <!-- Big rainbow unicorn background, bleeding to the card edges (rounded clip
```

(Place `$sceneBlock` on its own line between `<Grid>` and the `<!-- Big rainbow ... -->`
comment. When empty it renders as a blank line — harmless and absent from the
no-scene golden because the golden was captured the same way; if the golden diff
flags whitespace, see Step 4.)

- [ ] **Step 3: Expose the canvas on the `$box` bag**

In the returned hashtable at the end of `New-NotificationBox`, add `Scene`:

```powershell
  return @{
    Win = $win; Card = $win.FindName('card'); Slot = $win.FindName('slot')
    Overlay = $win.FindName('overlay'); Mascot = $win.FindName('mascot')
    Scene = $win.FindName('scene')
    Event = $Event
  }
```

- [ ] **Step 4: Verify the golden default-equivalence test still passes**

Run: `bash tests/show-notification.Tests.sh`
Expected: `ok: default XAML matches golden`.
If it FAILs only on a blank line where `$sceneBlock` is empty, change the injection
to interpolate with no extra newline by putting `$sceneBlock` immediately after
`<Grid>` on the SAME line: `<Grid>$sceneBlock` — re-run until byte-identical.

- [ ] **Step 5: Commit**

```bash
git add lib/notification-box.ps1
git commit -m "Emit scene Canvas in the card when a theme opts in"
```

---

## Task 5: Dispatch the scene from `show-notification.ps1`

**Files:**
- Modify: `show-notification.ps1`
- Test: `tests/scene.Tests.sh`

- [ ] **Step 1: Write the failing presence/absence test**

Create `tests/scene.Tests.sh`:

```bash
#!/usr/bin/env bash
# Emits XAML for a scened theme and a plain theme; asserts the scene Canvas is
# present only for the scened one. Swaps settings.json aside (restored on exit),
# mirroring show-notification.Tests.sh, so it never depends on the live config.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
S="$ROOT/settings.json"
BAK="$(mktemp)"; HAD=0
if [[ -f "$S" ]]; then HAD=1; cp "$S" "$BAK"; fi
restore() { if [[ "$HAD" == 1 ]]; then cp "$BAK" "$S"; else rm -f "$S"; fi; rm -f "$BAK"; }
trap restore EXIT

emit() { powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(wslpath -w "$ROOT/show-notification.ps1")" -Event done -EmitXaml | tr -d '\r'; }

fail=0
check() { if eval "$2"; then echo "ok: $1"; else echo "FAIL: $1"; fail=1; fi; }

# Scened theme -> Canvas present
cat > "$S" <<'JSON'
{ "activeTheme": "t", "themes": { "t": { "scene": { "kind": "waves" } } } }
JSON
GOT="$(emit)"
check "scened theme emits scene Canvas" "grep -q 'x:Name=\"scene\"' <<<\"\$GOT\""

# Plain theme -> no Canvas
cat > "$S" <<'JSON'
{ "activeTheme": "t", "themes": { "t": {} } }
JSON
GOT="$(emit)"
check "plain theme omits scene Canvas" "! grep -q 'x:Name=\"scene\"' <<<\"\$GOT\""

exit $fail
```

Make it executable: `chmod +x tests/scene.Tests.sh`

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/scene.Tests.sh`
Expected: FAIL on `scened theme emits scene Canvas` — `lib\scene-waves.ps1` is not
yet dot-sourced, so `show-notification.ps1` throws before emitting (or the Canvas is
absent). (Task 4 already emits the Canvas, so this may pass for presence but the
dot-source line below is still required for the live render path; if Step 1 already
passes presence, proceed — Step 3 wires the runtime renderer.)

- [ ] **Step 3: Dot-source the scene lib**

In `show-notification.ps1`, in the dot-source block (after the other `lib\*.ps1`
includes, before `. (Join-Path $PSScriptRoot 'notify-lib.ps1')`), add:

```powershell
. (Join-Path $PSScriptRoot 'lib\scene-waves.ps1')
```

- [ ] **Step 4: Resolve scene cfg and dispatch from a Loaded handler**

In `show-notification.ps1`, after the existing mascot choreography `$win.Add_Loaded({ ... })`
block (the one starting `Start-JumpPrep`), add the scene resolution + dispatch:

```powershell
# --- Scenery: resolve the scene config and dispatch by kind (script scope, so the
# renderer functions are visible; a plain scriptblock avoids the closure-rebind trap). ---
$sceneCfg = $null
if ($theme.scene -and (Get-Prop $theme.scene 'kind')) {
  $sceneCols = @(Get-Prop $theme.scene 'colors')
  if (-not $sceneCols -or $sceneCols.Count -eq 0) { $sceneCols = @(Get-StopColors $theme.gradient) }
  $sceneCfg = @{
    kind    = [string](Get-Prop $theme.scene 'kind')
    colors  = $sceneCols
    opacity = (Coalesce (Get-Prop $theme.scene 'opacity') 0.22)
    speed   = (Coalesce (Get-Prop $theme.scene 'speed')   1.0)
  }
}
$sceneKinds = @{ waves = { param($b, $c) Start-Waves $b $c } }
$win.Add_Loaded({
  if ($sceneCfg) {
    $fn = $sceneKinds[$sceneCfg.kind]
    if ($fn) { try { & $fn $box $sceneCfg } catch { Write-Warning "scene '$($sceneCfg.kind)' failed: $_" } }
  }
})
```

- [ ] **Step 5: Run the presence test**

Run: `bash tests/scene.Tests.sh`
Expected: both checks `ok`.

- [ ] **Step 6: Commit**

```bash
git add show-notification.ps1 tests/scene.Tests.sh
git commit -m "Dispatch theme scenery from the renderer"
```

---

## Task 6: Enable waves on the `ocean` theme

**Files:**
- Modify: `settings.json`
- Test: `tests/settings.Tests.sh`

- [ ] **Step 1: Add the failing settings assertion**

In `tests/settings.Tests.sh`, before the final `exit $fail`, add:

```bash
check "ocean has waves scene" "[[ \"\$(jq -r '.themes.ocean.scene.kind // empty' '$F')\" == 'waves' ]]"
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/settings.Tests.sh`
Expected: FAIL on `ocean has waves scene`.

- [ ] **Step 3: Add the scene to `ocean` in `settings.json`**

Change the `ocean` theme block to append a `scene`:

```json
    "ocean": {
      "hero": "🐳",
      "gradient": ["#0EA5E9 0", "#22D3EE 0.3", "#2DD4BF 0.6", "#14B8A6 0.8", "#0891B2 1"],
      "rim": ["#0C4A6E 0", "#0369A1 0.25", "#0891B2 0.5", "#06B6D4 0.75", "#14B8A6 1"],
      "card": "#0A1620",
      "scene": { "kind": "waves" }
    },
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash tests/settings.Tests.sh`
Expected: all `ok`, including `ocean has waves scene` and the unchanged `9 themes` /
`every theme has hero/gradient/rim/card`.

- [ ] **Step 5: Commit**

```bash
git add settings.json tests/settings.Tests.sh
git commit -m "Enable waves scenery on the ocean theme"
```

---

## Task 7: Document `scene` in the settings schema

**Files:**
- Modify: `settings.schema.json`

Editor-metadata only (no runtime test); validated by eye and the existing
`tests/settings.Tests.sh` JSON-parse check.

- [ ] **Step 1: Add `scene` to the `theme` definition**

In `settings.schema.json`, under `definitions.theme.properties` (after `card`), add:

```json
        "card": {
          "type": "string",
          "pattern": "^#[0-9A-Fa-f]{6}$",
          "description": "Card background colour (#RRGGBB)."
        },
        "scene": { "$ref": "#/definitions/scene" }
```

- [ ] **Step 2: Add the `scene` definition**

In `settings.schema.json`, under `definitions` (after `theme`), add:

```json
    "scene": {
      "type": "object",
      "additionalProperties": false,
      "required": ["kind"],
      "description": "Optional animated backdrop for the theme.",
      "properties": {
        "kind": { "enum": ["waves"], "description": "Scenery renderer. Currently only \"waves\"." },
        "colors": {
          "type": "array",
          "description": "Colours the scene cycles. Defaults to the theme's gradient colours.",
          "items": { "$ref": "#/definitions/hexColor" }
        },
        "opacity": { "type": "number", "minimum": 0, "maximum": 1, "description": "Scene layer opacity (default 0.22)." },
        "speed": { "type": "number", "exclusiveMinimum": 0, "description": "Animation speed multiplier (default 1.0)." }
      }
    }
```

- [ ] **Step 3: Validate the schema is still valid JSON**

Run: `jq -e . settings.schema.json >/dev/null && echo OK`
Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add settings.schema.json
git commit -m "Document scene config in settings schema"
```

---

## Task 8: Full verification

**Files:** none (verification only).

- [ ] **Step 1: Run every test**

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w tests/scene-waves.Tests.ps1)" | tr -d '\r'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w tests/notify-lib.Tests.ps1)" | tr -d '\r'
bash tests/settings.Tests.sh
bash tests/scene.Tests.sh
bash tests/show-notification.Tests.sh
```
Expected: `ALL PASS` / all `ok` for each; golden still matches.

- [ ] **Step 2: Per-theme render smoke (ocean exits clean)**

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(wslpath -w show-notification.ps1)" -Hwnd 0 -Folder demo -Event done -Seconds 6
```
Expected: exit 0, no error output; a card appears on the cursor's monitor with
waves drifting along the bottom (`activeTheme` is `ocean`).

- [ ] **Step 3: Visual check**

Render both events for `ocean`; confirm: waves roll subtly along the bottom, the
🐳 watermark and body text remain readable, the mascot animation is intact, and
no edge/seam is visible as the waves scroll.

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w show-notification.ps1)" -Hwnd 0 -Folder demo -Event needs-input -Seconds 6
```

- [ ] **Step 4: Default-look regression (no settings.json)**

`tests/show-notification.Tests.sh` already proves this byte-for-byte; confirm it is
green in Step 1. No separate action needed.

---

## Self-Review

- **Spec coverage:**
  - Config `scene` field + optional `colors`/`opacity`/`speed` → Tasks 3, 5, 6, 7.
  - Layering (scene behind hero via document order) → Task 4.
  - Back-compat / golden byte-identical → Task 4 Step 4, Task 8 Step 4.
  - `waves` renderer (layered scrolling sine paths, invariant-culture geometry) → Tasks 1, 2.
  - Dispatch table + try/catch + script-scope handler → Task 5.
  - Colour fallback to `Get-StopColors $theme.gradient` → Task 5 Step 4, Task 2.
  - Error handling: no scene → no Canvas (Task 4); unknown kind → dispatch no-op (Task 5, `$sceneKinds[...]` returns `$null`); renderer throw caught (Task 5); empty colours fallback (Task 2). ✓
  - Testing items 1–6 from the spec → Tasks 3/5/6 (parse + passthrough), Task 5 (EmitXaml presence/absence), Task 8 (per-theme render, visual, default golden). ✓
- **Placeholder scan:** none — every code/step is concrete. ✓
- **Type/name consistency:** `New-WavePathData(width, period, amp, top, bottom, step)`, `Start-Waves($box, $cfg)`, `$box.Scene`, `x:Name="scene"`, `$sceneCfg.{kind,colors,opacity,speed}`, `$sceneKinds` keyed by `kind` — identical across Tasks 1, 2, 4, 5. `New-Brush`/`Get-StopColors`/`Coalesce`/`Get-Prop` are pre-existing. ✓
