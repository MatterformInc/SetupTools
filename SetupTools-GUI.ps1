#Requires -Version 5.1
<#
.SYNOPSIS
  SetupTools GUI - pick setup steps from a category tree, run them as a to-do list with progress,
  and save/load defaults via config.json.
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
$ConfigPath = Join-Path $Script:BasePath 'config.json'

# ---------------------------------------------------------------------------
# Tools. Category = tree group. Admin = needs elevation. RestartsExplorer = applied by the
# single Explorer restart at the end of a run.
# ---------------------------------------------------------------------------
$Tools = @(
    @{ Key = 'autoLogin';            Category = 'Session and login'; Label = 'Auto login';                  Admin = $true;  Default = $false; Script = 'Auto Login\enable-auto-login.bat'; Interactive = $true
       Hint = 'Logs in automatically after a reboot. Asks for the password in its own window. Stores it in the registry.' }
    @{ Key = 'noAccountPrompts';     Category = 'Session and login'; Label = 'Stop Microsoft account prompts'; Admin = $false; Default = $true; Script = 'Microsoft Account\stop-account-prompts.bat'
       Hint = 'Turns off "Let''s finish setting up your device" and sign-in nags after updates. For the setup screen itself, use Windows Install\make-autounattend.bat on the install USB.' }
    @{ Key = 'autoDnd';              Category = 'Session and login'; Label = 'Do Not Disturb, 24/7';        Admin = $false; Default = $false; Script = 'Auto Do Not Disturb\enable-auto-dnd.bat'; RestartsExplorer = $true
       Hint = 'Turns notifications off all day. Stays set after restarts; nothing runs at startup.' }
    @{ Key = 'restartSchedule';      Category = 'Session and login'; Label = 'Daily restart';               Admin = $true;  Default = $false; Script = 'Auto Restart Schedule\schedule-restart.bat'
       Hint = 'Scheduled task that restarts the PC every day at the time set below. Runs as SYSTEM.' }
    @{ Key = 'disableGameBar';       Category = 'Performance';       Label = 'Disable Game Bar / DVR';      Admin = $true;  Default = $true;  Script = 'Disable Game Bar\disable-game-bar.bat'
       Hint = 'Turns off Xbox Game Bar, background recording and Game DVR.' }
    @{ Key = 'disableInterruptions'; Category = 'Performance';       Label = 'Disable interruptions';       Admin = $false; Default = $true;  Script = 'Disable Interruptions\disable-interruptions.bat'
       Hint = 'No sleep or display-off on AC power; no tips, suggestions or welcome screens.' }
    @{ Key = 'powerPerformance';     Category = 'Performance';       Label = 'Power and performance';       Admin = $true;  Default = $true;  Script = 'Power and Performance\power-and-performance.bat'
       Hint = 'High performance plan, no USB selective suspend, no PCIe link power saving.' }
    @{ Key = 'stability';            Category = 'Performance';       Label = 'Stability';                   Admin = $true;  Default = $true;  Script = 'Stability\stability-settings.bat'; RestartsExplorer = $true
       Hint = 'Delivery Optimization off (no uploading updates to other PCs); visual effects set for performance.' }
    @{ Key = 'defenderExclusions';   Category = 'Security';          Label = 'Defender exclusions';         Admin = $true;  Default = $true;  Script = 'Defender Exclusions\defender-exclusions-unreal-touchdesigner.bat'
       Hint = 'Excludes Unreal and TouchDesigner from Defender scans, plus any extra paths set below.' }
    @{ Key = 'autoTimeZone';         Category = 'Desktop';           Label = 'Set time zone automatically'; Admin = $true;  Default = $true;  Script = 'Desktop Preferences\set-time-zone-automatically.bat'
       Hint = 'Detects the time zone and keeps the clock synced. Also turns on location services.' }
    @{ Key = 'taskbarMainOnly';      Category = 'Desktop';           Label = 'Taskbar on main display only'; Admin = $false; Default = $true; Script = 'Desktop Preferences\disable-taskbar-all-displays.bat'; RestartsExplorer = $true
       Hint = 'Turns off "Show my taskbar on all displays".' }
    @{ Key = 'darkMode';             Category = 'Desktop';           Label = 'Dark mode';                   Admin = $false; Default = $true;  Script = 'Desktop Preferences\enable-dark-mode.bat'
       Hint = 'Sets Windows and apps to dark mode.' }
    @{ Key = 'noAutoUpdates';        Category = 'Windows Update';    Label = 'No automatic updates';        Admin = $true;  Default = $true;  Script = 'Windows Update\disable-auto-updates.bat'
       Hint = 'Windows stops updating and restarting on its own, skips driver updates and stays on the current version. Update manually now and then. Undo: Windows Update\enable-auto-updates.bat.' }
    @{ Key = 'gpuPcieCheck';         Category = 'Hardware';          Label = 'GPU PCIe link check';         Admin = $false; Default = $true;  Script = 'GPU PCIe Check\check-gpu-pcie.bat'
       Hint = 'Checks the GPU runs at full PCIe width (x16). Read-only; lists likely causes if not.' }
)

