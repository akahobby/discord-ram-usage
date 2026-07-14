#Requires -Version 5.1
<#
.SYNOPSIS
    Deploys version.dll and config.ini into the latest Discord app folder.

.DESCRIPTION
    Finds the newest %LOCALAPPDATA%\Discord\app-1.0.* folder, optionally stops
    Discord, then downloads version.dll and config.ini from GitHub and copies
    them into that folder. Pass -Local to use files next to the script instead.

.PARAMETER Download
    Download files from the GitHub raw URLs (default).

.PARAMETER Local
    Copy version.dll and config.ini from the script directory instead of downloading.

.PARAMETER NoKill
    Do not attempt to terminate Discord before copying files.

.PARAMETER DiscordBase
    Override the Discord install base path (default: %LOCALAPPDATA%\Discord).

.EXAMPLE
    .\install.ps1
    Download the latest published DLL and INI from GitHub, then deploy.

.EXAMPLE
    .\install.ps1 -Local
    Deploy using local files next to the script.
#>
[CmdletBinding(DefaultParameterSetName = 'Download')]
param(
    [Parameter(ParameterSetName = 'Download')]
    [switch] $Download,

    [Parameter(ParameterSetName = 'Local')]
    [switch] $Local,

    [switch] $NoKill,

    [string] $DiscordBase = "$env:LOCALAPPDATA\Discord"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
$ScriptDir   = $PSScriptRoot
$DllName     = 'version.dll'
$IniName     = 'config.ini'
$FolderGlob  = 'app-1.0.*'
$ProcessName = 'Discord.exe'

$DllUrl = 'https://raw.githubusercontent.com/akahobby/discord-ram-usage/main/version.dll'
$IniUrl = 'https://raw.githubusercontent.com/akahobby/discord-ram-usage/main/config.ini'

# ---------------------------------------------------------------------------
# Console helpers
# ---------------------------------------------------------------------------
function Write-Step([string] $Message) {
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Write-Ok([string] $Message) {
    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-Warn([string] $Message) {
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Write-Fail([string] $Message) {
    Write-Host "[x] $Message" -ForegroundColor Red
}

function Write-Dim([string] $Message) {
    Write-Host "    $Message" -ForegroundColor DarkGray
}

function Show-Banner {
    Write-Host ''
    Write-Host '==============================================' -ForegroundColor Cyan
    Write-Host '           Discord RAM Fix Installer        ' -ForegroundColor Cyan
    Write-Host '==============================================' -ForegroundColor Cyan
    Write-Host ''
}

function Test-Admin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-Admin {
    if (Test-Admin) { return }

    Write-Step 'Requesting administrator privileges...'
    $args = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', "`"$PSCommandPath`""
    )
    if ($Local)  { $args += '-Local' }
    if ($NoKill) { $args += '-NoKill' }
    if ($DiscordBase -ne "$env:LOCALAPPDATA\Discord") {
        $args += '-DiscordBase', "`"$DiscordBase`""
    }

    Start-Process powershell.exe -Verb RunAs -ArgumentList $args | Out-Null
    exit 0
}

function Get-LatestDiscordFolder([string] $BasePath) {
    if (-not (Test-Path -LiteralPath $BasePath)) {
        throw "Discord base folder not found: $BasePath"
    }

    $bestFolder = $null
    $bestVersion = [version]'0.0.0.0'

    Get-ChildItem -LiteralPath $BasePath -Directory -Filter $FolderGlob |
        ForEach-Object {
            $verText = $_.Name -replace '^app-', ''
            $ver = $null
            if ([version]::TryParse($verText, [ref]$ver) -and $ver -gt $bestVersion) {
                $bestVersion = $ver
                $bestFolder  = $_.FullName
            }
        }

    if (-not $bestFolder) {
        throw "No folder matching '$FolderGlob' found in: $BasePath"
    }

    return [pscustomobject]@{
        Path    = $bestFolder
        Version = $bestVersion
    }
}

function Stop-DiscordProcess([string] $ImageName) {
    $running = Get-Process -Name ($ImageName -replace '\.exe$', '') -ErrorAction SilentlyContinue
    if (-not $running) {
        Write-Ok 'Discord is not running.'
        return
    }

    Write-Warn "Discord is running - terminating $ImageName..."
    Stop-Process -Name ($ImageName -replace '\.exe$', '') -Force -ErrorAction SilentlyContinue

    $deadline = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500
        $stillRunning = Get-Process -Name ($ImageName -replace '\.exe$', '') -ErrorAction SilentlyContinue
        if (-not $stillRunning) {
            Write-Ok 'Discord terminated successfully.'
            return
        }
    }

    throw "Could not terminate $ImageName. Close Discord manually and try again."
}

function Get-SourceFiles {
    param(
        [bool] $UseDownload
    )

    $tempDir = Join-Path $env:TEMP "discord-ram-deploy-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        if ($UseDownload) {
            Write-Step 'Downloading files from GitHub...'
            $dllPath = Join-Path $tempDir $DllName
            $iniPath = Join-Path $tempDir $IniName

            Invoke-WebRequest -Uri $DllUrl -OutFile $dllPath -UseBasicParsing
            Invoke-WebRequest -Uri $IniUrl -OutFile $iniPath -UseBasicParsing

            foreach ($file in @($dllPath, $iniPath)) {
                if (-not (Test-Path -LiteralPath $file) -or (Get-Item -LiteralPath $file).Length -lt 1) {
                    throw "Download failed or file is empty: $file"
                }
            }

            Write-Ok 'Downloads complete.'
            return [pscustomobject]@{
                Dll = $dllPath
                Ini = $iniPath
                TempDir = $tempDir
            }
        }

        $localDll = Join-Path $ScriptDir $DllName
        $localIni = Join-Path $ScriptDir $IniName

        foreach ($file in @($localDll, $localIni)) {
            if (-not (Test-Path -LiteralPath $file)) {
                throw "Missing local file: $file`nPlace $DllName and $IniName next to install.ps1, or use -Download."
            }
        }

        Write-Ok 'Using local files from script directory.'
        return [pscustomobject]@{
            Dll = $localDll
            Ini = $localIni
            TempDir = $null
        }
    }
    catch {
        if (Test-Path -LiteralPath $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

function Copy-DeployFiles {
    param(
        [string] $SourceDll,
        [string] $SourceIni,
        [string] $DeployDir
    )

    Write-Step 'Copying files...'

    $destDll = Join-Path $DeployDir $DllName
    $destIni = Join-Path $DeployDir $IniName

    Copy-Item -LiteralPath $SourceDll -Destination $destDll -Force
    Write-Dim "$DllName -> $destDll"

    Copy-Item -LiteralPath $SourceIni -Destination $destIni -Force
    Write-Dim "$IniName -> $destIni"

    Write-Ok 'Deployment complete!'
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
Request-Admin
Show-Banner

$exitCode = 0
$tempDir  = $null

try {
    $target = Get-LatestDiscordFolder -BasePath $DiscordBase
    Write-Ok 'Target Discord folder:'
    Write-Dim $target.Path
    Write-Dim "Version: $($target.Version)"
    Write-Host ''

    $sources = Get-SourceFiles -UseDownload (-not $Local.IsPresent)
    $tempDir = $sources.TempDir

    if (-not $NoKill) {
        Write-Step 'Checking Discord process...'
        Stop-DiscordProcess -ImageName $ProcessName
        Write-Host ''
    }

    Copy-DeployFiles -SourceDll $sources.Dll -SourceIni $sources.Ini -DeployDir $target.Path
}
catch {
    Write-Fail $_.Exception.Message
    $exitCode = 1
}
finally {
    if ($tempDir -and (Test-Path -LiteralPath $tempDir)) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
if ($exitCode -eq 0) {
    Write-Host 'You can start Discord now. Edit config.ini in the deploy folder to change behavior.' -ForegroundColor DarkGray
}
Write-Host 'Press Enter to close...' -ForegroundColor DarkGray
[void] (Read-Host)
exit $exitCode
