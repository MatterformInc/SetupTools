#Requires -Version 5.1
<#
.SYNOPSIS
  SetupTools GUI — run setup scripts from checkboxes and save/load defaults via config.json.
#>
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Several tools need Administrator; elevate once here so the steps can run silently.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    try {
        Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
        exit
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Not running as Administrator. Admin-only steps will fail.", "SetupTools", "OK", "Warning") | Out-Null
    }
}

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
            autoTimeZone = $true
            taskbarMainOnly = $true
            darkMode = $true
            gpuPcieCheck = $true
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
        [System.Windows.Forms.CheckBox]$cbStability,
        [System.Windows.Forms.CheckBox]$cbTimeZone,
        [System.Windows.Forms.CheckBox]$cbTaskbar,
        [System.Windows.Forms.CheckBox]$cbDarkMode,
        [System.Windows.Forms.CheckBox]$cbGpuPcie
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
            autoTimeZone = $cbTimeZone.Checked
            taskbarMainOnly = $cbTaskbar.Checked
            darkMode = $cbDarkMode.Checked
            gpuPcieCheck = $cbGpuPcie.Checked
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

$Script:OemEncoding = [System.Text.Encoding]::GetEncoding([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage)

# Progress bar colour: 1 = green, 2 = red, 3 = yellow.
Add-Type -Namespace SetupTools -Name Native -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);
'@
# Jump straight to a value; Windows animates increases slowly, but decreases are instant.
function Set-BarValue($bar, [int]$value) {
    if ($value -lt $bar.Maximum) { $bar.Value = $value + 1 } else { $bar.Maximum++; $bar.Value = $bar.Maximum; $bar.Maximum-- }
    $bar.Value = $value
}
function Set-BarState($bar, [int]$state) {
    [void][SetupTools.Native]::SendMessage($bar.Handle, 0x410, [IntPtr]$state, [IntPtr]::Zero)
}

$Script:IconPending = [string][char]0x25CB   # empty circle
$Script:IconRunning = [string][char]0x25B6   # play
$Script:IconOk      = [string][char]0x2714   # check
$Script:IconFail    = [string][char]0x2716   # cross
$Script:IconWarn    = [string][char]0x26A0   # warning sign
$Script:ProblemPattern = '(?i)\b(fail(ed)?|error|invalid|skipped|denied|not found|needs administrator)\b'

function Show-TaskDetails($task) {
    $Script:SelectedTask = $task
    foreach ($t in $Script:Tasks) { $t.Panel.BackColor = [System.Drawing.SystemColors]::Window }
    $task.Panel.BackColor = [System.Drawing.Color]::FromArgb(229, 241, 251)
    $lblDetails.Text = "Details: $($task.Name)"
    $tbDetails.Text = $task.Output.ToString()
    $tbDetails.SelectionStart = $tbDetails.TextLength
    $tbDetails.ScrollToCaret()
}

function New-TaskRow([string]$Name, [scriptblock]$Action, $Data, [int]$Index) {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(0, ($Index * 56))
    $panel.Size = New-Object System.Drawing.Size(456, 54)
    $panel.BackColor = [System.Drawing.SystemColors]::Window
    $panel.Cursor = 'Hand'

    $icon = New-Object System.Windows.Forms.Label
    $icon.Text = $Script:IconPending
    $icon.Font = New-Object System.Drawing.Font('Segoe UI Symbol', 13)
    $icon.ForeColor = [System.Drawing.Color]::Gray
    $icon.Location = New-Object System.Drawing.Point(6, 8)
    $icon.Size = New-Object System.Drawing.Size(28, 28)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = $Name
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $title.Location = New-Object System.Drawing.Point(36, 6)
    $title.Size = New-Object System.Drawing.Size(250, 18)

    $bar = New-Object System.Windows.Forms.ProgressBar
    $bar.Location = New-Object System.Drawing.Point(294, 8)
    $bar.Size = New-Object System.Drawing.Size(150, 14)
    $bar.Style = 'Continuous'
    $bar.MarqueeAnimationSpeed = 30

    $summary = New-Object System.Windows.Forms.Label
    $summary.Text = 'Waiting'
    $summary.ForeColor = [System.Drawing.Color]::Gray
    $summary.AutoEllipsis = $true
    $summary.Location = New-Object System.Drawing.Point(36, 28)
    $summary.Size = New-Object System.Drawing.Size(410, 18)

    $line = New-Object System.Windows.Forms.Label
    $line.BorderStyle = 'Fixed3D'
    $line.Location = New-Object System.Drawing.Point(0, 52)
    $line.Size = New-Object System.Drawing.Size(456, 2)

    $panel.Controls.AddRange(@($icon, $title, $bar, $summary, $line))
    $pnlTasks.Controls.Add($panel)

    $task = [pscustomobject]@{
        Name = $Name; Action = $Action; Panel = $panel; Icon = $icon; Bar = $bar; Summary = $summary
        Output = New-Object System.Text.StringBuilder; Status = 'pending'; Data = $Data
    }
    foreach ($c in @($panel, $icon, $title, $summary)) {
        $c.Tag = $task
        $c.Add_Click({ param($sender) Show-TaskDetails $sender.Tag })
    }
    return $task
}