function Get-Config {
    if (Test-Path $ConfigPath) {
        try { return Get-Content $ConfigPath -Raw | ConvertFrom-Json } catch { }
    }
    return $null
}

function Save-Config {
    $defaults = [ordered]@{}
    foreach ($tool in $Tools) {
        $defaults[$tool.Key] = $Script:Nodes[$tool.Key].Checked
        if ($tool.Key -eq 'restartSchedule') { $defaults['restartTime'] = $tbRestartTime.Text.Trim() }
        if ($tool.Key -eq 'defenderExclusions') { $defaults['defenderExclusionPaths'] = @(Get-DefenderPaths) }
    }
    $o = [ordered]@{
        defaults = $defaults
        notes = [ordered]@{
            autoLogin = 'Requires Administrator. Prompts for credentials.'
            restartTime = '24-hour format, e.g. 04:00 or 22:30'
            defenderExclusionPaths = 'One path per line; saved in config and applied when Defender Exclusions is run.'
        }
    }
    $o | ConvertTo-Json -Depth 5 | Set-Content $ConfigPath -Encoding UTF8
    $lblOverall.Text = 'Defaults saved to config.json.'
}

function Get-DefenderPaths {
    @($tbDefenderPaths.Text -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
}

# ---------------------------------------------------------------------------
# Theme
# ---------------------------------------------------------------------------
function New-Color([int]$r, [int]$g, [int]$b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }
$Theme = @{
    Back     = New-Color 28 28 28
    Surface  = New-Color 40 40 40
    Selected = New-Color 52 58 66
    Border   = New-Color 64 64 64
    Track    = New-Color 58 58 58
    Text     = New-Color 236 236 236
    Muted    = New-Color 156 156 156
    Accent   = New-Color 76 194 255
    OnAccent = New-Color 0 0 0
    Ok       = New-Color 108 203 95
    Warn     = New-Color 252 200 60
    Fail     = New-Color 255 120 130
}
$Fonts = @{
    Base    = New-Object System.Drawing.Font('Segoe UI', 9.75)
    Small   = New-Object System.Drawing.Font('Segoe UI', 8.75)
    Bold    = New-Object System.Drawing.Font('Segoe UI Semibold', 9.75)
    Title   = New-Object System.Drawing.Font('Segoe UI Semibold', 16)
    Heading = New-Object System.Drawing.Font('Segoe UI Semibold', 12)
    Mono    = New-Object System.Drawing.Font('Consolas', 9)
    Icon    = New-Object System.Drawing.Font('Segoe UI Symbol', 12)
}

Add-Type -Namespace SetupTools -Name Native -MemberDefinition @'
[DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
[DllImport("uxtheme.dll", CharSet = CharSet.Unicode)] public static extern int SetWindowTheme(IntPtr hwnd, string app, string id);
[DllImport("uxtheme.dll", EntryPoint = "#135")] public static extern int SetPreferredAppMode(int mode);
[DllImport("uxtheme.dll", EntryPoint = "#133")] public static extern bool AllowDarkModeForWindow(IntPtr hwnd, bool allow);
'@
# Opt the app into dark mode so DarkMode_Explorer controls get dark scrollbars (2 = force dark).
try { [void][SetupTools.Native]::SetPreferredAppMode(2) } catch { }

# Dark scrollbars etc. for a control (undocumented but stable uxtheme calls; harmless if unsupported).
function Set-DarkControl($control) {
    try { [void][SetupTools.Native]::AllowDarkModeForWindow($control.Handle, $true) } catch { }
    [void][SetupTools.Native]::SetWindowTheme($control.Handle, 'DarkMode_Explorer', $null)
}

Add-Type -WarningAction SilentlyContinue -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @'
using System.Windows.Forms;
namespace SetupTools {
    public class CheckTree : TreeView {
        public CheckTree() { DoubleBuffered = true; }
        protected override void WndProc(ref Message m) {
            // WM_LBUTTONDBLCLK -> WM_LBUTTONDOWN, so fast clicks each count as a click.
            if (m.Msg == 0x203) { m.Msg = 0x201; }
            base.WndProc(ref m);
        }
    }
}
'@

function Set-DarkTitleBar($form) {
    $on = 1
    # 20 = DWMWA_USE_IMMERSIVE_DARK_MODE (Windows 10 20H1+ / 11); 19 on older builds.
    if ([SetupTools.Native]::DwmSetWindowAttribute($form.Handle, 20, [ref]$on, 4) -ne 0) {
        [void][SetupTools.Native]::DwmSetWindowAttribute($form.Handle, 19, [ref]$on, 4)
    }
}

function New-Label([string]$Text, $Font, $Color, [int]$X, [int]$Y, [int]$W, [int]$H) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.Font = $Font
    $l.ForeColor = $Color
    $l.BackColor = [System.Drawing.Color]::Transparent
    $l.Location = New-Object System.Drawing.Point($X, $Y)
    $l.Size = New-Object System.Drawing.Size($W, $H)
    $l.AutoEllipsis = $true
    $l
}

function New-TextBox([int]$X, [int]$Y, [int]$W, [int]$H, [bool]$Multiline = $false) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Multiline = $Multiline
    $t.BorderStyle = 'FixedSingle'
    $t.BackColor = $Theme.Surface
    $t.ForeColor = $Theme.Text
    $t.Font = $Fonts.Base
    $t.Location = New-Object System.Drawing.Point($X, $Y)
    $t.Size = New-Object System.Drawing.Size($W, $H)
    $t
}

