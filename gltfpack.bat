:: GLTF Packer
:: 1.0.0
:: Vasyl Lukianenko 
:: 3DGROUND
:: https://3dground.net

echo off
cls

set input=%1
set gltf=
set glb=
set glb2=

for /f "tokens=1,2,3 delims=;" %%i in (%input%) do (
	set gltf=%%i
	set glb=%%j
	set glb2=%%k
)

gltfpack.exe -noq -i "%gltf%" -o "%glb%"
gltfpack.exe -noq -vtf -vnf -vpf -vc 16 -vn 16 -vp 16 -vt 16 -tc -tl 2048 -i "%gltf%" -o "%glb2%"


for %%a in ("%gltf%") do set "folder=%%~dpa"
timeout /t 2 /nobreak > nul & rmdir /s /q "%folder%"