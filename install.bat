@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

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

:: =========================================================
:: UI
:: =========================================================
for /f "delims=" %%A in ('echo prompt $E^| cmd') do set "ESC=%%A"
set "C_RESET=%ESC%[0m"
set "C_OK=%ESC%[92m"
set "C_WARN=%ESC%[93m"
set "C_ERR=%ESC%[91m"
set "C_INFO=%ESC%[96m"
set "C_DIM=%ESC%[90m"

cls
echo %C_INFO%==============================================%C_RESET%
echo %C_INFO%           Discord RAM Fix Installer         %C_RESET%
echo %C_INFO%==============================================%C_RESET%
echo.

:: =========================================================
:: Validate base folder
:: =========================================================
if not exist "%BASE_DIR%\" (
  echo %C_ERR%[x]%C_RESET% Discord folder not found:
  echo   %C_DIM%%BASE_DIR%%C_RESET%
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
  echo %C_ERR%[x]%C_RESET% No folder matching "%FOLDER_GLOB%" found in:
  echo   %C_DIM%%BASE_DIR%%C_RESET%
  set "EXITCODE=1"
  goto :END
)

echo %C_OK%[+]%C_RESET% Target Discord folder:
echo   %C_DIM%%TARGET_DIR%%C_RESET%
echo %C_DIM%Version:%C_RESET% %BEST_VER%
echo.

:: =========================================================
:: Temp download folder
:: =========================================================
set "TEMP_DIR=%TEMP%\discord_ram_deploy_%RANDOM%%RANDOM%"
mkdir "%TEMP_DIR%" >nul 2>&1
if errorlevel 1 (
  echo %C_ERR%[x]%C_RESET% Failed to create temp folder.
  set "EXITCODE=1"
  goto :END
)

set "DLL_PATH=%TEMP_DIR%\%DLL_NAME%"
set "INI_PATH=%TEMP_DIR%\%INI_NAME%"

:: =========================================================
:: Download from GitHub
:: =========================================================
echo %C_INFO%[*]%C_RESET% Downloading files from GitHub...
echo.

call :Download "%DLL_URL%" "%DLL_PATH%" "DLL"
if errorlevel 1 ( set "EXITCODE=1" & goto :END )

call :Download "%INI_URL%" "%INI_PATH%" "INI"
if errorlevel 1 ( set "EXITCODE=1" & goto :END )

:: =========================================================
:: Close Discord if running
:: =========================================================
echo %C_INFO%[*]%C_RESET% Checking for "%LOCKING_PROCESS%"...

tasklist /fi "imagename eq %LOCKING_PROCESS%" 2>nul | find /i "%LOCKING_PROCESS%" >nul
if errorlevel 1 (
    echo %C_OK%[+]%C_RESET% Discord is not running.
) else (
    echo %C_WARN%[!]%C_RESET% Discord detected. Terminating...
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
        echo %C_OK%[+]%C_RESET% Discord terminated successfully.
    ) else (
        echo %C_ERR%[x]%C_RESET% Could not terminate Discord. Close it manually and try again.
        set "EXITCODE=1"
        goto :END
    )
)

echo.

:: =========================================================
:: Copy into Discord folder
:: =========================================================
echo %C_INFO%[*]%C_RESET% Copying files...
echo.

copy /y "%DLL_PATH%" "%TARGET_DIR%\%DLL_NAME%" >nul
if errorlevel 1 (
  echo %C_ERR%[x]%C_RESET% Failed to copy %DLL_NAME%.
  set "EXITCODE=1"
  goto :END
)
echo %C_OK%[+]%C_RESET% %DLL_NAME%

copy /y "%INI_PATH%" "%TARGET_DIR%\%INI_NAME%" >nul
if errorlevel 1 (
  echo %C_ERR%[x]%C_RESET% Failed to copy %INI_NAME%.
  set "EXITCODE=1"
  goto :END
)
echo %C_OK%[+]%C_RESET% %INI_NAME%

echo.
echo %C_OK%[+]%C_RESET% Deployment complete. You can start Discord now.
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

echo %C_INFO%[*]%C_RESET% %LABEL%
echo   %C_DIM%%URL%%C_RESET%

set "CURL_EXE=%SystemRoot%\System32\curl.exe"
if not exist "%CURL_EXE%" (
  echo %C_ERR%[x]%C_RESET% curl.exe not found in System32.
  exit /b 1
)

"%CURL_EXE%" -L --fail --silent --show-error "%URL%" -o "%OUT%"
if errorlevel 1 (
  echo %C_ERR%[x]%C_RESET% Download failed for %LABEL%.
  exit /b 1
)

if not exist "%OUT%" (
  echo %C_ERR%[x]%C_RESET% File missing after download.
  exit /b 1
)

for %%F in ("%OUT%") do (
  if %%~zF LSS 1 (
    echo %C_ERR%[x]%C_RESET% Downloaded file is empty.
    exit /b 1
  )
)

echo %C_OK%[+]%C_RESET% Downloaded.
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
echo %C_DIM%Press any key to close...%C_RESET%
pause >nul
exit /b %EXITCODE%