function New-Button([string]$Text, [int]$X, [int]$Y, [int]$W, [bool]$Primary = $false) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.FlatStyle = 'Flat'
    $b.Font = if ($Primary) { $Fonts.Bold } else { $Fonts.Base }
    $b.Location = New-Object System.Drawing.Point($X, $Y)
    $b.Size = New-Object System.Drawing.Size($W, 34)
    $b.Cursor = 'Hand'
    if ($Primary) {
        $b.BackColor = $Theme.Accent
        $b.ForeColor = $Theme.OnAccent
        $b.FlatAppearance.BorderSize = 0
    } else {
        $b.BackColor = $Theme.Surface
        $b.ForeColor = $Theme.Text
        $b.FlatAppearance.BorderColor = $Theme.Border
    }
    $b
}

# Checkbox images for the tree (index 0 = unchecked, 1 = checked).
function New-CheckImage([bool]$Checked) {
    $bmp = New-Object System.Drawing.Bitmap(16, 16)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear($Theme.Back)
    $rect = New-Object System.Drawing.Rectangle(1, 1, 13, 13)
    if ($Checked) {
        $g.FillRectangle((New-Object System.Drawing.SolidBrush($Theme.Accent)), $rect)
        $pen = New-Object System.Drawing.Pen($Theme.OnAccent, 2)
        $g.DrawLines($pen, [System.Drawing.Point[]]@(
            (New-Object System.Drawing.Point(4, 8)), (New-Object System.Drawing.Point(7, 11)), (New-Object System.Drawing.Point(12, 4))))
    } else {
        $g.FillRectangle((New-Object System.Drawing.SolidBrush($Theme.Surface)), $rect)
        $g.DrawRectangle((New-Object System.Drawing.Pen($Theme.Muted, 1)), $rect)
    }
    $g.Dispose()
    $bmp
}

# Flat progress bar: a track panel with a fill panel. Supports a value or a moving "busy" segment.
function New-Bar($Parent, [int]$X, [int]$Y, [int]$W, [int]$H) {
    $track = New-Object System.Windows.Forms.Panel
    $track.BackColor = $Theme.Track
    $track.Location = New-Object System.Drawing.Point($X, $Y)
    $track.Size = New-Object System.Drawing.Size($W, $H)
    $fill = New-Object System.Windows.Forms.Panel
    $fill.BackColor = $Theme.Accent
    $fill.Location = New-Object System.Drawing.Point(0, 0)
    $fill.Size = New-Object System.Drawing.Size(0, $H)
    $track.Controls.Add($fill)
    $Parent.Controls.Add($track)
    [pscustomobject]@{ Track = $track; Fill = $fill; Busy = $false; Phase = 0 }
}

function Set-BarValue($bar, [double]$Percent, $Color = $null) {
    $bar.Busy = $false
    if ($Color) { $bar.Fill.BackColor = $Color }
    $bar.Fill.Left = 0
    $bar.Fill.Width = [int]($bar.Track.Width * [Math]::Max(0, [Math]::Min(100, $Percent)) / 100)
}

function Start-BarBusy($bar) {
    $bar.Fill.BackColor = $Theme.Accent
    $bar.Phase = 0
    $bar.Busy = $true
}

