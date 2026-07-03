:: Great Catalog Merger
:: 1.1.1
:: Vasyl Lukianenko 
:: 3DGROUND
:: https://3dground.net

echo off
cls

set input=%1
set url=
set file=

for /f "tokens=1,2 delims=;" %%I in (%input%) do (
	set url=%%I
	set file=%%J
)

c:\Windows\System32\curl.exe --progress-bar --ssl-no-revoke -A "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64)" -L -o "%file%" "%url%" 

exit 0