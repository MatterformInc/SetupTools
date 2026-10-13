# SetupTools

Windows setup and optimization scripts for **activations**, **permanent installations**, and machines running **Unreal Engine** / **TouchDesigner**. Goals: fewer interruptions, less power waste, and more stability (e.g. no 3rd‑party security daemons, sensible power and update behavior).

Run scripts **as Administrator** where noted (the GUI handles this for you). Each .bat still works on its own by double-clicking it.

---

## GUI and config

- **Run-SetupTools-GUI.bat** — Opens the SetupTools GUI (dark theme). It asks for Administrator once when it opens. Steps are grouped in a category tree (Session and login, Performance, Security, Desktop, Hardware); tick a category to select all its steps, and select a step to see what it does. Restart time and extra Defender paths are under **Options**. Click **Run selected** and the steps run hidden as a to-do list on the right, each with a status icon, its own progress bar and a live status line, ending green (OK), yellow (warning) or red (failed); click a step to see its output. Only Auto Login opens its own window, since it asks for a password. Explorer restarts once at the end if needed.
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

### Windows Install (skip the Microsoft account screen)
- **make-autounattend.bat** — Creates `autounattend.xml` for a Windows 11 install USB: setup creates a local account and skips the "Let's add your Microsoft account" screens, the internet requirement and the privacy questions. Language, region, keyboard and disk choice stay manual. Writes straight to the USB if one is plugged in. The file holds the account password (Base64, not encrypted) and is git-ignored. See **README.txt** in the folder, including the Shift+F10 fallback.

### Microsoft Account
- **stop-account-prompts.bat** — Turns off "Let's finish setting up your device", the welcome experience after updates, and Start / Settings account notifications. No admin needed. On by default in the GUI.

### Boot Interruptions
- **disable-boot-interruptions.bat** — Blocks every screen that can stop an unattended PC on boot or sign-in, for **all** users (every existing profile plus the default profile new users copy):
  - no Startup Repair / Automatic Repair screen after a power cut (`bcdedit` recoveryenabled No, bootstatuspolicy IgnoreAllFailures)
  - no "Let's finish setting up your device" / Microsoft account / backup screens after updates, and no welcome experience
  - no privacy-settings screen after updates, no first sign-in animation (official policies)
  - no "Set up Windows Hello / PIN" prompt (official policy), no Ctrl+Alt+Del before sign-in
  *Run as Administrator.* On by default in the GUI.
- **enable-boot-interruptions.bat** — Undo.

For the Microsoft account screen during a fresh install, see **Windows Install** below.

### Backup Prompts
- **disable-backup-prompts.bat** — Opts out of OneDrive folder backup (official `KFMBlockOptIn` policy: no offer to move Desktop/Documents/Pictures into OneDrive, which avoids file locks on project folders) and Windows Backup settings sync and its prompts ("Do not sync" policy), and hides backup nudges in File Explorer and the Start menu. OneDrive itself keeps working. *Run as Administrator.* On by default in the GUI.
- **enable-backup-prompts.bat** — Undo.

### Auto Login
- **enable-auto-login.bat** — Store credentials so Windows logs in automatically after reboot (registry). Checks the password before saving it (3 tries), turns off the Windows 11 "Windows Hello only" setting that blocks auto-login, and reports failure to the GUI. *Run as Administrator.*
- **disable-auto-login.bat** — Remove stored auto-login and turn the feature off.

### Auto Do Not Disturb
- **enable-auto-dnd.bat** — Do Not Disturb all day, every day. Windows' own DND schedule can't cover a full 24 hours, so this turns toast notifications off instead (Notifications master switch + the "Turn off toast notifications" user policy). It stays set after restarts, so nothing runs at startup; it also removes the old `DoNotDisturb.bat` from Startup, which Windows could flag with a prompt at logon.
- **disable-auto-dnd.bat** — Turns notifications back on.
- **scripts\DoNotDisturb.bat** — The registry changes used by the installer.

### Auto Restart Schedule
- **schedule-restart.bat** — Prompts for a time (e.g. `04:00`), creates a **daily** scheduled task named **Restart PC** that runs `shutdown.exe /r /f` at that time. Runs as SYSTEM, so it fires even when nobody is logged in. Never expires. *Run as Administrator.*
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
- **disable-auto-updates.bat** — Stops Windows Update from downloading, installing and restarting on its own, skips driver updates (keeps your GPU driver), and pins the current Windows version so no feature upgrade arrives. Uses the official Windows Update policies (Pro / Enterprise / Education; Home ignores some). Update manually now and then. *Run as Administrator.* On by default in the GUI.
- **enable-auto-updates.bat** — Undo: back to normal automatic updates.
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
- Administrator rights for: Auto Login, Auto Restart Schedule, Disable Game Bar (policy), Power and Performance, Defender Exclusions, Stability (Delivery Optimization), automatic time zone.
