@echo off
setlocal EnableExtensions EnableDelayedExpansion

title 3ds Max Watchdog

set "WATCHDOG_INI=%~dp0watchdog.ini"
set "SETTINGS_INI=%~dp0global@settings.ini"
set "SETTINGS_SEC=GC-Autoconverter-GLB"
set "CHECK_INTERVAL_SEC=60"

if exist "%WATCHDOG_INI%" del /f /q "%WATCHDOG_INI%" >nul 2>nul

:watchdog_loop
set "SLUG="
set "A_ID="
set "STAGE="
set "STARTED_AT="
set "HEARTBEAT_AT="
set "TIMEOUT_MIN=15"
set "TIMEOUT_MIN_NUM=15"
set "TIMEOUT_SEC_NUM=900"
set "STATE=Idle"
set "ACTION=Waiting for active file"
set "ELAPSED="
set "REMAINING="
set "REMAINING_MIN="
set "REMAINING_SEC="
set "KILL_EXIT_CODE="
set "NOW="
set "MAX_STARTED_AT="
set "MAX_AGE="
set "MAX_GRACE_REMAINING="

for /f "tokens=*" %%A in ('powershell -NoP -C "(Get-Date).ToString(\"yyyy-MM-dd HH:mm:ss\")"') do set "NOW_TEXT=%%A"
for /f %%A in ('powershell -NoP -C "[int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"') do set "NOW=%%A"
set /a NOW_NUM=NOW+0 2>nul
if errorlevel 1 set "NOW_NUM=0"

