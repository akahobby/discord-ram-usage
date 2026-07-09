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
- Administrator rights for installation (to replace files and stop Discord if needed)

## Quick install

**Option A — double-click (easiest)**

1. Download or clone this repo.
2. Right-click **`install.bat`** → **Run as administrator**.
3. Start Discord.

The installer copies `version.dll` and `config.ini` from the repo folder into your latest `%LOCALAPPDATA%\Discord\app-1.0.*` directory.

**Option B — PowerShell**

```powershell
# Deploy local files (default)
.\install.ps1

# Download latest from GitHub instead of using local copies
.\install.ps1 -Download

# Skip killing Discord (copy only if files are not locked)
.\install.ps1 -NoKill
```

`discordfix.bat` is kept as a legacy alias for `install.bat`.

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

Discord installs a new `app-1.0.*` folder. Run **`install.bat`** again (as admin) or copy the two files manually into the new folder.

## Repository layout

| File | Role |
|------|------|
| `install.ps1` | Main installer (local or `-Download`) |
| `install.bat` | Double-click launcher |
| `discordfix.bat` | Legacy alias for `install.bat` |
| `version.dll` | Native hook loaded via DLL search order |
| `config.ini` | Default settings (copied on install) |
