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

set "SCRIPT_DIR=%~dp0"
set "OUT_DIR=%SCRIPT_DIR%out"
if exist "%OUT_DIR%" rd /s /q "%OUT_DIR%"
mkdir "%OUT_DIR%" 2>nul
mkdir "%OUT_DIR%\sources" 2>nul
mkdir "%OUT_DIR%\classes" 2>nul
echo Base output directory: "%OUT_DIR%"
echo.

set /p "IN_PATH=Enter path to .JAR file or classes directory: "
if "%IN_PATH%"=="" (
    echo Operation canceled.
    exit /b 0
)

for %%I in ("%IN_PATH%") do set "PROJECT=%%~nI"

set "SRC_DIR=%OUT_DIR%\sources\%PROJECT%"
set "CLS_DIR=%OUT_DIR%\classes\%PROJECT%"
mkdir "%SRC_DIR%" 2>nul
mkdir "%CLS_DIR%" 2>nul
echo Sources will go into: "%SRC_DIR%"
echo Classes will go into: "%CLS_DIR%"
echo.

set "EXT=%IN_PATH:~-4%"
if /I "%EXT%"==".jar" (
    echo Extracting "%IN_PATH%" to "%CLS_DIR%"...
    pushd "%CLS_DIR%"
    jar xf "%IN_PATH%"
    popd
    echo Extraction done.
) else if exist "%IN_PATH%\*" (
    echo Using existing folder "%IN_PATH%" as classes input.
    set "CLS_DIR=%IN_PATH%"
    echo Extraction skipped.
) else (
    echo ERROR: "%IN_PATH%" is not a .jar file or an existing directory.
    pause
    exit /b 1
)
echo.

echo Running VineFlower decompiler...
set "JAVA_OPTS=--add-opens=java.base/java.lang.reflect=ALL-UNNAMED"
java %JAVA_OPTS% -jar "%SCRIPT_DIR%vineflower-1.11.1.jar" "%CLS_DIR%" "%SRC_DIR%"
if errorlevel 1 (
    echo ERROR: VineFlower reported a problem.
    pause
    exit /b 1
)
echo Decompilation done.
echo.

echo Searching Maven Central for dependencies and scanning Java class version...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scan-sources.ps1" -SourceDir "%SRC_DIR%" -ClassDir "%CLS_DIR%"
echo.
echo All steps complete! Press any key to exit.
pause
