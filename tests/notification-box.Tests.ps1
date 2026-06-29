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

if ($script:fail -gt 0) { exit 1 } else { Write-Host "ALL PASS" }
