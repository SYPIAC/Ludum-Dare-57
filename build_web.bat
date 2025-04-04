@echo off
if exist game.love del game.love
powershell -Command "Compress-Archive -Force -Path main.lua, conf.lua -DestinationPath game.zip"
rename game.zip game.love
if not exist web mkdir web
node "%APPDATA%\npm\node_modules\love.js\index.js" game.love web
del game.love 