function Add-TaskOutput($task, [string]$Text) {
    [void]$task.Output.AppendLine($Text)
    if ($Text.Trim()) { $task.Summary.Text = $Text.Trim() }
    if ($Script:SelectedTask -eq $task) { $tbDetails.AppendText($Text + "`r`n") }
}

function Set-TaskProgress($task, [int]$Percent) {
    $task.Bar.Style = 'Continuous'
    Set-BarValue $task.Bar ([Math]::Max(0, [Math]::Min(100, $Percent)))
}

function Complete-Task($task, [string]$Status, [string]$Summary) {
    $task.Status = $Status
    $task.Bar.Style = 'Continuous'
    Set-BarValue $task.Bar 100
    switch ($Status) {
        'ok'   { $task.Icon.Text = $Script:IconOk;   $task.Icon.ForeColor = [System.Drawing.Color]::FromArgb(16, 124, 16);  Set-BarState $task.Bar 1 }
        'warn' { $task.Icon.Text = $Script:IconWarn; $task.Icon.ForeColor = [System.Drawing.Color]::FromArgb(196, 120, 0); Set-BarState $task.Bar 3 }
        'fail' { $task.Icon.Text = $Script:IconFail; $task.Icon.ForeColor = [System.Drawing.Color]::FromArgb(196, 43, 28);  Set-BarState $task.Bar 2 }
    }
    if ($Summary) { $task.Summary.Text = $Summary }
    $task.Summary.ForeColor = if ($Status -eq 'ok') { [System.Drawing.Color]::DimGray } else { $task.Icon.ForeColor }
}

function Wait-WhileRunning($process) {
    while (-not $process.HasExited) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 30
    }
}

