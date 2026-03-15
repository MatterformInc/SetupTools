# Sync DND state at logon: ON between 03:45 and 03:44 (next day), OFF 03:44-03:45
$m = (Get-Date).Hour * 60 + (Get-Date).Minute
$value = if ($m -ge 225 -or $m -lt 224) { 0 } else { 1 }  # 225=03:45, 224=03:44
$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings'
Set-ItemProperty -Path $path -Name NOC_GLOBAL_SETTING_TOASTS_ENABLED -Value $value -Type DWord -Force -ErrorAction SilentlyContinue
