# Scenery renderer: sakura — falling cherry-blossom petals + optional bloom glow,
# corner branch and parallax foreground petals. New-PetalPathData / New-SakuraStop
# are the pure bits (unit-tested); the Add-Sakura* helpers and Start-Sakura build
# live WPF visuals. Dot-sourced by show-notification.ps1; New-Brush comes from
# notification-box.ps1.

# One cherry-blossom petal as XAML path geometry: a rounded body tapering to a
# notched tip, pointing up, base at the bottom-centre. Coordinates are SPACE-
# separated and formatted with the invariant culture: the nl-BE machine locale
# would emit ',' decimals and Geometry.Parse would choke (see New-WavePathData).
function New-PetalPathData([double]$w, [double]$h) {
  $ic = [System.Globalization.CultureInfo]::InvariantCulture
  $n = { param($v) ([double]$v).ToString('0.###', $ic) }
  $cx = $w / 2.0
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append("M $(& $n $cx) $(& $n $h) ")
  # Up the left flank to the notched tip (tip dips to h*0.16 at centre).
  [void]$sb.Append("C $(& $n ($w*0.04)) $(& $n ($h*0.58)) $(& $n ($w*0.16)) $(& $n ($h*0.06)) $(& $n $cx) $(& $n ($h*0.16)) ")
  # Down the right flank back to the base.
  [void]$sb.Append("C $(& $n ($w*0.84)) $(& $n ($h*0.06)) $(& $n ($w*0.96)) $(& $n ($h*0.58)) $(& $n $cx) $(& $n $h) ")
  [void]$sb.Append('Z')
  $sb.ToString()
}

# Gradient stop with a 0..1 alpha baked into #AARRGGBB (lets the bloom glows fade
# to transparent without a separate Opacity per stop). Mirrors New-SpaceStop.
function New-SakuraStop([string]$hex6, [double]$alpha, [double]$offset) {
  $a = [int][Math]::Round(255 * $alpha)
  $argb = ('#{0:X2}{1}' -f $a, $hex6.TrimStart('#'))
  New-Object System.Windows.Media.GradientStop ([System.Windows.Media.ColorConverter]::ConvertFromString($argb)), $offset
}

# Light-pink → lilac petal tints; lighter than the card gradient so they read on the
# dark #1A1620 card.
$script:SakuraPetalColors = @('#FFC1D6', '#FFB7C5', '#FBC2EB', '#F8A5C2', '#E8B4FF')

# One petal Shape (Path) of the given size/colour, with a RotateTransform (tumble,
# centred on the petal) + TranslateTransform (drift) ready for animation.
function New-PetalVisual([double]$w, [double]$h, [string]$col) {
  $p = New-Object System.Windows.Shapes.Path
  $p.Data = [System.Windows.Media.Geometry]::Parse((New-PetalPathData $w $h))
  $p.Fill = New-Brush $col
  $rot = New-Object System.Windows.Media.RotateTransform 0
  $rot.CenterX = $w / 2; $rot.CenterY = $h / 2
  $tt = New-Object System.Windows.Media.TranslateTransform
  $grp = New-Object System.Windows.Media.TransformGroup
  $grp.Children.Add($rot); $grp.Children.Add($tt)
  $p.RenderTransform = $grp
  @{ Path = $p; Rot = $rot; TT = $tt }
}

# A seamless top->bottom fall on a TranslateTransform.Y, started mid-cycle at $phase
# (0..1) so petals scatter without a negative BeginTime (unreliable). The bottom->top
# wrap is a discrete jump but happens off-card (both ends are past the edges).
function Add-PetalFall($tt, [double]$yTop, [double]$yBot, [double]$dur, [double]$phase) {
  $span = $yBot - $yTop
  $startY = $yTop + $phase * $span
  $t1 = $dur * (1 - $phase)
  $kf = New-Object System.Windows.Media.Animation.DoubleAnimationUsingKeyFrames
  $kf.Duration = [System.Windows.Duration][TimeSpan]::FromSeconds($dur)
  $kf.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
  $kf.KeyFrames.Add((New-Object System.Windows.Media.Animation.LinearDoubleKeyFrame $startY, ([System.Windows.Media.Animation.KeyTime][TimeSpan]::FromSeconds(0)))) | Out-Null
  $kf.KeyFrames.Add((New-Object System.Windows.Media.Animation.LinearDoubleKeyFrame $yBot, ([System.Windows.Media.Animation.KeyTime][TimeSpan]::FromSeconds($t1)))) | Out-Null
  $kf.KeyFrames.Add((New-Object System.Windows.Media.Animation.DiscreteDoubleKeyFrame $yTop, ([System.Windows.Media.Animation.KeyTime][TimeSpan]::FromSeconds($t1)))) | Out-Null
  $kf.KeyFrames.Add((New-Object System.Windows.Media.Animation.LinearDoubleKeyFrame $startY, ([System.Windows.Media.Animation.KeyTime][TimeSpan]::FromSeconds($dur)))) | Out-Null
  $tt.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $kf)
}

