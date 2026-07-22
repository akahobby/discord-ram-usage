@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1

:: =========================================================
:: AUTO ELEVATE
:: =========================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

title Discord RAM Fix

:: =========================================================
:: CONFIG
:: =========================================================
set "BASE_DIR=%LOCALAPPDATA%\Discord"
set "FOLDER_GLOB=app-1.0.*"

set "DLL_NAME=version.dll"
set "INI_NAME=config.ini"

set "DLL_URL=https://raw.githubusercontent.com/akahobby/discord-ram-usage/main/version.dll"
set "INI_URL=https://raw.githubusercontent.com/akahobby/discord-ram-usage/main/config.ini"

set "LOCKING_PROCESS=Discord.exe"

cls
echo ==============================================
echo            Discord RAM Fix Installer
echo ==============================================
echo.

:: =========================================================
:: Validate base folder
:: =========================================================
if not exist "%BASE_DIR%\" (
  echo [x] Discord folder not found:
  echo     %BASE_DIR%
  set "EXITCODE=1"
  goto :END
)

:: =========================================================
:: Find latest app-1.0.* folder
:: =========================================================
set "TARGET_DIR="
set "BEST_VER=0.0.0.0"

for /d %%D in ("%BASE_DIR%\%FOLDER_GLOB%") do (
  set "FOLDER=%%~nxD"
  set "VER=!FOLDER:*-=!"
  call :CompareVer "!VER!" "!BEST_VER!"
  if !errorlevel! equ 1 (
    set "BEST_VER=!VER!"
    set "TARGET_DIR=%%~fD"
  )
)

if not defined TARGET_DIR (
  echo [x] No folder matching "%FOLDER_GLOB%" found in:
  echo     %BASE_DIR%
  set "EXITCODE=1"
  goto :END
)

echo [+] Target Discord folder:
echo     !TARGET_DIR!
echo     Version: !BEST_VER!
echo.

:: =========================================================
:: Temp download folder
:: =========================================================
set "TEMP_DIR=%TEMP%\discord_ram_deploy_%RANDOM%%RANDOM%"
mkdir "%TEMP_DIR%" >nul 2>&1
if errorlevel 1 (
  echo [x] Failed to create temp folder.
  set "EXITCODE=1"
  goto :END
)

set "DLL_PATH=%TEMP_DIR%\%DLL_NAME%"
set "INI_PATH=%TEMP_DIR%\%INI_NAME%"

:: =========================================================
:: Download from GitHub
:: =========================================================
echo [*] Downloading files from GitHub...
echo.

call :Download "%DLL_URL%" "%DLL_PATH%" "DLL"
if errorlevel 1 ( set "EXITCODE=1" & goto :END )

call :Download "%INI_URL%" "%INI_PATH%" "INI"
if errorlevel 1 ( set "EXITCODE=1" & goto :END )

:: =========================================================
:: Close Discord if running
:: =========================================================
echo [*] Checking for "%LOCKING_PROCESS%"...

tasklist /fi "imagename eq %LOCKING_PROCESS%" 2>nul | find /i "%LOCKING_PROCESS%" >nul
if errorlevel 1 (
    echo [+] Discord is not running.
) else (
    echo [!] Discord detected. Terminating...
    taskkill /f /im "%LOCKING_PROCESS%" >nul 2>&1

    set "WAITCOUNT=0"
    :waitloop
    timeout /t 1 /nobreak >nul
    tasklist /fi "imagename eq %LOCKING_PROCESS%" 2>nul | find /i "%LOCKING_PROCESS%" >nul
    if not errorlevel 1 (
        set /a WAITCOUNT+=1
        if !WAITCOUNT! LSS 10 goto waitloop
    )

    tasklist /fi "imagename eq %LOCKING_PROCESS%" 2>nul | find /i "%LOCKING_PROCESS%" >nul
    if errorlevel 1 (
        echo [+] Discord terminated successfully.
    ) else (
        echo [x] Could not terminate Discord. Close it manually and try again.
        set "EXITCODE=1"
        goto :END
    )
)

echo.

:: =========================================================
:: Copy into Discord folder
:: =========================================================
echo [*] Copying files...
echo.

copy /y "%DLL_PATH%" "%TARGET_DIR%\%DLL_NAME%" >nul
if errorlevel 1 (
  echo [x] Failed to copy %DLL_NAME%.
  set "EXITCODE=1"
  goto :END
)
echo [+] %DLL_NAME%

copy /y "%INI_PATH%" "%TARGET_DIR%\%INI_NAME%" >nul
if errorlevel 1 (
  echo [x] Failed to copy %INI_NAME%.
  set "EXITCODE=1"
  goto :END
)
echo [+] %INI_NAME%

echo.
echo [+] Deployment complete. You can start Discord now.
set "EXITCODE=0"
goto :END

:: =========================================================
:: FUNCTIONS
:: =========================================================

:Download
:: %1=url %2=outpath %3=label
set "URL=%~1"
set "OUT=%~2"
set "LABEL=%~3"

echo [*] %LABEL%
echo     %URL%

set "CURL_EXE=%SystemRoot%\System32\curl.exe"
if not exist "%CURL_EXE%" (
  echo [x] curl.exe not found in System32.
  exit /b 1
)

"%CURL_EXE%" -L --fail --silent --show-error "%URL%" -o "%OUT%" 2>nul
if errorlevel 1 (
  echo [x] Download failed for %LABEL%.
  exit /b 1
)

if not exist "%OUT%" (
  echo [x] File missing after download.
  exit /b 1
)

for %%F in ("%OUT%") do (
  if %%~zF LSS 1 (
    echo [x] Downloaded file is empty.
    exit /b 1
  )
)

echo [+] Downloaded.
echo.
exit /b 0

:CompareVer
:: Returns ERRORLEVEL 1 if %1 > %2
setlocal EnableDelayedExpansion
set "A=%~1"
set "B=%~2"

for /f "tokens=1-4 delims=." %%a in ("%A%") do (
  set "a1=%%a" & set "a2=%%b" & set "a3=%%c" & set "a4=%%d"
)
for /f "tokens=1-4 delims=." %%a in ("%B%") do (
  set "b1=%%a" & set "b2=%%b" & set "b3=%%c" & set "b4=%%d"
)

for %%X in (a1 a2 a3 a4 b1 b2 b3 b4) do if "!%%X!"=="" set "%%X=0"

for %%N in (1 2 3 4) do (
  if !a%%N! GTR !b%%N! ( endlocal & exit /b 1 )
  if !a%%N! LSS !b%%N! ( endlocal & exit /b 0 )
)

endlocal & exit /b 0

:END
echo.
if defined TEMP_DIR rd /s /q "%TEMP_DIR%" >nul 2>&1
if not defined EXITCODE set "EXITCODE=1"
echo Press any key to close...
pause >nul
exit /b %EXITCODE%
