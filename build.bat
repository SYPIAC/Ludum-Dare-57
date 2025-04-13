@echo off
echo Building LOVE executable...

REM Create bin directory if it doesn't exist
if not exist bin mkdir bin

REM Remove old files if they exist
if exist bin\game.love del bin\game.love
if exist bin\HelloWorld.exe del bin\HelloWorld.exe

REM Create the game.love file
powershell -Command "Compress-Archive -Force -Path main.lua, ui.lua, conf.lua, story.lua, cards.lua, gameLogic.lua, img, sounds -DestinationPath game.zip"
rename game.zip game.love
move game.love bin\

REM Copy the LOVE executable and rename it
copy "C:\Program Files\LOVE\love.exe" "bin\HelloWorld.exe"

REM Append the .love file to the executable
copy /b bin\HelloWorld.exe+bin\game.love bin\HelloWorld.exe

REM Copy all necessary DLL files if they don't exist in bin
for %%F in ("C:\Program Files\LOVE\*.dll") do (
    if not exist bin\%%~nxF copy "%%F" "bin\%%~nxF"
)

REM Create bin.zip for distribution
echo Creating distribution package bin.zip...
if exist bin.zip del bin.zip
REM Package all the required files into a single zip for easy distribution
powershell -Command "Compress-Archive -Force -Path bin\* -DestinationPath bin.zip"
if %ERRORLEVEL% NEQ 0 (
    echo Error creating bin.zip package
) else (
    echo Distribution package bin.zip created successfully
)

echo Build complete! Executable is in the bin folder.

echo Starting game...
start "" "bin\HelloWorld.exe"