# Scenery renderer: spooky — eight independent, flag-toggled Halloween/haunted
# layers. New-WebPathData / New-BatPathData are WPF-free + unit-tested; the
# Add-Spooky* helpers build live WPF visuals. Dot-sourced by show-notification.ps1.

# XAML path geometry for a corner spiderweb: `spokes` radial threads fanning 0..90deg
# from (cx,cy), plus `rings` concentric polyline threads connecting the spokes at
# fractional radii. One combined Path data string (multiple M subpaths), stroked.
# Invariant culture: XAML needs '.' decimals; nl-BE would emit ',' and choke Parse.
function New-WebPathData([double]$cx, [double]$cy, [double]$r, [int]$spokes, [int]$rings) {
  $ic = [System.Globalization.CultureInfo]::InvariantCulture
  if ($spokes -lt 2) { $spokes = 2 }
  if ($rings -lt 1) { $rings = 1 }
  $f = { param($v) ([double]$v).ToString('0.##', $ic) }
  $angles = @()
  for ($s = 0; $s -lt $spokes; $s++) {
    $t = $s / ($spokes - 1)
    $angles += (90.0 * $t)
  }
  $sb = New-Object System.Text.StringBuilder
  foreach ($deg in $angles) {
    $rad = $deg * [Math]::PI / 180.0
    $x = $cx + $r * [Math]::Cos($rad)
    $y = $cy + $r * [Math]::Sin($rad)
    [void]$sb.Append(("M {0},{1} L {2},{3} " -f (&$f $cx), (&$f $cy), (&$f $x), (&$f $y)))
  }
  for ($ringi = 1; $ringi -le $rings; $ringi++) {
    $rr = $r * $ringi / ($rings + 1)
    for ($s = 0; $s -lt $spokes; $s++) {
      $rad = $angles[$s] * [Math]::PI / 180.0
      $x = $cx + $rr * [Math]::Cos($rad)
      $y = $cy + $rr * [Math]::Sin($rad)
      $cmd = if ($s -eq 0) { 'M' } else { 'L' }
      [void]$sb.Append(("{0} {1},{2} " -f $cmd, (&$f $x), (&$f $y)))
    }
  }
  $sb.ToString().TrimEnd()
}

# Filled, closed bat silhouette centred on (0,0): a small body with two scalloped
# wings. Right side is built explicitly then mirrored to the left, so the shape is
# symmetric. Wing tips reach +/-w/2; top/bottom reach +/-h/2.
function New-BatPathData([double]$w, [double]$h) {
  $ic = [System.Globalization.CultureInfo]::InvariantCulture
  $hw = $w / 2; $hh = $h / 2
  $f = { param($v) ([double]$v).ToString('0.##', $ic) }
  # Right half, top-of-head -> outer wing -> wing notch -> bottom-of-body.
  $right =
    "L $(&$f ($hw*0.15)),$(&$f (-$hh*0.55)) " +   # right ear/shoulder
    "L $(&$f ($hw*0.40)),$(&$f (-$hh*0.15)) " +   # inner wing
    "L $(&$f ($hw*0.75)),$(&$f (-$hh*0.45)) " +   # outer wing rise (-> 37.5,... for hw=50)
    "L $(&$f $hw),$(&$f (-$hh*0.10)) " +          # wing tip (+hw)
    "L $(&$f ($hw*0.70)),$(&$f ($hh*0.35)) " +    # scallop
    "L $(&$f ($hw*0.30)),$(&$f ($hh*0.10)) " +    # back toward body
    "L 0,$(&$f $hh) "                              # bottom of body
  $left =
    "L $(&$f (-$hw*0.30)),$(&$f ($hh*0.10)) " +
    "L $(&$f (-$hw*0.70)),$(&$f ($hh*0.35)) " +
    "L $(&$f (-$hw)),$(&$f (-$hh*0.10)) " +        # wing tip (-hw)
    "L $(&$f (-$hw*0.75)),$(&$f (-$hh*0.45)) " +
    "L $(&$f (-$hw*0.40)),$(&$f (-$hh*0.15)) " +
    "L $(&$f (-$hw*0.15)),$(&$f (-$hh*0.55)) "
  "M 0,$(&$f (-$hh*0.30)) " + $right + $left + "Z"
}