# Falling petals of one class. background: small/slow/faint/many; foreground: large/
# fast/bolder/few (the parallax layer). All motion is via RenderTransform (Y fall,
# X sway, tumble) — a plain Opacity BeginAnimation does not repaint reliably here.
function Add-SakuraPetals($canvas, [double]$w, [double]$h, [int]$count, [double]$speed, [string]$class) {
  $fg = ($class -eq 'foreground')
  for ($i = 0; $i -lt $count; $i++) {
    if ($fg) { $pw = 22 + (Get-Random -Minimum 0 -Maximum 12) }      # 22 .. 33
    else     { $pw = 9  + (Get-Random -Minimum 0 -Maximum 8) }       # 9 .. 16
    $ph = $pw * (1.05 + (Get-Random -Minimum 0 -Maximum 25) / 100.0) # slightly taller
    $col = $script:SakuraPetalColors[(Get-Random -Minimum 0 -Maximum $script:SakuraPetalColors.Count)]
    $v = New-PetalVisual $pw $ph $col
    $v.Path.Opacity = if ($fg) { 0.30 + (Get-Random -Minimum 0 -Maximum 25) / 100.0 }  # 0.30 .. 0.55
                      else      { 0.55 + (Get-Random -Minimum 0 -Maximum 40) / 100.0 }  # 0.55 .. 0.95

    $startX = -$pw + (Get-Random -Minimum 0 -Maximum 1000) / 1000.0 * ($w + 2 * $pw)
    [System.Windows.Controls.Canvas]::SetLeft($v.Path, $startX)
    [System.Windows.Controls.Canvas]::SetTop($v.Path, 0)
    $canvas.Children.Add($v.Path) | Out-Null

    $yTop = -$ph - 4
    $yBot = $h + $ph + 4
    $base = if ($fg) { 4.5 } else { 8.0 }                            # foreground falls faster
    $dur = ($base + (Get-Random -Minimum 0 -Maximum 60) / 10.0) / $speed
    Add-PetalFall $v.TT $yTop $yBot $dur ((Get-Random -Minimum 0 -Maximum 1000) / 1000.0)

    # Horizontal sway around the resting X (transform space), desynced by duration.
    $amp = $pw * (0.5 + (Get-Random -Minimum 0 -Maximum 80) / 100.0)
    $sdur = (2.2 + (Get-Random -Minimum 0 -Maximum 26) / 10.0) / $speed
    $sway = New-Object System.Windows.Media.Animation.DoubleAnimation (-$amp), $amp, ([System.Windows.Duration][TimeSpan]::FromSeconds($sdur))
    $sway.AutoReverse = $true; $sway.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
    $v.TT.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $sway)

    # Continuous tumble; seamless full turn (a -> a±360), random start angle/direction.
    $a0 = Get-Random -Minimum 0 -Maximum 360
    $dir = if ((Get-Random -Minimum 0 -Maximum 2) -eq 0) { 360 } else { -360 }
    $rdur = (6.0 + (Get-Random -Minimum 0 -Maximum 80) / 10.0) / $speed
    $spin = New-Object System.Windows.Media.Animation.DoubleAnimation $a0, ($a0 + $dir), ([System.Windows.Duration][TimeSpan]::FromSeconds($rdur))
    $spin.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
    $v.Rot.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $spin)
  }
}

# Soft radial bokeh glows in pink/rose/lilac, drifting slowly. Mirrors Add-SpaceNebula.
function Add-SakuraBloom($canvas, [double]$w, [double]$h, [double]$speed) {
  foreach ($b in @(
      @{ cx = ($w * 0.24); cy = ($h * 0.34); r = ($h * 0.62); col = '#FF8FB1'; op = 0.20; dur = 28 },
      @{ cx = ($w * 0.74); cy = ($h * 0.58); r = ($h * 0.74); col = '#E0AAFF'; op = 0.16; dur = 36 },
      @{ cx = ($w * 0.54); cy = ($h * 0.22); r = ($h * 0.48); col = '#FBC2EB'; op = 0.18; dur = 32 })) {
    $e = New-Object System.Windows.Shapes.Ellipse
    $e.Width = $b.r * 2; $e.Height = $b.r * 2
    $rg = New-Object System.Windows.Media.RadialGradientBrush
    $rg.GradientStops.Add((New-SakuraStop $b.col $b.op 0.0))
    $rg.GradientStops.Add((New-SakuraStop $b.col ($b.op * 0.4) 0.5))
    $rg.GradientStops.Add((New-SakuraStop $b.col 0.0 1.0))
    $e.Fill = $rg
    [System.Windows.Controls.Canvas]::SetLeft($e, $b.cx - $b.r); [System.Windows.Controls.Canvas]::SetTop($e, $b.cy - $b.r)
    $tt = New-Object System.Windows.Media.TranslateTransform
    $e.RenderTransform = $tt
    $canvas.Children.Add($e) | Out-Null
    $dx = New-Object System.Windows.Media.Animation.DoubleAnimation 0, ($w * 0.05), ([System.Windows.Duration][TimeSpan]::FromSeconds($b.dur / $speed))
    $dx.AutoReverse = $true; $dx.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
    $tt.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $dx)
  }
}

