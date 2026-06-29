. "$PSScriptRoot\..\lib\scene-vaporwave.ps1"

$script:fail = 0
function Assert-Eq($got, $exp, $msg) {
  if ("$got" -ne "$exp") { Write-Host "FAIL: $msg`n  exp=[$exp]`n  got=[$got]"; $script:fail++ }
  else { Write-Host "ok: $msg" }
}
function Assert-True($cond, $msg) { Assert-Eq ([bool]$cond) $true $msg }

# Perspective grid: width 100, horizon y=60, bottom y=200, 3 columns, 2 rows,
# vanishing point x=50. Bottom xs = 0, 33.33, 66.67, 100 (cols+1 verticals).
# Horizontal rows tighten toward the horizon: y = 60 + 140 * (r/rows)^2.
#   r=1 -> 60 + 140*0.25 = 95 ; r=2 -> 60 + 140 = 200.
$d = New-GridPathData 100 60 200 3 2 50

Assert-True ($d.StartsWith('M')) "grid path starts with M (moveto)"
Assert-True ($d.Contains('M 50,60 L 0,200')) "left vertical: vanishing point -> bottom-left"
Assert-True ($d.Contains('L 100,200')) "right vertical reaches bottom-right (100,200)"
Assert-True ($d.Contains('33.33,200')) "interior vertical hits bottom at x=33.33"
Assert-True ($d.Contains('66.67,200')) "interior vertical hits bottom at x=66.67"
Assert-True ($d.Contains('M 0,95 L 100,95')) "near-horizon row tightened to y=95"
Assert-True ($d.Contains('M 0,200 L 100,200')) "front row at the bottom edge"
# One 'M 50,60 ' move per vertical line (cols+1 = 4).
Assert-Eq ([regex]::Matches($d, 'M 50,60 ').Count) 4 "one move per vertical (cols+1)"

# Invariant decimals: XAML needs '.', NOT the ',' an nl-BE locale emits.
Assert-True ($d.Contains('33.33')) "uses '.' decimal separator"
Assert-True (-not $d.Contains('33,33')) "does not use ',' decimal separator"

# Degenerate inputs are coerced, never throw / divide by zero.
$d2 = New-GridPathData 100 50 150 0 0 50
Assert-True ($d2.StartsWith('M')) "cols<1 / rows<1 still yields a path"

if ($script:fail -gt 0) { exit 1 } else { Write-Host "ALL PASS" }
