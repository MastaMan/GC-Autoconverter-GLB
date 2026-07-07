:: Get Render
:: 1.0.0
:: Vasyl Lukianenko 
:: 3DGROUND
:: https://3dground.net

echo off
cls

set input=%1
set arg1=
set arg2=

for /f "tokens=1,2 delims=;" %%I in (%input%) do (
	set arg1=%%I
	set arg2=%%J
)

echo [index] > "%arg2%"

findstr /i /m "vrender" "%arg1%" > nul
if %errorlevel%==0 (
	echo render=VRay >> "%arg2%"
)

findstr /i /m "coronamax" "%arg1%" > nul
if %errorlevel%==0 (
	echo render=Corona >> "%arg2%"
) 

exit 0