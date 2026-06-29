# Frame-by-frame flipbook player for an Image element.
# -Loop plays forever; otherwise -OnDone fires once after the last frame.
# Returns the DispatcherTimer so a looping caller (e.g. the walk) can stop it.
function Start-Flipbook {
  param(
    [System.Windows.Controls.Image]$Image,
    [string]$Dir,
    [int]$Fps = 30,
    [switch]$Loop,
    [scriptblock]$OnDone,
    [hashtable]$Box   # when given, the timer is tracked on $Box.Anims so the card can be torn down
  )
  $files = @(Get-ChildItem -Path $Dir -Filter 'frame_*.png' -ErrorAction SilentlyContinue | Sort-Object Name)
  if ($files.Count -eq 0) { if ($OnDone) { & $OnDone }; return }
  $frames = foreach ($f in $files) {
    $bi = New-Object System.Windows.Media.Imaging.BitmapImage
    $bi.BeginInit()
    $bi.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bi.UriSource = New-Object System.Uri($f.FullName)
    $bi.EndInit(); $bi.Freeze(); $bi
  }
  $Image.Source = $frames[0]
  $Image.Visibility = [System.Windows.Visibility]::Visible
  $state = [pscustomobject]@{ Idx = 0 }
  $timer = New-Object System.Windows.Threading.DispatcherTimer
  $timer.Interval = [TimeSpan]::FromMilliseconds([int](1000 / $Fps))
  $timer.Add_Tick({
    $state.Idx++
    if ($state.Idx -ge $frames.Count) {
      if ($Loop) { $state.Idx = 0 }
      else { $timer.Stop(); if ($OnDone) { & $OnDone }; return }
    }
    $Image.Source = $frames[$state.Idx]
  }.GetNewClosure())
  if ($Box) {
    if (-not $Box.Anims) { $Box.Anims = New-Object System.Collections.Generic.List[object] }
    [void]$Box.Anims.Add($timer)
  }
  $timer.Start()
  return $timer
}

# Stop a card's mascot frame-timers. The looping celebrate/walk flipbooks tick forever, so a
# card that's been replaced (the editor rebuilds one per edit) would otherwise keep updating
# its now-offscreen mascot on the shared Dispatcher — several at once visibly jank the live one.
function Stop-CardAnimations($Box) {
  if ($Box -and $Box.Anims) {
    foreach ($t in $Box.Anims) { try { $t.Stop() } catch {} }
    $Box.Anims.Clear()
  }
}
