#Requires -Version 5.1
<#
.SYNOPSIS
  Removes the screens that can stop an unattended PC on boot or sign-in, for every user.
  Used by disable-boot-interruptions.bat (and enable-boot-interruptions.bat with -Undo).

  Machine:
    - No Startup Repair / Automatic Repair screen after a power cut (bcdedit)
    - No privacy-settings screen after updates (policy DisablePrivacyExperience)
    - No "Hi / getting things ready" first sign-in animation (policy EnableFirstLogonAnimation)
    - No "Set up Windows Hello / PIN" prompt after sign-in (policy PassportForWork)
    - No Ctrl+Alt+Del before signing in (DisableCAD)
    - Fewer consumer "experiences" (CloudContent policies; some only apply on Enterprise/Education)
  Every user profile (existing users + the default profile new users are copied from):
    - No "Let's finish setting up your device" / Microsoft account / backup upsell after updates
    - No Windows welcome experience after updates, no account or backup nags in Start / Explorer

  Exit code: 0 = all applied, 1 = something failed (see output).
#>
param([switch]$Undo)

$failures = 0
function Invoke-Step([string]$Name, [scriptblock]$Action) {
    try {
        & $Action
        Write-Host "  OK      $Name"
    } catch {
        Write-Host "  FAILED  $Name ($($_.Exception.Message))"
        $script:failures++
    }
}

function Set-Value([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord') {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
}

function Remove-Value([string]$Path, [string]$Name) {
    if (Test-Path $Path) { Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue }
}

# Per-user values: path under the user's hive, name, value when blocking, value when undoing.
$userValues = @(
    ,@('Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement',           'ScoobeSystemSettingEnabled',       0, 1)
    ,@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager',          'SubscribedContent-310093Enabled',  0, 1)
    ,@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager',          'SoftLandingEnabled',               0, 1)
    ,@('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager',          'SubscribedContent-338389Enabled',  0, 1)
    ,@('Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced',               'Start_AccountNotifications',       0, 1)
    ,@('Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced',               'Start_IrisRecommendations',        0, 1)
    ,@('Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced',               'ShowSyncProviderNotifications',    0, 1)
    ,@('Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications', 'EnableAccountNotifications',   0, 1)
    ,@('Software\Policies\Microsoft\Windows\CloudContent',                          'DisableWindowsSpotlightFeatures',  1, $null)
    ,@('Software\Policies\Microsoft\Windows\CloudContent',                          'DisableTailoredExperiencesWithDiagnosticData', 1, $null)
)

function Set-UserValues([string]$HiveRoot) {
    foreach ($v in $userValues) {
        $path = "Registry::$HiveRoot\$($v[0])"
        if ($Undo) {
            if ($null -eq $v[3]) { Remove-Value $path $v[1] } else { Set-Value $path $v[1] $v[3] }
        } else {
            Set-Value $path $v[1] $v[2]
        }
    }
}

$verb = if ($Undo) { 'Restoring' } else { 'Blocking' }
Write-Host "$verb boot and sign-in interruptions..."
Write-Host ''
Write-Host 'Machine'

# --- Startup Repair after power loss ---
Invoke-Step 'Startup Repair screen after power loss' {
    $settings = if ($Undo) { @(@('recoveryenabled', 'Yes'), @('bootstatuspolicy', 'DisplayAllFailures')) }
                else       { @(@('recoveryenabled', 'No'),  @('bootstatuspolicy', 'IgnoreAllFailures')) }
    foreach ($b in $settings) {
        $out = & bcdedit /set '{current}' $b[0] $b[1] 2>&1
        if ($LASTEXITCODE -ne 0) { throw "bcdedit $($b[0]): $out" }
    }
}

# --- Policies ---
$policies = @(
    ,@('Privacy-settings screen after updates',     'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE',           'DisablePrivacyExperience',      1)
    ,@('First sign-in animation',                   'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System',         'EnableFirstLogonAnimation',     0)
    ,@('Windows Hello / PIN setup prompt',          'HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork',        'Enabled',                       0)
    ,@('Windows Hello post-sign-in provisioning',   'HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork',        'DisablePostLogonProvisioning',  1)
    ,@('Consumer experiences (Enterprise/Edu)',     'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent',   'DisableWindowsConsumerFeatures', 1)
    ,@('Soft-landing tips',                         'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent',   'DisableSoftLanding',            1)
    ,@('Cloud-optimized content',                   'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent',   'DisableCloudOptimizedContent',  1)
)
foreach ($p in $policies) {
    Invoke-Step $p[0] { if ($Undo) { Remove-Value $p[1] $p[2] } else { Set-Value $p[1] $p[2] $p[3] } }
}
Invoke-Step 'Ctrl+Alt+Del before sign-in' {
    $k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    if ($Undo) { Remove-Value $k 'DisableCAD' } else { Set-Value $k 'DisableCAD' 1 }
}

# --- Every user profile ---
Write-Host ''
Write-Host 'Users'
$profiles = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { -not $_.Special -and $_.LocalPath }
foreach ($prof in $profiles) {
    $name = Split-Path $prof.LocalPath -Leaf
    Invoke-Step "User: $name" {
        if (Test-Path "Registry::HKEY_USERS\$($prof.SID)") {
            Set-UserValues "HKEY_USERS\$($prof.SID)"          # signed in: hive already loaded
        } else {
            $hive = Join-Path $prof.LocalPath 'NTUSER.DAT'
            if (-not (Test-Path $hive)) { throw 'no NTUSER.DAT' }
            $mount = "HKU\SetupTools_$($prof.SID)"
            & reg.exe load $mount $hive 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'could not load the profile (in use?)' }
            try { Set-UserValues "HKEY_USERS\SetupTools_$($prof.SID)" }
            finally { [gc]::Collect(); [gc]::WaitForPendingFinalizers(); & reg.exe unload $mount 2>&1 | Out-Null }
        }
    }
}
Invoke-Step 'Default profile (new users)' {
    $hive = Join-Path $env:SystemDrive 'Users\Default\NTUSER.DAT'
    $mount = 'HKU\SetupTools_Default'
    & reg.exe load $mount $hive 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'could not load the default profile' }
    try { Set-UserValues 'HKEY_USERS\SetupTools_Default' }
    finally { [gc]::Collect(); [gc]::WaitForPendingFinalizers(); & reg.exe unload $mount 2>&1 | Out-Null }
}

& gpupdate /target:computer /force 2>&1 | Out-Null

Write-Host ''
if ($failures -gt 0) {
    Write-Host "$failures item(s) failed."
    exit 1
}
Write-Host $(if ($Undo) { 'Done. Boot and sign-in screens restored.' } else { 'Done. Boot and sign-in interruptions blocked for all users.' })
exit 0