if exist "%SETTINGS_INI%" (
	for /f "tokens=*" %%A in ('powershell -NoP -ExecutionPolicy Bypass -Command "$ini=$env:SETTINGS_INI; $sec=$env:SETTINGS_SEC; $value=''; if (Test-Path -LiteralPath $ini) { $inside=$false; foreach ($line in (Get-Content -LiteralPath $ini)) { $t=$line.Trim(); if ($t -ieq ('[' + $sec + ']')) { $inside=$true; continue }; if ($t.StartsWith('[')) { $inside=$false }; if ($inside -and $t -match '^spnWatchdogTimeoutMin=(.*)$') { $value=$Matches[1].Trim(); break } } }; if ($value -match '^[0-9]+$') { $value } else { '15' }"') do set "TIMEOUT_MIN=%%A"
)

set "TIMEOUT_MIN=%TIMEOUT_MIN:L=%"
set "TIMEOUT_MIN=%TIMEOUT_MIN:l=%"
set /a TIMEOUT_MIN_NUM=TIMEOUT_MIN+0 2>nul
if errorlevel 1 set "TIMEOUT_MIN_NUM=15"
if %TIMEOUT_MIN_NUM% LSS 1 set "TIMEOUT_MIN_NUM=15"
set /a TIMEOUT_SEC_NUM=TIMEOUT_MIN_NUM*60

if exist "%WATCHDOG_INI%" (
	for /f "tokens=1,2,3,4,5 delims=|" %%A in ('powershell -NoP -ExecutionPolicy Bypass -Command "$ini=$env:WATCHDOG_INI; $data=@{slug='';a_id='';stage='';startedAt='';heartbeatAt=''}; if (Test-Path -LiteralPath $ini) { $inside=$false; foreach ($line in (Get-Content -LiteralPath $ini)) { $t=$line.Trim(); if ($t -ieq '[WATCHDOG]') { $inside=$true; continue }; if ($t.StartsWith('[')) { $inside=$false }; if ($inside -and $t -match '^(slug|a_id|stage|startedAt|heartbeatAt)=(.*)$') { $data[$Matches[1]]=$Matches[2].Trim() } } }; Write-Output ($data.slug + '|' + $data.a_id + '|' + $data.stage + '|' + $data.startedAt + '|' + $data.heartbeatAt)"') do (
		set "SLUG=%%~A"
		set "A_ID=%%~B"
		set "STAGE=%%~C"
		set "STARTED_AT=%%~D"
		set "HEARTBEAT_AT=%%~E"
	)
) else (
	set "STATE=Idle"
	set "ACTION=No watchdog.ini. Waiting for MaxScript to create it."
	goto watchdog_render
)

if not defined SLUG (
	set "STATE=Idle"
	set "ACTION=No active file"
	goto watchdog_render
)

if not defined HEARTBEAT_AT (
	set "STATE=Idle"
	set "ACTION=Active slug has no heartbeatAt. Waiting for next INI reread."
	goto watchdog_render
)

set "HEARTBEAT_AT=%HEARTBEAT_AT:L=%"
set "HEARTBEAT_AT=%HEARTBEAT_AT:l=%"
set /a HEARTBEAT_AT_NUM=HEARTBEAT_AT+0 2>nul
if errorlevel 1 (
	set "STATE=Idle"
	set "ACTION=Invalid heartbeatAt. Waiting for next INI reread."
	goto watchdog_render
)

if %NOW_NUM% LEQ 0 (
	set "STATE=Idle"
	set "ACTION=Cannot read current time. Waiting for next INI reread."
	goto watchdog_render
)

for /f "tokens=1,2 delims=|" %%A in ('powershell -NoP -ExecutionPolicy Bypass -Command "$p=Get-Process -Name 3dsmax -ErrorAction SilentlyContinue | Sort-Object StartTime -Descending | Select-Object -First 1; if ($p -and $p.StartTime) { $start=[int64]([DateTimeOffset]$p.StartTime).ToUnixTimeSeconds(); $now=[int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()); Write-Output ($start.ToString() + '|' + [Math]::Max(0, $now - $start).ToString()) } else { Write-Output '0|0' }"') do (
	set "MAX_STARTED_AT=%%~A"
	set "MAX_AGE=%%~B"
)
set /a MAX_STARTED_AT_NUM=MAX_STARTED_AT+0 2>nul
if errorlevel 1 set "MAX_STARTED_AT_NUM=0"
set /a MAX_AGE_NUM=MAX_AGE+0 2>nul
if errorlevel 1 set "MAX_AGE_NUM=0"

if %MAX_STARTED_AT_NUM% LEQ 0 (
	set "STATE=Idle"
	set "ACTION=3ds Max is not running. Waiting for Desktop bat to start it."
	set "SLUG="
	set "A_ID="
	set "STAGE="
	set "STARTED_AT="
	set "HEARTBEAT_AT="
	goto watchdog_render
)

set /a STALE_LIMIT=MAX_STARTED_AT_NUM-5
if %HEARTBEAT_AT_NUM% LSS %STALE_LIMIT% (
	if exist "%WATCHDOG_INI%" del /f /q "%WATCHDOG_INI%" >nul 2>nul
	set "STATE=Idle"
	set "ACTION=Removed stale watchdog.ini from previous 3ds Max process."
	set "SLUG="
	set "A_ID="
	set "STAGE="
	set "STARTED_AT="
	set "HEARTBEAT_AT="
	goto watchdog_render
)

set /a ELAPSED=NOW_NUM-HEARTBEAT_AT_NUM
if %ELAPSED% LSS 0 set "ELAPSED=0"
set /a REMAINING=TIMEOUT_SEC_NUM-ELAPSED
if %REMAINING% LSS 0 set "REMAINING=0"
set /a MAX_GRACE_REMAINING=TIMEOUT_SEC_NUM-MAX_AGE_NUM
if %MAX_GRACE_REMAINING% LSS 0 set "MAX_GRACE_REMAINING=0"
if %REMAINING% LSS %MAX_GRACE_REMAINING% set "REMAINING=%MAX_GRACE_REMAINING%"
set /a REMAINING_MIN=REMAINING/60
set /a REMAINING_SEC=REMAINING%%60
set "STATE=Active"
set "ACTION=Monitoring heartbeat"

if %ELAPSED% GEQ %TIMEOUT_SEC_NUM% if %MAX_AGE_NUM% GEQ %TIMEOUT_SEC_NUM% (
	cls
	echo 3ds Max Watchdog
	echo =================
	echo Time:       !NOW_TEXT!
	echo.
	echo TIMEOUT
	echo a_id ^| slug: !A_ID! ^| !SLUG!
	echo stage:      !STAGE!
	echo max age:    !MAX_AGE_NUM! sec
	echo heartbeat:  !HEARTBEAT_AT!
	echo elapsed:    !ELAPSED! sec
	echo timeout:    !TIMEOUT_SEC_NUM! sec
	echo.
	echo Killing 3ds Max...
	taskkill /F /T /IM 3dsmax.exe
	set "KILL_EXIT_CODE=!ERRORLEVEL!"
	echo taskkill exit code: !KILL_EXIT_CODE!
	echo Removing watchdog.ini...
	if exist "%WATCHDOG_INI%" del /f /q "%WATCHDOG_INI%" >nul 2>nul
	set "STATE=Idle"
	set "ACTION=3ds Max was killed. Waiting for Desktop bat to restart it."
	set "SLUG="
	set "A_ID="
	set "STAGE="
	set "STARTED_AT="
	set "HEARTBEAT_AT="
	set "ELAPSED="
	set "REMAINING="
	set "REMAINING_MIN="
	set "REMAINING_SEC="
	timeout /t 5 /nobreak >nul
)

:watchdog_render
for /l %%S in (%CHECK_INTERVAL_SEC%,-1,1) do (
	set "NEXT_CHECK=%%S"
	set /a WAITED=CHECK_INTERVAL_SEC-%%S
	set "DISPLAY_NOW=!NOW!"
	set "DISPLAY_ELAPSED=!ELAPSED!"
	set "DISPLAY_REMAINING=!REMAINING!"
	set "DISPLAY_REMAINING_MIN=!REMAINING_MIN!"
	set "DISPLAY_REMAINING_SEC=!REMAINING_SEC!"
	set "DISPLAY_MAX_AGE=!MAX_AGE_NUM!"

	if !NOW_NUM! GTR 0 (
		set /a DISPLAY_NOW=NOW_NUM+WAITED
	)

	if defined MAX_AGE_NUM (
		set /a DISPLAY_MAX_AGE=MAX_AGE_NUM+WAITED
	)

	if defined HEARTBEAT_AT (
		set /a DISPLAY_ELAPSED=DISPLAY_NOW-HEARTBEAT_AT_NUM
		if !DISPLAY_ELAPSED! LSS 0 set "DISPLAY_ELAPSED=0"
		set /a DISPLAY_REMAINING=TIMEOUT_SEC_NUM-DISPLAY_ELAPSED
		if !DISPLAY_REMAINING! LSS 0 set "DISPLAY_REMAINING=0"
		if defined DISPLAY_MAX_AGE (
			set /a DISPLAY_MAX_GRACE_REMAINING=TIMEOUT_SEC_NUM-DISPLAY_MAX_AGE
			if !DISPLAY_MAX_GRACE_REMAINING! LSS 0 set "DISPLAY_MAX_GRACE_REMAINING=0"
			if !DISPLAY_REMAINING! LSS !DISPLAY_MAX_GRACE_REMAINING! set "DISPLAY_REMAINING=!DISPLAY_MAX_GRACE_REMAINING!"
		)
		set /a DISPLAY_REMAINING_MIN=DISPLAY_REMAINING/60
		set /a DISPLAY_REMAINING_SEC=DISPLAY_REMAINING%%60
	)

	call :draw_watchdog_screen
	ping -n 2 127.0.0.1 >nul
)
goto watchdog_loop

:draw_watchdog_screen
cls
echo 3ds Max Watchdog
echo =================
echo Time:            !NOW_TEXT!
echo INI:             %WATCHDOG_INI%
echo Settings:        %SETTINGS_INI%
echo Next INI reread: !NEXT_CHECK! sec
echo.
echo State:           !STATE!
echo Action:          !ACTION!
echo Timeout:         !TIMEOUT_MIN_NUM! min ^(!TIMEOUT_SEC_NUM! sec^)
echo nowUtc:          !DISPLAY_NOW!
echo.
if defined SLUG (
	echo a_id ^| slug:     !A_ID! ^| !SLUG!
	echo stage:           !STAGE!
	echo startedAt:       !STARTED_AT!
	echo heartbeatAt:     !HEARTBEAT_AT!
	echo max startedAt:   !MAX_STARTED_AT!
	echo max age:         !DISPLAY_MAX_AGE! sec
	echo elapsed:         !DISPLAY_ELAPSED! sec since heartbeat
	echo restart in:      !DISPLAY_REMAINING_MIN! min !DISPLAY_REMAINING_SEC! sec
) else (
	echo a_id ^| slug:     no active file
	echo stage:           -
	echo startedAt:       -
	echo heartbeatAt:     -
	echo elapsed:         -
	echo restart in:      no active file
)
exit /b 0
