# SetupTools

Windows setup and optimization scripts for **activations**, **permanent installations**, and machines running **Unreal Engine** / **TouchDesigner**. Goals: fewer interruptions, less power waste, and more stability (e.g. no 3rd‑party security daemons, sensible power and update behavior).

Run scripts **as Administrator** where noted.

---

## GUI and config

- **Run-SetupTools-GUI.bat** — Opens the SetupTools GUI (checkboxes for each tool, restart-time field, Apply / Save as default / Open config).
- **SetupTools-GUI.ps1** — PowerShell script that builds the form and runs the selected batch files.
- **config.json** — Defaults for the GUI: which checkboxes are checked and the default **Restart time** (e.g. `04:00`). Edit this file to pre-fill your preferred options; the GUI loads it on start. Use **Save as default** in the GUI to write the current choices back to `config.json`.

Example **config.json**:

```json
{
  "defaults": {
    "autoLogin": false,
    "autoDnd": false,
    "restartSchedule": false,
    "restartTime": "04:00",
    "disableGameBar": true,
    "disableInterruptions": true,
    "powerPerformance": true,
    "defenderExclusions": true,
    "stability": true,
    "autoTimeZone": true,
    "taskbarMainOnly": true,
    "darkMode": true,
    "gpuPcieCheck": true
  }
}
```

---

## Tools

### Auto Login
- **enable-auto-login.bat** — Store credentials so Windows logs in automatically after reboot (registry). *Run as Administrator.*
- **disable-auto-login.bat** — Remove stored auto-login and turn the feature off.

### Auto Do Not Disturb
- **enable-auto-dnd.bat** — Turns on Do Not Disturb now and copies **DoNotDisturb.bat** to the Startup folder so it runs at every logon. On many Windows 11 builds the registry is ignored; the script opens Notifications settings so you can turn DND on there if needed.
- **disable-auto-dnd.bat** — Turns DND off and removes **DoNotDisturb.bat** from Startup.
- **scripts\DoNotDisturb.bat** — Dependency: runs the registry toggle for DND (used by the installer and by Startup).

### Auto Restart Schedule
- **schedule-restart.bat** — Prompts for a time (e.g. `04:00`), creates a **daily** scheduled task named **Restart PC** that runs `shutdown.exe /r /f` at that time. Never expires.
- **cancel-restart.bat** — Deletes the **Restart PC** scheduled task.

### Disable Game Bar
- **disable-game-bar.bat** — Disables Xbox Game Bar, “Record what happened,” and Game DVR via registry (AllowAutoGameMode, AppCaptureEnabled, GameDVR_Enabled, AllowGameDVR). *Run as Administrator* for the machine-wide policy.

### Disable Interruptions
- **disable-interruptions.bat** — No sleep / no display-off on AC; disables tips, suggestions, and the Windows welcome experience (registry). Reduces pop-ups and screen blanking during long runs.

### Power and Performance
- **power-and-performance.bat** — Sets High Performance power plan, never sleep/display-off on AC, disables USB selective suspend and PCIe link-state power management. *Run as Administrator.*

### Defender Exclusions
- **defender-exclusions-unreal-touchdesigner.bat** — Adds Windows Defender exclusions for Unreal and TouchDesigner (processes, common install paths, .uasset/.umap). Reduces scans and file locks. *Run as Administrator.*

### Stability
- **stability-settings.bat** — Turns off Delivery Optimization (no uploading to other PCs); sets visual effects to “best performance” and disables some animations. *Run as Administrator* for delivery optimization.

### Desktop Preferences
- **set-time-zone-automatically.bat** — Turns on *Set time zone automatically* and time sync. Also turns on Location services, which Windows needs to detect the time zone. *Run as Administrator.*
- **disable-taskbar-all-displays.bat** — Turns off *Show my taskbar on all displays* (taskbar on the main display only) and restarts Explorer.
- **enable-dark-mode.bat** — Sets Windows and apps to dark mode.

### GPU PCIe Check
- **check-gpu-pcie.bat** — Reports each PCIe GPU's current vs. max link width and speed (vendor-neutral, via Windows device properties). Fails if the card runs below full width (e.g. a 4090 at x1 instead of x16) and prints the likely causes: card not seated / sagging, bad riser, wrong slot or shared lanes, BIOS slot setting. Link *speed* below max is only a note, since GPUs drop speed at idle. No admin needed.
- **check-gpu-pcie.ps1** — The check itself; exits 1 if any GPU is below full width.

### Windows Update
- **README.txt** — Explains Active hours, Pause updates, and restart options (no full control via script on all editions).
- **open-update-settings.bat** — Opens **Settings > Windows Update**.

### Reminders
- **README.txt** — Checklist for things that **can’t** be set from Windows: BIOS (e.g. auto power recovery, Wake on LAN, XMP), 3rd‑party antivirus, OneDrive, cooling, etc.
- **show-reminders.bat** — Opens the reminders README in Notepad.

---

## Quick reference

| Goal                    | Tool / action                                      |
|-------------------------|----------------------------------------------------|
| **Use the GUI**         | Run **Run-SetupTools-GUI.bat**                     |
| Auto logon after reboot | Auto Login → enable-auto-login.bat (Admin)         |
| Do Not Disturb at logon | Auto Do Not Disturb → enable-auto-dnd.bat          |
| Daily restart at 04:00 | Auto Restart Schedule → schedule-restart.bat       |
| No Game Bar / DVR       | Disable Game Bar → disable-game-bar.bat            |
| No sleep/interruptions  | Disable Interruptions + Power and Performance     |
| Fewer Defender scans    | Defender Exclusions → defender-exclusions-… (Admin)|
| No update uploads       | Stability → stability-settings.bat (Admin)        |
| Auto time zone, taskbar, dark mode | Desktop Preferences → the three .bat files |
| GPU at full x16?        | GPU PCIe Check → check-gpu-pcie.bat                |
| Update / restart control| Windows Update → open-update-settings + README    |
| BIOS / manual checklist | Reminders → show-reminders.bat / README            |

---

## Requirements

- Windows 10/11.
- Administrator rights for: Auto Login, Disable Game Bar (policy), Power and Performance, Defender Exclusions, Stability (Delivery Optimization), automatic time zone.
