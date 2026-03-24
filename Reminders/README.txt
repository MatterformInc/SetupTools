================================================================================
  REMINDERS — Things we can't set from Windows (BIOS / firmware / manual)
  For activations, Unreal, TouchDesigner, and long-running installs
================================================================================

BIOS / UEFI
-----------
• Auto power recovery when AC returns
  (Power Management / After Power Loss: Power On or Last State)

• Wake on LAN
  (Enable if you need remote wake; disable if you want no network wake)

• XMP / DOCP / EXPO for RAM
  (Enable for full RAM speed; ensure stability with a quick test)

• Secure Boot
  (Leave enabled unless a driver or tool requires it off)

• Disable unused onboard devices
  (e.g. serial, parallel, extra SATA if not used — fewer interrupts)


POWER / COOLING
---------------
• Power limit / thermal limits in BIOS
  (Avoid throttling under sustained load)

• Adequate cooling and airflow
  (Prevent thermal throttling during long renders)


THIRD-PARTY SOFTWARE
--------------------
• Disable or uninstall 3rd party antivirus / security daemons
  (They can cause instability, file locks, and interruptions; use Defender + exclusions instead)

• Disable OneDrive (or exclude project folders) if it causes file locks
  (Settings > Apps > OneDrive > Unlink, or exclude Unreal/TD project paths)


WINDOWS (manual check)
----------------------
• Active hours for Windows Update
  (Settings > Update & Security > Advanced > Active hours — set to when you are not rendering)

• Optional: pause updates during critical installs
  (Settings > Update & Security > Pause updates)


NETWORK (optional)
------------------
• Static IP if you need fixed addressing for licensing or remote access
• Disable Wi‑Fi power saving in Device Manager if on Ethernet and Wi‑Fi is unused

================================================================================
