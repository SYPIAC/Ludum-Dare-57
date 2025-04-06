@echo off
echo Building web export for FOREMAN...

if exist game.love del game.love
echo Creating game.love package...
powershell -Command "Compress-Archive -Force -Path main.lua, ui.lua, conf.lua, story.lua, img, sounds -DestinationPath game.zip"
if %ERRORLEVEL% NEQ 0 (
    echo Error creating game.zip
    pause
    exit /b 1
)

rename game.zip game.love
if %ERRORLEVEL% NEQ 0 (
    echo Error renaming file
    pause
    exit /b 1
)

if not exist web mkdir web
echo Running love.js to generate web version...
node "%APPDATA%\npm\node_modules\love.js\index.js" game.love web --title "FOREMAN"
if %ERRORLEVEL% NEQ 0 (
    echo Error generating web version
    pause
    exit /b 1
)

powershell -Command "(Get-Content web\index.html) -replace 'width=\"800\" height=\"600\"', 'width=\"520\" height=\"800\"' | Set-Content web\index.html"
if %ERRORLEVEL% NEQ 0 (
    echo Warning: Failed to update canvas dimensions
)

powershell -Command "(Get-Content web\index.html) -replace '<h1>.*?</h1>', '' | Set-Content web\index.html"
if %ERRORLEVEL% NEQ 0 (
    echo Warning: Failed to remove h1 tag
)

del game.love

echo Creating itch.io upload package...
if exist foreman_web.zip del foreman_web.zip
powershell -Command "Compress-Archive -Force -Path web\* -DestinationPath foreman_web.zip"
if %ERRORLEVEL% NEQ 0 (
    echo Error creating itch.io package
    pause
    exit /b 1
)

echo Build complete! 
echo - Web files in: web folder
echo - Itch.io package: foreman_web.zip
echo - Local testing: cd web ^& run_server.bat 