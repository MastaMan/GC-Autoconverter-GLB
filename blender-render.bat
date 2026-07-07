:: Blender Background Render
:: 1.0.0
:: Vasyl Lukianenko 
:: 3DGROUND
:: https://3dground.net

echo off
cls

set input=%1
set blender=
set glb=
set script=
set rend=
set hdri=

for /f "tokens=1,2,3,4,5 delims=;" %%i in (%input%) do (
	set blender=%%i
    set script=%%j
	set glb=%%k    
	set rend=%%l
	set hdri=%%m
)


"%blender%" -b -P "%script%" -- "%glb%" "%rend%" "%hdri%"


::exit 0
