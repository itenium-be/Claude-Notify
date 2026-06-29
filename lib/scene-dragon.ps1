# Scenery renderer: dragon — rising embers + optional fire glow, flame tongues and
# smoke wisps. New-FlamePathData / New-DragonStop are the pure bits (unit-tested);
# the Add-Dragon* helpers and Start-Dragon build live WPF visuals. Dot-sourced by
# show-notification.ps1; New-Brush comes from notification-box.ps1.

# One flame tongue as XAML path geometry: a teardrop tapering to a point at the top,
# base at the bottom-centre. Coordinates are SPACE-separated and formatted with the
# invariant culture (the nl-BE machine locale would emit ',' decimals and
# Geometry.Parse would choke — see New-WavePathData).
function New-FlamePathData([double]$w, [double]$h) {
  $ic = [System.Globalization.CultureInfo]::InvariantCulture
  $n = { param($v) ([double]$v).ToString('0.###', $ic) }
  $cx = $w / 2.0
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append("M $(& $n $cx) $(& $n $h) ")
  # Up the left flank, curling inward to the pointed tip.
  [void]$sb.Append("C $(& $n ($w*0.02)) $(& $n ($h*0.62)) $(& $n ($w*0.28)) $(& $n ($h*0.26)) $(& $n $cx) $(& $n 0) ")
  # Down the right flank back to the base.
  [void]$sb.Append("C $(& $n ($w*0.72)) $(& $n ($h*0.26)) $(& $n ($w*0.98)) $(& $n ($h*0.62)) $(& $n $cx) $(& $n $h) ")
  [void]$sb.Append('Z')
  $sb.ToString()
}

# Gradient stop with a 0..1 alpha baked into #AARRGGBB (lets the glow/flame gradients
# fade to transparent without a separate Opacity per stop). Mirrors New-SpaceStop.
function New-DragonStop([string]$hex6, [double]$alpha, [double]$offset) {
  $a = [int][Math]::Round(255 * $alpha)
  $argb = ('#{0:X2}{1}' -f $a, $hex6.TrimStart('#'))
  New-Object System.Windows.Media.GradientStop ([System.Windows.Media.ColorConverter]::ConvertFromString($argb)), $offset
}

# Fire spark tints, hottest (white-yellow) to coolest (deep orange).
$script:DragonEmberColors = @('#FFF3B0', '#FDE047', '#FBBF24', '#F97316', '#FB923C')

# A seamless vertical loop on a TranslateTransform.Y from $yStart to $yEnd, started
# mid-cycle at $phase (0..1) so elements scatter without a negative BeginTime
# (unreliable). The wrap is a discrete jump but happens off-card (both ends are past
# the edges). Works either direction: embers rise (yStart>yEnd), petals fall.
function Add-VertLoop($tt, [double]$yStart, [double]$yEnd, [double]$dur, [double]$phase) {
  $span = $yEnd - $yStart
  $startV = $yStart + $phase * $span
  $t1 = $dur * (1 - $phase)
  $kf = New-Object System.Windows.Media.Animation.DoubleAnimationUsingKeyFrames
  $kf.Duration = [System.Windows.Duration][TimeSpan]::FromSeconds($dur)
  $kf.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
  $kf.KeyFrames.Add((New-Object System.Windows.Media.Animation.LinearDoubleKeyFrame $startV, ([System.Windows.Media.Animation.KeyTime][TimeSpan]::FromSeconds(0)))) | Out-Null
  $kf.KeyFrames.Add((New-Object System.Windows.Media.Animation.LinearDoubleKeyFrame $yEnd, ([System.Windows.Media.Animation.KeyTime][TimeSpan]::FromSeconds($t1)))) | Out-Null
  $kf.KeyFrames.Add((New-Object System.Windows.Media.Animation.DiscreteDoubleKeyFrame $yStart, ([System.Windows.Media.Animation.KeyTime][TimeSpan]::FromSeconds($t1)))) | Out-Null
  $kf.KeyFrames.Add((New-Object System.Windows.Media.Animation.LinearDoubleKeyFrame $startV, ([System.Windows.Media.Animation.KeyTime][TimeSpan]::FromSeconds($dur)))) | Out-Null
  $tt.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $kf)
}