$Script:Bars = New-Object System.Collections.ArrayList
$busyTimer = New-Object System.Windows.Forms.Timer
$busyTimer.Interval = 25
$busyTimer.Add_Tick({
    foreach ($bar in $Script:Bars) {
        if (-not $bar.Busy) { continue }
        $w = $bar.Track.Width
        $seg = [int]($w / 3)
        $bar.Phase = ($bar.Phase + 5) % ($w + $seg)
        $left = $bar.Phase - $seg
        $bar.Fill.Left = [Math]::Max(0, $left)
        $bar.Fill.Width = [Math]::Max(0, [Math]::Min($left + $seg, $w) - [Math]::Max(0, $left))
    }
})

# ---------------------------------------------------------------------------
# Task list
# ---------------------------------------------------------------------------
$Script:OemEncoding = [System.Text.Encoding]::GetEncoding([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage)
$Script:IconPending = [string][char]0x25CB   # empty circle
$Script:IconRunning = [string][char]0x25B6   # play
$Script:IconOk      = [string][char]0x2714   # check
$Script:IconFail    = [string][char]0x2716   # cross
$Script:IconWarn    = [string][char]0x26A0   # warning sign
$Script:ProblemPattern = '(?i)\b(fail(ed)?|error|invalid|skipped|denied|not found|needs administrator)\b'

function Show-TaskDetails($task) {
    $Script:SelectedTask = $task
    foreach ($t in $Script:Tasks) { $t.Panel.BackColor = $Theme.Surface }
    $task.Panel.BackColor = $Theme.Selected
    $lblDetails.Text = "Output: $($task.Name)"
    $tbDetails.Text = $task.Output.ToString()
    $tbDetails.SelectionStart = $tbDetails.TextLength
    $tbDetails.ScrollToCaret()
}

function New-TaskRow([string]$Name, [scriptblock]$Action, $Data, [int]$Index) {
    $width = $pnlTasks.ClientSize.Width - 2
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(0, ($Index * 60))
    $panel.Size = New-Object System.Drawing.Size($width, 54)
    $panel.BackColor = $Theme.Surface
    $panel.Cursor = 'Hand'

    $icon = New-Label $Script:IconPending $Fonts.Icon $Theme.Muted 10 13 28 28
    $title = New-Label $Name $Fonts.Bold $Theme.Text 42 7 ($width - 200) 20
    $summary = New-Label 'Waiting' $Fonts.Small $Theme.Muted 42 29 ($width - 54) 18
    $panel.Controls.AddRange(@($icon, $title, $summary))
    $bar = New-Bar $panel ($width - 150) 14 136 6
    [void]$Script:Bars.Add($bar)
    $pnlTasks.Controls.Add($panel)

    $task = [pscustomobject]@{
        Name = $Name; Action = $Action; Data = $Data; Panel = $panel; Icon = $icon; Bar = $bar; Summary = $summary
        Output = New-Object System.Text.StringBuilder; Status = 'pending'
    }
    foreach ($c in @($panel, $icon, $title, $summary)) {
        $c.Tag = $task
        $c.Add_Click({ param($sender) Show-TaskDetails $sender.Tag })
    }
    $task
}

function Add-TaskOutput($task, [string]$Text) {
    [void]$task.Output.AppendLine($Text)
    if ($Text.Trim()) { $task.Summary.Text = $Text.Trim() }
    if ($Script:SelectedTask -eq $task) { $tbDetails.AppendText($Text + "`r`n") }
}

function Complete-Task($task, [string]$Status, [string]$Summary) {
    $task.Status = $Status
    $color = switch ($Status) { 'ok' { $Theme.Ok } 'warn' { $Theme.Warn } default { $Theme.Fail } }
    $task.Icon.Text = switch ($Status) { 'ok' { $Script:IconOk } 'warn' { $Script:IconWarn } default { $Script:IconFail } }
    $task.Icon.ForeColor = $color
    Set-BarValue $task.Bar 100 $color
    if ($Summary) { $task.Summary.Text = $Summary }
    $task.Summary.ForeColor = if ($Status -eq 'ok') { $Theme.Muted } else { $color }
}

function Wait-WhileRunning($process) {
    while (-not $process.HasExited) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 20
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
            Start-Sleep -Milliseconds 20
        }
    }
    $p.WaitForExit()
    return $p.ExitCode
}

