@echo off
title VineFlower 1.11.1 CLI
setlocal enabledelayedexpansion
cls

echo ================================================================================================
echo ^|^| VineFlower 1.11.1 - Decompile Java classes extracted from .JAR files ^| CLI Wrapper by Xeon ^|^|
echo ================================================================================================

echo Checking for Java installation...
where java >nul 2>&1
if errorlevel 1 (
    echo.
    echo ERROR: Java installation not found.
    echo Get Java at: https://www.oracle.com/java/technologies/downloads/
    pause
    exit /b 1
)

java -version 2>&1
echo ================================================================================================
echo.

echo To begin, simply type or paste:
echo ------------------------------------------------------------
echo   1) The path to a .JAR file OR an extracted classes folder.
echo   2) The path to your desired output folder.
echo ------------------------------------------------------------
echo.

set /p IN_PATH=Enter path to .JAR file or classes directory: 
if "%IN_PATH%"=="" (
    echo.
    echo Operation canceled.
    exit /b 0
)

set "EXT=%IN_PATH:~-4%"
if /I "%EXT%"==".jar" (
    for %%I in ("%IN_PATH%") do (
        set "BASENAME=%%~nI"
        set "PARENT=%%~dpI"
    )
    set "IN_DIR=%PARENT%%BASENAME%_classes"
    echo Extracting "%IN_PATH%" to "%IN_DIR%"...
    mkdir "%IN_DIR%" >nul 2>&1
    powershell -NoProfile -Command "Expand-Archive -LiteralPath '%IN_PATH%' -DestinationPath '%IN_DIR%' -Force"
    if errorlevel 1 (
        echo.
        echo ERROR: Failed to extract JAR.
        pause
        exit /b 1
    )
) else if exist "%IN_PATH%\*" (
    set "IN_DIR=%IN_PATH%"
) else (
    echo.
    echo ERROR: "%IN_PATH%" is not a .jar file or an existing directory.
    pause
    exit /b 1
)

set /p OUT_DIR=Enter path for output decompiled folder: 
if "%OUT_DIR%"=="" (
    echo.
    echo Operation canceled.
    exit /b 0
)
if not exist "%OUT_DIR%" (
    echo.
    set /p CREATE_OUT=Output folder does not exist. Create it? [Y/N]: 
    if /i "%CREATE_OUT%"=="Y" (
        mkdir "%OUT_DIR%"
    ) else (
        echo Aborting.
        pause
        exit /b 1
    )
)

echo.
echo Running VineFlower decompiler...
echo =================================
java -jar "vineflower-1.11.1.jar" "%IN_DIR%" "%OUT_DIR%"

if errorlevel 1 (
    echo.
    echo ERROR: VineFlower reported a problem.
) else (
    echo.
    echo Success. Decompiled sources are in: "%OUT_DIR%".
)
echo =================================
pause
