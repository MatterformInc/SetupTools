================================================================================
  WINDOWS INSTALL - Skip "Let's add your Microsoft account" (local account)
================================================================================

The Microsoft account screen appears during Windows setup, before any of the
SetupTools scripts can run, so it has to be handled on the install USB.

RECOMMENDED: ANSWER FILE ON THE INSTALL USB
-------------------------------------------
1. Make a Windows 11 install USB (Media Creation Tool or Rufus).
2. Plug it in and run make-autounattend.bat.
   It asks for a local account name, an optional password and an optional
   computer name, then writes autounattend.xml to the root of the USB.
3. Boot the PC from the USB and install as usual.

Setup then:
  - creates the local account (Administrators group)
  - skips the Microsoft account / sign-in screens
  - skips the internet requirement and the privacy questions (all off)
Language, region, keyboard and which disk to install to are still asked,
so the USB can never wipe a drive on its own.

This uses Microsoft's supported unattended-setup settings
(HideOnlineAccountScreens + a LocalAccount), so it keeps working when the
manual tricks below are removed.

Security: the password is stored Base64-encoded (not encrypted) in
autounattend.xml. Keep that USB with the machines, and never commit the file
(it is git-ignored in this repo).

FALLBACK: ALREADY ON THE MICROSOFT ACCOUNT SCREEN
-------------------------------------------------
Press Shift+F10 to open a command prompt, then try, in order:
  start ms-cxh:localonly        (Windows 11 24H2 and newer)
  oobe\bypassnro                (older builds; PC restarts, then choose
                                 "I don't have internet")
Microsoft removes these tricks in newer builds, so they may not work on the
latest media. The answer file above is the reliable option.

AFTER SETUP
-----------
Run the SetupTools GUI. "Stop Microsoft account prompts" (on by default)
turns off the "Let's finish setting up your device" and account nags that
can come back after updates.
================================================================================
