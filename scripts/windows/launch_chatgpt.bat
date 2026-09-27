@echo off
setlocal enabledelayedexpansion

:: ==============================================================================
:: ChatGPT & Codex Windows Launcher
:: 启动 PowerShell 执行动态探测与启动逻辑
:: ==============================================================================

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch_chatgpt.ps1"
