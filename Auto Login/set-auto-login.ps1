#Requires -Version 5.1
<#
.SYNOPSIS
  Used by enable-auto-login.bat: asks for the password, checks it, then writes the Winlogon auto-login values.
  Reads the account from env WL_USERNAME / WL_DOMAIN.
  Exit codes: 0 = enabled, 2 = password rejected (nothing saved), 3 = registry write/verify failed.
#>
$u = $env:WL_USERNAME
$d = $env:WL_DOMAIN

Add-Type -Namespace SetupTools -Name Logon -MemberDefinition @'
[DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern bool LogonUser(string user, string domain, string password, int logonType, int provider, out IntPtr token);
[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
'@

# Check the password before saving it: a typo here is the most common reason auto-login "doesn't work".
$plain = $null
for ($attempt = 1; $attempt -le 3; $attempt++) {
    $secure = Read-Host 'Password' -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }

    $token = [IntPtr]::Zero
    if ([SetupTools.Logon]::LogonUser($u, $d, $plain, 2, 0, [ref]$token)) {   # 2 = interactive logon
        [void][SetupTools.Logon]::CloseHandle($token)
        Write-Host 'Password OK.' -ForegroundColor Green
        break
    }
    $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    if ($err -eq 1327 -and -not $plain) {
        # Blank password: Windows refuses it for this check but allows it for console/auto logon.
        Write-Host 'Blank password: accepted for auto-login.' -ForegroundColor Yellow
        break
    }
    if ($err -ne 1326) {
        # Not "wrong user name or password" (e.g. logon type restricted by policy): can't verify, so don't block.
        Write-Host "Could not verify the password (Windows error $err). Saving it anyway." -ForegroundColor Yellow
        break
    }
    Write-Host "Wrong user name or password for $d\$u." -ForegroundColor Red
    if ($attempt -lt 3) { Write-Host 'Try again. (Microsoft account: use the account password, not the PIN.)' }
    $plain = $null
}
if ($null -eq $plain) {
    Write-Host 'Auto-login NOT enabled: password was not accepted.' -ForegroundColor Red
    exit 2
}

try {
    $k = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    Set-ItemProperty -Path $k -Name AutoAdminLogon -Value '1' -Type String -ErrorAction Stop
    Set-ItemProperty -Path $k -Name DefaultUserName -Value $u -Type String -ErrorAction Stop
    Set-ItemProperty -Path $k -Name DefaultPassword -Value $plain -Type String -ErrorAction Stop
    Set-ItemProperty -Path $k -Name DefaultDomainName -Value $d -Type String -ErrorAction Stop
    # AutoLogonCount would stop auto-login after N logons; remove it.
    Remove-ItemProperty -Path $k -Name AutoLogonCount -ErrorAction SilentlyContinue

    # Windows 11 "Only allow Windows Hello sign-in" blocks password auto-login; turn it off.
    $pl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device'
    if (-not (Test-Path $pl)) { New-Item -Path $pl -Force | Out-Null }
    Set-ItemProperty -Path $pl -Name DevicePasswordLessBuildVersion -Value 0 -Type DWord -ErrorAction Stop

    # Read back to confirm
    $v = Get-ItemProperty -Path $k
    if ($v.AutoAdminLogon -ne '1' -or $v.DefaultUserName -ne $u -or $v.DefaultDomainName -ne $d) {
        throw 'Values did not stick after writing (Group Policy may be overriding them).'
    }
} catch {
    Write-Host "Registry update failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 3
} finally {
    $plain = $null
}
exit 0