# Runs a tool's .bat hidden, with SETUPTOOLS_GUI=1 so it skips its pauses, streaming its output into the task.
# Returns the exit code.
function Invoke-BatTask($task, [string]$RelativePath, [string[]]$Arguments = @()) {
    $fullPath = Join-Path $Script:BasePath $RelativePath
    if (-not (Test-Path $fullPath)) {
        Add-TaskOutput $task "Not found: $RelativePath"
        return 1
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'cmd.exe'
    $psi.Arguments = '/c "' + ((@("`"$fullPath`"") + $Arguments) -join ' ') + ' 2>&1"'
    $psi.WorkingDirectory = Split-Path $fullPath -Parent
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true   # closed below, so any prompt gets EOF instead of hanging
    $psi.RedirectStandardOutput = $true
    $psi.StandardOutputEncoding = $Script:OemEncoding
    $psi.EnvironmentVariables['SETUPTOOLS_GUI'] = '1'

    $p = [System.Diagnostics.Process]::Start($psi)
    $p.StandardInput.Close()
    $pending = $p.StandardOutput.ReadLineAsync()
    while ($true) {
        if ($pending.IsCompleted) {
            $text = $pending.Result
            if ($null -eq $text) { break }
            Add-TaskOutput $task $text
            $pending = $p.StandardOutput.ReadLineAsync()
        } else {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 30
        }
    }
    $p.WaitForExit()
    return $p.ExitCode
}

# Runs one task: marks it running, calls its action, then marks ok / warn / fail.
# An action returns an exit code (0 = success) or a hashtable @{ Status; Summary }.
function Invoke-Task($task) {
    $task.Icon.Text = $Script:IconRunning
    $task.Icon.ForeColor = [System.Drawing.Color]::FromArgb(0, 103, 192)
    $task.Summary.ForeColor = [System.Drawing.Color]::Black
    $task.Summary.Text = 'Running...'
    $task.Bar.Style = 'Marquee'
    $pnlTasks.ScrollControlIntoView($task.Panel)
    [System.Windows.Forms.Application]::DoEvents()

    try {
        $result = & $task.Action $task
    } catch {
        Add-TaskOutput $task "Error: $($_.Exception.Message)"
        $result = 1
    }
    $result = @($result)[-1]

    $lines = @($task.Output.ToString() -split "`r?`n" | Where-Object { $_.Trim() })
    $problem = $lines | Where-Object { $_ -match $Script:ProblemPattern } | Select-Object -First 1
    if ($result -is [hashtable]) {
        Complete-Task $task $result.Status $result.Summary
    } elseif ([int]$result -ne 0) {
        $msg = if ($problem) { $problem.Trim() } elseif ($lines) { $lines[-1].Trim() } else { "Exit code $result" }
        Complete-Task $task 'fail' $msg
    } elseif ($problem) {
        Complete-Task $task 'warn' $problem.Trim()
    } else {
        Complete-Task $task 'ok' $null
    }
}

$config = Get-Config
$d = $config.defaults

$form = New-Object System.Windows.Forms.Form
$form.Text = 'SetupTools'
$form.Size = New-Object System.Drawing.Size(960, 632)
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
$cbPower.Text = 'Power && Performance (Admin)'
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
$y += $rowH

$cbTimeZone = New-Object System.Windows.Forms.CheckBox
$cbTimeZone.Text = 'Set time zone automatically (enables location) (Admin)'
$cbTimeZone.Location = New-Object System.Drawing.Point(20, $y)
$cbTimeZone.Size = New-Object System.Drawing.Size(400, 24)
$cbTimeZone.Checked = ($d.autoTimeZone -ne $false)
$form.Controls.Add($cbTimeZone)
$y += $rowH

$cbTaskbar = New-Object System.Windows.Forms.CheckBox
$cbTaskbar.Text = 'Taskbar on main display only'
$cbTaskbar.Location = New-Object System.Drawing.Point(20, $y)
$cbTaskbar.Size = New-Object System.Drawing.Size(400, 24)
$cbTaskbar.Checked = ($d.taskbarMainOnly -ne $false)
$form.Controls.Add($cbTaskbar)
$y += $rowH

$cbDarkMode = New-Object System.Windows.Forms.CheckBox
$cbDarkMode.Text = 'Dark mode'
$cbDarkMode.Location = New-Object System.Drawing.Point(20, $y)
$cbDarkMode.Size = New-Object System.Drawing.Size(400, 24)
$cbDarkMode.Checked = ($d.darkMode -ne $false)
$form.Controls.Add($cbDarkMode)
$y += $rowH

$cbGpuPcie = New-Object System.Windows.Forms.CheckBox
$cbGpuPcie.Text = 'Check GPU PCIe link (x16, reseat/riser/BIOS)'
$cbGpuPcie.Location = New-Object System.Drawing.Point(20, $y)
$cbGpuPcie.Size = New-Object System.Drawing.Size(400, 24)
$cbGpuPcie.Checked = ($d.gpuPcieCheck -ne $false)
$form.Controls.Add($cbGpuPcie)
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

$lblOverall = New-Object System.Windows.Forms.Label
$lblOverall.Text = 'Tick the steps on the left, then click Apply selected.'
$lblOverall.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$lblOverall.Location = New-Object System.Drawing.Point(450, 14)
$lblOverall.Size = New-Object System.Drawing.Size(480, 20)
$form.Controls.Add($lblOverall)

$barOverall = New-Object System.Windows.Forms.ProgressBar
$barOverall.Location = New-Object System.Drawing.Point(450, 36)
$barOverall.Size = New-Object System.Drawing.Size(480, 18)
$barOverall.Style = 'Continuous'
$form.Controls.Add($barOverall)

$pnlTasks = New-Object System.Windows.Forms.Panel
$pnlTasks.Location = New-Object System.Drawing.Point(450, 62)
$pnlTasks.Size = New-Object System.Drawing.Size(480, 340)
$pnlTasks.AutoScroll = $true
$pnlTasks.BorderStyle = 'FixedSingle'
$pnlTasks.BackColor = [System.Drawing.SystemColors]::Window
$form.Controls.Add($pnlTasks)

$lblDetails = New-Object System.Windows.Forms.Label
$lblDetails.Text = 'Details (click a task)'
$lblDetails.Location = New-Object System.Drawing.Point(450, 408)
$lblDetails.Size = New-Object System.Drawing.Size(480, 18)
$form.Controls.Add($lblDetails)

$tbDetails = New-Object System.Windows.Forms.TextBox
$tbDetails.Multiline = $true
$tbDetails.ReadOnly = $true
$tbDetails.ScrollBars = 'Vertical'
$tbDetails.WordWrap = $true
$tbDetails.Font = New-Object System.Drawing.Font('Consolas', 9)
$tbDetails.BackColor = [System.Drawing.SystemColors]::Window
$tbDetails.Location = New-Object System.Drawing.Point(450, 428)
$tbDetails.Size = New-Object System.Drawing.Size(480, 150)
$form.Controls.Add($tbDetails)

$Script:Tasks = @()
$Script:SelectedTask = $null

$btnApply.Add_Click({
    $restartTime = $tbRestartTime.Text.Trim()
    if ($cbRestart.Checked -and -not $restartTime) {
        [System.Windows.Forms.MessageBox]::Show("Enter a restart time (HH:MM).", "SetupTools", "OK", "Information")
        return
    }
    $customPaths = @($tbDefenderPaths.Text -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })

    # Each entry: name + action. Actions get the task and return an exit code or @{ Status; Summary }.
    $plan = New-Object System.Collections.ArrayList
    if ($cbAutoLogin.Checked) {
        [void]$plan.Add(@('Auto Login', {
            param($t)
            $t.Summary.Text = 'Waiting for input in the Auto Login window...'
            $path = Join-Path $Script:BasePath 'Auto Login\enable-auto-login.bat'
            $p = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', "`"$path`"") -WorkingDirectory (Split-Path $path -Parent) -PassThru
            Wait-WhileRunning $p
            Add-TaskOutput $t 'Ran in its own window (it asks for the password).'
            $p.ExitCode
        }))
    }
    if ($cbAutoDnd.Checked)       { [void]$plan.Add(@('Do Not Disturb (24/7)', { param($t) Invoke-BatTask $t 'Auto Do Not Disturb\enable-auto-dnd.bat' })) }
    if ($cbRestart.Checked)       { [void]$plan.Add(@("Daily restart at $restartTime", { param($t) Invoke-BatTask $t 'Auto Restart Schedule\schedule-restart.bat' @($t.Data) }, $restartTime)) }
    if ($cbGameBar.Checked)       { [void]$plan.Add(@('Disable Game Bar / DVR', { param($t) Invoke-BatTask $t 'Disable Game Bar\disable-game-bar.bat' })) }
    if ($cbInterruptions.Checked) { [void]$plan.Add(@('Disable interruptions', { param($t) Invoke-BatTask $t 'Disable Interruptions\disable-interruptions.bat' })) }
    if ($cbPower.Checked)         { [void]$plan.Add(@('Power and performance', { param($t) Invoke-BatTask $t 'Power and Performance\power-and-performance.bat' })) }
    if ($cbDefender.Checked) {
        [void]$plan.Add(@('Defender exclusions (Unreal / TouchDesigner)', { param($t) Invoke-BatTask $t 'Defender Exclusions\defender-exclusions-unreal-touchdesigner.bat' }))
        if ($customPaths.Count -gt 0) {
            [void]$plan.Add(@("Defender exclusions ($($customPaths.Count) custom path(s))", {
                param($t)
                $paths = @($t.Data)
                $failed = 0
                for ($i = 0; $i -lt $paths.Count; $i++) {
                    $path = $paths[$i]
                    try {
                        Add-MpPreference -ExclusionPath $path -ErrorAction Stop
                        Add-TaskOutput $t "Added: $path"
                    } catch {
                        Add-TaskOutput $t "FAILED: $path ($($_.Exception.Message))"
                        $failed++
                    }
                    Set-TaskProgress $t ((($i + 1) * 100) / $paths.Count)
                    [System.Windows.Forms.Application]::DoEvents()
                }
                $failed
            }, $customPaths))
        }
    }
    if ($cbStability.Checked)     { [void]$plan.Add(@('Stability', { param($t) Invoke-BatTask $t 'Stability\stability-settings.bat' })) }
    if ($cbTimeZone.Checked)      { [void]$plan.Add(@('Set time zone automatically', { param($t) Invoke-BatTask $t 'Desktop Preferences\set-time-zone-automatically.bat' })) }
    if ($cbTaskbar.Checked)       { [void]$plan.Add(@('Taskbar on main display only', { param($t) Invoke-BatTask $t 'Desktop Preferences\disable-taskbar-all-displays.bat' })) }
    if ($cbDarkMode.Checked)      { [void]$plan.Add(@('Dark mode', { param($t) Invoke-BatTask $t 'Desktop Preferences\enable-dark-mode.bat' })) }
    if ($cbGpuPcie.Checked)       { [void]$plan.Add(@('GPU PCIe link check', { param($t) Invoke-BatTask $t 'GPU PCIe Check\check-gpu-pcie.bat' })) }
    # The steps skip their own Explorer restarts in GUI mode; do it once at the end.
    if ($cbAutoDnd.Checked -or $cbTaskbar.Checked -or $cbStability.Checked) {
        [void]$plan.Add(@('Restart Explorer (apply taskbar / notification changes)', {
            param($t)
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 800
            if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
            Add-TaskOutput $t 'Explorer restarted.'
            0
        }))
    }

    if ($plan.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Select at least one option.", "SetupTools", "OK", "Information")
        return
    }

    # Build the to-do stack
    $btnApply.Enabled = $false
    $pnlTasks.Controls.Clear()
    $tbDetails.Clear()
    $lblDetails.Text = 'Details (click a task)'
    $Script:SelectedTask = $null
    $Script:Tasks = @()
    for ($i = 0; $i -lt $plan.Count; $i++) {
        $Script:Tasks += New-TaskRow $plan[$i][0] $plan[$i][1] $plan[$i][2] $i
    }
    $barOverall.Maximum = $Script:Tasks.Count
    $barOverall.Value = 0
    Set-BarState $barOverall 1

    try {
        $done = 0
        foreach ($task in $Script:Tasks) {
            $lblOverall.Text = "Running $($done + 1) of $($Script:Tasks.Count): $($task.Name)"
            Invoke-Task $task
            $done++
            Set-BarValue $barOverall $done
        }
    } finally {
        $btnApply.Enabled = $true
    }

    $failed = @($Script:Tasks | Where-Object Status -eq 'fail').Count
    $warned = @($Script:Tasks | Where-Object Status -eq 'warn').Count
    $ok = $Script:Tasks.Count - $failed - $warned
    $lblOverall.Text = "Done: $ok succeeded, $warned warning(s), $failed failed. Click a task for details."
    if ($failed -gt 0) { Set-BarState $barOverall 2 } elseif ($warned -gt 0) { Set-BarState $barOverall 3 }
    $firstProblem = $Script:Tasks | Where-Object { $_.Status -ne 'ok' } | Select-Object -First 1
    if ($firstProblem) { Show-TaskDetails $firstProblem }
})

$btnSave.Add_Click({
    Save-Config -cbAutoLogin $cbAutoLogin -cbAutoDnd $cbAutoDnd -cbRestart $cbRestart -tbRestartTime $tbRestartTime -cbGameBar $cbGameBar -cbInterruptions $cbInterruptions -cbPower $cbPower -cbDefender $cbDefender -tbDefenderPaths $tbDefenderPaths -cbStability $cbStability -cbTimeZone $cbTimeZone -cbTaskbar $cbTaskbar -cbDarkMode $cbDarkMode -cbGpuPcie $cbGpuPcie
})

$btnConfig.Add_Click({
    if (Test-Path $ConfigPath) { Start-Process notepad $ConfigPath } else { [System.Windows.Forms.MessageBox]::Show("config.json not found.", "SetupTools") }
})

$form.Topmost = $false
[void]$form.ShowDialog()
