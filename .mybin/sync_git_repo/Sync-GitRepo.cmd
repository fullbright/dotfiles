@echo off
REM ============================================================================
REM Git Repository Sync - Command Line Wrapper
REM ============================================================================
REM This wrapper makes it easier to call the PowerShell script from cmd.exe
REM and handles parameter quoting automatically.
REM
REM Usage:
REM   Sync-GitRepo.cmd
REM   Sync-GitRepo.cmd "C:\path\to\repo"
REM   Sync-GitRepo.cmd "C:\path\to\repo" -DryRun
REM   Sync-GitRepo.cmd "C:\path\to\repo" -Verbose
REM   Sync-GitRepo.cmd "C:\path\to\repo" -CommitMessage "My message here"
REM ============================================================================

setlocal enabledelayedexpansion

REM Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%Sync-GitRepo.ps1"

REM Check if PowerShell script exists
if not exist "%PS_SCRIPT%" (
    echo ERROR: Cannot find Sync-GitRepo.ps1 in %SCRIPT_DIR%
    exit /b 1
)

REM Default values
set "REPO_PATH=%CD%"
set "LOG_PATH=%SCRIPT_DIR%Logs\git-sync.log"
set "COMMIT_MSG=Auto-sync: Local changes committed at {timestamp}"
set "EXTRA_ARGS="

REM Parse arguments
set "ARG_COUNT=0"
:parse_args
if "%~1"=="" goto :done_parsing
set /a ARG_COUNT+=1

REM Check for switches
if /i "%~1"=="-DryRun" (
    set "EXTRA_ARGS=!EXTRA_ARGS! -DryRun"
    shift
    goto :parse_args
)
if /i "%~1"=="-Verbose" (
    set "EXTRA_ARGS=!EXTRA_ARGS! -Verbose"
    shift
    goto :parse_args
)
if /i "%~1"=="-CommitMessage" (
    set "COMMIT_MSG=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="-LogPath" (
    set "LOG_PATH=%~2"
    shift
    shift
    goto :parse_args
)

REM First positional argument is repo path
if !ARG_COUNT! equ 1 (
    set "REPO_PATH=%~1"
)

shift
goto :parse_args

:done_parsing

REM Display configuration
echo ============================================================================
echo Git Repository Sync
echo ============================================================================
echo Repository: %REPO_PATH%
echo Log File:   %LOG_PATH%
echo Commit Msg: %COMMIT_MSG%
if not "!EXTRA_ARGS!"=="" echo Options:    !EXTRA_ARGS!
echo ============================================================================
echo.

REM Execute PowerShell script with proper quoting
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%PS_SCRIPT%" ^
    -RepoPath "%REPO_PATH%" ^
    -LogPath "%LOG_PATH%" ^
    -CommitMessage "%COMMIT_MSG%" ^
    %EXTRA_ARGS%

set "EXIT_CODE=%ERRORLEVEL%"

if %EXIT_CODE% equ 0 (
    echo.
    echo ============================================================================
    echo Sync completed successfully
    echo ============================================================================
) else (
    echo.
    echo ============================================================================
    echo Sync failed with error code: %EXIT_CODE%
    echo ============================================================================
)

exit /b %EXIT_CODE%