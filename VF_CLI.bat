@echo off
title VineFlower 1.11.1 CLI
setlocal enabledelayedexpansion
cls

echo ================================================================================================
echo ^|^| VineFlower 1.11.1 - Decompile Java classes extracted from .JAR files ^| CLI Wrapper by Xeon ^|^|
echo ================================================================================================

Checking for Java installation...
where java >nul 2>&1
if errorlevel 1 (
  echo ERROR: Java installation not found.
  echo Get Java at: https://www.oracle.com/java/technologies/downloads/
  pause
  exit /b 1
)
java -version 2>&1
echo.
echo ================================================================================================
set "SCRIPT_DIR=%~dp0"
set "OUT_DIR=%SCRIPT_DIR%out"
if exist "%OUT_DIR%" (
  echo Clearing existing output folder: "%OUT_DIR%"
  rd /s /q "%OUT_DIR%"
)
echo Creating output structure under "%OUT_DIR%"
mkdir "%OUT_DIR%\sources" 2>nul
mkdir "%OUT_DIR%\classes" 2>nul
echo.

set /p "IN_PATH=Enter path to .JAR or classes dir: "
if "%IN_PATH%"=="" exit /b 0

for %%I in ("%IN_PATH%") do set "PROJECT=%%~nI"
set "SRC_DIR=%OUT_DIR%\sources\%PROJECT%"
set "CLS_DIR=%OUT_DIR%\classes\%PROJECT%"
mkdir "%SRC_DIR%" 2>nul
mkdir "%CLS_DIR%" 2>nul
echo Sources directory: "%SRC_DIR%"
echo Classes directory: "%CLS_DIR%"
echo.

if /I "%IN_PATH:~-4%"==".jar" (
  pushd "%CLS_DIR%"
  jar xf "%IN_PATH%"
  popd
) else (
  echo Using existing folder "%IN_PATH%" as classes input.
  set "CLS_DIR=%IN_PATH%"
)
echo.

echo Running VineFlower decompiler...
set "JAVA_OPTS=--add-opens=java.base/java.lang.reflect=ALL-UNNAMED"
java %JAVA_OPTS% -jar "%SCRIPT_DIR%vineflower-1.11.1.jar" "%CLS_DIR%" "%SRC_DIR%"
if errorlevel 1 (
  echo ERROR during decompilation!
  pause
  exit /b 1
)
echo Decompilation complete, sources in "%SRC_DIR%"
echo.

echo Scanning for dependencies and Java version...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scan-sources.ps1" ^
  -SourceDir "%SRC_DIR%" -ClassDir "%CLS_DIR%"
if errorlevel 1 (
  echo ERROR during scanning!
  pause
  exit /b 1
)

echo.
set /p "DL=Download found JARs into %SRC_DIR%\libs? (Y/N): "
if /I "%DL%"=="Y" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%download-libs.ps1" ^
    -SourceDir "%SRC_DIR%" -ClassDir "%CLS_DIR%" -Project "%PROJECT%"
)

echo.
echo All steps complete!  Press any key to exit.
pause
