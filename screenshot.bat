@echo off

:: Путь для сохранения скриншота
set "screenshotPath=C:\temp\screenshot.png"

:: Создание скриншота с помощью PowerShell
powershell -command "Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds; $bitmap = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height; $graphics = [System.Drawing.Graphics]::FromImage($bitmap); $graphics.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size); $bitmap.Save('%screenshotPath%'); $graphics.Dispose(); $bitmap.Dispose();"

exit /b
