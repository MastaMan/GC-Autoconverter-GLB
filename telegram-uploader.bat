:: Telegram Curl Sender
:: 1.0.0
:: Vasyl Lukianenko
:: 3DGROUND
:: https://3dground.net


@echo off
setlocal

set input=%~1

set botToken=
set chatId=
set messageFile=
set imageFile=
set logFile=
set curlExe=%~dp0curl.exe
set statusFile=%TEMP%\telegram-send-%RANDOM%-%RANDOM%.status
set responseFile=%TEMP%\telegram-send-%RANDOM%-%RANDOM%.response
set errorFile=%TEMP%\telegram-send-%RANDOM%-%RANDOM%.error

for /f "tokens=1,2,3,4,5 delims=;" %%A in ("%input%") do (
	set botToken=%%A
	set chatId=%%B
	set messageFile=%%C
	set imageFile=%%D
	set logFile=%%E
)

if "%logFile%"=="" set logFile=%TEMP%\telegram-send-%RANDOM%-%RANDOM%.log

if "%botToken%"=="" (
	echo Error: Telegram bot token is not specified>"%logFile%"
	type "%logFile%"
	exit /b 2
)

if "%chatId%"=="" (
	echo Error: Telegram chat ID is not specified>"%logFile%"
	type "%logFile%"
	exit /b 2
)

if "%messageFile%"=="" (
	echo Error: Telegram message file is not specified>"%logFile%"
	type "%logFile%"
	exit /b 2
)

if not exist "%messageFile%" (
	echo Error: Telegram message file not found: "%messageFile%">"%logFile%"
	type "%logFile%"
	exit /b 3
)

if not exist "%curlExe%" (
	echo Error: local curl.exe not found: "%curlExe%">"%logFile%"
	type "%logFile%"
	exit /b 4
)

set apiMethod=sendMessage
if not "%imageFile%"=="" if exist "%imageFile%" set apiMethod=sendPhoto

if "%apiMethod%"=="sendPhoto" (
	"%curlExe%" -sS -X POST -H "Content-Type:multipart/form-data" -k -w "%%{http_code}" -o "%responseFile%" -F "chat_id=%chatId%" -F "photo=@%imageFile%" -F "caption=<%messageFile%" "https://api.telegram.org/bot%botToken%/%apiMethod%" > "%statusFile%" 2> "%errorFile%"
) else (
	"%curlExe%" -sS -X POST -H "Content-Type:multipart/form-data" -k -w "%%{http_code}" -o "%responseFile%" -F "chat_id=%chatId%" -F "text=<%messageFile%" "https://api.telegram.org/bot%botToken%/%apiMethod%" > "%statusFile%" 2> "%errorFile%"
)

set curlExit=%errorlevel%

echo TELEGRAM_METHOD:%apiMethod%>"%logFile%"
echo CURL_EXIT_CODE:%curlExit%>>"%logFile%"
echo CURL_ERROR:>>"%logFile%"
if exist "%errorFile%" type "%errorFile%">>"%logFile%"
echo.>>"%logFile%"
echo TELEGRAM_RESPONSE:>>"%logFile%"
if exist "%responseFile%" type "%responseFile%">>"%logFile%"
echo.>>"%logFile%"

set httpStatus=
if exist "%statusFile%" set /p httpStatus=<"%statusFile%"
echo HTTP_STATUS:%httpStatus%>>"%logFile%"

if not "%curlExit%"=="0" (
	type "%logFile%"
	del "%statusFile%" >nul 2>nul
	del "%responseFile%" >nul 2>nul
	del "%errorFile%" >nul 2>nul
	exit /b 10
)

if "%httpStatus%"=="" (
	echo Error: curl did not return HTTP status.>>"%logFile%"
	type "%logFile%"
	del "%statusFile%" >nul 2>nul
	del "%responseFile%" >nul 2>nul
	del "%errorFile%" >nul 2>nul
	exit /b 10
)

if %httpStatus% GEQ 200 if %httpStatus% LSS 300 (
	echo Success: Telegram message sent.>>"%logFile%"
	type "%logFile%"
	del "%statusFile%" >nul 2>nul
	del "%responseFile%" >nul 2>nul
	del "%errorFile%" >nul 2>nul
	exit /b 0
)

echo Error: Telegram API returned HTTP status %httpStatus%.>>"%logFile%"
type "%logFile%"
del "%statusFile%" >nul 2>nul
del "%responseFile%" >nul 2>nul
del "%errorFile%" >nul 2>nul
exit /b 10
