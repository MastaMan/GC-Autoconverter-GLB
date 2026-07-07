:: Contrast
:: 1.0.0
:: Vasyl Lukianenko 
:: 3DGROUND
:: https://3dground.net

echo off
cls

set input=%1
set in=
set out=


for /f "tokens=1,2,3,4,5 delims=;" %%i in (%input%) do (
	set in=%%i
    set out=%%j
)

convert.exe "%in%" -sigmoidal-contrast 7x56%% "%out%"

::exit 0
