:: Blender Background Run
:: 1.0.0
:: Vasyl Lukianenko 
:: 3DGROUND
:: https://3dground.net

echo off

cls

set input=%1
set blender=
set file=
set script=

for /f "tokens=1,2,3 delims=;" %%i in (%input%) do (
	set blender=%%i
	set file=%%j
	set script=%%k
)

"%blender%" -b "%file%" -P "%script%"

rem exit 0