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
set folder=

for /f "tokens=1,2,3,4 delims=;" %%i in (%input%) do (
	set blender=%%i
	set script=%%j
	set glb=%%k
	set blend=%%l
)

for %%i in ("%blend%") do set "folder=%%~dpi"
if exist "%folder%" (
    rmdir /s /q "%folder%"	
)
mkdir "%folder%"

"%blender%" -b -P "%script%" -- "%glb%" "%blend%"
if exist "%blend%1" (
	del "%blend%1"
)

::exit 0