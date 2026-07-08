@echo off
setlocal EnableExtensions EnableDelayedExpansion

set MAX_PATH=C:\Program Files\Autodesk\3ds Max 2025\
set MAX_EXE=%MAX_PATH%3dsmax.exe
set MAX_SENDDMP=%MAX_PATH%senddmp.exe
set MAX_ARGS=-q -ma -U MaxScript "%~dp0%autorun.ms"

for /f %%A in ('powershell -NoP -C "(Get-Date).ToString(\"yyyy-MM-dd HH:mm:ss\")"') do set "NOW=%%A"

if exist "%MAX_SENDDMP%" (
    ren "%MAX_SENDDMP%" "__senddmp.exe"
    echo senddmp.exe disabled!
) 

:restart

tasklist /fi "imagename eq 3dsmax.exe" | find /i "3dsmax.exe" >nul && (
  for /f %%A in ('powershell -NoP -C "(Get-Date).ToString(\"yyyy-MM-dd HH:mm:ss\")"') do set "NOW=%%A"
  echo [!NOW!] 3ds Max already run, waiting 10sec...
  timeout /t 10 /nobreak >nul
  goto restart
)

for /f %%A in ('powershell -NoP -C "(Get-Date).ToString(\"yyyy-MM-dd HH:mm:ss\")"') do set "NOW=%%A"
echo [!NOW!] Start 3ds Max...

start "" /wait "%MAX_EXE%" %MAX_ARGS%

for /f %%A in ('powershell -NoP -C "(Get-Date).ToString(\"yyyy-MM-dd HH:mm:ss\")"') do set "NOW=%%A"
echo [!NOW!] 3ds Max exited. Restart in 5sec...
timeout /t 5 /nobreak >nul
goto restart