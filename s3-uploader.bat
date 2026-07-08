:: S3 Curl Uploader
:: 1.0.0
:: Vasyl Lukianenko
:: 3DGROUND
:: https://3dground.net

@echo off
setlocal

set input=%~1

set localFile=
set bucket=
set region=
set s3key=
set accessKey=
set secretKey=
set logFile=
set curlExe=%~dp0curl.exe
set statusFile=%TEMP%\s3-upload-%RANDOM%-%RANDOM%.status
set responseFile=%TEMP%\s3-upload-%RANDOM%-%RANDOM%.response
set errorFile=%TEMP%\s3-upload-%RANDOM%-%RANDOM%.error

for /f "tokens=1,2,3,4,5,6,7 delims=;" %%A in ("%input%") do (
	set localFile=%%A
	set bucket=%%B
	set region=%%C
	set s3key=%%D
	set accessKey=%%E
	set secretKey=%%F
	set logFile=%%G
)

if "%logFile%"=="" set logFile=%TEMP%\s3-upload-%RANDOM%-%RANDOM%.log

if "%localFile%"=="" (
	echo Error: local file is not specified
	echo Error: local file is not specified>"%logFile%"
	exit /b 2
)

if "%bucket%"=="" (
	echo Error: S3 bucket is not specified
	echo Error: S3 bucket is not specified>"%logFile%"
	exit /b 2
)

if "%region%"=="" (
	echo Error: AWS region is not specified
	echo Error: AWS region is not specified>"%logFile%"
	exit /b 2
)

if "%s3key%"=="" (
	echo Error: S3 object key is not specified
	echo Error: S3 object key is not specified>"%logFile%"
	exit /b 2
)

if "%accessKey%"=="" (
	echo Error: AWS access key is not specified
	echo Error: AWS access key is not specified>"%logFile%"
	exit /b 2
)

if "%secretKey%"=="" (
	echo Error: AWS secret key is not specified
	echo Error: AWS secret key is not specified>"%logFile%"
	exit /b 2
)

if not exist "%localFile%" (
	echo Error: file not found: "%localFile%"
	echo Error: file not found: "%localFile%">"%logFile%"
	exit /b 3
)

if not exist "%curlExe%" (
	echo Error: local curl.exe not found: "%curlExe%"
	echo Error: local curl.exe not found: "%curlExe%">"%logFile%"
	exit /b 4
)

"%curlExe%" -sS -X PUT -T "%localFile%" --user "%accessKey%:%secretKey%" --aws-sigv4 "aws:amz:%region%:s3" -w "%%{http_code}" -o "%responseFile%" "https://%bucket%.s3.%region%.amazonaws.com/%s3key%" > "%statusFile%" 2> "%errorFile%"

if errorlevel 1 (
	echo CURL_ERROR:>"%logFile%"
	if exist "%errorFile%" type "%errorFile%">>"%logFile%"
	echo.>>"%logFile%"
	echo S3_RESPONSE:>>"%logFile%"
	if exist "%responseFile%" type "%responseFile%">>"%logFile%"
	echo.>>"%logFile%"
	echo CURL_EXIT_CODE:%errorlevel%>>"%logFile%"
	echo Error: upload failed: "%localFile%"
	type "%logFile%"
	del "%statusFile%" >nul 2>nul
	del "%responseFile%" >nul 2>nul
	del "%errorFile%" >nul 2>nul
	exit /b 10
)

set httpStatus=
if exist "%statusFile%" set /p httpStatus=<"%statusFile%"
del "%statusFile%" >nul 2>nul

if "%httpStatus%"=="" (
	echo CURL_ERROR:>"%logFile%"
	if exist "%errorFile%" type "%errorFile%">>"%logFile%"
	echo.>>"%logFile%"
	echo S3_RESPONSE:>>"%logFile%"
	if exist "%responseFile%" type "%responseFile%">>"%logFile%"
	echo.>>"%logFile%"
	echo Error: curl did not return HTTP status.>>"%logFile%"
	echo Error: upload failed: "%localFile%"
	type "%logFile%"
	del "%responseFile%" >nul 2>nul
	del "%errorFile%" >nul 2>nul
	exit /b 10
)

echo S3_RESPONSE:>"%logFile%"
if exist "%responseFile%" type "%responseFile%">>"%logFile%"
echo.>>"%logFile%"
echo CURL_ERROR:>>"%logFile%"
if exist "%errorFile%" type "%errorFile%">>"%logFile%"
echo.>>"%logFile%"
echo HTTP_STATUS:%httpStatus%>>"%logFile%"

if %httpStatus% GEQ 200 if %httpStatus% LSS 300 (
echo Success: uploaded "%localFile%" to "s3://%bucket%/%s3key%"
del "%responseFile%" >nul 2>nul
del "%errorFile%" >nul 2>nul
exit /b 0
)

echo Error: upload failed with HTTP status %httpStatus%: "%localFile%"
type "%logFile%"
del "%responseFile%" >nul 2>nul
del "%errorFile%" >nul 2>nul
exit /b 10