# Runs one task: marks it running, calls its action, then marks ok / warn / fail.
# An action returns an exit code (0 = success).
function Invoke-Task($task) {
    $task.Icon.Text = $Script:IconRunning
    $task.Icon.ForeColor = $Theme.Accent
    $task.Summary.ForeColor = $Theme.Text
    $task.Summary.Text = 'Running...'
    Start-BarBusy $task.Bar
    $pnlTasks.ScrollControlIntoView($task.Panel)
    [System.Windows.Forms.Application]::DoEvents()

    try {
        $result = & $task.Action $task
    } catch {
        Add-TaskOutput $task "Error: $($_.Exception.Message)"
        $result = 1
    }
    $result = [int](@($result)[-1])

    $lines = @($task.Output.ToString() -split "`r?`n" | Where-Object { $_.Trim() })
    $problem = $lines | Where-Object { $_ -match $Script:ProblemPattern } | Select-Object -First 1
    if ($result -ne 0) {
        $msg = if ($problem) { $problem.Trim() } elseif ($lines) { $lines[-1].Trim() } else { "Exit code $result" }
        Complete-Task $task 'fail' $msg
    } elseif ($problem) {
        Complete-Task $task 'warn' $problem.Trim()
    } else {
        Complete-Task $task 'ok' $null
    }
}

# Task actions. Each gets the task (tool hashtable in $t.Data) and returns an exit code.
$RunBat = { param($t) Invoke-BatTask $t $t.Data.Script @($t.Data.Arguments) }
$RunInteractive = {
    param($t)
    $t.Summary.Text = "Waiting for input in the $($t.Name) window..."
    $path = Join-Path $Script:BasePath $t.Data.Script
    $p = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', "`"$path`"") -WorkingDirectory (Split-Path $path -Parent) -PassThru
    # Touch the handle now: without it .NET may not keep the exit code, and ExitCode reads as $null (= 0, "success").
    $null = $p.Handle
    Wait-WhileRunning $p
    $p.WaitForExit()
    $code = $p.ExitCode
    if ($null -eq $code) { $code = 1; Add-TaskOutput $t 'Could not read the exit code; treating as failed.' }
    if ($code -eq 0) {
        Add-TaskOutput $t 'Completed in its own window.'
    } else {
        Add-TaskOutput $t "FAILED in its own window (exit code $code). Run it again to see the message."
    }
    $code
}
$RunDefenderPaths = {
    param($t)
    $paths = @($t.Data)
    $failed = 0
    for ($i = 0; $i -lt $paths.Count; $i++) {
        try {
            Add-MpPreference -ExclusionPath $paths[$i] -ErrorAction Stop
            Add-TaskOutput $t "Added: $($paths[$i])"
        } catch {
            Add-TaskOutput $t "FAILED: $($paths[$i]) ($($_.Exception.Message))"
            $failed++
        }
        Set-BarValue $t.Bar ((($i + 1) * 100) / $paths.Count)
        [System.Windows.Forms.Application]::DoEvents()
    }
    $failed
}
$RunExplorerRestart = {
    param($t)
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
    Add-TaskOutput $t 'Explorer restarted.'
    0
}

