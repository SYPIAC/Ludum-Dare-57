@echo off
echo Building web export for itch.io...

REM Create web directory if it doesn't exist
if not exist web mkdir web
if not exist web\js mkdir web\js

REM Remove old game.love if it exists
if exist web\game.love del web\game.love

REM Create the game.love file
powershell -Command "Compress-Archive -Force -Path main.lua, conf.lua -DestinationPath web\game.zip"
rename web\game.zip game.love

REM Check if all necessary web files exist
if not exist web\index.html echo Warning: Missing index.html in web folder
if not exist web\style.css echo Warning: Missing style.css in web folder
if not exist web\game.js echo Warning: Missing game.js in web folder
if not exist web\js\love.js echo Warning: Missing js\love.js in web folder

REM Create a zip file for itch.io upload
if exist web_export.zip del web_export.zip
powershell -Command "Compress-Archive -Force -Path web\* -DestinationPath web_export.zip"

echo Build complete! web_export.zip is ready to upload to itch.io.
echo Files are also available in the web folder.
pause 