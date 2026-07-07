:: S3 Curl Uploader
:: 1.0.0
:: Vasyl Lukianenko
:: 3DGROUND
:: https://3dground.net

@echo off
cls

set input=%~1

set localFile=
set bucket=
set region=
set s3key=
set accessKey=
set secretKey=

for /f "tokens=1,2,3,4,5,6 delims=;" %%A in ("%input%") do (
	set localFile=%%A
	set bucket=%%B
	set region=%%C
	set s3key=%%D
	set accessKey=%%E
	set secretKey=%%F
)


if not exist "%localFile%" (
	echo File not found: "%localFile%"
	exit /b 1
)

c:\Windows\System32\curl.exe -X PUT -T "%localFile%" --user "%accessKey%:%secretKey%" --aws-sigv4 "aws:amz:%region%:s3" "https://%bucket%.s3.%region%.amazonaws.com/%s3key%"

if errorlevel 1 (
	echo Upload failed
	exit /b 1
)

echo Upload complete
exit /b 0