# Glowing spark particles rising from the bottom, swaying and flickering. Flicker is a
# ScaleTransform pulse (the star-twinkle trick): a plain Opacity BeginAnimation does
# not repaint reliably for scene children here, but render-transform animations do.
function Add-DragonEmbers($canvas, [double]$w, [double]$h, [int]$count, [double]$speed) {
  for ($i = 0; $i -lt $count; $i++) {
    $sz = 2.0 + (Get-Random -Minimum 0 -Maximum 35) / 10.0          # 2.0 .. 5.5 px
    $col = $script:DragonEmberColors[(Get-Random -Minimum 0 -Maximum $script:DragonEmberColors.Count)]
    $e = New-Object System.Windows.Shapes.Ellipse
    $e.Width = $sz; $e.Height = $sz
    $rg = New-Object System.Windows.Media.RadialGradientBrush
    $rg.GradientStops.Add((New-DragonStop $col 1.0 0.0))
    $rg.GradientStops.Add((New-DragonStop $col 0.6 0.5))
    $rg.GradientStops.Add((New-DragonStop $col 0.0 1.0))
    $e.Fill = $rg
    $e.Opacity = 0.6 + (Get-Random -Minimum 0 -Maximum 40) / 100.0  # 0.6 .. 1.0

    $startX = (Get-Random -Minimum 0 -Maximum 1000) / 1000.0 * $w
    [System.Windows.Controls.Canvas]::SetLeft($e, $startX); [System.Windows.Controls.Canvas]::SetTop($e, 0)
    $sc = New-Object System.Windows.Media.ScaleTransform 1, 1
    $sc.CenterX = $sz / 2; $sc.CenterY = $sz / 2
    $tt = New-Object System.Windows.Media.TranslateTransform
    $grp = New-Object System.Windows.Media.TransformGroup
    $grp.Children.Add($sc); $grp.Children.Add($tt)
    $e.RenderTransform = $grp
    $canvas.Children.Add($e) | Out-Null

    # Rise from just below the bottom to just above the top.
    $dur = (5.0 + (Get-Random -Minimum 0 -Maximum 70) / 10.0) / $speed   # 5 .. 12 s
    Add-VertLoop $tt ($h + $sz) (-$sz) $dur ((Get-Random -Minimum 0 -Maximum 1000) / 1000.0)

    $amp = 6 + (Get-Random -Minimum 0 -Maximum 14)
    $sdur = (1.6 + (Get-Random -Minimum 0 -Maximum 22) / 10.0) / $speed
    $sway = New-Object System.Windows.Media.Animation.DoubleAnimation (-$amp), $amp, ([System.Windows.Duration][TimeSpan]::FromSeconds($sdur))
    $sway.AutoReverse = $true; $sway.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
    $tt.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $sway)

    $fdur = (0.5 + (Get-Random -Minimum 0 -Maximum 12) / 10.0) / $speed
    $fl = New-Object System.Windows.Media.Animation.DoubleAnimation 0.5, 1.4, ([System.Windows.Duration][TimeSpan]::FromSeconds($fdur))
    $fl.AutoReverse = $true; $fl.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
    $sc.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $fl)
    $sc.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $fl)
  }
}

