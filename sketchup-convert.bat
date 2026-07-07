:: Sketchup Converter
:: 1.0.0
:: Vasyl Lukianenko 
:: 3DGROUND
:: https://3dground.net

echo off

cls

set "currentDate=%DATE%"
set "currentTime=%TIME%"
set "timestamp=%currentDate%_%currentTime%"
set "timestamp=%timestamp::=-%"
set "timestamp=%timestamp: =_%"
set "timestamp=%timestamp:/=-%"
set "timestamp=%timestamp:,=-%"

set input=%1
set sketchup=
set glb=
set skp=
set script=c:\temp\sketchup_ruby_%timestamp%.rb

for /f "tokens=1,2,3 delims=;" %%i in (%input%) do (
	set sketchup=%%i
	set glb=%%j
	set skp=%%k
)

::echo File: %skp%>ruby_log.txt

::Write Ruby Script

echo begin>%script%
echo model = Sketchup.active_model>>%script%
echo model.import("%glb%", show_summary: false)>>%script%
::echo view = model.active_view>>%script%
::echo view.zoom_extents>>%script%
echo model.save("%skp%")>>%script%
echo spawn("taskkill /F /IM SketchUp.exe")>>%script%
::echo Sketchup.quit>>%script%
echo end>>%script%

::Run Sketchup
taskkill /F /IM SketchUp.exe
"%sketchup%" "C:\temp\template.skp" -RubyStartup "%script%" 
::>> ruby_log.txt
taskkill /F /IM SketchUp.exe
taskkill /F /IM BsSndRpt64.exe

del "%script%" /q > nul

::exit 0