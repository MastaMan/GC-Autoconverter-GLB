:: Restarter
:: 1.0.0
:: Vasyl Lukianenko 
:: 3DGROUND
:: https://3dground.net

echo off
setlocal enabledelayedexpansion
cls

set input=%1
set run=
set adv=


for /f "tokens=1,2 delims=;" %%i in (%input%) do (
	set run=%%i
	set adv=%%j
)

taskkill /F /IM 3dsmax.exe

:: 10sec pause
ping -n 11 127.0.0.1 >nul

if /i not "%adv%"=="dontrun" (
	echo Run 3ds Max
	start "" "%run%"
) else (
	echo Exit
)

ping -n 11 127.0.0.1 >nul

exit /b 0