# Warm heat haze from the bottom edge: a transparent->orange vertical wash plus a few
# drifting radial blooms low in the card. Mirrors the ocean sea + sakura bloom.
function Add-DragonGlow($canvas, [double]$w, [double]$h, [double]$speed) {
  $base = New-Object System.Windows.Shapes.Rectangle
  $base.Width = $w; $base.Height = $h
  $lg = New-Object System.Windows.Media.LinearGradientBrush
  $lg.StartPoint = '0,0'; $lg.EndPoint = '0,1'
  $lg.GradientStops.Add((New-DragonStop '#F97316' 0.0 0.0))
  $lg.GradientStops.Add((New-DragonStop '#EA580C' 0.10 0.55))
  $lg.GradientStops.Add((New-DragonStop '#DC2626' 0.34 1.0))
  $base.Fill = $lg
  [System.Windows.Controls.Canvas]::SetLeft($base, 0); [System.Windows.Controls.Canvas]::SetTop($base, 0)
  $canvas.Children.Add($base) | Out-Null

  foreach ($b in @(
      @{ cx = ($w * 0.30); r = ($h * 0.70); col = '#F97316'; op = 0.22; dur = 22 },
      @{ cx = ($w * 0.70); r = ($h * 0.85); col = '#DC2626'; op = 0.18; dur = 28 })) {
    $e = New-Object System.Windows.Shapes.Ellipse
    $e.Width = $b.r * 2; $e.Height = $b.r * 2
    $rg = New-Object System.Windows.Media.RadialGradientBrush
    $rg.GradientStops.Add((New-DragonStop $b.col $b.op 0.0))
    $rg.GradientStops.Add((New-DragonStop $b.col ($b.op * 0.4) 0.5))
    $rg.GradientStops.Add((New-DragonStop $b.col 0.0 1.0))
    $e.Fill = $rg
    [System.Windows.Controls.Canvas]::SetLeft($e, $b.cx - $b.r); [System.Windows.Controls.Canvas]::SetTop($e, $h - $b.r)
    $tt = New-Object System.Windows.Media.TranslateTransform
    $e.RenderTransform = $tt
    $canvas.Children.Add($e) | Out-Null
    $dx = New-Object System.Windows.Media.Animation.DoubleAnimation 0, ($w * 0.06), ([System.Windows.Duration][TimeSpan]::FromSeconds($b.dur / $speed))
    $dx.AutoReverse = $true; $dx.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
    $tt.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $dx)
  }
}

# One flame tongue: a flame-shaped Path with a hot vertical gradient, anchored at its
# base for a height-flicker (ScaleTransform.Y) + slight sideways lick (RotateTransform).
function Add-DragonFlame($canvas, [double]$x, [double]$baseY, [double]$fw, [double]$fh, [double]$speed) {
  $p = New-Object System.Windows.Shapes.Path
  $p.Data = [System.Windows.Media.Geometry]::Parse((New-FlamePathData $fw $fh))
  $g = New-Object System.Windows.Media.LinearGradientBrush
  $g.StartPoint = '0,1'; $g.EndPoint = '0,0'   # bottom -> top
  $g.GradientStops.Add((New-DragonStop '#FFF3B0' 0.95 0.0))
  $g.GradientStops.Add((New-DragonStop '#FBBF24' 0.90 0.35))
  $g.GradientStops.Add((New-DragonStop '#F97316' 0.80 0.7))
  $g.GradientStops.Add((New-DragonStop '#DC2626' 0.30 1.0))
  $p.Fill = $g
  [System.Windows.Controls.Canvas]::SetLeft($p, $x); [System.Windows.Controls.Canvas]::SetTop($p, $baseY - $fh)
  $sc = New-Object System.Windows.Media.ScaleTransform 1, 1
  $sc.CenterX = $fw / 2; $sc.CenterY = $fh           # anchor at the base
  $rot = New-Object System.Windows.Media.RotateTransform 0
  $rot.CenterX = $fw / 2; $rot.CenterY = $fh
  $grp = New-Object System.Windows.Media.TransformGroup
  $grp.Children.Add($sc); $grp.Children.Add($rot)
  $p.RenderTransform = $grp
  $canvas.Children.Add($p) | Out-Null

  $fdur = (0.6 + (Get-Random -Minimum 0 -Maximum 9) / 10.0) / $speed
  $fy = New-Object System.Windows.Media.Animation.DoubleAnimation 0.78, 1.18, ([System.Windows.Duration][TimeSpan]::FromSeconds($fdur))
  $fy.AutoReverse = $true; $fy.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
  $sc.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $fy)
  $fx = New-Object System.Windows.Media.Animation.DoubleAnimation 0.92, 1.08, ([System.Windows.Duration][TimeSpan]::FromSeconds($fdur * 1.3))
  $fx.AutoReverse = $true; $fx.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
  $sc.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $fx)
  $a0 = (Get-Random -Minimum -30 -Maximum 30) / 10.0
  $wob = New-Object System.Windows.Media.Animation.DoubleAnimation ($a0 - 4), ($a0 + 4), ([System.Windows.Duration][TimeSpan]::FromSeconds($fdur * 1.6))
  $wob.AutoReverse = $true; $wob.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
  $rot.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $wob)
}

