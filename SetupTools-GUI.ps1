#Requires -Version 5.1
<#
.SYNOPSIS
  SetupTools GUI — run setup scripts from checkboxes and save/load defaults via config.json.
#>
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Script:BasePath = $PSScriptRoot
$ConfigPath = Join-Path $BasePath 'config.json'

function Get-Config {
    if (Test-Path $ConfigPath) {
        try {
            return Get-Content $ConfigPath -Raw | ConvertFrom-Json
        } catch { }
    }
    return @{
        defaults = @{
            autoLogin = $false
            autoDnd = $false
            restartSchedule = $false
            restartTime = '04:00'
            disableGameBar = $true
            disableInterruptions = $true
            powerPerformance = $true
            defenderExclusions = $true
            defenderExclusionPaths = @()
            stability = $true
        }
    } | ConvertTo-Json -Depth 5 | ConvertFrom-Json
}

function Save-Config {
    param(
        [System.Windows.Forms.CheckBox]$cbAutoLogin,
        [System.Windows.Forms.CheckBox]$cbAutoDnd,
        [System.Windows.Forms.CheckBox]$cbRestart,
        [System.Windows.Forms.TextBox]$tbRestartTime,
        [System.Windows.Forms.CheckBox]$cbGameBar,
        [System.Windows.Forms.CheckBox]$cbInterruptions,
        [System.Windows.Forms.CheckBox]$cbPower,
        [System.Windows.Forms.CheckBox]$cbDefender,
        [System.Windows.Forms.TextBox]$tbDefenderPaths,
        [System.Windows.Forms.CheckBox]$cbStability
    )
    $paths = @($tbDefenderPaths.Text -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    $o = @{
        defaults = @{
            autoLogin = $cbAutoLogin.Checked
            autoDnd = $cbAutoDnd.Checked
            restartSchedule = $cbRestart.Checked
            restartTime = $tbRestartTime.Text.Trim()
            disableGameBar = $cbGameBar.Checked
            disableInterruptions = $cbInterruptions.Checked
            powerPerformance = $cbPower.Checked
            defenderExclusions = $cbDefender.Checked
            defenderExclusionPaths = $paths
            stability = $cbStability.Checked
        }
        notes = @{
            autoLogin = 'Requires Administrator. Prompts for credentials.'
            restartTime = '24-hour format, e.g. 04:00 or 22:30'
            defenderExclusionPaths = 'One path per line; saved in config and applied when Defender Exclusions is run.'
        }
    }
    $o | ConvertTo-Json -Depth 5 | Set-Content $ConfigPath -Encoding UTF8
    [System.Windows.Forms.MessageBox]::Show("Defaults saved to config.json.", "SetupTools")
}

function Run-Bat {
    param([string]$RelativePath, [string[]]$Arguments = @())
    $fullPath = Join-Path $Script:BasePath $RelativePath
    if (-not (Test-Path $fullPath)) {
        [System.Windows.Forms.MessageBox]::Show("Not found: $RelativePath", "SetupTools", "OK", "Warning")
        return
    }
    $argList = @('/c', "`"$fullPath`"") + $Arguments
    Start-Process -FilePath 'cmd.exe' -ArgumentList $argList -WorkingDirectory (Split-Path $fullPath -Parent) -Wait
}

$config = Get-Config
$d = $config.defaults

$form = New-Object System.Windows.Forms.Form
$form.Text = 'SetupTools'
$form.Size = New-Object System.Drawing.Size(460, 520)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false

[int]$y = 16
[int]$rowH = 28

$cbAutoLogin = New-Object System.Windows.Forms.CheckBox
$cbAutoLogin.Text = 'Auto Login (enable)'
$cbAutoLogin.Location = New-Object System.Drawing.Point(20, $y)
$cbAutoLogin.Size = New-Object System.Drawing.Size(360, 24)
$cbAutoLogin.Checked = $d.autoLogin
$form.Controls.Add($cbAutoLogin)
$y += $rowH

$cbAutoDnd = New-Object System.Windows.Forms.CheckBox
$cbAutoDnd.Text = 'Auto Do Not Disturb (enable)'
$cbAutoDnd.Location = New-Object System.Drawing.Point(20, $y)
$cbAutoDnd.Size = New-Object System.Drawing.Size(360, 24)
$cbAutoDnd.Checked = $d.autoDnd
$form.Controls.Add($cbAutoDnd)
$y += $rowH

$cbRestart = New-Object System.Windows.Forms.CheckBox
$cbRestart.Text = 'Auto Restart Schedule (daily)'
$cbRestart.Location = New-Object System.Drawing.Point(20, $y)
$cbRestart.Size = New-Object System.Drawing.Size(360, 24)
$cbRestart.Checked = $d.restartSchedule
$form.Controls.Add($cbRestart)
$y += $rowH

$lblTime = New-Object System.Windows.Forms.Label
$lblTime.Text = 'Restart time (HH:MM):'
$lblTime.Location = New-Object System.Drawing.Point(40, $y)
$lblTime.Size = New-Object System.Drawing.Size(120, 20)
$form.Controls.Add($lblTime)
$tbRestartTime = New-Object System.Windows.Forms.TextBox
$tbRestartTime.Text = $d.restartTime
$tbRestartTime.Location = New-Object System.Drawing.Point(165, ([int]$y - 2))
$tbRestartTime.Size = New-Object System.Drawing.Size(80, 22)
$form.Controls.Add($tbRestartTime)
$y += $rowH

$cbGameBar = New-Object System.Windows.Forms.CheckBox
$cbGameBar.Text = 'Disable Game Bar / DVR'
$cbGameBar.Location = New-Object System.Drawing.Point(20, $y)
$cbGameBar.Size = New-Object System.Drawing.Size(360, 24)
$cbGameBar.Checked = $d.disableGameBar
$form.Controls.Add($cbGameBar)
$y += $rowH

$cbInterruptions = New-Object System.Windows.Forms.CheckBox
$cbInterruptions.Text = 'Disable Interruptions (sleep, tips)'
$cbInterruptions.Location = New-Object System.Drawing.Point(20, $y)
$cbInterruptions.Size = New-Object System.Drawing.Size(360, 24)
$cbInterruptions.Checked = $d.disableInterruptions
$form.Controls.Add($cbInterruptions)
$y += $rowH

$cbPower = New-Object System.Windows.Forms.CheckBox
$cbPower.Text = 'Power & Performance (Admin)'
$cbPower.Location = New-Object System.Drawing.Point(20, $y)
$cbPower.Size = New-Object System.Drawing.Size(360, 24)
$cbPower.Checked = $d.powerPerformance
$form.Controls.Add($cbPower)
$y += $rowH

$cbDefender = New-Object System.Windows.Forms.CheckBox
$cbDefender.Text = 'Defender Exclusions (Unreal/TD + custom paths) (Admin)'
$cbDefender.Location = New-Object System.Drawing.Point(20, $y)
$cbDefender.Size = New-Object System.Drawing.Size(400, 24)
$cbDefender.Checked = $d.defenderExclusions
$form.Controls.Add($cbDefender)
$y += $rowH

$lblDefenderPaths = New-Object System.Windows.Forms.Label
$lblDefenderPaths.Text = 'Extra paths (one per line):'
$lblDefenderPaths.Location = New-Object System.Drawing.Point(40, $y)
$lblDefenderPaths.Size = New-Object System.Drawing.Size(380, 18)
$form.Controls.Add($lblDefenderPaths)
$y += 20

$tbDefenderPaths = New-Object System.Windows.Forms.TextBox
$tbDefenderPaths.Multiline = $true
$tbDefenderPaths.ScrollBars = 'Vertical'
$tbDefenderPaths.Location = New-Object System.Drawing.Point(40, $y)
$tbDefenderPaths.Size = New-Object System.Drawing.Size(380, 72)
$defPaths = @($d.defenderExclusionPaths)
if ($defPaths -and $defPaths.Count -gt 0) {
    $tbDefenderPaths.Text = ($defPaths -join "`r`n")
}
$form.Controls.Add($tbDefenderPaths)
$y += 80

$cbStability = New-Object System.Windows.Forms.CheckBox
$cbStability.Text = 'Stability (delivery opt, visuals) (Admin)'
$cbStability.Location = New-Object System.Drawing.Point(20, $y)
$cbStability.Size = New-Object System.Drawing.Size(360, 24)
$cbStability.Checked = $d.stability
$form.Controls.Add($cbStability)
$y += $rowH + 8

$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = 'Apply selected'
$btnApply.Location = New-Object System.Drawing.Point(20, $y)
$btnApply.Size = New-Object System.Drawing.Size(120, 28)
$form.Controls.Add($btnApply)

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = 'Save as default'
$btnSave.Location = New-Object System.Drawing.Point(150, $y)
$btnSave.Size = New-Object System.Drawing.Size(120, 28)
$form.Controls.Add($btnSave)

$btnConfig = New-Object System.Windows.Forms.Button
$btnConfig.Text = 'Open config'
$btnConfig.Location = New-Object System.Drawing.Point(280, $y)
$btnConfig.Size = New-Object System.Drawing.Size(100, 28)
$form.Controls.Add($btnConfig)
$y += 40

$btnApply.Add_Click({
    if ($cbAutoLogin.Checked)   { Run-Bat 'Auto Login\enable-auto-login.bat' }
    if ($cbAutoDnd.Checked)     { Run-Bat 'Auto Do Not Disturb\enable-auto-dnd.bat' }
    if ($cbRestart.Checked)      {
        $t = $tbRestartTime.Text.Trim()
        if ($t) { Run-Bat 'Auto Restart Schedule\schedule-restart.bat' @($t) } else { Run-Bat 'Auto Restart Schedule\schedule-restart.bat' }
    }
    if ($cbGameBar.Checked)      { Run-Bat 'Disable Game Bar\disable-game-bar.bat' }
    if ($cbInterruptions.Checked){ Run-Bat 'Disable Interruptions\disable-interruptions.bat' }
    if ($cbPower.Checked)        { Run-Bat 'Power and Performance\power-and-performance.bat' }
    if ($cbDefender.Checked)     {
        Run-Bat 'Defender Exclusions\defender-exclusions-unreal-touchdesigner.bat'
        $customPaths = @($tbDefenderPaths.Text -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
        if ($customPaths.Count -gt 0) {
            $tempFile = [System.IO.Path]::GetTempFileName()
            $customPaths | Set-Content $tempFile -Encoding UTF8
            $script = "param(`$f); `$lines = Get-Content -Path `$f -Encoding UTF8; foreach (`$p in `$lines) { Add-MpPreference -ExclusionPath `$p -ErrorAction SilentlyContinue }; Remove-Item -Path `$f -Force; Write-Host ('Added ' + `$lines.Count + ' path(s).')"
            powershell -NoProfile -ExecutionPolicy Bypass -Command $script -Args $tempFile
        }
    }
    if ($cbStability.Checked)    { Run-Bat 'Stability\stability-settings.bat' }
    if (-not ($cbAutoLogin.Checked -or $cbAutoDnd.Checked -or $cbRestart.Checked -or $cbGameBar.Checked -or $cbInterruptions.Checked -or $cbPower.Checked -or $cbDefender.Checked -or $cbStability.Checked)) {
        [System.Windows.Forms.MessageBox]::Show("Select at least one option.", "SetupTools", "OK", "Information")
    }
})

$btnSave.Add_Click({
    Save-Config -cbAutoLogin $cbAutoLogin -cbAutoDnd $cbAutoDnd -cbRestart $cbRestart -tbRestartTime $tbRestartTime -cbGameBar $cbGameBar -cbInterruptions $cbInterruptions -cbPower $cbPower -cbDefender $cbDefender -tbDefenderPaths $tbDefenderPaths -cbStability $cbStability
})

$btnConfig.Add_Click({
    if (Test-Path $ConfigPath) { Start-Process notepad $ConfigPath } else { [System.Windows.Forms.MessageBox]::Show("config.json not found.", "SetupTools") }
})

$form.Topmost = $false
[void]$form.ShowDialog()