function Start-Run {
    $selected = @($Tools | Where-Object { $Script:Nodes[$_.Key].Checked })
    if ($selected.Count -eq 0) {
        $lblOverall.Text = 'Tick at least one step in the tree first.'
        return
    }
    $restartTime = $tbRestartTime.Text.Trim()
    if (($selected.Key -contains 'restartSchedule') -and -not $restartTime) {
        $lblOverall.Text = 'Set a daily restart time (HH:MM) under Options.'
        $tbRestartTime.Focus()
        return
    }

    # Build the to-do list: [name, action, data]
    $plan = New-Object System.Collections.ArrayList
    foreach ($tool in $selected) {
        if ($tool.Interactive) {
            [void]$plan.Add(@($tool.Label, $RunInteractive, $tool))
        } elseif ($tool.Key -eq 'restartSchedule') {
            [void]$plan.Add(@("Daily restart at $restartTime", $RunBat, (@{ Script = $tool.Script; Arguments = @($restartTime) })))
        } else {
            [void]$plan.Add(@($tool.Label, $RunBat, $tool))
        }
        if ($tool.Key -eq 'defenderExclusions') {
            $paths = @(Get-DefenderPaths)
            if ($paths.Count -gt 0) { [void]$plan.Add(@("Defender exclusions: $($paths.Count) extra path(s)", $RunDefenderPaths, $paths)) }
        }
    }
    # The steps skip their own Explorer restarts in GUI mode; do it once at the end.
    if ($selected | Where-Object { $_.RestartsExplorer }) {
        [void]$plan.Add(@('Restart Explorer', $RunExplorerRestart, $null))
    }

    $btnRun.Enabled = $false
    $btnRun.BackColor = $Theme.Track
    $Script:Running = $true
    $pnlTasks.Controls.Clear()
    $Script:Bars.Clear()
    [void]$Script:Bars.Add($barOverall)
    $tbDetails.Clear()
    $lblDetails.Text = 'Output (click a task)'
    $Script:SelectedTask = $null
    $Script:Tasks = @()
    for ($i = 0; $i -lt $plan.Count; $i++) {
        $Script:Tasks += New-TaskRow $plan[$i][0] $plan[$i][1] $plan[$i][2] $i
    }
    Set-BarValue $barOverall 0 $Theme.Accent

    try {
        $done = 0
        foreach ($task in $Script:Tasks) {
            $lblOverall.Text = "Running $($done + 1) of $($Script:Tasks.Count): $($task.Name)"
            Invoke-Task $task
            $done++
            Set-BarValue $barOverall (100 * $done / $Script:Tasks.Count)
        }
    } finally {
        $btnRun.Enabled = $true
        $btnRun.BackColor = $Theme.Accent
        $Script:Running = $false
    }

    $failed = @($Script:Tasks | Where-Object Status -eq 'fail').Count
    $warned = @($Script:Tasks | Where-Object Status -eq 'warn').Count
    $ok = $Script:Tasks.Count - $failed - $warned
    $lblOverall.Text = "Done: $ok succeeded, $warned warning(s), $failed failed."
    $overallColor = if ($failed) { $Theme.Fail } elseif ($warned) { $Theme.Warn } else { $Theme.Ok }
    Set-BarValue $barOverall 100 $overallColor
    $firstProblem = $Script:Tasks | Where-Object { $_.Status -ne 'ok' } | Select-Object -First 1
    if ($firstProblem) { Show-TaskDetails $firstProblem }
}

# ---------------------------------------------------------------------------
# Form
# ---------------------------------------------------------------------------
$config = Get-Config
$d = if ($config) { $config.defaults } else { $null }

$form = New-Object System.Windows.Forms.Form
$form.Text = 'SetupTools'
$form.ClientSize = New-Object System.Drawing.Size(1000, 740)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = $Theme.Back
$form.ForeColor = $Theme.Text
$form.Font = $Fonts.Base
$form.Add_HandleCreated({ Set-DarkTitleBar $form })

# --- Left column: header, category tree, options, buttons ---
[int]$lx = 24
[int]$lw = 440
$form.Controls.Add((New-Label 'SetupTools' $Fonts.Title $Theme.Text $lx 14 $lw 32))
$adminText = if ($isAdmin) { 'Running as Administrator' } else { 'Not running as Administrator: admin steps will fail' }
$adminColor = if ($isAdmin) { $Theme.Muted } else { $Theme.Warn }
$form.Controls.Add((New-Label "Tick the steps to run, then click Run.  $([char]0x00B7)  $adminText" $Fonts.Small $adminColor $lx 48 $lw 18))

$checkImages = New-Object System.Windows.Forms.ImageList
$checkImages.ImageSize = New-Object System.Drawing.Size(16, 16)
$checkImages.ColorDepth = 'Depth32Bit'
$checkImages.Images.Add((New-CheckImage $false))
$checkImages.Images.Add((New-CheckImage $true))

$tree = New-Object SetupTools.CheckTree
$tree.Location = New-Object System.Drawing.Point($lx, 78)
$tree.Size = New-Object System.Drawing.Size($lw, 412)
$tree.BackColor = $Theme.Back
$tree.ForeColor = $Theme.Text
$tree.LineColor = $Theme.Border
$tree.BorderStyle = 'None'
$tree.Font = $Fonts.Base
$tree.ItemHeight = 24
$tree.Indent = 24
$tree.CheckBoxes = $true
$tree.StateImageList = $checkImages
$tree.ShowLines = $false
$tree.ShowPlusMinus = $true   # reserves the clickable expand area; we draw our own chevron there
$tree.ShowRootLines = $true
$tree.DrawMode = 'OwnerDrawAll'
$tree.FullRowSelect = $true
$tree.HideSelection = $false
$tree.ShowNodeToolTips = $false  # the description shows under the tree instead (tooltips are always light)
$tree.Add_HandleCreated({ Set-DarkControl $tree })
$form.Controls.Add($tree)

