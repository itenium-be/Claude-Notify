# Phase 2.5: after landing, stroll along the top edge from the slot side to the
# right end, looping the walk cycle, then hand off to the celebrate phase.
function Start-Walk {
  param([hashtable]$Box, [scriptblock]$OnDone)
  $m = $Box.Mascot
  $dur = [System.Windows.Duration][TimeSpan]::FromMilliseconds(1600)
  $move = New-Object System.Windows.Media.Animation.DoubleAnimation $Box.RestLeft, $Box.RightLeft, $dur
  $walk = Start-Flipbook -Image $m -Dir (Join-Path $PSScriptRoot '..\mascots\walking') -Loop
  $move.Add_Completed({
    if ($walk) { $walk.Stop() }
    $m.BeginAnimation([System.Windows.Controls.Canvas]::LeftProperty, $null)
    [System.Windows.Controls.Canvas]::SetLeft($m, $Box.RightLeft)
    if ($OnDone) { & $OnDone }
  }.GetNewClosure())
  $m.BeginAnimation([System.Windows.Controls.Canvas]::LeftProperty, $move)
}
