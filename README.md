# Discord RAM Fix

Windows helper that deploys **`version.dll`** and **`config.ini`** next to the Discord desktop app so Discord cannot keep rewriting its own **process and thread priorities**. Optional **periodic memory trim** and **raw-input handling** tweaks are controlled in the INI.

> **Note:** Unofficial — not affiliated with Discord. DLL sideloading can break after major Discord updates; redeploy into the new `app-1.0.*` folder when that happens.

## What it does

| Feature | Description |
|---------|-------------|
| **Priority fix** | Stops Discord from pushing itself to idle/low priority |
| **Thread priority fix** | Same at the thread level |
| **Trim** (optional) | Periodically asks Windows to trim working set |
| **Raw input** (optional) | Configurable raw-input behavior (see `config.ini`) |

All behavior is driven by **`config.ini`** in the same folder as the DLL.

## Requirements

- Windows 10/11 with the Discord desktop client
- Administrator rights for installation
- `curl.exe` in System32 (included with Windows 10/11)

## Quick install

1. Download **`install.bat`** (or **`discordfix.bat`**) from this repo — that one file is enough.
2. Right-click it → **Run as administrator**.
3. Start Discord.

The script finds your latest `%LOCALAPPDATA%\Discord\app-1.0.*` folder, downloads `version.dll` and `config.ini` from GitHub, and copies them in.

## Manual install

1. Find `%LOCALAPPDATA%\Discord\app-1.0.xxxx\` (newest version folder).
2. Copy **`version.dll`** and **`config.ini`** into that folder.
3. Restart Discord.

## Configuration (`config.ini`)

| Key | Values | Default |
|-----|--------|---------|
| `EnableTrim` | `0` / `1` | `1` |
| `TrimIntervalMs` | milliseconds | `10000` |
| `EnablePriorityFix` | `0` / `1` | `1` |
| `PriorityClass` | `0` Idle … `4` High | `2` (Normal) |
| `EnableThreadPriorityFix` | `0` / `1` | `1` |
| `RawInputMode` | `0` off, `1` suspend, `2` zeroing, `3` zeroing + throttle | `1` |
| `RawInputSleepMs` | throttle delay for mode `3` | `1500` |
| `RawInputPatchDelayMs` | delay before IAT patch | `10000` |

Edit `config.ini` in the Discord app folder, then restart Discord.

## After a Discord update

Discord installs a new `app-1.0.*` folder. Run the `.bat` again (as admin) or copy the two files manually into the new folder.

## Repository layout

| File | Role |
|------|------|
| `install.bat` | Standalone installer — download this alone and run as admin |
| `discordfix.bat` | Same installer (alternate name) |
| `version.dll` | Native hook loaded via DLL search order |
| `config.ini` | Default settings (downloaded on install) |
| `install.ps1` | Optional PowerShell version of the installer |
