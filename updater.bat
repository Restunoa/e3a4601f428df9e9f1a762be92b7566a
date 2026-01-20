@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: CONFIGURATION
:: ============================================================
set "GITHUB_API=https://api.github.com/repos/Restunoa/e3a4601f428df9e9f1a762be92b7566a/releases/latest"
set "UPDATER_URL=https://github.com/Restunoa/e3a4601f428df9e9f1a762be92b7566a/raw/main/updater.bat"

set "ROBLOX_DIR=%localappdata%\Roblox\Versions"
set "TEMP_ZIP=%temp%\update.zip"
set "TEMP_SHA=%temp%\update.sha256"

set "CURRENT_UPDATER=%~f0"
set "NEW_UPDATER=%temp%\updater_new.bat"
set "REPLACE_HELPER=%temp%\replace_updater.bat"

echo ============================================================
echo Checking GitHub for latest release...
echo ============================================================

:: ============================================================
:: FETCH LATEST RELEASE JSON
:: ============================================================
for /f "delims=" %%A in ('powershell -NoLogo -Command ^
    "(Invoke-WebRequest '%GITHUB_API%' -UseBasicParsing).Content"') do (
    set "API_JSON=%%A"
)

:: Extract version, ZIP URL, and SHA256 from JSON
for /f "delims=" %%A in ('powershell -NoLogo -Command ^
    "$j = '%API_JSON%' | ConvertFrom-Json; $j.tag_name"') do set "LATEST_VERSION=%%A"

for /f "delims=" %%A in ('powershell -NoLogo -Command ^
    "$j = '%API_JSON%' | ConvertFrom-Json; $j.assets[0].browser_download_url"') do set "ZIP_URL=%%A"

for /f "delims=" %%A in ('powershell -NoLogo -Command ^
    "$j = '%API_JSON%' | ConvertFrom-Json; $j.assets[0].label"') do set "EXPECTED_SHA=%%A"

echo Latest version: %LATEST_VERSION%
echo ZIP URL:        %ZIP_URL%
echo Expected SHA:   %EXPECTED_SHA%
echo.

:: ============================================================
:: SELF‑UPDATE CHECK
:: ============================================================
echo Checking for updater self-update...

powershell -command ^
    "(New-Object Net.WebClient).DownloadFile('%UPDATER_URL%', '%NEW_UPDATER%')"

for /f "delims=" %%A in ('powershell -NoLogo -Command ^
    "(Get-FileHash '%CURRENT_UPDATER%' -Algorithm SHA256).Hash"') do set "CURR_SHA=%%A"

for /f "delims=" %%A in ('powershell -NoLogo -Command ^
    "(Get-FileHash '%NEW_UPDATER%' -Algorithm SHA256).Hash"') do set "NEW_SHA=%%A"

if /i not "%CURR_SHA%"=="%NEW_SHA%" (
    echo New updater detected. Updating...

    (
    echo @echo off
    echo echo Waiting for main updater to close...
    echo :waitloop
    echo tasklist ^| findstr /i "%~nx0" >nul && (timeout /t 1 >nul & goto waitloop)
    echo copy /y "%NEW_UPDATER%" "%CURRENT_UPDATER%" >nul
    echo echo Restarting updater...
    echo start "" "%CURRENT_UPDATER%"
    ) > "%REPLACE_HELPER%"

    start "" "%REPLACE_HELPER%"
    exit /b
)

echo Updater is already the latest version.
echo.

:continue_update

:: ============================================================
:: FIND ROBLOX INSTALLATIONS
:: ============================================================
echo Searching for Roblox installations...

set "TARGETS="

for /d %%A in ("%ROBLOX_DIR%\*") do (
    if exist "%%A\RobloxPlayerBeta.exe" (
        echo Found: %%A
        set "TARGETS=!TARGETS!;%%A"
    )
)

if "%TARGETS%"=="" (
    echo No Roblox installations found.
    pause
    exit /b 1
)

echo.

:: ============================================================
:: VERSION COMPARISON
:: ============================================================
echo Checking installed versions...

set "UPDATE_NEEDED=0"

for %%D in (%TARGETS%) do (
    if exist "%%D\version.txt" (
        set /p INSTALLED_VERSION=<"%%D\version.txt"
        echo Installed in %%D: !INSTALLED_VERSION!

        if not "!INSTALLED_VERSION!"=="%LATEST_VERSION%" (
            echo Update required for %%D
            set "UPDATE_NEEDED=1"
        )
    ) else (
        echo No version file in %%D — update required.
        set "UPDATE_NEEDED=1"
    )
)

if "%UPDATE_NEEDED%"=="0" (
    echo All installations are already up to date.
    pause
    exit /b 0
)

echo.

:: ============================================================
:: DOWNLOAD ZIP WITH PROGRESS BAR
:: ============================================================
echo Downloading update...

powershell -command ^
    "$wc = New-Object System.Net.WebClient;" ^
    "$wc.DownloadProgressChanged += { Write-Progress -Activity 'Downloading update' -Status ('{0}%% complete' -f $_.ProgressPercentage) -PercentComplete $_.ProgressPercentage };" ^
    "$wc.DownloadFileAsync([Uri]'%ZIP_URL%', '%TEMP_ZIP%');" ^
    "while ($wc.IsBusy) { Start-Sleep -Milliseconds 200 }"

echo.

:: ============================================================
:: VERIFY SHA256
:: ============================================================
echo Verifying integrity...

for /f "delims=" %%A in ('powershell -NoLogo -Command ^
    "(Get-FileHash '%TEMP_ZIP%' -Algorithm SHA256).Hash"') do set "ACTUAL_SHA=%%A"

echo Expected: %EXPECTED_SHA%
echo Actual:   %ACTUAL_SHA%

if /i not "%EXPECTED_SHA%"=="%ACTUAL_SHA%" (
    echo SHA256 mismatch! Aborting.
    del "%TEMP_ZIP%"
    pause
    exit /b 1
)

echo Integrity OK.
echo.

:: ============================================================
:: EXTRACT ZIP TO ALL INSTALLATIONS
:: ============================================================
echo Extracting update...

for %%D in (%TARGETS%) do (
    echo Extracting into %%D
    powershell -command "Expand-Archive -Path '%TEMP_ZIP%' -DestinationPath '%%D' -Force"
    echo %LATEST_VERSION%>"%%D\version.txt"
)

echo.

:: ============================================================
:: CLEANUP
:: ============================================================
del "%TEMP_ZIP%"

echo Update complete.
pause
