#Requires -Version 5.1
<#
.SYNOPSIS
  Checks that each PCIe GPU is running at its full link width (e.g. x16, not x1).
  Uses Windows PnP device properties, so it works for NVIDIA, AMD and Intel cards.
  Exit code: 0 = all GPUs at full width, 1 = at least one GPU running below full width.
#>

$speedNames = @{ 1 = 'Gen1'; 2 = 'Gen2'; 3 = 'Gen3'; 4 = 'Gen4'; 5 = 'Gen5'; 6 = 'Gen6' }
$keys = 'DEVPKEY_PciDevice_CurrentLinkWidth', 'DEVPKEY_PciDevice_MaxLinkWidth',
        'DEVPKEY_PciDevice_CurrentLinkSpeed', 'DEVPKEY_PciDevice_MaxLinkSpeed'

$found = 0
$problems = 0

foreach ($dev in Get-PnpDevice -Class Display -PresentOnly -ErrorAction SilentlyContinue) {
    $props = @{}
    Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName $keys -ErrorAction SilentlyContinue |
        ForEach-Object { $props[$_.KeyName] = $_.Data }

    $curW = $props['DEVPKEY_PciDevice_CurrentLinkWidth']
    $maxW = $props['DEVPKEY_PciDevice_MaxLinkWidth']
    # Integrated GPUs, USB docks and virtual displays have no PCIe link; skip them.
    if (-not $curW -or -not $maxW) { continue }
    $found++

    $curS = $props['DEVPKEY_PciDevice_CurrentLinkSpeed']
    $maxS = $props['DEVPKEY_PciDevice_MaxLinkSpeed']
    $curSName = if ($speedNames.ContainsKey([int]$curS)) { $speedNames[[int]$curS] } else { "speed $curS" }
    $maxSName = if ($speedNames.ContainsKey([int]$maxS)) { $speedNames[[int]$maxS] } else { "speed $maxS" }

    Write-Host ''
    Write-Host $dev.FriendlyName -ForegroundColor White
    Write-Host ("  Link width: x{0} of x{1}" -f $curW, $maxW)
    Write-Host ("  Link speed: {0} of {1}" -f $curSName, $maxSName)

    if ([int]$curW -lt [int]$maxW) {
        $problems++
        Write-Host ("  FAIL: running at x{0} instead of x{1}." -f $curW, $maxW) -ForegroundColor Red
    } else {
        Write-Host '  OK: full link width.' -ForegroundColor Green
    }
    if ([int]$curS -lt [int]$maxS) {
        # GPUs drop link speed at idle to save power, so this alone is not a fault.
        Write-Host '  Note: link speed below max. Normal at idle; re-check while the GPU is under load.' -ForegroundColor DarkGray
    }
}

Write-Host ''
if ($found -eq 0) {
    Write-Host 'No PCIe GPU found (only integrated, USB or virtual display adapters).' -ForegroundColor Yellow
    exit 0
}

if ($problems -gt 0) {
    Write-Host 'GPU is not running at full PCIe width. Common causes, most likely first:' -ForegroundColor Yellow
    Write-Host @'

  1. Card not fully seated, or it sagged. Heavy cards (e.g. 4090) can lift the far
     end of the connector so only the first lanes make contact. Power down, reseat
     it, and support it with an anti-sag bracket.
  2. Riser cable, if the card is mounted vertically. A bad or loose riser often
     drops to x1.
  3. Wrong slot or lanes shared. Make sure it's in the top x16 slot from the CPU.
     Some boards cut that slot's lanes when certain M.2 slots or a second card are
     in use; the board manual has a table for this.
  4. BIOS setting. Check that the PCIe slot setting is Auto or Gen4 x16, not x1 or
     bifurcated.
'@
    exit 1
}

Write-Host 'All PCIe GPUs are running at full link width.' -ForegroundColor Green
exit 0
