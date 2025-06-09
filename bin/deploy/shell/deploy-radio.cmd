@echo off

REM Accept an optional parameter for file extension
set "fileext=%~1"

if not "%fileext%"==".lua" (
    echo No file extension specified or unsupported parameter. Proceeding with default behavior.
)

set tgt=RF2
set srcfolder=%FRSKY_RF2_GIT_SRC%
set dstfolder=%FRSKY_RADIO_SRC%

REM Extract the drive letter from dstfolder
for %%A in ("%dstfolder%") do set "driveLetter=%%~dA"

REM If .lua parameter is set, handle .lua files specifically
if "%fileext%"==".lua" (
    echo Removing all .lua files from target...
    for /r "%dstfolder%\%tgt%" %%F in (*.lua) do del "%%F"
    
    echo Syncing only .lua files to target...
    mkdir "%dstfolder%\%tgt%"
    xcopy "%srcfolder%\%tgt%\*.lua" "%dstfolder%\%tgt%" /h /i /c /k /e /r /y /j


) else (
    REM Remove the entire destination folder
    RMDIR "%dstfolder%\%tgt%" /S /Q

    REM Recreate the destination folder
    mkdir "%dstfolder%\%tgt%"
    
    REM Copy all files to the destination folder
    xcopy "%srcfolder%\%tgt%" "%dstfolder%\%tgt%" /h /i /c /k /e /r /y /j
)

REM Dismount the volume as the last step
fsutil volume dismount %driveLetter%

echo Script execution completed.

REM Unmount the drive using DevEject
echo Unmounting drive %driveLetter%...
removedrive %driveLetter% 
