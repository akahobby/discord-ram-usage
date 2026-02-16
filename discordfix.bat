chcp 65001 >nul
@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: =========================================================
:: AUTO ELEVATE
:: =========================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "Start-Process '%~f0' -Verb RunAs"
    exit
)

title Discord Ram Fix

:: =========================================================
:: CONFIG
:: =========================================================
set "BASE_DIR=%LOCALAPPDATA%\Discord"
set "FOLDER_GLOB=app-1.0.*"

:: Optional: deploy into a subfolder inside the matched folder (blank = root)
set "DEPLOY_SUBDIR="

set "DLL_NAME=version.dll"
set "INI_NAME=config.ini"

set "DLL_URL=https://raw.githubusercontent.com/akahobby/discord-ram-usage/main/version.dll"
set "INI_URL=https://raw.githubusercontent.com/akahobby/discord-ram-usage/main/config.ini"

:: If your app locks files, set the process name (example: disco.exe). Blank to skip.
set "LOCKING_PROCESS=Discord.exe"

:: =========================================================
:: UI COLORS
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
echo %C_INFO%           Discord Ram Fix            %C_RESET%
echo %C_INFO%==============================================%C_RESET%
echo.

:: =========================================================
:: Validate Base Folder
:: =========================================================
if not exist "%BASE_DIR%\" (
  echo %C_ERR%[x]%C_RESET% Base folder not found:
  echo   %C_DIM%%BASE_DIR%%C_RESET%
  set "EXITCODE=1"
  goto :END
)

:: =========================================================
:: Find Latest Version Folder
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

set "DEPLOY_DIR=%TARGET_DIR%"
if not "%DEPLOY_SUBDIR%"=="" set "DEPLOY_DIR=%TARGET_DIR%\%DEPLOY_SUBDIR%"

echo %C_OK%[✓]%C_RESET% Target detected:
echo   %C_DIM%%TARGET_DIR%%C_RESET%
echo %C_DIM%Parsed version:%C_RESET% %BEST_VER%
echo.
echo %C_INFO%[i]%C_RESET% Deploy destination:
echo   %C_DIM%%DEPLOY_DIR%%C_RESET%
echo.

:: =========================================================
:: Temp Folder
:: =========================================================
set "TEMP_DIR=%TEMP%\disco_deploy_%RANDOM%%RANDOM%"
mkdir "%TEMP_DIR%" >nul 2>&1
if errorlevel 1 (
  echo %C_ERR%[x]%C_RESET% Failed to create temp folder:
  echo   %C_DIM%%TEMP_DIR%%C_RESET%
  set "EXITCODE=1"
  goto :END
)

set "DLL_PATH=%TEMP_DIR%\%DLL_NAME%"
set "INI_PATH=%TEMP_DIR%\%INI_NAME%"

:: =========================================================
:: Download
:: =========================================================
echo %C_INFO%[i]%C_RESET% Downloading files...
echo.

call :Download "%DLL_URL%" "%DLL_PATH%" "DLL"
if errorlevel 1 ( set "EXITCODE=1" & goto :END )

call :Download "%INI_URL%" "%INI_PATH%" "INI"
if errorlevel 1 ( set "EXITCODE=1" & goto :END )

:: =========================================================
:: Close Locking Process (robust)
:: =========================================================
if not "%LOCKING_PROCESS%"=="" (

  echo %C_INFO%[i]%C_RESET% Checking for "%LOCKING_PROCESS%"...

  tasklist /fi "imagename eq %LOCKING_PROCESS%" | find /i "%LOCKING_PROCESS%" >nul
  if errorlevel 1 (
      echo %C_OK%[✓]%C_RESET% Process not running.
  ) else (
      echo %C_WARN%[!]%C_RESET% Process detected. Terminating...

      :: Kill all instances
      taskkill /f /im "%LOCKING_PROCESS%" >nul 2>&1

      :: Wait until fully closed
      set "WAITCOUNT=0"
      :waitloop
      timeout /t 1 /nobreak >nul
      tasklist /fi "imagename eq %LOCKING_PROCESS%" | find /i "%LOCKING_PROCESS%" >nul
      if not errorlevel 1 (
          set /a WAITCOUNT+=1
          if !WAITCOUNT! LSS 10 goto waitloop
      )

      :: Final check
      tasklist /fi "imagename eq %LOCKING_PROCESS%" | find /i "%LOCKING_PROCESS%" >nul
      if errorlevel 1 (
          echo %C_OK%[✓]%C_RESET% Process terminated successfully.
      ) else (
          echo %C_ERR%[x]%C_RESET% Process could not be terminated.
          pause
          exit /b 1
      )
  )

  echo.
)

:: =========================================================
:: Ensure Deploy Folder Exists
:: =========================================================
if not exist "%DEPLOY_DIR%\" (
  mkdir "%DEPLOY_DIR%" 2>nul
  if errorlevel 1 (
    echo %C_ERR%[x]%C_RESET% Failed to create deploy folder:
    echo   %C_DIM%%DEPLOY_DIR%%C_RESET%
    set "EXITCODE=1"
    goto :END
  )
)

:: =========================================================
:: Copy Files (VERBOSE)
:: =========================================================
echo %C_INFO%[i]%C_RESET% Copying files...
echo.

echo %C_INFO%[^>] DLL%C_RESET%
echo   %C_DIM%From:%C_RESET% %DLL_PATH%
echo   %C_DIM%To:  %C_RESET% %DEPLOY_DIR%\%DLL_NAME%
copy /y "%DLL_PATH%" "%DEPLOY_DIR%\%DLL_NAME%"
if errorlevel 1 (
  echo %C_ERR%[x]%C_RESET% Copy failed for %DLL_NAME%.
  set "EXITCODE=1"
  goto :END
)

echo %C_INFO%[^>] INI%C_RESET%
echo   %C_DIM%From:%C_RESET% %INI_PATH%
echo   %C_DIM%To:  %C_RESET% %DEPLOY_DIR%\%INI_NAME%
copy /y "%INI_PATH%" "%DEPLOY_DIR%\%INI_NAME%"
if errorlevel 1 (
  echo %C_ERR%[x]%C_RESET% Copy failed for %INI_NAME%.
  set "EXITCODE=1"
  goto :END
)

echo.
echo %C_OK%[✓]%C_RESET% Deployment Complete!
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

echo %C_INFO%[^>] %LABEL%%C_RESET%
echo   %C_DIM%%URL%%C_RESET%

:: Force use of system curl (avoids PATH issues when elevated)
set "CURL_EXE=%SystemRoot%\System32\curl.exe"

if not exist "%CURL_EXE%" (
  echo %C_ERR%[x]%C_RESET% curl.exe not found in System32.
  pause
  exit /b 1
)

"%CURL_EXE%" -L --fail "%URL%" -o "%OUT%"
if errorlevel 1 (
  echo.
  echo %C_ERR%[x]%C_RESET% Download failed for %LABEL%.
  echo %C_DIM%Check internet connection or URL.%C_RESET%
  pause
  exit /b 1
)

if not exist "%OUT%" (
  echo.
  echo %C_ERR%[x]%C_RESET% File missing after download:
  echo   %C_DIM%%OUT%%C_RESET%
  pause
  exit /b 1
)

for %%F in ("%OUT%") do if %%~zF LSS 1 (
  echo.
  echo %C_ERR%[x]%C_RESET% Downloaded file is empty.
  pause
  exit /b 1
)

echo %C_OK%[✓]%C_RESET% Downloaded successfully.
echo.
exit /b 0

:CompareVer
:: Returns ERRORLEVEL 1 if %1 > %2 (dotted version compare)
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
pause
exit