$Script:Nodes = @{}
$categoryNodes = [ordered]@{}
foreach ($tool in $Tools) {
    if (-not $categoryNodes.Contains($tool.Category)) {
        $cat = New-Object System.Windows.Forms.TreeNode($tool.Category)
        $cat.NodeFont = $Fonts.Bold
        $cat.Tag = $null
        [void]$tree.Nodes.Add($cat)
        $categoryNodes[$tool.Category] = $cat
    }
    $node = New-Object System.Windows.Forms.TreeNode($tool.Label)
    $node.Tag = $tool
    $node.ToolTipText = $tool.Hint
    $saved = if ($d -and ($d.PSObject.Properties.Name -contains $tool.Key)) { [bool]$d.($tool.Key) } else { $tool.Default }
    $node.Checked = $saved
    [void]$categoryNodes[$tool.Category].Nodes.Add($node)
    $Script:Nodes[$tool.Key] = $node
}
function Update-CategoryCheck($cat) {
    $all = $true
    foreach ($n in $cat.Nodes) { if (-not $n.Checked) { $all = $false } }
    $cat.Checked = $all
}
foreach ($cat in $categoryNodes.Values) { Update-CategoryCheck $cat }
$tree.ExpandAll()

# Owner-drawn rows so the checkboxes, selection and "admin" tags match the dark theme.
# Our checkbox sits exactly where the native one would, so clicking it still toggles the node.
$Script:BrushBack = New-Object System.Drawing.SolidBrush($Theme.Back)
$Script:ChevronOpen = [string][char]0x25BE    # small down triangle
$Script:ChevronClosed = [string][char]0x25B8  # small right triangle
$Script:BrushSelected = New-Object System.Drawing.SolidBrush($Theme.Selected)
$tree.Add_DrawNode({
    param($sender, $e)
    if ($e.Bounds.Height -le 0) { return }
    $node = $e.Node
    $g = $e.Graphics
    # With OwnerDrawAll, $e.Bounds is the whole row; $node.Bounds is where the native control put the label.
    $row = $e.Bounds
    $brush = if ($node.IsSelected) { $Script:BrushSelected } else { $Script:BrushBack }
    $g.FillRectangle($brush, $row)

    $x = $node.Bounds.X
    $imgIndex = if ($node.Checked) { 1 } else { 0 }
    $g.DrawImage($checkImages.Images[$imgIndex], ($x - 18), ($row.Y + [int](($row.Height - 16) / 2)))

    $font = if ($node.NodeFont) { $node.NodeFont } else { $tree.Font }
    $flags = [System.Windows.Forms.TextFormatFlags]'VerticalCenter, NoPrefix, SingleLine'
    if ($node.Nodes.Count -gt 0) {
        $chevron = if ($node.IsExpanded) { $Script:ChevronOpen } else { $Script:ChevronClosed }
        $chevRect = New-Object System.Drawing.Rectangle(($x - 18 - $tree.Indent), $row.Y, $tree.Indent, $row.Height)
        [System.Windows.Forms.TextRenderer]::DrawText($g, $chevron, $Fonts.Base, $chevRect, $Theme.Muted, ($flags -bor [System.Windows.Forms.TextFormatFlags]::HorizontalCenter))
    }
    $textRect = New-Object System.Drawing.Rectangle(($x + 2), $row.Y, ($row.Width - $x - 2), $row.Height)
    [System.Windows.Forms.TextRenderer]::DrawText($g, $node.Text, $font, $textRect, $Theme.Text, $flags)
    if ($node.Tag -and $node.Tag.Admin) {
        $w = [System.Windows.Forms.TextRenderer]::MeasureText($g, $node.Text, $font, $textRect.Size, $flags).Width
        $tagRect = New-Object System.Drawing.Rectangle(($textRect.X + $w + 6), $row.Y, 80, $row.Height)
        [System.Windows.Forms.TextRenderer]::DrawText($g, 'admin', $Fonts.Small, $tagRect, $Theme.Muted, $flags)
    }
})

$Script:Running = $false
$tree.Add_BeforeCheck({
    param($sender, $e)
    if ($Script:Running -and $e.Action -ne [System.Windows.Forms.TreeViewAction]::Unknown) { $e.Cancel = $true }
})

# Ticking a category ticks all its steps; ticking a step updates its category.
$tree.Add_AfterCheck({
    param($sender, $e)
    if ($e.Action -eq [System.Windows.Forms.TreeViewAction]::Unknown) { return }  # programmatic change
    if ($e.Node.Nodes.Count -gt 0) {
        foreach ($n in $e.Node.Nodes) { $n.Checked = $e.Node.Checked }
    } elseif ($e.Node.Parent) {
        Update-CategoryCheck $e.Node.Parent
    }
})
$tree.Add_NodeMouseClick({
    param($sender, $e)
    if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
    $hit = $tree.HitTest($e.Location)
    # Checkbox and expand-button clicks are handled natively.
    if ($hit.Location -eq [System.Windows.Forms.TreeViewHitTestLocations]::StateImage) { return }
    if ($hit.Location -eq [System.Windows.Forms.TreeViewHitTestLocations]::PlusMinus) { return }
    $node = $e.Node
    if ($node.Nodes.Count -gt 0) {
        $node.Toggle()
    } elseif (-not $Script:Running) {
        $node.Checked = -not $node.Checked
        Update-CategoryCheck $node.Parent
    }
})