# A single five-petal blossom (petals fanned 72deg around a base point) with a tiny
# golden centre, as a Canvas sized $size.
function New-BlossomVisual([double]$size, [string]$col) {
  $c = New-Object System.Windows.Controls.Canvas
  $pw = $size * 0.5; $ph = $size * 0.58
  for ($k = 0; $k -lt 5; $k++) {
    $p = New-Object System.Windows.Shapes.Path
    $p.Data = [System.Windows.Media.Geometry]::Parse((New-PetalPathData $pw $ph))
    $p.Fill = New-Brush $col
    # Base point sits at the blossom centre; rotate each petal around it.
    [System.Windows.Controls.Canvas]::SetLeft($p, $size / 2 - $pw / 2)
    [System.Windows.Controls.Canvas]::SetTop($p, $size / 2 - $ph)
    $rot = New-Object System.Windows.Media.RotateTransform ($k * 72)
    $rot.CenterX = $pw / 2; $rot.CenterY = $ph
    $p.RenderTransform = $rot
    $c.Children.Add($p) | Out-Null
  }
  $ctr = New-Object System.Windows.Shapes.Ellipse
  $ctr.Width = $size * 0.16; $ctr.Height = $size * 0.16; $ctr.Fill = New-Brush '#FDE68A'
  [System.Windows.Controls.Canvas]::SetLeft($ctr, $size / 2 - $size * 0.08)
  [System.Windows.Controls.Canvas]::SetTop($ctr, $size / 2 - $size * 0.08)
  $c.Children.Add($ctr) | Out-Null
  $c
}

# A blossom branch in the top-left corner: a dark limb with a few blossoms, gently
# swaying as one group about the corner anchor.
function Add-SakuraBranch($canvas, [double]$w, [double]$h, [double]$speed) {
  $ic = [System.Globalization.CultureInfo]::InvariantCulture
  $g = New-Object System.Windows.Controls.Canvas
  $limb = New-Object System.Windows.Shapes.Path
  $n = { param($v) ([double]$v).ToString('0.##', $ic) }
  $limb.Data = [System.Windows.Media.Geometry]::Parse(
    "M 0 0 C $(& $n ($w*0.10)) $(& $n ($h*0.10)) $(& $n ($w*0.22)) $(& $n ($h*0.12)) $(& $n ($w*0.40)) $(& $n ($h*0.30))")
  $limb.Stroke = New-Brush '#6B4A3A'
  $limb.StrokeThickness = 3.0
  $limb.StrokeEndLineCap = 'Round'; $limb.StrokeStartLineCap = 'Round'
  $g.Children.Add($limb) | Out-Null

  foreach ($bl in @(
      @{ x = ($w * 0.07); y = ($h * 0.06); s = 20 },
      @{ x = ($w * 0.20); y = ($h * 0.10); s = 24 },
      @{ x = ($w * 0.33); y = ($h * 0.22); s = 18 },
      @{ x = ($w * 0.27); y = ($h * 0.02); s = 16 })) {
    $b = New-BlossomVisual $bl.s '#FFB7C5'
    [System.Windows.Controls.Canvas]::SetLeft($b, $bl.x); [System.Windows.Controls.Canvas]::SetTop($b, $bl.y)
    $g.Children.Add($b) | Out-Null
  }

  $sway = New-Object System.Windows.Media.RotateTransform 0
  $sway.CenterX = 0; $sway.CenterY = 0
  $g.RenderTransform = $sway
  $canvas.Children.Add($g) | Out-Null
  $a = New-Object System.Windows.Media.Animation.DoubleAnimation -1.5, 1.5, ([System.Windows.Duration][TimeSpan]::FromSeconds(7.0 / $speed))
  $a.AutoReverse = $true; $a.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
  $sway.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $a)
}

# Render the sakura scene into $box.Scene. $cfg flags: petals (default on) / count /
# speed / bloom / branch / parallax. Back (bloom) to front (foreground petals) order.
function Start-Sakura($box, $cfg) {
  $canvas = $box.Scene
  if ($null -eq $canvas) { return }
  $card = $box.Card
  $w = [double]$card.ActualWidth; $h = [double]$card.ActualHeight
  if ($w -le 0 -or $h -le 0) { return }
  $canvas.Width = $w; $canvas.Height = $h

  $speed = [double]$cfg.speed; if ($speed -le 0) { $speed = 1.0 }
  $count = [int]$cfg.count; if ($count -le 0) { $count = 22 }

  if ($cfg.bloom)  { Add-SakuraBloom  $canvas $w $h $speed }
  if ($cfg.branch) { Add-SakuraBranch $canvas $w $h $speed }
  if ($cfg.petals) { Add-SakuraPetals $canvas $w $h $count $speed 'background' }
  if ($cfg.parallax) { Add-SakuraPetals $canvas $w $h ([Math]::Max(3, [int]($count / 5))) $speed 'foreground' }
}
