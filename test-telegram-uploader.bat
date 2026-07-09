@echo off
cls
setlocal

set botToken=%TELEGRAM_BOT_TOKEN%
set chatId=%TELEGRAM_CHAT_ID%
set messageFile=%TEMP%\telegram-test-message.txt
set logFile=%TEMP%\telegram-test-log.txt
set imageFile=%~dp0api-error.jpg

if "%botToken%"=="" (
	set /p botToken=Telegram bot token: 
)

if "%chatId%"=="" (
	set /p chatId=Telegram chat ID: 
)

echo GC Autoconverter GLB Telegram BAT test>"%messageFile%"
echo.
echo Testing Telegram upload...
echo Log file: "%logFile%"
echo.

call "%~dp0telegram-uploader.bat" "%botToken%;%chatId%;%messageFile%;%imageFile%;%logFile%"

echo.
echo ---------------- LOG ----------------
if exist "%logFile%" type "%logFile%"
echo -------------------------------------
echo.

del "%messageFile%" >nul 2>nul
pause