# A row of flickering flame tongues along the bottom edge: a dim taller back row and a
# brighter shorter front row, spread with jitter.
function Add-DragonFlames($canvas, [double]$w, [double]$h, [double]$speed) {
  foreach ($row in @(
      @{ n = 6; fw = ($w * 0.16); fh = ($h * 0.42); op = 0.55 },
      @{ n = 9; fw = ($w * 0.11); fh = ($h * 0.30); op = 0.95 })) {
    $holder = New-Object System.Windows.Controls.Canvas
    $holder.Opacity = $row.op
    $canvas.Children.Add($holder) | Out-Null
    for ($i = 0; $i -lt $row.n; $i++) {
      $jit = (Get-Random -Minimum -40 -Maximum 40) / 100.0
      $x = ($i + 0.5 + $jit) / $row.n * $w - $row.fw / 2
      $fwv = $row.fw * (0.8 + (Get-Random -Minimum 0 -Maximum 50) / 100.0)
      $fhv = $row.fh * (0.75 + (Get-Random -Minimum 0 -Maximum 55) / 100.0)
      Add-DragonFlame $holder $x ($h + $fhv * 0.12) $fwv $fhv $speed
    }
  }
}

# Dark translucent smoke wisps rising slowly and growing as they climb.
function Add-DragonSmoke($canvas, [double]$w, [double]$h, [double]$speed) {
  $n = 4
  for ($i = 0; $i -lt $n; $i++) {
    $r = $h * (0.30 + (Get-Random -Minimum 0 -Maximum 30) / 100.0)
    $e = New-Object System.Windows.Shapes.Ellipse
    $e.Width = $r * 2; $e.Height = $r * 2
    $rg = New-Object System.Windows.Media.RadialGradientBrush
    $rg.GradientStops.Add((New-DragonStop '#3F3A38' 0.16 0.0))
    $rg.GradientStops.Add((New-DragonStop '#2A2624' 0.08 0.55))
    $rg.GradientStops.Add((New-DragonStop '#1A0F0A' 0.0 1.0))
    $e.Fill = $rg
    $x = (Get-Random -Minimum 0 -Maximum 1000) / 1000.0 * $w - $r
    [System.Windows.Controls.Canvas]::SetLeft($e, $x); [System.Windows.Controls.Canvas]::SetTop($e, -$r)
    $sc = New-Object System.Windows.Media.ScaleTransform 0.6, 0.6
    $sc.CenterX = $r; $sc.CenterY = $r
    $tt = New-Object System.Windows.Media.TranslateTransform
    $grp = New-Object System.Windows.Media.TransformGroup
    $grp.Children.Add($sc); $grp.Children.Add($tt)
    $e.RenderTransform = $grp
    $canvas.Children.Add($e) | Out-Null

    $dur = (14.0 + (Get-Random -Minimum 0 -Maximum 80) / 10.0) / $speed
    $phase = (Get-Random -Minimum 0 -Maximum 1000) / 1000.0
    Add-VertLoop $tt ($h + $r) (-$r) $dur $phase
    $grow = New-Object System.Windows.Media.Animation.DoubleAnimation 0.5, 1.3, ([System.Windows.Duration][TimeSpan]::FromSeconds($dur))
    $grow.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
    $sc.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $grow)
    $sc.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $grow)
  }
}

# Render the dragon scene into $box.Scene. $cfg flags: embers (default on) / count /
# speed / glow / flames / smoke. Back (glow) to front (embers) draw order.
function Start-Dragon($box, $cfg) {
  $canvas = $box.Scene
  if ($null -eq $canvas) { return }
  $card = $box.Card
  $w = [double]$card.ActualWidth; $h = [double]$card.ActualHeight
  if ($w -le 0 -or $h -le 0) { return }
  $canvas.Width = $w; $canvas.Height = $h

  $speed = [double]$cfg.speed; if ($speed -le 0) { $speed = 1.0 }
  $count = [int]$cfg.count; if ($count -le 0) { $count = 26 }

  if ($cfg.glow)   { Add-DragonGlow   $canvas $w $h $speed }
  if ($cfg.flames) { Add-DragonFlames $canvas $w $h $speed }
  if ($cfg.smoke)  { Add-DragonSmoke  $canvas $w $h $speed }
  if ($cfg.embers) { Add-DragonEmbers $canvas $w $h $count $speed }
}
