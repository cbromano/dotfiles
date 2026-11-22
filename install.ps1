#Requires -RunAsAdministrator
############################
# Sets up a Windows machine (the native layer; WSL gets ../ubuntu/install.sh):
#   1. Installs winget packages and apps       (winget.txt)
#   2. Links config files into place           (PowerShell profile, Terminal, bat, ruff, ssh, VS Code)
#      and sets Windows preferences          (settings.ps1)
#   3. Installs global npm/uv tools, AI agent skills, VS Code extensions, fonts
#
# Run from an elevated PowerShell:  Set-ExecutionPolicy Bypass -Scope Process; .\windows\install.ps1
# Safe to re-run: steps check before changing anything, and replaced files
# are backed up to ~\.dotfiles_backup\<timestamp>\
############################

# -NoInput: never wait for a person (test machines): skips the computer-name and git
# identity prompts, the GitHub login, and the sign-in pauses
param([switch]$NoInput)
$ErrorActionPreference = 'Stop'

# The prompts hardcode ~\dotfiles, so refuse to run from anywhere else
$dotfiledir = Split-Path -Parent $PSScriptRoot
if ((Resolve-Path $dotfiledir).Path -ne (Join-Path $HOME 'dotfiles')) {
    Write-Host "This repo must live at $HOME\dotfiles (currently running from $dotfiledir)." -ForegroundColor Red
    Write-Host "Clone it there and re-run:  git clone https://github.com/cbromano/dotfiles/tree/myWindowsDotfile $HOME\dotfiles"
    exit 1
}
. "$PSScriptRoot\helpers.ps1"
Set-Location $dotfiledir

# --- winget packages and apps
# Snapshot the Desktop shortcuts: installers add more, and only those are removed at the end
$desktopBefore = @(Get-ChildItem "$HOME\Desktop\*.lnk", "$env:PUBLIC\Desktop\*.lnk" -ErrorAction SilentlyContinue).FullName
$packages = Read-Manifest "$PSScriptRoot\winget.txt"
$installed = Get-CommandOutput { winget list --accept-source-agreements }
foreach ($id in $packages) {
    if ($installed -match [regex]::Escape($id)) { Write-Info "$id is already installed. Skipping."; continue }
    # --no-upgrade: an app that's installed but newer upstream (or self-updated past winget's
    # record) must not get its upgrade installer run here - that's update_all's job, and
    # upgrade installers can hang on a running app
    $result = Get-CommandOutput { winget install --id $id --exact --silent --no-upgrade --accept-source-agreements --accept-package-agreements }
    # Store apps don't show in `winget list`, so some land here every run
    if ($result -match 'already installed') { Write-Info "$id is already installed. Skipping."; continue }
    if ($result -match 'Successfully installed') { Write-Info "Installed $id."; continue }
    # The exit code isn't reliable (portable packages, installers that return early), so check the package list
    if (-not ((Get-CommandOutput { winget list --id $id --exact }) -match [regex]::Escape($id))) {
        Write-Warn "$id is not registered with winget yet (its installer may still be running) - re-run the script later to check."
    }
}
Update-Path   # tools installed above become callable from here on


if (-not $NoInput) {
    Pause-For 'Sign in to Google Chrome.'
    Pause-For 'Sign in to Google Drive.'
    Pause-For 'Sign in to Discord.'
    Pause-For 'Optional: to SSH into this PC, see "SSH into this PC" in windows\README.md.'
    Pause-For 'Open PowerToys and set up a FancyZones layout.'
    Pause-For 'Sign in to your accounts (GitHub Copilot, etc.) within VS Code.'
}

Write-Host ''
Write-Info 'Installation Complete!'
if (Test-Path $script:BackupDir) { Write-Info "Files replaced by this run were backed up to $script:BackupDir" }
