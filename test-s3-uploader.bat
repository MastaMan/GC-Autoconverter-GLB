@echo off
cls
set AWS_ACCESS_KEY_ID=
set AWS_SECRET_ACCESS_KEY=
call s3-uploader.bat "c:\Projects\Scripts\GC-Autoconverter-GLB\7za.exe;dev-autoconverter;eu-central-1;7za.exe;%AWS_ACCESS_KEY_ID%;%AWS_SECRET_ACCESS_KEY%;%TEMP%\uploader_log.txt"

pause
