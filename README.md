# discord-ram-usage

Windows helper that deploys **`version.dll`** and **`config.ini`** next to the Discord desktop app so Discord cannot keep rewriting its own **process and thread priorities**. Optional **periodic memory trim** and **raw-input handling** tweaks are controlled in the INI.

> **Note:** This is unofficial and not affiliated with Discord. Use at your own risk. DLL sideloading can break if Discord changes how it loads dependencies; you may need to redeploy after major updates.

## What it does

- **Priority fix** — Stops Discord from pushing itself to idle/low priority behavior you may not want for voice, games, or responsiveness.
- **Thread priority fix** — Same idea at the thread level.
- **Trim (optional)** — `EnableTrim` can periodically ask the OS to trim working set (see `config.ini`).
- **Raw input (optional)** — Configurable modes for raw input–related behavior (suspend thread, zeroing, throttle); see comments in `config.ini`.

Behavior is entirely driven by **`config.ini`** next to the DLL.

## Requirements

- **Windows** (Discord desktop client).
- **Administrator rights** when using the included installer script (needed to replace files while Discord may be running, and for reliable deployment).
- **`curl.exe`** in `System32` (standard on Windows 10/11) for the script’s downloads.

## Quick install (`discordfix.bat`)

1. Close Discord (or let the script terminate `Discord.exe` if configured).
2. Right‑click **`discordfix.bat`** → **Run as administrator**.
3. The script will:
   - Find the newest `%LOCALAPPDATA%\Discord\app-1.0.*` folder.
   - Download `version.dll` and `config.ini` from this repository.
   - Copy them into that folder (same directory as the app binaries Discord runs from).

Default script settings assume standard Discord install paths and process name `Discord.exe`. Edit the `CONFIG` section at the top of `discordfix.bat` if your layout differs.

## Manual install

1. Locate your Discord app folder (typically `%LOCALAPPDATA%\Discord\app-1.0.xxxx\`).
2. Copy **`version.dll`** and **`config.ini`** into that folder (same level as the main executables).
3. Start Discord.

## Configuration (`config.ini`)

| Key | Meaning |
|-----|--------|
| `EnableTrim` | `1` = enable periodic trim, `0` = off |
| `TrimIntervalMs` | Milliseconds between trims (default `10000`) |
| `EnablePriorityFix` | `1` = enforce priority behavior |
| `PriorityClass` | `0` Idle … `4` High (default `2` Normal) |
| `EnableThreadPriorityFix` | `1` = fix thread priorities |
| `RawInputMode` | `0` off, `1` suspend thread, `2` zeroing, `3` zeroing + throttle |
| `RawInputSleepMs` | Throttle delay for mode `3` |
| `RawInputPatchDelayMs` | Delay before IAT patch (default `10000`) |

Edit **`config.ini`** after deployment, then restart Discord for changes to apply.

## After a Discord update

Discord may install a new `app-1.0.*` folder. Run **`discordfix.bat`** again (as admin) so the DLL and INI land in the **new** folder, or copy the two files manually.

## Repository layout

| File | Role |
|------|------|
| `discordfix.bat` | Finds latest Discord app folder, downloads and copies DLL + INI |
| `version.dll` | Native hook loaded via Windows DLL search order next to Discord |
| `config.ini` | Runtime settings |

## License / safety

Inspect binaries before running them in elevated context. Prefer building or auditing `version.dll` yourself if you need full transparency. This project is provided as-is.