$tree.Add_AfterSelect({
    param($sender, $e)
    $tool = $e.Node.Tag
    if ($tool) {
        $lblHintTitle.Text = $tool.Label + $(if ($tool.Admin) { '  (needs admin)' } else { '' })
        $lblHint.Text = $tool.Hint
    } else {
        $lblHintTitle.Text = $e.Node.Text
        $lblHint.Text = "$($e.Node.Nodes.Count) step(s). Tick the category to select them all."
    }
})

# Description of the selected tree item
$lblHintTitle = New-Label 'Select a step to see what it does.' $Fonts.Bold $Theme.Text $lx 500 $lw 20
$lblHint = New-Label '' $Fonts.Small $Theme.Muted $lx 520 $lw 34
$form.Controls.AddRange(@($lblHintTitle, $lblHint))

# Options
$form.Controls.Add((New-Label 'OPTIONS' $Fonts.Small $Theme.Muted $lx 562 $lw 18))
$form.Controls.Add((New-Label 'Daily restart time (HH:MM)' $Fonts.Base $Theme.Text $lx 585 200 22))
$tbRestartTime = New-TextBox ($lx + 200) 582 70 24
$tbRestartTime.Text = if ($d -and $d.restartTime) { $d.restartTime } else { '04:00' }
$form.Controls.Add($tbRestartTime)

$form.Controls.Add((New-Label 'Extra Defender exclusion paths, one per line' $Fonts.Base $Theme.Text $lx 614 $lw 20))
$tbDefenderPaths = New-TextBox $lx 636 $lw 40 $true
$defPaths = @($d.defenderExclusionPaths | Where-Object { $_ })
if ($defPaths.Count -gt 0) { $tbDefenderPaths.Text = ($defPaths -join "`r`n") }
$form.Controls.Add($tbDefenderPaths)

$btnRun = New-Button 'Run selected' $lx 690 140 $true
$btnSave = New-Button 'Save as default' ($lx + 150) 690 140
$btnConfig = New-Button 'Open config' ($lx + 300) 690 120
$form.Controls.AddRange(@($btnRun, $btnSave, $btnConfig))

# --- Right column: overall progress, task list, output ---
[int]$rx = 496
[int]$rw = 480
$form.Controls.Add((New-Label 'Tasks' $Fonts.Heading $Theme.Text $rx 18 $rw 26))
$lblOverall = New-Label 'Nothing run yet.' $Fonts.Small $Theme.Muted $rx 48 $rw 18
$form.Controls.Add($lblOverall)
$barOverall = New-Bar $form $rx 72 $rw 6
[void]$Script:Bars.Add($barOverall)

$pnlTasks = New-Object System.Windows.Forms.Panel
$pnlTasks.Location = New-Object System.Drawing.Point($rx, 92)
$pnlTasks.Size = New-Object System.Drawing.Size($rw, 420)
$pnlTasks.AutoScroll = $true
$pnlTasks.BackColor = $Theme.Back
$pnlTasks.Add_HandleCreated({ Set-DarkControl $pnlTasks })
$form.Controls.Add($pnlTasks)

$lblDetails = New-Label 'Output (click a task)' $Fonts.Small $Theme.Muted $rx 524 $rw 18
$form.Controls.Add($lblDetails)
$tbDetails = New-TextBox $rx 544 $rw 180 $true
$tbDetails.ReadOnly = $true
# No scrollbar: edit controls can't draw a dark one. It still scrolls with the wheel and keyboard.
$tbDetails.ScrollBars = 'None'
$tbDetails.WordWrap = $true
$tbDetails.Font = $Fonts.Mono
$tbDetails.Add_HandleCreated({ Set-DarkControl $tbDetails })
$form.Controls.Add($tbDetails)

$Script:Tasks = @()
$Script:SelectedTask = $null

$btnRun.Add_Click({ Start-Run })
$btnSave.Add_Click({ Save-Config })
$btnConfig.Add_Click({
    if (Test-Path $ConfigPath) { Start-Process notepad $ConfigPath } else { $lblOverall.Text = 'config.json not found.' }
})

$busyTimer.Start()
[void]$form.ShowDialog()
$busyTimer.Stop()
