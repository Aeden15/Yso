@echo off
REM Wrapper for sync_workspace.ps1 that bypasses the PowerShell execution policy.
REM Usage:  sync push            - copies repo -> Desktop
REM         sync pull            - copies Desktop -> repo
REM         sync push -DryRun    - preview without copying
where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
  pwsh -ExecutionPolicy Bypass -File "%~dp0sync_workspace.ps1" %*
) else (
  powershell -ExecutionPolicy Bypass -File "%~dp0sync_workspace.ps1" %*
)
