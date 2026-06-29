# WPF object construction needs STA; powershell.exe (5.1) is STA by default.
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing
. "$PSScriptRoot\..\notify-lib.ps1"
. "$PSScriptRoot\..\lib\notification-box.ps1"

$script:fail = 0
function Assert-True($cond, $msg) {
  if ([bool]$cond) { Write-Host "ok: $msg" } else { Write-Host "FAIL: $msg"; $script:fail++ }
}

$theme = @{ gradient = @('#FF5F6D 0', '#A56BFF 1'); rim = @('#7C3AED 0', '#EC4899 1'); card = '#18181B'; hero = '🦄' }
$ev    = @{ label = 'Done!'; accent = '#22C55E'; indicator = '' }
$body  = @(
  [pscustomobject]@{ text = ('x' * 300); style = 'headline' },
  [pscustomobject]@{ text = '/proj/';    style = 'sub' }
)
$wa  = New-Object System.Drawing.Rectangle 0, 0, 1920, 1080
$box = New-NotificationBox -Event 'done' -Theme $theme -Ev $ev -BodyLines $body -WorkArea $wa

# A body line must be width-bounded: an unbounded TextBlock runs off the card's right
# edge (hard-clipped, no marquee). Bounding it both stops the overflow AND lets the
# Initialize-NotificationCard marquee engage (it gates on ActualWidth < full text width).
foreach ($tb in $box.BodyTbs) {
  Assert-True (-not [double]::IsInfinity($tb.MaxWidth)) "body line has a finite MaxWidth"
  Assert-True ($tb.MaxWidth -le 560) "body line MaxWidth fits inside the 586px card"
}

# --- Marquee actually reveals the full text ---
# The card is shown off-screen so its body lines get a real ActualWidth, then the marquee
# engages. A long line is hosted in a clip viewport and scrolled; for any tail to exist to
# scroll into view, the TextBlock's own MaxWidth must be lifted - otherwise NoWrap clips it
# at the card width and the text past ~52 chars is never rendered (permanently cut off).
$win = $box.Win
$win.ShowInTaskbar = $false
$win.WindowStartupLocation = 'Manual'
$win.Left = -10000; $win.Top = -10000
$script:marqueeWidth = 0
$script:viewportWidth = 0
$win.Add_Loaded({
  try {
    # New-NotificationBox's own Loaded already ran the marquee; force a layout pass so the
    # relaid-out body line reports its real rendered width, then measure.
    $win.UpdateLayout()
    $tb = $box.BodyTbs[0]
    $script:marqueeWidth  = $tb.ActualWidth
    $script:viewportWidth = $tb.Parent.ActualWidth
  } finally { $win.Close() }
})
# Safety net: never let a misbehaving Loaded hang the suite.
$guard = New-Object System.Windows.Threading.DispatcherTimer
$guard.Interval = [TimeSpan]::FromSeconds(5)
$guard.Add_Tick({ $guard.Stop(); $win.Close() })
$guard.Start()
$win.ShowDialog() | Out-Null

# The line must lay out at its FULL text width inside the clip viewport - far wider than
# the ~520px viewport. If it only renders viewport-width, the tail was clipped at layout
# and scrolling reveals blank space, not the rest of the message.
Assert-True ($script:marqueeWidth -gt ($script:viewportWidth * 2)) "marquee'd body line lays out full-width (got $([int]$script:marqueeWidth)px vs viewport $([int]$script:viewportWidth)px)"

if ($script:fail -gt 0) { exit 1 } else { Write-Host "ALL PASS" }
