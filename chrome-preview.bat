:: Chrome
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

if %arg2%==1 (
	taskkill /f /im chrome.exe
)

start chrome.exe --guest --disable-features=Translate --disable-web-security --incognito "%arg1%"

exit 0