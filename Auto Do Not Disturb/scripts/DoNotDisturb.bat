@echo off
:: Turn notifications off all day (24/7 Do Not Disturb), current user, no admin needed.
:: These settings persist across restarts, so nothing has to run at startup.
::   ToastEnabled = 0                    -> Settings > System > Notifications master switch off
::   NoToastApplicationNotification = 1 -> policy "Turn off toast notifications" (apps can't turn it back on)
::   NOC_GLOBAL_SETTING_TOASTS_ENABLED  -> legacy Focus Assist / DND flag (older builds)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" /v NoToastApplicationNotification /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" /v NoToastApplicationNotificationOnLockScreen /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" /v NOC_GLOBAL_SETTING_TOASTS_ENABLED /t REG_DWORD /d 0 /f >nul
