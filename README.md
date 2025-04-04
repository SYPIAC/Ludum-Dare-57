# LÖVE Hello World

A simple Hello World project made with LÖVE 11.5.

## How to Run

### Method 1: Direct Run
1. Open a command prompt or PowerShell
2. Navigate to this project directory
3. Run the command: `"C:\Program Files\LOVE\love.exe" .`

### Method 2: Create .love File
1. Select all files in this directory
2. Add them to a ZIP archive
3. Rename the .zip extension to .love
4. Double-click the .love file to run

### Method 3: Use the Executable
1. Simply double-click on `bin\HelloWorld.exe` to run the game
2. The executable and all required DLL files are in the bin folder

### Method 4: Rebuild the Executable
1. Run the `build.bat` script
2. This will create a new executable in the bin folder based on the current source files

### Method 5: Web Export (for itch.io)
1. Run the `build_web.bat` script
2. This will create a web_export.zip file ready for uploading to itch.io
3. The web export files are also available in the web folder

## Project Structure
- `main.lua` - Main game code
- `conf.lua` - LÖVE configuration
- `build.bat` - Script to build the executable
- `build_web.bat` - Script to build the web export
- `bin/` - Contains the executable and DLL files
- `web/` - Contains the web export files

## Controls
- Press ESC to quit the application 